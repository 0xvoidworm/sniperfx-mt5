# Deployment

Run from PowerShell 7:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy_and_compile.ps1
```

The script copies only project files to `MQL5/Experts/SniperFX`, compiles `SniperFX.mq5` and `Tests/TestSniperFX.mq5`, requires fresh artifacts with exactly 0 errors/0 warnings, records hashes, and stores logs under `outputs/sniperfx-mt5`.

Run the deterministic harness without credentials or history:

```powershell
pwsh -NoProfile -File .\scripts\run_unit_tester_isolated.ps1
```

This creates a portable terminal under the output folder, copies only the unit-test `.ex5`, uses official tester `Model=3` math mode, and verifies the `TEST_SUMMARY` line. It does not copy `accounts.dat`.

The default deployment is scan-only. Do not enable Algo Trading or attach the EA to a live chart during development. Use Strategy Tester for offline verification. Confirm `SniperFX.ex5` and `Tests/TestSniperFX.ex5` exist after build.

Deployment never recursively deletes the MT5 data directory and does not touch other EA folders.
