# Handoff

## Current outcome

SniperFX is a compiled, auditable research candidate with a connected vertical path: closed-bar H4 regime → H1 impulse → M15 pullback/broken-swing zone → M5 trigger → cross-symbol ranking → exposure/daily-loss gates → broker-normalized sizing → pending request → scan-only or guarded execution → transaction reconciliation → pending/time-stop management. Phase 1 also adds a separate read-only Python path that turns completed M5 data into visible research zones and a labelled discovery ledger.

It is **not live-ready and not proven profitable**. The correct current operating state is `SCAN_ONLY`. The user has explicitly designated the new currently logged-in FBS account as the tester account; this authorizes isolated Strategy Tester use, not live order placement.

## Verified evidence

- Main EA and test EA compile with 0 errors and 0 warnings.
- Fresh `.ex5` files are deployed only under `MQL5/Experts/SniperFX`.
- Portable MetaTrader math-mode harness passes 47/47 and contains no account database.
- The Python Alpha Lab resolved the real broker symbol `XAUUSD`, read 800 completed M5 bars and 1,591 ticks, published six Bridge V2 zones, and continuously advances its heartbeat.
- The broker feed was closed/stale during verification, and the bridge correctly published `STALE_QUOTE_*` instead of presenting the old quote as live.
- Attached charts automatically receive the saved `Yuri Clean Dark` palette through non-destructive chart-property updates.
- At the latest runtime check the main terminal reported `Invalid account`; the Python sidecar stayed alive in bounded reconnect mode and the overlay retained its last valid zones with a stale warning.
- Main source has one `OrderSend` call, inside the double-gated `SubmitGuarded` function.
- The XAUUSD quality-gated Model=1 candidate returned 53 trades, +538.03, PF 1.4596, and 2.8896% drawdown over 2020–2026; six of seven calendar years were positive.
- Model=4 history coverage was insufficient (4% on the long validation range, 66% on the short available range), so no full-quality real-tick pass exists.
- No Algo Trading setting was changed, no EA was attached to a live chart by automation, and no live-market order was sent. The Alpha Lab background process is read-only and remains active for chart attachment.

Evidence is in `C:\Users\yuri\Desktop\Workspace\outputs\sniperfx-mt5`:

- `build-result.json`, `compile.log`, `test-compile.log`
- `unit-test-result.json`
- `alpha-lab.stdout.log`, `alpha-lab.stderr.log`
- `integration-scan-result.json`
- `backtest-xau-analysis.json`, `backtest-xau-feature-analysis.json`, `backtest-xau-telemetry-analysis.json`
- `backtest-xau-quality91-analysis.json`
- `backtest-xau-quality91-realtick-analysis.json`, `backtest-xau-quality91-realtick-available-analysis.json`

## Reproduce

```powershell
pwsh -NoProfile -File .\scripts\deploy_and_compile.ps1
pwsh -NoProfile -File .\scripts\run_unit_tester_isolated.ps1
pwsh -NoProfile -File .\scripts\start_alpha_lab.ps1 -Symbol XAUUSD
```

## Next required gate

Required sequence before any live decision:

1. Obtain a trustworthy XAUUSD tick source with near-100% coverage across several years, then rerun the fixed `0.91` profile without retuning.
2. Stress commission, spread, slippage, gaps, and execution delay.
3. Run rolling walk-forward without selecting parameters from the evaluation windows.
4. Complete restart/timeout/cancel/partial-fill simulations.
5. Run a multi-week guarded burn-in on the designated test account with independent log reconciliation.

Only after those pass should a human decide whether to prepare a live candidate. Default inputs must remain scan-only in source.
