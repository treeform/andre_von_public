# Leader theory

Working hypothesis, 2026-09-12: Daveey wins the base race by maintaining
pressure in separate lanes, while Richard and Relh commit five heroes to
the top corridor. Copying a lane assignment alone is insufficient. We
need to reproduce the decisions that keep each lane advancing.

Evidence: twelve hosted league replays reconstructed through the exact
wasm named in their headers. Final ticks, winner, all hero stats and
ancient health match. See research/trajectories.md and the per-game
evidence. These are behavior measurements, not experimental scores.

- Daveey has four or more heroes in one opening corridor for only 0-1%
  of ticks. Richard reaches 40-94%; Relh reaches 81-87%.
- Richard and Relh take their first top outer tower before tick 250 in
  these games. Daveey can still win after losing the top tower chain.
- Daveey's tank, assassin and carry stay on top, mid and bottom lanes.
  The support spends very little time inside enemy tower firing range.
- Most actual assassin haste casts happen at low health. Frequent E
  button flags mostly fail due to cooldown, mana or Q/W priority.

The current champion already intends to split like Daveey. Its weak
hosted results therefore challenge the idea that lane layout explains
the gap. Five Grok lanes compare original v1 decisions with actual
leader actions on the same reconstructed observations:

| Lane | Question | Predicted replication effect |
|---|---|---|
| routes | Does steering or waypoint state stall progress? | More useful lane movement |
| sieging | Where do cores stand while attacking towers? | More time dealing tower damage |
| sustain | When do leaders leave and return to lane? | Less unnecessary downtime |
| casting | Which skill intentions actually become casts? | Better healing or escape uptime |
| targets | When do leaders stop, chase or change targets? | More effective combat near waves |

Each lane may upload one changed strategy only after a concrete
behavior discrepancy and isolation checks. A refuted theory is logged,
not dressed up as a new experiment. Each uploaded version immediately
plays the same three live opponent policies as gorynych:v1, under Andre
von Auto. Only matched hosted XP with strategy activation and statistical
significance can justify keeping or submitting it.

Rejected first batch: occupancy, topstack, push haste, strict creep
cover, local recovery. Recovery's second look produced 5/60 wins versus
4/60 for v1, exact p=0.50. None is part of the next candidates.
