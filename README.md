# SniperFX MT5

Native MQL5 multi-symbol trend-continuation EA with a causal H4 → H1 → M15 → M5 pipeline. It ranks valid setups, sizes from stop distance, builds broker-normalized pending stops, and manages one guarded intent. An optional H1 impulse-quality gate is available for research profiles.

This repository is an auditable engineering baseline, not evidence of profitability. The default build is `InpTradingEnabled=false` plus `SCAN_ONLY`; the only `OrderSend` call is behind both gates. Source is in `src/SniperFX`, and deployment is isolated to `MQL5/Experts/SniperFX`.

Build and run deterministic offline tests:

```powershell
pwsh -NoProfile -File .\scripts\deploy_and_compile.ps1
pwsh -NoProfile -File .\scripts\run_unit_tester_isolated.ps1
```

Latest result: both targets compile with 0 errors/0 warnings; isolated test harness passes 40/40 without an account database. The XAUUSD quality-gated research profile is profitable in a 2020–2026 one-minute-OHLC test, but full-quality real-tick evidence is unavailable and the EA is not live-ready. Read `STATUS.md`, `TEST_RESULTS.md`, `HANDOFF.md`, `DECISIONS.md`, and `KNOWN_GAPS.md` before any tester or live operation.
