# Known Gaps

- Full-quality historical real ticks are unavailable from the current broker cache. Model=4 produced only 4% coverage for 2024–2026 and 66% for July–August 2026; these runs cannot validate the candidate edge.
- The XAU quality profile has only 53 Model=1 trades across roughly 6.7 years (about eight per year). It made +538.03 on a 10,000 deposit with 2.8896% drawdown, but 2026 was slightly negative and the sample remains small.
- The impulse-quality threshold was selected from the 2020–2023 sample. Later Model=1 data stayed positive, but rolling walk-forward and an untouched high-quality tick dataset have not been completed.
- Zone state is reconstructed from closed bars on each M5 decision. There is no persistent per-symbol zone ledger or retest history yet.
- Only one active managed intent is supported. Configuration now rejects `MaxConcurrentPositions` other than 1 instead of pretending multi-intent recovery is safe.
- Restart, transport timeout, order-cancel race, gap fill, and partial-fill flows still need broker-simulator or designated-test-account integration tests.
- Cost gating currently estimates spread relative to stop distance. The observed broker reports charged zero commission on these tests; commission, swap, stop-trigger slippage, and gap risk still require stress tests.
- There is no session-quality or economic-news filter in the baseline. These may materially change frequency and tail risk and must be tested rather than added by intuition.
- No profitability or live-readiness claim is made.
