#!/usr/bin/env python3
"""Evaluate causal closed-bar exit hypotheses against an SniperFX audit journal."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

try:
    from analyze_backtest import parse_trades, stats
except ModuleNotFoundError:
    from scripts.analyze_backtest import parse_trades, stats


def details(value: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for item in value.split(";"):
        if "=" in item:
            key, raw = item.split("=", 1)
            parsed[key] = raw
    return parsed


def load_telemetry(journal: Path) -> list[dict]:
    pending: dict | None = None
    active: dict | None = None
    completed: list[dict] = []
    with journal.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            event = row["event"]
            data = details(row["details"])
            if event == "ORDER_SUBMIT" and row["reason"] == "PROGRESS":
                pending = {
                    "entry": float(data["entry"]),
                    "stop": float(data["stop"]),
                    "volume": float(data["volume"]),
                    "side": data["side"].lower(),
                    "net_r": float(data["net_r"]),
                    "efficiency": float(data["eff"]),
                    "slope": float(data["slope"]),
                    "impulse_quality": float(data["impulse_q"]),
                    "pullback_depth": float(data["depth"]),
                    "cost_r": float(data["cost_r"]),
                    "bars": {},
                }
            elif event == "DEAL" and row["reason"] == "ENTRY" and pending is not None:
                active = pending
                active["ticket"] = data["deal"]
                pending = None
            elif event == "POSITION_BAR" and active is not None:
                bar = int(data["bar"])
                # A partial entry candle can be logged more than once as bar zero.
                # Keep the latest closed candle for each elapsed-bar index.
                active["bars"][bar] = {
                    "close_r": float(data["close_r"]),
                    "favorable_r": float(data["favorable_r"]),
                    "adverse_r": float(data["adverse_r"]),
                }
            elif event == "DEAL" and row["reason"] == "EXIT" and active is not None:
                completed.append(active)
                active = None
    return completed


def simulate(trades: list[dict], telemetry: list[dict], contract_size: float, bar: int, threshold: float) -> dict:
    outcomes: list[dict] = []
    triggered = 0
    avoided_losses = 0
    sacrificed_winners = 0
    for trade, trace in zip(trades, telemetry):
        outcome = dict(trade)
        sample = trace["bars"].get(bar)
        if sample is not None and sample["close_r"] <= threshold:
            triggered += 1
            avoided_losses += trade["net"] < 0
            sacrificed_winners += trade["net"] > 0
            risk_cash = abs(trace["entry"] - trace["stop"]) * trace["volume"] * contract_size
            outcome["net"] = sample["close_r"] * risk_cash
        outcomes.append(outcome)
    result = stats(outcomes)
    result.update(
        {
            "bar": bar,
            "threshold_r": threshold,
            "triggered": triggered,
            "avoided_losing_trades": avoided_losses,
            "sacrificed_winning_trades": sacrificed_winners,
        }
    )
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("journal", type=Path)
    parser.add_argument("--contract-size", type=float, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    trades = parse_trades(args.report)
    telemetry = load_telemetry(args.journal)
    if len(trades) != len(telemetry):
        raise ValueError(f"trade/telemetry mismatch: {len(trades)} != {len(telemetry)}")
    policies = [
        simulate(trades, telemetry, args.contract_size, bar, threshold)
        for bar in (1, 2, 3)
        for threshold in (-0.2, -0.3, -0.4, -0.5)
    ]
    result = {
        "report": str(args.report.resolve()),
        "journal": str(args.journal.resolve()),
        "baseline": stats(trades),
        "policies": policies,
        "note": "Hypothetical exits use the recorded closed-bar R and supplied contract size; they exclude additional exit slippage.",
    }
    rendered = json.dumps(result, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)


if __name__ == "__main__":
    main()
