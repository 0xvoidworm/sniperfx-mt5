"""Causal Phase 1 discovery primitives and four-bar outcome labels.

These are research hypotheses, not trade recommendations.  Every calculation
uses completed M5 bars plus the latest observable quote supplied by the caller.
"""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha1
import math
from statistics import fmean
import time

from .models import Bar, ResearchZone


BUY = 1
SELL = -1


@dataclass(frozen=True, slots=True)
class DetectorConfig:
    symbol: str
    digits: int
    point: float
    pivot_left_right: int = 2
    atr_lookback: int = 14
    trend_lookback: int = 24
    zone_half_atr: float = 0.12
    stop_buffer_atr: float = 0.10
    directional_change_atr: float = 0.45
    max_distance_atr: float = 2.50
    future_bars: int = 12
    round_step: float | None = None
    max_zones: int = 8


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _stable_id(*parts: object) -> str:
    raw = "|".join(str(part) for part in parts).encode("utf-8")
    return sha1(raw).hexdigest()[:16].upper()


def true_range(current: Bar, previous_close: float) -> float:
    return max(
        current.high - current.low,
        abs(current.high - previous_close),
        abs(current.low - previous_close),
    )


def closed_atr(bars: list[Bar], lookback: int = 14) -> float:
    if len(bars) < 2:
        return 0.0
    sample = bars[-min(lookback, len(bars) - 1) :]
    first_index = len(bars) - len(sample)
    ranges = [true_range(bar, bars[index - 1].close) for index, bar in enumerate(sample, first_index)]
    return fmean(ranges) if ranges else 0.0


def trend_state(bars: list[Bar], lookback: int, atr: float) -> tuple[int, float, float]:
    if atr <= 0.0 or len(bars) < max(5, lookback):
        return 0, 0.0, 0.0
    closes = [bar.close for bar in bars[-lookback:]]
    count = len(closes)
    x_mean = (count - 1) / 2.0
    y_mean = fmean(closes)
    denominator = sum((index - x_mean) ** 2 for index in range(count))
    slope = sum((index - x_mean) * (value - y_mean) for index, value in enumerate(closes)) / denominator
    normalized_slope = slope / atr
    travelled = sum(abs(closes[index] - closes[index - 1]) for index in range(1, count))
    efficiency = abs(closes[-1] - closes[0]) / travelled if travelled > 0.0 else 0.0
    direction = BUY if normalized_slope > 0.015 else SELL if normalized_slope < -0.015 else 0
    return direction, normalized_slope, _clamp(efficiency, 0.0, 1.0)


def confirmed_pivots(bars: list[Bar], left_right: int) -> tuple[list[Bar], list[Bar]]:
    highs: list[Bar] = []
    lows: list[Bar] = []
    if len(bars) < left_right * 2 + 1:
        return highs, lows
    for index in range(left_right, len(bars) - left_right):
        window = bars[index - left_right : index + left_right + 1]
        center = bars[index]
        if all(center.high > bar.high for offset, bar in enumerate(window) if offset != left_right):
            highs.append(center)
        if all(center.low < bar.low for offset, bar in enumerate(window) if offset != left_right):
            lows.append(center)
    return highs, lows


def infer_round_step(symbol: str, digits: int, point: float) -> float:
    upper = symbol.upper()
    if "XAU" in upper:
        return 5.0
    if "XAG" in upper:
        return 0.5
    if digits >= 4:
        return 0.005
    if digits == 3:
        return 0.5
    return max(point * 500.0, point)


