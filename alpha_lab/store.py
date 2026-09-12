"""SQLite trial/tick ledger for Phase 1 discovery."""

from __future__ import annotations

import json
from pathlib import Path
import sqlite3

from .detector import label_four_bar_outcome
from .models import Bar, ResearchZone, Tick


SCHEMA = """
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS ticks (
    symbol TEXT NOT NULL,
    time_msc INTEGER NOT NULL,
    bid REAL NOT NULL,
    ask REAL NOT NULL,
    last REAL NOT NULL,
    volume REAL NOT NULL,
    flags INTEGER NOT NULL,
    PRIMARY KEY (symbol, time_msc, bid, ask, flags)
);
CREATE TABLE IF NOT EXISTS observations (
    event_id TEXT PRIMARY KEY,
    zone_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    decision_time INTEGER NOT NULL,
    direction INTEGER NOT NULL,
    source TEXT NOT NULL,
    state TEXT NOT NULL,
    entry REAL NOT NULL,
    stop REAL NOT NULL,
    low_price REAL NOT NULL,
    high_price REAL NOT NULL,
    atr REAL NOT NULL,
    research_score REAL NOT NULL,
    features_json TEXT NOT NULL,
    label_status TEXT NOT NULL DEFAULT 'PENDING',
    mfe_4r REAL,
    mae_4r REAL,
    first_hit TEXT
);
CREATE INDEX IF NOT EXISTS ix_observations_pending
ON observations(label_status, symbol, decision_time);
"""


class AlphaLabStore:
    def __init__(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.path = path
        self.connection = sqlite3.connect(path)
        self.connection.executescript(SCHEMA)

    def close(self) -> None:
        self.connection.close()

    def insert_ticks(self, ticks: list[Tick]) -> int:
        before = self.connection.total_changes
        self.connection.executemany(
            "INSERT OR IGNORE INTO ticks VALUES (?, ?, ?, ?, ?, ?, ?)",
            [(tick.symbol, tick.time_msc, tick.bid, tick.ask, tick.last, tick.volume, tick.flags) for tick in ticks],
        )
        self.connection.commit()
        return self.connection.total_changes - before

    def last_tick_msc(self, symbol: str) -> int | None:
        row = self.connection.execute("SELECT MAX(time_msc) FROM ticks WHERE symbol = ?", (symbol,)).fetchone()
        return int(row[0]) if row and row[0] is not None else None

    def insert_observations(self, zones: list[ResearchZone]) -> int:
        before = self.connection.total_changes
        self.connection.executemany(
            """
            INSERT OR IGNORE INTO observations (
                event_id, zone_id, symbol, decision_time, direction, source, state,
                entry, stop, low_price, high_price, atr, research_score, features_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    f"{zone.zone_id}:{zone.decision_time}",
                    zone.zone_id,
                    zone.symbol,
                    zone.decision_time,
                    zone.direction,
                    zone.source,
                    zone.state,
                    zone.entry,
                    zone.stop,
                    zone.low_price,
                    zone.high_price,
                    zone.atr,
                    zone.research_score,
                    json.dumps(zone.features, sort_keys=True, separators=(",", ":")),
                )
                for zone in zones
            ],
        )
        self.connection.commit()
        return self.connection.total_changes - before

    def label_matured(self, symbol: str, bars: list[Bar], target_r: float = 1.5) -> int:
        by_time = sorted(bars, key=lambda bar: bar.time)
        if len(by_time) < 4:
            return 0
        pending = self.connection.execute(
            """
            SELECT event_id, zone_id, decision_time, direction, source, state, entry,
                   stop, low_price, high_price, atr, research_score, features_json
            FROM observations
            WHERE label_status = 'PENDING' AND symbol = ? AND decision_time <= ?
            """,
            (symbol, by_time[-4].time),
        ).fetchall()
        labelled = 0
        for row in pending:
            future = [bar for bar in by_time if bar.time >= row[2]][:4]
            if len(future) < 4:
                continue
            zone = ResearchZone(
                zone_id=row[1],
                symbol=symbol,
                time_start=row[2],
                time_end=row[2] + 3600,
                low_price=row[8],
                high_price=row[9],
                direction=row[3],
                research_score=row[11],
                state=row[5],
                source=row[4],
                reason="stored",
                decision_time=row[2],
                entry=row[6],
                stop=row[7],
                atr=row[10],
                features=json.loads(row[12]),
            )
            outcome = label_four_bar_outcome(zone, future, target_r)
            self.connection.execute(
                """
                UPDATE observations
                SET label_status = 'LABELLED', mfe_4r = ?, mae_4r = ?, first_hit = ?
                WHERE event_id = ?
                """,
                (outcome["mfe_4r"], outcome["mae_4r"], outcome["first_hit"], row[0]),
            )
            labelled += 1
        self.connection.commit()
        return labelled

    def counts(self) -> dict[str, int]:
        ticks = self.connection.execute("SELECT COUNT(*) FROM ticks").fetchone()[0]
        observations = self.connection.execute("SELECT COUNT(*) FROM observations").fetchone()[0]
        labelled = self.connection.execute(
            "SELECT COUNT(*) FROM observations WHERE label_status = 'LABELLED'"
        ).fetchone()[0]
        return {"ticks": ticks, "observations": observations, "labelled": labelled}
