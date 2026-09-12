# Failure Modes

The data gate rejects unsynchronized or stale series. Symbol ambiguity is rejected. Closed-bar mapping excludes the current bar. Broker capability failures, invalid stops/volume, missing tick, margin failure, and `OrderCheck` rejection become logged no-trade reasons.

Execution must reconcile after timeout, partial fill, connection failure, or restart before considering a retry. A transport-level `OrderSend` failure and infrastructure retcodes preserve the intent and enter safe mode. `OrderSend()==true` is not treated as fill confirmation. `OnTradeTransaction` is the authoritative lifecycle hook.

State mismatch enters safe mode: no new entries, while existing server-side protection remains active. Daily managed P/L is reconstructed from history plus open positions and measured against approximate start-of-day equity.

Known current limitation: the lifecycle is wired for one active intent, but a full broker-history replay and tester failure matrix remain not run.
