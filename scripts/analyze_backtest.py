#!/usr/bin/env python3
"""Summarize closed trades from a MetaTrader 5 HTML tester report."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict, deque
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path


class TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self._row: list[str] | None = None
        self._cell: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "tr":
            self._row = []
        elif tag in {"td", "th"} and self._row is not None:
            self._cell = []

    def handle_data(self, data: str) -> None:
        if self._cell is not None:
            self._cell.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag in {"td", "th"} and self._cell is not None and self._row is not None:
            self._row.append(" ".join("".join(self._cell).split()))
            self._cell = None
        elif tag == "tr" and self._row is not None:
            self.rows.append(self._row)
            self._row = None


def number(value: str) -> float:
    return float(value.replace(" ", "").replace("\xa0", "") or 0)


def stats(trades: list[dict]) -> dict:
    values = [trade["net"] for trade in trades]
    gross_profit = sum(value for value in values if value > 0)
    gross_loss = -sum(value for value in values if value < 0)
    return {
        "trades": len(values),
        "net": round(sum(values), 2),
        "gross_profit": round(gross_profit, 2),
        "gross_loss": round(gross_loss, 2),
        "profit_factor": None if gross_loss == 0 else round(gross_profit / gross_loss, 6),
        "wins": sum(value > 0 for value in values),
        "losses": sum(value < 0 for value in values),
        "flat": sum(value == 0 for value in values),
        "win_rate_pct": None if not values else round(100 * sum(value > 0 for value in values) / len(values), 2),
    }


def classify_exit(comment: str) -> str:
    lowered = comment.lower()
    if "time_exit" in lowered:
        return "time_exit"
    if lowered.startswith("sl ") or lowered == "sl":
        return "stop_loss"
    if lowered.startswith("tp ") or lowered == "tp":
        return "take_profit"
    return "other"


def parse_trades(report: Path) -> list[dict]:
    parser = TableParser()
    parser.feed(report.read_text(encoding="utf-16" if report.read_bytes().startswith(b"\xff\xfe") else "utf-8", errors="replace"))
    header = ["Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price", "Order", "Commission", "Swap", "Profit", "Balance", "Comment"]
    try:
        start = next(index for index, row in enumerate(parser.rows) if row == header) + 1
    except StopIteration as error:
        raise ValueError("Deals table was not found") from error

    open_entries: dict[str, deque[dict]] = defaultdict(deque)
    trades: list[dict] = []
    for row in parser.rows[start:]:
        if len(row) != len(header):
            continue
        values = dict(zip(header, row))
        if values["Direction"] not in {"in", "out"} or not values["Symbol"]:
            continue
        deal = {
            "time": datetime.strptime(values["Time"], "%Y.%m.%d %H:%M:%S"),
            "symbol": values["Symbol"],
            "side": values["Type"],
            "volume": number(values["Volume"]),
            "price": number(values["Price"]),
            "commission": number(values["Commission"]),
            "swap": number(values["Swap"]),
            "profit": number(values["Profit"]),
            "comment": values["Comment"],
        }
        if values["Direction"] == "in":
            open_entries[deal["symbol"]].append(deal)
            continue
        if not open_entries[deal["symbol"]]:
            continue
        entry = open_entries[deal["symbol"]].popleft()
        trades.append(
            {
                "symbol": entry["symbol"],
                "side": entry["side"],
                "entry_time": entry["time"],
                "exit_time": deal["time"],
                "entry_hour": entry["time"].hour,
                "exit_type": classify_exit(deal["comment"]),
                "net": entry["commission"] + entry["swap"] + entry["profit"] + deal["commission"] + deal["swap"] + deal["profit"],
            }
        )
    return trades


def report_value(report: Path, label: str) -> str | None:
    parser = TableParser()
    parser.feed(report.read_text(encoding="utf-16" if report.read_bytes().startswith(b"\xff\xfe") else "utf-8", errors="replace"))
    for row in parser.rows:
        for index, value in enumerate(row[:-1]):
            if value == label:
                return row[index + 1]
    return None


def grouped(trades: list[dict], key) -> dict:
    groups: dict[str, list[dict]] = defaultdict(list)
    for trade in trades:
        groups[str(key(trade))].append(trade)
    return {name: stats(groups[name]) for name in sorted(groups, key=lambda item: int(item) if item.isdigit() else item)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    trades = parse_trades(args.report)
    result = {
        "report": str(args.report.resolve()),
        "history_quality": report_value(args.report, "History Quality:"),
        "overall": stats(trades),
        "by_entry_year": grouped(trades, lambda trade: trade["entry_time"].year),
        "by_entry_hour_server": grouped(trades, lambda trade: trade["entry_hour"]),
        "by_side": grouped(trades, lambda trade: trade["side"]),
        "by_exit_type": grouped(trades, lambda trade: trade["exit_type"]),
    }
    rendered = json.dumps(result, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)


if __name__ == "__main__":
    main()