def _previous_utc_day_levels(bars: list[Bar]) -> tuple[tuple[float, int] | None, tuple[float, int] | None]:
    if not bars:
        return None, None
    latest_day = bars[-1].time // 86_400
    previous = [bar for bar in bars if bar.time // 86_400 < latest_day]
    if not previous:
        return None, None
    day = previous[-1].time // 86_400
    sample = [bar for bar in previous if bar.time // 86_400 == day]
    high_bar = max(sample, key=lambda bar: bar.high)
    low_bar = min(sample, key=lambda bar: bar.low)
    return (high_bar.high, high_bar.time), (low_bar.low, low_bar.time)


def last_directional_change(bars: list[Bar], threshold: float) -> tuple[int, float, int] | None:
    if not bars or threshold <= 0.0:
        return None
    mode = 0
    high = low = bars[0].close
    high_time = low_time = bars[0].time
    last_event: tuple[int, float, int] | None = None
    for bar in bars[1:]:
        price = bar.close
        if price > high:
            high, high_time = price, bar.time
        if price < low:
            low, low_time = price, bar.time
        if mode <= 0 and price >= low + threshold:
            mode = BUY
            high, high_time = price, bar.time
            last_event = (BUY, low, low_time)
        elif mode >= 0 and price <= high - threshold:
            mode = SELL
            low, low_time = price, bar.time
            last_event = (SELL, high, high_time)
    return last_event


def _zone_state(direction: int, low: float, high: float, current_price: float, latest: Bar) -> str:
    if low <= current_price <= high:
        return "TOUCHED"
    if direction == BUY:
        if current_price < low:
            return "INVALID"
        if latest.low <= high and latest.close > high:
            return "ACCEPTED"
    else:
        if current_price > high:
            return "INVALID"
        if latest.high >= low and latest.close < low:
            return "ACCEPTED"
    return "WATCH"


def discover_zones(bars: list[Bar], current_price: float, config: DetectorConfig) -> list[ResearchZone]:
    if len(bars) < max(config.trend_lookback, config.atr_lookback + 1) or current_price <= 0.0:
        return []
    bars = sorted(bars, key=lambda bar: bar.time)
    atr = closed_atr(bars, config.atr_lookback)
    if atr <= max(config.point, 0.0):
        return []
    trend, normalized_slope, efficiency = trend_state(bars, config.trend_lookback, atr)
    half_width = max(config.zone_half_atr * atr, config.point * 5.0)
    decision_time = bars[-1].time + 300
    time_end = max(decision_time, int(time.time())) + config.future_bars * 300
    raw: list[tuple[str, int, float, int, str]] = []

    step = config.round_step or infer_round_step(config.symbol, config.digits, config.point)
    floor_level = math.floor(current_price / step) * step
    ceil_level = floor_level if math.isclose(floor_level, current_price) else floor_level + step
    raw.extend(("ROUND", BUY, level, decision_time, f"step={step:g}") for level in {floor_level, floor_level - step})
    raw.extend(("ROUND", SELL, level, decision_time, f"step={step:g}") for level in {ceil_level, ceil_level + step})

    pivot_highs, pivot_lows = confirmed_pivots(bars, config.pivot_left_right)
    if pivot_lows:
        raw.append(("SWING", BUY, pivot_lows[-1].low, pivot_lows[-1].time, "confirmed_low"))
    if pivot_highs:
        raw.append(("SWING", SELL, pivot_highs[-1].high, pivot_highs[-1].time, "confirmed_high"))

    previous_high, previous_low = _previous_utc_day_levels(bars)
    if previous_low:
        raw.append(("PREV_DAY", BUY, previous_low[0], previous_low[1], "previous_utc_low"))
    if previous_high:
        raw.append(("PREV_DAY", SELL, previous_high[0], previous_high[1], "previous_utc_high"))

    dc = last_directional_change(bars[-min(240, len(bars)) :], config.directional_change_atr * atr)
    if dc:
        raw.append(("DIRECTIONAL_CHANGE", dc[0], dc[1], dc[2], "intrinsic_time_turn"))

    zones: list[ResearchZone] = []
    seen: set[tuple[int, int]] = set()
    for source, direction, center, formed_at, mechanism in raw:
        distance_atr = abs(current_price - center) / atr
        if distance_atr > config.max_distance_atr:
            continue
        low = center - half_width
        high = center + half_width
        state = _zone_state(direction, low, high, current_price, bars[-1])
        if state == "INVALID":
            continue
        rounded_center = int(round(center / max(config.point, 1e-12)))
        key = (direction, rounded_center)
        if key in seen:
            continue
        seen.add(key)
        alignment = 1.0 if trend == direction else 0.0 if trend == 0 else -0.5
        proximity = max(0.0, 1.0 - distance_atr / config.max_distance_atr)
        score = 0.38 + 0.22 * alignment + 0.20 * efficiency + 0.15 * proximity
        if source == "DIRECTIONAL_CHANGE":
            score += 0.05
        if state in {"TOUCHED", "ACCEPTED"}:
            score += 0.05
        score = _clamp(score, 0.05, 0.95)
        entry = high if direction == BUY else low
        stop = low - config.stop_buffer_atr * atr if direction == BUY else high + config.stop_buffer_atr * atr
        reason = (
            f"{mechanism}|trend={trend}|slope_atr={normalized_slope:.4f}|"
            f"eff={efficiency:.3f}|distance_atr={distance_atr:.3f}"
        )
        zones.append(
            ResearchZone(
                zone_id=_stable_id(config.symbol, source, direction, rounded_center, formed_at),
                symbol=config.symbol,
                time_start=formed_at,
                time_end=time_end,
                low_price=low,
                high_price=high,
                direction=direction,
                research_score=score,
                state=state,
                source=source,
                reason=reason,
                decision_time=decision_time,
                entry=entry,
                stop=stop,
                atr=atr,
                features={
                    "trend": trend,
                    "normalized_slope": normalized_slope,
                    "efficiency": efficiency,
                    "distance_atr": distance_atr,
                    "current_price": current_price,
                    "mechanism": mechanism,
                },
            )
        )
    zones.sort(key=lambda zone: (-zone.research_score, abs(current_price - zone.entry), zone.zone_id))
    return zones[: config.max_zones]


def label_four_bar_outcome(
    zone: ResearchZone,
    future_bars: list[Bar],
    target_r: float = 1.5,
) -> dict[str, float | str]:
    sample = sorted(future_bars, key=lambda bar: bar.time)[:4]
    risk = abs(zone.entry - zone.stop)
    if len(sample) < 4 or risk <= 0.0:
        raise ValueError("four completed future bars and positive risk are required")
    if zone.direction == BUY:
        mfe = max(bar.high - zone.entry for bar in sample) / risk
        mae = max(zone.entry - bar.low for bar in sample) / risk
    else:
        mfe = max(zone.entry - bar.low for bar in sample) / risk
        mae = max(bar.high - zone.entry for bar in sample) / risk

    first_hit = "NONE"
    for bar in sample:
        if zone.direction == BUY:
            target_hit = bar.high >= zone.entry + target_r * risk
            stop_hit = bar.low <= zone.stop
        else:
            target_hit = bar.low <= zone.entry - target_r * risk
            stop_hit = bar.high >= zone.stop
        if target_hit and stop_hit:
            first_hit = "AMBIGUOUS_SAME_BAR"
            break
        if target_hit:
            first_hit = "TARGET"
            break
        if stop_hit:
            first_hit = "STOP"
            break
    return {"mfe_4r": mfe, "mae_4r": mae, "first_hit": first_hit}
