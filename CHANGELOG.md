# Changelog

## 0.3.2 - 2026-09-12

- Kept the last valid research zones visible with a yellow `PYTHON_STALE_*` status during terminal disconnects instead of clearing the chart.
- Added bounded Python-side reconnect after transient IPC and terminal-authorization failures.

## 0.3.1 - 2026-09-12

- Applied the exact `Yuri Clean Dark` chart palette and layout whenever SniperFX is attached.
- Kept the styling optional through `InpApplyYuriCleanDark`; applying it does not replace or unload the EA.

## 0.3.0 - 2026-09-12

- Added the read-only Python Alpha Lab with initial round-level, confirmed-swing, previous-day, and directional-change research zones.
- Added an append-only SQLite tick/observation ledger and causal four-M5-bar MFE/MAE/first-hit labels.
- Added the versioned atomic `FILE_COMMON` bridge and visible MT5 zone/status overlay.
- Separated Python heartbeat freshness from broker quote freshness so closed-market data is visibly marked stale.
- Added foreground/background setup, start, and stop scripts.
- Kept the MQL5 order path unchanged and scan-only by default.

## 0.2.0 - 2026-09-12

- Wired the full H4/H1/M15/M5 candidate path through ranking, sizing, pending request construction, scan-only logging, guarded submit, transaction handling, and reconciliation.
- Fixed series-order copying, trigger-reference price drift, broker prefix/suffix parsing, pending-order exposure checks, and wall-clock time-stop behavior.
- Added account-scoped intent persistence with large-ticket-safe CSV serialization.
- Added start-of-day loss anchoring, a 50% free-margin cap, and safe-mode handling for uncertain `OrderSend` outcomes.
- Hardened build validation to require fresh artifacts with 0 errors/0 warnings and recorded SHA-256 hashes.
- Added isolated portable MetaTrader unit runner; 33 deterministic tests pass without credentials.
- Documented the blocked credential-free market-data test and remaining validation gates.

## 0.1.0 - 2026-09-12

- Added isolated SniperFX MQL5 project structure.
- Added scan-only vertical slice with one-second timer and closed M5 audit events.
- Added broker-adaptive MTF cache, analysis primitives, risk sizing, pending-order builder, retcode policy, state marker, and smoke harness.
- Added deployment/compile script and audit documentation.
