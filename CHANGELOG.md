# Changelog

## 0.2.0 - 2026-09-12

- Wired the full H4/H1/M15/M5 candidate path through ranking, sizing, pending request construction, scan-only logging, guarded submit, transaction handling, and reconciliation.
- Fixed series-order copying, trigger-reference price drift, broker prefix/suffix parsing, pending-order exposure checks, and wall-clock time-stop behavior.
- Added account-scoped intent persistence with large-ticket-safe CSV serialization.
- Added start-of-day loss anchoring, a 50% free-margin cap, and safe-mode handling for uncertain `OrderSend` outcomes.
- Hardened build validation to require fresh artifacts with 0 errors/0 warnings and recorded SHA-256 hashes.
- Added isolated portable MetaTrader unit runner; 33 deterministic tests pass without credentials.
- Documented the blocked credential-free market-data test and remaining validation gates.

## 0.1.0 - 2026-09-12

- Added isolated SniperFX MQL5 project structure.
- Added scan-only vertical slice with one-second timer and closed M5 audit events.
- Added broker-adaptive MTF cache, analysis primitives, risk sizing, pending-order builder, retcode policy, state marker, and smoke harness.
- Added deployment/compile script and audit documentation.
