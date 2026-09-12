# SniperFX Strategy Specification

Baseline universe: EURUSD, USDJPY, GBPUSD, USDCHF, AUDUSD, USDCAD, and XAUUSD. Broker prefixes/suffixes are resolved only when a requested code appears in exactly one available contract.

A candidate must have a directional H4 confirmed-pivot structure, ATR-normalized log slope, and efficiency threshold, followed by a causal H1 displacement through a confirmed swing. M15 pullback depth is constrained to 0.25 through 0.70 of the impulse. The zone baseline is an ATR-scaled broken-swing zone, with invalidation beyond the pullback extreme. A closed M5 bar must touch the zone, reclaim its directional boundary, and close beyond the prior M5 bar's micro level.

Ranking is lexicographic: net room in R, trend efficiency, impulse quality, entry distance to invalidation, estimated cost, then symbol/time. A neutral or incomplete setup is logged as a no-trade reason.

The four M5 bar horizon is a time-stop hypothesis, not a profit promise. Strategy Tester results must be gathered separately by symbol, direction, session, zone source, candidate day, and executed day.

The current implementation is a deterministic baseline. It does not yet include session or economic-news quality filters. All thresholds are starting hypotheses and require broker-feed historical verification.
