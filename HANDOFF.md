# Handoff

## Current outcome

SniperFX is a compiled, auditable research candidate with a connected vertical path: closed-bar H4 regime → H1 impulse → M15 pullback/broken-swing zone → M5 trigger → cross-symbol ranking → exposure/daily-loss gates → broker-normalized sizing → pending request → scan-only or guarded execution → transaction reconciliation → pending/time-stop management.

It is **not live-ready and not proven profitable**. The correct current operating state is `SCAN_ONLY`. The user has explicitly designated the new currently logged-in FBS account as the tester account; this authorizes isolated Strategy Tester use, not live order placement.

## Verified evidence

- Main EA and test EA compile with 0 errors and 0 warnings.
- Fresh `.ex5` files are deployed only under `MQL5/Experts/SniperFX`.
- Portable MetaTrader math-mode harness passes 40/40 and contains no account database.
- Main source has one `OrderSend` call, inside the double-gated `SubmitGuarded` function.
- The XAUUSD quality-gated Model=1 candidate returned 53 trades, +538.03, PF 1.4596, and 2.8896% drawdown over 2020–2026; six of seven calendar years were positive.
- Model=4 history coverage was insufficient (4% on the long validation range, 66% on the short available range), so no full-quality real-tick pass exists.
- No Algo Trading setting was changed, no EA was attached to a live chart, and no live-market order was sent.

Evidence is in `C:\Users\yuri\Desktop\Workspace\outputs\sniperfx-mt5`:

- `build-result.json`, `compile.log`, `test-compile.log`
- `unit-test-result.json`
- `integration-scan-result.json`
- `backtest-xau-analysis.json`, `backtest-xau-feature-analysis.json`, `backtest-xau-telemetry-analysis.json`
- `backtest-xau-quality91-analysis.json`
- `backtest-xau-quality91-realtick-analysis.json`, `backtest-xau-quality91-realtick-available-analysis.json`

## Reproduce

```powershell
pwsh -NoProfile -File .\scripts\deploy_and_compile.ps1
pwsh -NoProfile -File .\scripts\run_unit_tester_isolated.ps1
```

## Next required gate

Required sequence before any live decision:

1. Obtain a trustworthy XAUUSD tick source with near-100% coverage across several years, then rerun the fixed `0.91` profile without retuning.
2. Stress commission, spread, slippage, gaps, and execution delay.
3. Run rolling walk-forward without selecting parameters from the evaluation windows.
4. Complete restart/timeout/cancel/partial-fill simulations.
5. Run a multi-week guarded burn-in on the designated test account with independent log reconciliation.

Only after those pass should a human decide whether to prepare a live candidate. Default inputs must remain scan-only in source.
