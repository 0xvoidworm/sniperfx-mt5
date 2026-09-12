# Test Results

Updated: 2026-09-12

## Engineering PASS

- MetaEditor build on 2026-09-12 13:21 WIB: main EA 0 errors/0 warnings; test EA 0 errors/0 warnings.
- Fresh main SHA-256: `6102BC8E2633D799D77FAECBA9242EF1BD4CBFFAC5969EC8CF1F426057EE6286`.
- Fresh test SHA-256: `BD08E1704E3E98708AA09877041DD3EB9438DFCA3C9E29A86EE857CC8346BBBE`.
- Isolated MetaTrader `Model=3` run on 2026-09-12 13:21 WIB: 47 passed, 0 failed, terminal exit 0.
- The isolated unit terminal had no `accounts.dat`; it used no broker history and sent no order.
- Covered pure logic includes configuration gates, timeout classification, pending-entry stability, state round-trip with large tickets, symbol parsing/exposure, causal pivots, efficiency, buy/sell triggers, ranking, bar-count time stop, impulse-quality bounds, and once-per-M5-bar time-exit retry.
- Static order-path audit finds one `OrderSend` call, inside `SubmitGuarded`; default inputs block before `OrderCheck` and `OrderSend`.
- Python unit suite passes 4/4, including bounded reconnect backoff; bytecode compilation passes.
- Actual terminal acquisition resolved exact symbol `XAUUSD`, loaded 800 completed M5 bars, retained 1,591 unique ticks, and published six causal Bridge V2 zones.
- A three-second heartbeat check advanced the bridge timestamp while the background process remained alive with empty stderr. The quote itself was roughly five hours old, so market state correctly remained `STALE_QUOTE_*`.
- The EA now applies the exact saved `Yuri Clean Dark.tpl` palette through chart properties; it does not call `ChartApplyTemplate`, so styling cannot unload the attached EA.

## Market-data results

- Authorized isolated scan-only integration: 1,149 scan events, 1,147 health events, zero order submissions, and zero transactions.
- Unfiltered EURUSD Model=1 baseline, 2026-01-01 to 2026-09-01: 11 trades, -219.09, PF 0.4453, 4.1234% drawdown.
- Unfiltered seven-symbol Model=1 baseline over the same dates: 103 trades, -1,136.37, PF 0.5990, 12.1235% drawdown. XAUUSD was the only positive symbol in that short sample.
- Unfiltered XAUUSD Model=1, 2020-01-01 to 2026-09-01: 211 trades, -97.05, PF 0.9801, 6.5033% drawdown.
- The H1 impulse-quality threshold was selected using 2020–2023 feature bins. The actual quality-gated XAUUSD Model=1 rerun produced 53 trades, +538.03, PF 1.4596, 2.8896% drawdown. Training years together: 28 trades and +165.82. Later years together: 25 trades and +372.21; 2026 alone was -3.60.
- Exit decomposition for that candidate: 46 four-bar exits +643.25, five stop losses -506.26, and two take-profits +401.04.
- The runner copies the explicitly authorized tester account database only into an isolated sandbox and removes it in `finally`. Latest results report `AccountDatabaseRemoved=true`; Algo Trading and live charts were untouched.

## Insufficient evidence / not passed

- The 2024–2026 Model=4 report showed only 4% real ticks. A 2026-07-01 to 2026-09-01 run showed 66% real ticks and only one losing trade (-55.72). Neither is valid full-quality real-tick evidence.
- Cost/slippage stress, rolling walk-forward, restart/timeout/partial-fill replay, and guarded demo burn-in remain outstanding.
- No live-market transaction was sent. Strategy Tester transactions were emulated only.

Artifacts and machine-readable analyses are under `C:\Users\yuri\Desktop\Workspace\outputs\sniperfx-mt5`.
