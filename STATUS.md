# Status

Updated: 2026-09-12

- [x] Causal closed-bar H4 → H1 → M15 → M5 analysis pipeline
- [x] Multi-symbol resolution, including one unambiguous broker prefix/suffix variant
- [x] Candidate ranking and full controller path to scan-only or guarded intent
- [x] `OrderCalcProfit` risk sizing, free-margin cap, broker normalization, pending request, and `OrderCheck`
- [x] One-intent persistence, account-scoped state, audit CSV, pending expiry, and M5 bar-count time stop
- [x] Transaction filtering/reconciliation wired; uncertain sends preserve intent and enter safe mode
- [x] Main EA and test harness deployed as fresh `.ex5` artifacts
- [x] Deterministic tester harness executed in a credential-free portable terminal: 47 passed, 0 failed
- [x] Phase 1 read-only Python Alpha Lab with atomic bridge, SQLite discovery ledger, and visible MT5 research zones
- [x] Independent Python-heartbeat and broker-quote freshness state (`PYTHON_ACTIVE_MARKET_STALE` on closed/stale feed)
- [x] Exact `Yuri Clean Dark.tpl` palette applied automatically to the attached chart
- [x] Isolated market-data scans and one-minute-OHLC Strategy Tester baselines
- [x] Chronological XAUUSD research split: impulse-quality threshold selected on 2020–2023 and checked on 2024–2026
- [ ] Full-quality real-tick backtest, cost stress, and rolling walk-forward validation
- [ ] Restart, timeout, order-cancel, and partial-fill integration simulations
- [ ] Guarded demo burn-in and profitability evidence

Latest compiler result: main and tests both 0 errors, 0 warnings. Main SHA-256: `6102BC8E2633D799D77FAECBA9242EF1BD4CBFFAC5969EC8CF1F426057EE6286`.

Phase 1 live-read check: exact broker symbol `XAUUSD` resolved; 800 completed M5 bars and 1,591 bid/ask ticks were acquired; six causal zones were published. The background process is active, while the current broker quote is correctly marked stale because the market is closed.

Current runtime note: MT5 reports `authorization on FBS-Real failed (Invalid account)`. The Python runner remains alive and retries every 10 seconds; Bridge V2 retains the last six zones with a visible stale warning until terminal authorization returns.

Research status: the unfiltered seven-symbol baseline is negative. The XAUUSD profile with `InpMinImpulseQuality=0.91` produced 53 trades, +538.03, PF 1.4596, and 2.8896% drawdown on Model=1 from 2020-01-01 through 2026-09-01. Six calendar years were positive and 2026 was -3.60. This is a candidate edge, not proof: available Model=4 reports contained only 4% and 66% real ticks. Keep the source default in `SCAN_ONLY`.
