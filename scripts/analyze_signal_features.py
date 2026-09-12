#!/usr/bin/env python3
"""Compare pre-entry SniperFX features on chronological train/validation sets."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from analyze_backtest import parse_trades, stats
from analyze_position_telemetry import load_telemetry


FEATURES = (
    "net_r",
    "efficiency",
    "abs_slope",
    "impulse_quality",
    "pullback_depth",
    "cost_r",
)


def quantile(values: list[float], probability: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def summarize(records: list[dict]) -> dict:
    return stats([record["trade"] for record in records])


def feature_bins(training: list[dict], validation: list[dict], feature: str) -> dict:
    cuts = [quantile([record[feature] for record in training], probability) for probability in (0.25, 0.5, 0.75)]

    def bucket(value: float) -> int:
        return sum(value > cut for cut in cuts)

    result = {"training_cuts": [round(cut, 6) for cut in cuts], "bins": {}}
    for index in range(4):
        train_bin = [record for record in training if bucket(record[feature]) == index]
        validation_bin = [record for record in validation if bucket(record[feature]) == index]
        result["bins"][str(index + 1)] = {
            "training": summarize(train_bin),
            "validation": summarize(validation_bin),
        }
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("journal", type=Path)
    parser.add_argument("--training-through", type=int, default=2023)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    trades = parse_trades(args.report)
    telemetry = load_telemetry(args.journal)
    if len(trades) != len(telemetry):
        raise ValueError(f"trade/telemetry mismatch: {len(trades)} != {len(telemetry)}")

    records: list[dict] = []
    for trade, trace in zip(trades, telemetry):
        if trade["side"] != trace["side"]:
            raise ValueError("trade/telemetry side mismatch")
        record = dict(trace)
        record["abs_slope"] = abs(record["slope"])
        record["trade"] = trade
        records.append(record)
    training = [record for record in records if record["trade"]["entry_time"].year <= args.training_through]
    validation = [record for record in records if record["trade"]["entry_time"].year > args.training_through]
    result = {
        "training_through": args.training_through,
        "training": summarize(training),
        "validation": summarize(validation),
        "by_side": {
            side: {
                "training": summarize([record for record in training if record["side"] == side]),
                "validation": summarize([record for record in validation if record["side"] == side]),
            }
            for side in ("buy", "sell")
        },
        "features": {feature: feature_bins(training, validation, feature) for feature in FEATURES},
        "note": "Quartile boundaries are fitted only on the chronological training period, then reused unchanged on validation.",
    }
    rendered = json.dumps(result, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)


if __name__ == "__main__":
    main()
