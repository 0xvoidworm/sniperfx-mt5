# Configuration

Defaults are intentionally non-trading:

- `InpTradingEnabled=false`
- `InpOperationMode=OPERATION_SCAN_ONLY`
- `InpRiskPercent=1.0`
- `InpMaxMarginFraction=0.50`
- `InpMaxConcurrentPositions=1` (the only supported value in v0.2)
- `InpMinNetRewardR=1.5`
- `InpDefaultTargetR=2.0`
- `InpPendingExpiryM5Bars=2`
- `InpTimeStopM5Bars=4`
- `InpMaxDailyLossR=3.0`

Broker properties are read at runtime. Price normalization uses tick size; volume normalization floors to volume step and rejects a result below minimum volume. Sizing uses `OrderCalcProfit`, then caps the final volume to 50% of free margin using `OrderCalcMargin`. Leverage is never a lot multiplier.

Do not enable live operation until historical, failure, and source audit gates are complete. No credentials belong in inputs, files, or logs.
