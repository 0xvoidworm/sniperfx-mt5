# Status

Updated: 2026-09-12

- [x] Causal closed-bar H4 → H1 → M15 → M5 analysis pipeline
- [x] Multi-symbol resolution, including one unambiguous broker prefix/suffix variant
- [x] Candidate ranking and full controller path to scan-only or guarded intent
- [x] `OrderCalcProfit` risk sizing, free-margin cap, broker normalization, pending request, and `OrderCheck`
- [x] One-intent persistence, account-scoped state, audit CSV, pending expiry, and M5 bar-count time stop
- [x] Transaction filtering/reconciliation wired; uncertain sends preserve intent and enter safe mode
- [x] Main EA and test harness deployed as fresh `.ex5` artifacts
- [x] Deterministic tester harness executed in a credential-free portable terminal: 40 passed, 0 failed
- [x] Isolated market-data scans and one-minute-OHLC Strategy Tester baselines
- [x] Chronological XAUUSD research split: impulse-quality threshold selected on 2020–2023 and checked on 2024–2026
- [ ] Full-quality real-tick backtest, cost stress, and rolling walk-forward validation
- [ ] Restart, timeout, order-cancel, and partial-fill integration simulations
- [ ] Guarded demo burn-in and profitability evidence

Latest compiler result: main and tests both 0 errors, 0 warnings. Main SHA-256: `95B602D8916A59F4A47E9136C8B25BB43D52532257F58F6C562FD28605DF88A1`.

Research status: the unfiltered seven-symbol baseline is negative. The XAUUSD profile with `InpMinImpulseQuality=0.91` produced 53 trades, +538.03, PF 1.4596, and 2.8896% drawdown on Model=1 from 2020-01-01 through 2026-09-01. Six calendar years were positive and 2026 was -3.60. This is a candidate edge, not proof: available Model=4 reports contained only 4% and 66% real ticks. Keep the source default in `SCAN_ONLY`.
