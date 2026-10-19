Immutable (101-104): turn structure (propose/debate/vote), strict-majority passage with nay defaults, judge authority, and the key-value state model with integer points.

Mutable at start: 201 — start at 10 points, win at the victory threshold (initially 30), most points wins at the 15-turn cap; 202 — passing proposer +3, other aye voters +1, failing proposer -1; 203 — proposals may add/amend/repeal mutable rules or direct state changes.

The judge executes ALL rules in effect every turn, including standing per-turn effects created by enacted rules. State ops are absolute sets of JSON scalars; player `points` must stay integers; the common key `victory_points` holds the live victory threshold.