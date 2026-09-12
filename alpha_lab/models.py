"""Small dependency-free domain types shared by the Phase 1 tools."""

from __future__ import annotations

from dataclasses import asdict, dataclass


@dataclass(frozen=True, slots=True)
class Bar:
    time: int
    open: float
    high: float
    low: float
    close: float
    tick_volume: int = 0


@dataclass(frozen=True, slots=True)
class Tick:
    symbol: str
    time_msc: int
    bid: float
    ask: float
    last: float = 0.0
    volume: float = 0.0
    flags: int = 0


@dataclass(frozen=True, slots=True)
class ResearchZone:
    zone_id: str
    symbol: str
    time_start: int
    time_end: int
    low_price: float
    high_price: float
    direction: int
    research_score: float
    state: str
    source: str
    reason: str
    decision_time: int
    entry: float
    stop: float
    atr: float
    features: dict[str, float | str]

    def bridge_row(self, generated_at: int, market_state: str) -> dict[str, object]:
        return {
            "schema": "SFX_ALPHA_ZONE_V2",
            "generated_at": generated_at,
            "zone_id": self.zone_id,
            "symbol": self.symbol,
            "time_start": self.time_start,
            "time_end": self.time_end,
            "low_price": f"{self.low_price:.10f}",
            "high_price": f"{self.high_price:.10f}",
            "direction": self.direction,
            "research_score": f"{self.research_score:.6f}",
            "state": self.state,
            "source": self.source,
            "market_state": market_state,
            "reason": self.reason.replace(";", "|").replace("\r", " ").replace("\n", " "),
        }

    def as_dict(self) -> dict[str, object]:
        return asdict(self)
