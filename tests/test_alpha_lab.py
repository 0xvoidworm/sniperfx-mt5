from __future__ import annotations

import csv
from pathlib import Path
import sqlite3
import tempfile
import unittest

from alpha_lab.bridge import BRIDGE_FIELDS, publish_zones
from alpha_lab.detector import BUY, DetectorConfig, discover_zones, label_four_bar_outcome
from alpha_lab.models import Bar, ResearchZone, Tick
from alpha_lab.runner import retry_delay_seconds
from alpha_lab.store import AlphaLabStore


def synthetic_bars(count: int = 320, start: int = 1_760_000_000) -> list[Bar]:
    bars: list[Bar] = []
    price = 2_500.0
    for index in range(count):
        drift = 0.38 if index % 17 not in (0, 1, 2) else -0.22
        opened = price
        closed = price + drift
        bars.append(
            Bar(
                time=start + index * 300,
                open=opened,
                high=max(opened, closed) + 0.35,
                low=min(opened, closed) - 0.35,
                close=closed,
                tick_volume=100 + index,
            )
        )
        price = closed
    return bars


def sample_zone() -> ResearchZone:
    return ResearchZone(
        zone_id="ABC",
        symbol="XAUUSD",
        time_start=1_760_000_000,
        time_end=1_760_003_600,
        low_price=2_499.5,
        high_price=2_500.5,
        direction=BUY,
        research_score=0.75,
        state="WATCH",
        source="ROUND",
        reason="test",
        decision_time=1_760_000_300,
        entry=2_500.5,
        stop=2_499.0,
        atr=2.0,
        features={"efficiency": 0.7},
    )


class DetectorTests(unittest.TestCase):
    def test_mt5_ipc_retry_backoff_is_bounded(self) -> None:
        self.assertEqual([retry_delay_seconds(index) for index in range(1, 6)], [1.0, 2.0, 4.0, 8.0, 10.0])

    def test_discovers_visible_causal_zones(self) -> None:
        bars = synthetic_bars()
        zones = discover_zones(
            bars,
            bars[-1].close,
            DetectorConfig(symbol="XAUUSD", digits=2, point=0.01),
        )
        self.assertGreaterEqual(len(zones), 2)
        self.assertTrue(all(zone.time_end > zone.decision_time for zone in zones))
        self.assertTrue(all(0.05 <= zone.research_score <= 0.95 for zone in zones))
        self.assertIn("ROUND", {zone.source for zone in zones})

    def test_four_bar_path_label_preserves_barrier_order(self) -> None:
        zone = sample_zone()
        future = [
            Bar(zone.decision_time + index * 300, 2_500.6, 2_501.0 + index, 2_500.1, 2_500.8)
            for index in range(4)
        ]
        outcome = label_four_bar_outcome(zone, future, target_r=1.5)
        self.assertEqual(outcome["first_hit"], "TARGET")
        self.assertGreater(outcome["mfe_4r"], 1.5)


class PersistenceTests(unittest.TestCase):
    def test_bridge_and_ledger_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bridge = root / "alpha_zones.csv"
            zone = sample_zone()
            publish_zones(
                bridge,
                [zone],
                generated_at=1_760_000_999,
                market_state="STALE_QUOTE_600S",
            )
            with bridge.open(newline="", encoding="ascii") as stream:
                rows = list(csv.DictReader(stream, delimiter=";"))
            self.assertEqual(tuple(rows[0]), BRIDGE_FIELDS)
            self.assertEqual(rows[0]["schema"], "SFX_ALPHA_ZONE_V2")
            self.assertEqual(rows[0]["zone_id"], "ABC")
            self.assertEqual(rows[0]["market_state"], "STALE_QUOTE_600S")

            store = AlphaLabStore(root / "lab.sqlite3")
            try:
                self.assertEqual(store.insert_observations([zone]), 1)
                self.assertEqual(store.insert_observations([zone]), 0)
                self.assertEqual(
                    store.insert_ticks([Tick("XAUUSD", 1000, 2_500.0, 2_500.2)]),
                    1,
                )
                self.assertEqual(store.counts(), {"ticks": 1, "observations": 1, "labelled": 0})
                row = store.connection.execute("SELECT features_json FROM observations").fetchone()
                self.assertIn("efficiency", row[0])
            finally:
                store.close()


if __name__ == "__main__":
    unittest.main()
