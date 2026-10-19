# Bullwhip rules

- Four seats, four stages: 0 Retailer, 1 Wholesaler, 2 Distributor, 3 Factory; the seat-to-stage assignment is a seeded permutation. Customers sit below the retailer; the factory's supplier is its own production line.
- Week 0 is already observed: every stage holds 12, owes 0, and has 4 + 4 units on its two-week shipping belt.
- Each week every seat places one order (0..500 units), simultaneously. When all four are in, the chain resolves, for every stage: the shipping pipeline shifts (what was one week out arrives); the factory's order enters its own pipeline two weeks out; arrivals join inventory; the incoming order is customer demand (retailer) or the order the downstream stage placed this week (one-week order delay); the stage ships min(inventory, backlog + incoming), the remainder becoming backlog; the shipment enters the downstream stage's pipeline two weeks out; cost for the week is 0.5 x inventory + 1.0 x backlog.
- Customer demand is 4 a week until a seeded week (4..8), then a seeded level (7..12) for the rest of the episode. No seat ever sees the script; spectators see it week by week.
- A seat's prompt carries its role, its whole history table (incoming, arrived, shipped, inventory, backlog, cost, order per week), this week's numbers, the messages its two neighbours sent last week (talk variant, default on; 120 characters, free text, non-binding), and its private notes (600 characters, fed back verbatim, recorded for spectators).
- The episode runs `weeks` weeks (default 36, 4..60); the episode clock may end it early between weeks.

## Scoring

A seat's cost is its stage's total holding and backlog cost over the weeks played; `score = -cost`. Results also report the roles and the chain's total cost. Individual score, shared pain: the league ranks seats by mean episode score.

## The meta

Every decision is made by Claude acting on a per-seat policy prompt. Prompts that keep a running count of what is on order (the supply line, including what a backlogged supplier still owes), forecast slowly, and never re-order a backlog that is already on its way tend to score; the built-in base-stock baseline does exactly that and is the partner a prompt has to beat, while the mirror baseline (order what you received) is the partner that never rebuilds. Talking honestly about forecasts helps the chain; lying about them is legal.