"""Read-only adapter around MetaQuotes' MetaTrader5 Python package."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import Bar, Tick


class MT5ReadOnlyAdapter:
    def __init__(self, terminal_path: Path):
        try:
            import MetaTrader5 as mt5
        except ImportError as error:
            raise RuntimeError("MetaTrader5 package missing; run scripts/setup_alpha_lab.ps1") from error
        self.mt5 = mt5
        self.terminal_path = terminal_path
        self.symbol = ""

    def connect(self) -> None:
        if not self.mt5.initialize(path=str(self.terminal_path)):
            raise RuntimeError(f"MT5 initialize failed: {self.mt5.last_error()}")

    def close(self) -> None:
        self.mt5.shutdown()

    def resolve_symbol(self, requested: str) -> str:
        exact = self.mt5.symbol_info(requested)
        if exact is not None:
            self.symbol = requested
            if not self.mt5.symbol_select(requested, True):
                raise RuntimeError(f"symbol_select failed for {requested!r}: {self.mt5.last_error()}")
            return requested
        matches = [item.name for item in (self.mt5.symbols_get(f"*{requested}*") or ())]
        matches = sorted(set(matches))
        if len(matches) != 1:
            raise RuntimeError(f"symbol {requested!r} resolved to {matches}; use the exact broker symbol")
        self.symbol = matches[0]
        if not self.mt5.symbol_select(self.symbol, True):
            raise RuntimeError(f"symbol_select failed for {self.symbol!r}: {self.mt5.last_error()}")
        return self.symbol

    def symbol_spec(self) -> dict[str, Any]:
        info = self.mt5.symbol_info(self.symbol)
        if info is None:
            raise RuntimeError(f"symbol_info failed: {self.mt5.last_error()}")
        return {"digits": int(info.digits), "point": float(info.point)}

    def completed_m5_bars(self, count: int) -> list[Bar]:
        rates = self.mt5.copy_rates_from_pos(self.symbol, self.mt5.TIMEFRAME_M5, 1, count)
        if rates is None:
            raise RuntimeError(f"copy_rates_from_pos failed: {self.mt5.last_error()}")
        bars = [
            Bar(
                time=int(row["time"]),
                open=float(row["open"]),
                high=float(row["high"]),
                low=float(row["low"]),
                close=float(row["close"]),
                tick_volume=int(row["tick_volume"]),
            )
            for row in rates
        ]
        return sorted(bars, key=lambda bar: bar.time)

    def current_mid(self) -> tuple[float, int]:
        tick = self.mt5.symbol_info_tick(self.symbol)
        if tick is None or tick.ask <= tick.bid or tick.bid <= 0.0:
            raise RuntimeError(f"invalid latest tick: {tick}; last_error={self.mt5.last_error()}")
        return (float(tick.bid + tick.ask) / 2.0, int(tick.time_msc))

    def ticks_since(self, start_msc: int, limit: int = 200_000) -> list[Tick]:
        start = datetime.fromtimestamp(start_msc / 1000.0, tz=timezone.utc)
        rows = self.mt5.copy_ticks_from(self.symbol, start, limit, self.mt5.COPY_TICKS_ALL)
        if rows is None:
            raise RuntimeError(f"copy_ticks_from failed: {self.mt5.last_error()}")
        return [
            Tick(
                symbol=self.symbol,
                time_msc=int(row["time_msc"]),
                bid=float(row["bid"]),
                ask=float(row["ask"]),
                last=float(row["last"]),
                volume=float(row["volume_real"] if "volume_real" in rows.dtype.names else row["volume"]),
                flags=int(row["flags"]),
            )
            for row in rows
            if int(row["time_msc"]) >= start_msc
        ]
