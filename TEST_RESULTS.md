# Test Results

Updated: 2026-09-12

## PASS

- MetaEditor build on 2026-09-12 09:42 WIB: main EA 0 errors/0 warnings; test EA 0 errors/0 warnings; deployment script exit 0.
- Fresh main SHA-256: `DCAAD32289475380AADD59744B5AD4297F9DECFEE3864BB0DEB5B4511618E13A`.
- Fresh test SHA-256: `9B14923EFEE2B8DEBD11A3AE79069277C0FB3043EC2C89D6C0D335F5D2A4A290`.
- Isolated MetaTrader `Model=3` run on 2026-09-12 09:43 WIB: 33 passed, 0 failed, terminal exit 0.
- The isolated unit terminal had no `accounts.dat`; it used no broker history and sent no order.
- Covered pure logic includes configuration gates, timeout classification, pending-entry stability, state round-trip with large tickets, symbol parsing/exposure, causal pivots, efficiency, buy/sell triggers, ranking, and bar-count time stop.
- Static order-path audit finds one `OrderSend` call, inside `SubmitGuarded`; default inputs block before `OrderCheck` and `OrderSend`.

## BLOCKED SAFELY

- A credential-free market-data integration run was attempted twice. MT5 stopped before EA initialization with `tester not started because the account is not specified`.
- No live account database was copied into the sandbox. The failure log is preserved in `outputs/sniperfx-mt5/integration-scan-blocker.log`.

## NOT RUN

- Market-data historical run and custom `OnTester` metrics.
- Real-tick broker-feed verification, cost/slippage stress, restart/timeout/partial-fill replay, and demo burn-in.
- Live account connectivity and any transaction.

No trading order was sent by any build or test process.
