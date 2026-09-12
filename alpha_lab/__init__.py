"""SniperFX Phase 1 alpha-discovery components."""

from .detector import DetectorConfig, discover_zones, label_four_bar_outcome
from .models import Bar, ResearchZone, Tick

__all__ = [
    "Bar",
    "DetectorConfig",
    "ResearchZone",
    "Tick",
    "discover_zones",
    "label_four_bar_outcome",
]
