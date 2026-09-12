# Known Gaps

- The local market-data integration attempt stopped before EA initialization because the isolated terminal had no registered tester account. Copying the live terminal's `accounts.dat` was intentionally refused. Use a separate demo/tester account.
- Real-tick, spread/commission/slippage stress, out-of-sample, walk-forward, and four-bar event studies are not run. The local FBS cache inspected during this audit contained no real-tick files.
- Strategy expectancy, trade frequency, drawdown, and profitable parameter ranges are unknown. Compile success and 33 unit passes do not answer those questions.
- Zone state is reconstructed from closed bars on each M5 decision. There is no persistent per-symbol zone ledger or retest history yet.
- Only one active managed intent is supported. Configuration now rejects `MaxConcurrentPositions` other than 1 instead of pretending multi-intent recovery is safe.
- Restart, transport timeout, order-cancel race, gap fill, and partial-fill flows still need broker-simulator or demo integration tests.
- Cost gating currently estimates spread relative to stop distance. Commission, swap, stop-trigger slippage, and gap risk require tester evidence.
- There is no session-quality or economic-news filter in the baseline. These may materially change frequency and tail risk and must be tested rather than added by intuition.
- No profitability or live-readiness claim is made.
