"""Run the read-only Phase 1 discovery loop and publish visible MT5 zones."""

from __future__ import annotations

import argparse
from dataclasses import asdict
import json
from pathlib import Path
import signal
import time

from .bridge import default_bridge_path, publish_zones
from .detector import DetectorConfig, discover_zones
from .mt5_adapter import MT5ReadOnlyAdapter
from .store import AlphaLabStore


DEFAULT_TERMINAL = Path(r"C:\Program Files\MetaTrader 5\terminal64.exe")
DEFAULT_DATA = Path(__file__).resolve().parents[1] / "data" / "phase1" / "alpha_lab.sqlite3"


def retry_delay_seconds(consecutive_errors: int, maximum: float = 10.0) -> float:
    """Short exponential reconnect delay for transient MT5 IPC failures."""
    return min(maximum, float(2 ** max(0, consecutive_errors - 1)))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--symbol", default="XAUUSD", help="requested or exact broker symbol")
    parser.add_argument("--terminal", type=Path, default=DEFAULT_TERMINAL)
    parser.add_argument("--bridge-file", type=Path, default=None)
    parser.add_argument("--database", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--interval", type=float, default=2.0)
    parser.add_argument("--bars", type=int, default=800)
    parser.add_argument("--round-step", type=float)
    parser.add_argument("--tick-lookback-minutes", type=int, default=15)
    parser.add_argument("--max-quote-age-seconds", type=int, default=120)
    parser.add_argument("--status-seconds", type=int, default=30)
    parser.add_argument("--once", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.interval < 0.5:
        raise SystemExit("--interval must be at least 0.5 seconds")
    if args.max_quote_age_seconds < 1:
        raise SystemExit("--max-quote-age-seconds must be positive")
    bridge_file = args.bridge_file or default_bridge_path()
    adapter = MT5ReadOnlyAdapter(args.terminal)
    store = AlphaLabStore(args.database)
    stopping = False
    connected = False

    def request_stop(_signum: int, _frame: object) -> None:
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGINT, request_stop)
    signal.signal(signal.SIGTERM, request_stop)
    try:
        symbol = ""
        config: DetectorConfig | None = None
        first_tick_start: int | None = None
        last_status_second = 0
        consecutive_errors = 0
        while not stopping:
            try:
                if not connected:
                    adapter.connect()
                    symbol = adapter.resolve_symbol(args.symbol)
                    spec = adapter.symbol_spec()
                    config = DetectorConfig(
                        symbol=symbol,
                        digits=spec["digits"],
                        point=spec["point"],
                        round_step=args.round_step,
                    )
                    connected = True

                bars = adapter.completed_m5_bars(args.bars)
                current_price, current_tick_msc = adapter.current_mid()
                generated_at = int(time.time())
                quote_age_seconds = max(0, generated_at - current_tick_msc // 1000)
                market_state = (
                    "LIVE"
                    if quote_age_seconds <= args.max_quote_age_seconds
                    else f"STALE_QUOTE_{quote_age_seconds}S"
                )
                if first_tick_start is None:
                    lookback_msc = args.tick_lookback_minutes * 60_000
                    first_tick_start = min(int(time.time() * 1000), current_tick_msc) - lookback_msc
                assert config is not None
                zones = discover_zones(bars, current_price, config)
                generated_at = publish_zones(
                    bridge_file,
                    zones,
                    generated_at=generated_at,
                    market_state=market_state,
                )
                inserted_observations = store.insert_observations(zones)

                last_tick_msc = store.last_tick_msc(symbol)
                tick_start = last_tick_msc if last_tick_msc is not None else first_tick_start
                ticks = adapter.ticks_since(tick_start)
                inserted_ticks = store.insert_ticks(ticks)
                labelled = store.label_matured(symbol, bars)
                recovered = consecutive_errors > 0
                consecutive_errors = 0

                if generated_at-last_status_second >= args.status_seconds or args.once or recovered:
                    last_status_second = generated_at
                    print(
                        json.dumps(
                            {
                                "status": "RECOVERED" if recovered else "ACTIVE",
                                "generated_at": generated_at,
                                "symbol": symbol,
                                "current_tick_msc": current_tick_msc,
                                "quote_age_seconds": quote_age_seconds,
                                "market_state": market_state,
                                "completed_m5_bars": len(bars),
                                "zones": len(zones),
                                "top_zone": zones[0].as_dict() if zones else None,
                                "inserted_observations": inserted_observations,
                                "inserted_ticks": inserted_ticks,
                                "new_labels": labelled,
                                "ledger": store.counts(),
                                "bridge_file": str(bridge_file),
                                "database": str(args.database),
                                "config": asdict(config),
                            },
                            sort_keys=True,
                        ),
                        flush=True,
                    )
                if args.once:
                    break
                time.sleep(args.interval)
            except RuntimeError as error:
                if args.once:
                    raise
                consecutive_errors += 1
                delay = retry_delay_seconds(consecutive_errors)
                print(
                    json.dumps(
                        {
                            "status": "RETRYING_MT5_IPC",
                            "error": str(error),
                            "consecutive_errors": consecutive_errors,
                            "retry_in_seconds": delay,
                            "bridge_file": str(bridge_file),
                        },
                        sort_keys=True,
                    ),
                    flush=True,
                )
                adapter.close()
                connected = False
                time.sleep(delay)
    finally:
        if connected:
            adapter.close()
        store.close()


if __name__ == "__main__":
    main()
