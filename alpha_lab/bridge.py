"""Atomic publisher for the MQL5 FILE_COMMON visualization bridge."""

from __future__ import annotations

import csv
import os
from pathlib import Path
import time

from .models import ResearchZone


BRIDGE_FIELDS = (
    "schema",
    "generated_at",
    "zone_id",
    "symbol",
    "time_start",
    "time_end",
    "low_price",
    "high_price",
    "direction",
    "research_score",
    "state",
    "source",
    "market_state",
    "reason",
)


def default_bridge_path() -> Path:
    appdata = os.environ.get("APPDATA")
    if not appdata:
        raise RuntimeError("APPDATA is unavailable; pass --bridge-file explicitly")
    return Path(appdata) / "MetaQuotes" / "Terminal" / "Common" / "Files" / "SniperFX" / "alpha_zones.csv"


def publish_zones(
    path: Path,
    zones: list[ResearchZone],
    generated_at: int | None = None,
    market_state: str = "LIVE",
) -> int:
    generated_at = generated_at or int(time.time())
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", newline="", encoding="ascii", errors="strict") as stream:
        writer = csv.DictWriter(stream, fieldnames=BRIDGE_FIELDS, delimiter=";", lineterminator="\n")
        writer.writeheader()
        for zone in zones:
            writer.writerow(zone.bridge_row(generated_at, market_state))
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)
    return generated_at
