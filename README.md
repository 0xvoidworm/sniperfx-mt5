# SniperFX MT5

Native MQL5 multi-symbol trend-continuation EA with a causal H4 → H1 → M15 → M5 pipeline. It ranks valid setups, sizes from stop distance, builds broker-normalized pending stops, and manages one guarded intent. Phase 1 now also includes a read-only Python Alpha Lab that records ticks, labels four-bar outcomes, and publishes research areas to a visible MT5 chart overlay.

This repository is an auditable engineering baseline, not evidence of profitability. The default build is `InpTradingEnabled=false` plus `SCAN_ONLY`; the only `OrderSend` call is behind both gates. Source is in `src/SniperFX`, and deployment is isolated to `MQL5/Experts/SniperFX`.

Build and run deterministic offline tests:

```powershell
pwsh -NoProfile -File .\scripts\deploy_and_compile.ps1
pwsh -NoProfile -File .\scripts\run_unit_tester_isolated.ps1
```

Latest result: both targets compile with 0 errors/0 warnings; isolated test harness passes 47/47 without an account database. The XAUUSD quality-gated research profile is profitable in a 2020–2026 one-minute-OHLC test, but full-quality real-tick evidence is unavailable and the EA is not live-ready. Read `STATUS.md`, `TEST_RESULTS.md`, `HANDOFF.md`, `DECISIONS.md`, and `KNOWN_GAPS.md` before any tester or live operation.

Start the Phase 1 visual discovery loop after one-time setup:

```powershell
pwsh -NoProfile -File .\scripts\setup_alpha_lab.ps1
pwsh -NoProfile -File .\scripts\start_alpha_lab.ps1 -Symbol XAUUSD
```

See `docs/PHASE1_ALPHA_LAB.md` for the bridge, chart legend, data locations, and current limitations. The displayed `SCORE` is a hypothesis-ranking value, not a win probability. Attached charts use the saved `Yuri Clean Dark` palette by default.
