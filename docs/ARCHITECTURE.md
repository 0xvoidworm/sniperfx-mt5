# SniperFX Architecture

SniperFX is a native MQL5 Expert Advisor. `src/SniperFX` is the source of truth; deployment copies only that tree into the dedicated `MQL5/Experts/SniperFX` folder.

The controller uses a configurable timer (one second by default) for multi-symbol scanning. Each symbol owns independent H4, H1, M15, and M5 caches. The cache rejects unsynchronized series, insufficient bars, and non-monotonic current/closed timestamps. Final decisions use shift 1 or older; shift 0 is never used as a closed value.

The pipeline is:

`data quality -> H4 regime -> H1 impulse -> M15 pullback/zone -> closed M5 trigger -> hard gates -> lexicographic ranking -> risk -> OrderCheck -> execution -> transaction reconciliation`.

`SCAN_ONLY` is the default. The only function that can call `OrderSend` is `SubmitGuarded`, and it returns before `OrderCheck`/`OrderSend` when scan-only is active.

State persistence uses account-scoped terminal Global Variables plus an account-scoped active-intent CSV in the terminal file sandbox. Audit data is a separate account/version-tagged CSV in the same sandbox. Broker state remains authoritative after restart; mismatch or ambiguous transport enters safe mode. Version 0.2 supports exactly one active managed intent.

No DLL, WebRequest, live LLM, martingale, grid, averaging down, or blind retry is used in the order path.

## Phase 1 research sidecar

Python is now used outside the order path as a read-only research sidecar. `alpha_lab.runner` reads completed M5 bars and bid/ask ticks through the official MetaTrader5 package, writes an append-only SQLite discovery ledger, and atomically publishes current zones to `FILE_COMMON`. `CAlphaBridge` parses that versioned CSV and `CResearchOverlay` draws only the exact chart symbol. Bridge V2 carries quote freshness separately from the Python heartbeat, so a live process on a closed market is shown as `PYTHON_ACTIVE_MARKET_STALE`. No Python output can reach `OrderSend`; the existing guarded MQL5 candidate path is unchanged.
