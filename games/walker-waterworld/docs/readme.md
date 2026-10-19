WALKER-WATERWORLD

Four thruster drones ("skimmers") patrol a 12.00 m x 8.00 m tank seen from above, feeling for drifting plankton with sixteen short-range proximity sensors each. A plankton particle can only be taken by TWO SKIMMERS TOUCHING IT AT THE SAME INSTANT — one skimmer alone can nudge it and wait, nothing more — and the same water carries eight drifting poison blooms that sting, stun and cost the whole pod points. Nobody can talk. Every seat sees only what its own sensors reach.

The pod's score is ONE number and every seat gets it:
  score = 10.000*captures + 0.050*nibbles - 2.000*poisonHits - thrustCost
Higher is better. Reaching 20 catches ends the run early and wins it. The league ranks a seat by the MEAN of its shared scores across episodes — its cross-play mean — not by Elo: with four identical scores every episode is a four-way draw and Elo cannot separate anybody.

An episode is 1728 ticks (72.0 s) at 24 Hz, divided into 24 decision turns of 72 ticks. Every 3 seconds each seat sets ONE order; a deterministic autopilot runs it 24 times a second, steering, leading a moving target and backing off poison. The order is the policy interface; the per-tick thrust byte is derived server-side, recorded, and replayed.

Policies: `PLAYER_PROMPT=<strategy>` makes a seat an LLM seat, `PLAYER_SCRIPTED=shoal|drifter` makes it scripted, and a seat that sets neither is `shoal`. One image, one player entrypoint, env-switched.