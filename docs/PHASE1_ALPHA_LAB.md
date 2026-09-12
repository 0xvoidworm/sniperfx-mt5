# Phase 1 Alpha Lab and MT5 Overlay

Phase 1 adds a read-only Python discovery process, a persistent SQLite event/tick ledger, and a visible MT5 chart overlay. It does not submit, modify, or cancel orders.

## Data path

```text
MT5 completed M5 bars + bid/ask ticks
  -> Python causal feature detectors
  -> research zones + four-bar observations
  -> persistent SQLite ledger
  -> atomic FILE_COMMON CSV bridge
  -> MQL5 rectangles, labels, and heartbeat on the chart
```

The initial hypothesis sources are:

- `ROUND`: zones around symbol-aware round-price steps.
- `SWING`: the latest causally confirmed pivot high/low.
- `PREV_DAY`: previous UTC day high/low when present in the requested history.
- `DIRECTIONAL_CHANGE`: the latest intrinsic-time reversal anchor using an ATR-scaled threshold.

The `SCORE 0..100` displayed on the chart is a research ranking based on trend alignment, efficiency, proximity, source, and interaction state. It is explicitly **not a calibrated win probability**.

## Install once

```powershell
pwsh -NoProfile -File .\scripts\setup_alpha_lab.ps1
pwsh -NoProfile -File .\scripts\deploy_and_compile.ps1
```

## Run

Foreground:

```powershell
pwsh -NoProfile -File .\scripts\run_alpha_lab.ps1 -Symbol XAUUSD
```

Hidden background process:

```powershell
pwsh -NoProfile -File .\scripts\start_alpha_lab.ps1 -Symbol XAUUSD
```

Stop the background process:

```powershell
pwsh -NoProfile -File .\scripts\stop_alpha_lab.ps1
```

The broker symbol is resolved exactly when possible. If several prefix/suffix variants match, pass the exact symbol shown by the broker.

## Make it visible in MT5

1. Open the broker's exact XAUUSD chart.
2. In Navigator, refresh Expert Advisors and attach `SniperFX\SniperFX` to that chart.
3. Keep `InpResearchOverlayEnabled=true` and `InpResearchBridgeFile=SniperFX\alpha_zones.csv`.
4. `Algo Trading` may stay disabled; the overlay does not require live-order permission.
5. The top-left heartbeat reads `SFX ALPHA LAB | PYTHON_ACTIVE` only while Python is publishing and the broker quote is fresh.

Chart legend:

- green zone: BUY research area;
- red zone: SELL research area;
- gold zone: current price is touching the area;
- `ACCEPTED`: the latest completed bar interacted with the area and closed on the expected side;
- `WATCH`: nearby area, not yet triggered;
- `PYTHON_STALE_*S`: Python stopped or its bridge is no longer fresh.
- `PYTHON_ACTIVE_MARKET_STALE`: Python is healthy, but the broker quote is old (normally a closed market); the panel is yellow and the zones are historical, not a current entry cue.

Hover over a zone to see source, state, raw research score, trend, normalized slope, efficiency, and distance in ATR.

## Files

- Bridge: `%APPDATA%\MetaQuotes\Terminal\Common\Files\SniperFX\alpha_zones.csv`
- Ledger: `data\phase1\alpha_lab.sqlite3`
- Background stdout/stderr: `Workspace\outputs\sniperfx-mt5\alpha-lab.*.log`
- PID marker: `data\phase1\alpha_lab.pid`

## Four-bar label behavior

Each zone is recorded once per completed decision bar. After four later M5 bars exist, the ledger stores `mfe_4r`, `mae_4r`, and whether a `+1.5R` target or `-1R` stop was hit first. If both are inside the same M5 candle, the label is `AMBIGUOUS_SAME_BAR`; Phase 1 does not invent an intrabar order without tick evidence.

## Current limitations

- Initial scores are heuristic research rankings, not learned probabilities.
- The first detector set uses M5 plus causal context computed from that history; cross-asset and macro inputs are not implemented yet.
- Previous-day boundaries use UTC in Python and will be upgraded to explicit broker/session calendars.
- A weekend/closed market displays the last known zones with `PYTHON_ACTIVE_MARKET_STALE`; no new labels mature until new completed bars arrive.
- The chart overlay only renders rows whose symbol exactly matches the chart symbol.
