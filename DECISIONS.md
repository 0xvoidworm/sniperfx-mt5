# Engineering Decisions

Updated: 2026-09-12

1. **Closed bars only.** H4, H1, M15, and M5 decisions use shift 1 or older with explicit close-time checks. The cache preserves series direction.
2. **One active intent.** The recovery ledger represents one order or position. `MaxConcurrentPositions` must equal 1 until a real multi-intent ledger exists.
3. **Risk first, leverage second.** Default risk is 1% of equity. Volume comes from `OrderCalcProfit`, is floored to broker step, and is capped so estimated margin is at most 50% of current free margin. Leverage is never used as a lot multiplier.
4. **Pending-stop confirmation.** A closed M5 touch/reclaim/micro-break produces a stop-entry reference. Broker minimum distance can move the executable entry; risk and target are recalculated from the original trigger reference so repeated builds do not drift.
5. **Fail closed.** Missing/ambiguous symbols, stale data, unknown exposure contracts, invalid stops, excessive spread, unsupported broker modes, persistence failure, and uncertain transport outcomes block new exposure.
6. **Broker state is authoritative.** Intent is persisted before `OrderSend`. Timeout/connection uncertainty enters safe mode and requires reconciliation; there is no blind retry.
7. **Default cannot trade.** Both `InpTradingEnabled=true` and `OPERATION_LIVE_GUARDED` are required before `OrderCheck` or `OrderSend`. The shipped defaults are false plus `SCAN_ONLY`.
8. **Tester authorization is narrow.** The user explicitly designated the new logged-in FBS account as the test account. Market-data scripts may temporarily copy its account database into an isolated Strategy Tester sandbox, then must delete it in `finally`. This does not authorize live orders, enabling Algo Trading, or attaching the EA to a live chart.
9. **Exit retries are candle-rate limited.** A failed four-bar close can retry only after the next M5 candle closes; a closed market cannot cause requests every timer tick.
10. **Impulse quality is an optional research gate.** The shipped default is disabled (`0.0`). The XAU research profile uses `0.91`, selected from 2020–2023 feature quartiles and evaluated unchanged on later data.
11. **Power means selectivity and controlled execution.** Higher leverage or looser limits are not treated as evidence of edge. Profitability must survive high-quality real-tick, cost-stress, and out-of-sample checks.
12. **Visible discovery is isolated from execution.** Python may read terminal data, record observations, and publish versioned visualization rows, but exposes no order method. The MQL5 overlay also distinguishes a fresh Python heartbeat from a stale broker quote.
