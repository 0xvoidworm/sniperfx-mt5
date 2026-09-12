# Handoff

## Current outcome

SniperFX is now a compiled, auditable engineering baseline with a connected vertical path: closed-bar H4 regime → H1 impulse → M15 pullback/broken-swing zone → M5 trigger → cross-symbol ranking → exposure/daily-loss gates → broker-normalized sizing → pending request → scan-only or guarded execution → transaction reconciliation → pending/time-stop management.

It is **not live-ready and not proven profitable**. The correct current operating state is `SCAN_ONLY`.

## Verified evidence

- Main EA and test EA compile with 0 errors and 0 warnings.
- Fresh `.ex5` files are deployed only under `MQL5/Experts/SniperFX`.
- Portable MetaTrader math-mode harness passes 33/33 and contains no account database.
- Main source has one `OrderSend` call, inside the double-gated `SubmitGuarded` function.
- No Algo Trading setting was changed, no EA was attached to a live chart, and no order was sent.

Evidence is in `C:\Users\yuri\Desktop\Workspace\outputs\sniperfx-mt5`:

- `build-result.json`, `compile.log`, `test-compile.log`
- `unit-test-result.json`
- `mt5-unit-sandbox/Tester/Agent-127.0.0.1-3000/logs/20260912.log`
- `integration-scan-result.json`, `integration-scan-blocker.log`

## Reproduce

```powershell
pwsh -NoProfile -File .\scripts\deploy_and_compile.ps1
pwsh -NoProfile -File .\scripts\run_unit_tester_isolated.ps1
```

## Next required gate

Create or designate a separate MT5 **demo/tester account**, then run the main EA in Strategy Tester using `src/SniperFX/Tests/SniperFX_SCAN_ONLY.set`. Do not reuse or copy the active FBS-Real account database into automation. Required sequence:

1. Scan-only integration on one symbol, then all configured symbols.
2. Real-tick in-sample sanity test with broker commission, spread, swap, and execution delay.
3. Untouched out-of-sample and rolling walk-forward runs.
4. Restart/timeout/cancel/partial-fill simulations.
5. Multi-week guarded demo burn-in and independent log reconciliation.

Only after those pass should a human decide whether to prepare a live candidate. Default inputs must remain scan-only in source.
