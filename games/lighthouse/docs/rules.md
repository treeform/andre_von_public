# Lighthouse rules

## The board

A `width` x `height` grid, default 11 x 9, both odd. `x` runs 0..10 left to right, `y` runs
0..8 TOP to BOTTOM (y = 0 is the top). Tiles are wall or floor. Everything is drawn from
`seed`:

1. Every tile starts as wall; the rooms are the tiles with odd x and odd y.
2. A randomised depth-first search (recursive backtracker) over the rooms carves a PERFECT
   maze: exactly one path between any two floor tiles, no loops.
3. The EXIT is a seed-drawn odd x on row 0, carved to floor. It is the only gap in the outer
   border.
4. Three RUNNER STARTS are distinct rooms on the bottom room row (y = height - 2), pairwise at
   least 4 apart in x.
5. Three KEYS are placed in dead-end rooms (exactly one open neighbour) that are not a start,
   not the exit and not adjacent to it, with y <= height - 4, drawn from the ones nearest the
   exit and pairwise at least 6 apart by maze distance. At the default 11 x 9 a maze of 5 x 4
   rooms usually offers fewer than three eligible dead ends, and then the keys are drawn
   instead from the floor tiles of greatest exit distance under the same exclusions, still
   pairwise at least 6 apart - the normal case on this board size, not an exception.
6. The KEEPER occupies no tile. It is in the lantern room, off board. It cannot move.

## Resolution order

Tick t (0-based) resolves in exactly these twelve numbered steps:

1. OBSERVE. Each seat's observation is built from the state as it stands at the START of tick
   t. Runners that have escaped or drowned are not observed and not queried.
2. DECIDE. Every active seat's LLM call goes out as ONE parallel batch. Each active runner
   returns a move; the keeper returns transmit + message. Every seat may return notes.
3. KEEPER TRANSMIT. If the reply has transmit true and a non-empty message after truncation,
   the message is recorded and queued for delivery at the start of tick t+1.
4. RUNNER MOVES, in seat order 1, 2, 3. WAIT = (0, 0), N = (0, -1), S = (0, +1), E = (+1, 0),
   W = (-1, 0). A target that is out of bounds, a wall, or currently flooded leaves the runner
   where it was and records blocked: a bump, NOT an illegal reply. Runners may not walk into
   water; the water has to catch them.
5. KEY PICKUP, in seat order. A runner standing on an uncollected key takes it.
6. GATE. When all keys are collected the gate opens, permanently.
7. EXIT, in seat order. A runner on the exit tile with the gate OPEN escapes. On a shut gate it
   simply waits there.
8. CLOCK. clock += 1 + (the keeper transmitted this tick ? 1 : 0).
9. TIDE. Recomputed from the new clock.
10. DROWN. Every still-active runner whose tile is now flooded drowns.
11. TICK RECORD. The post-resolution board is appended to the event log; tick += 1.
12. END CHECK, in order: all three runners resolved -> complete; clock >= floodClock ->
    complete; tick >= maxTicks -> timeup; otherwise continue.

Runners do NOT collide: any number may stand on one tile, and two may swap tiles in one step.

## The tide

    tideRows(clock) = clamp((clock - tideDelay) div tidePeriod, 0, height)
    waterLine       = height - tideRows        # y of the topmost flooded row
    flooded(x, y)   = y >= waterLine
    floodClock      = tideDelay + height * tidePeriod

At the defaults (tideDelay 10, tidePeriod 7, height 9) row y floods at
clock = tideDelay + tidePeriod * (height - y): the bottom row (y = 8) at clock 17, the
runners' start row (y = 7) at clock 24, then 31, 38, 45, 52, 59 and 66, and the exit row
(y = 0) at clock 73, which is floodClock. The spring-tide variant (tidePeriod 5) reaches the
same rows at 15, 20, 25, 30, 35, 40, 45, 50 and 55 - harsher on every row.

## Scoring

    K = keysCollected                   (0 .. keyCount)
    E = escapedCount                    (0 .. 3)
    B = if E == 3: clamp(1 - clock / floodClock, 0, 1) else 0

    teamScore = 6 * (K / keyCount) + 10 * E + 6 * B          # range [0, 42]

The sign is POSITIVE: higher is better. `results.scores[i]` is the same team score for all four
seats, keeper included, so a keeper's rank is the mean of the teams it made work. Nothing is
subtracted for drowning. The time bonus is charged against the CLOCK, not the tick count, so a
chatty keeper pays for its words twice.

`results.reason` is one of exactly three values: `complete` (every runner resolved, or the
whole board flooded), `timeup` (the tick cap with at least one runner still active), or
`deadline` (the wall-clock play budget, 60% of episodeTimeoutSeconds, expired first).

## What each seat sees

THE KEEPER sees, every tick: the whole grid rendered as `height` lines of `width` characters
(`#` wall, `.` floor, `~` flooded, `K` uncollected key, `E` exit with the gate shut, `O` exit
with the gate open, `1`/`2`/`3` a runner; precedence is runner over exit over wall over water
over key, so an uncollected key on a flooded tile renders `~`, not `K` - nobody may step onto
it); every runner's alias, position, status, last move
and bump flag, and the keys it carries; the tide rows, the water line, and how many ticks until
the next row floods BOTH ways - if it stays silent and if it transmits; the tick, the clock,
the key count and the gate; its own notes; and a transcript of its last five transmissions. It
does NOT see any runner's private notes.

EACH RUNNER sees, every tick: its 3 x 3 window (same glyphs, `@` for itself, `#` off grid); the
keys it holds, the team's key count and whether the gate is open; the tick and the tick cap;
its inbox - the keeper's message from last tick, verbatim, or silence; the most recent non-empty
message and its age in ticks, so it is not amnesiac between transmissions; its own notes and
its own last six moves with their bump flags. It does NOT see the map, its own coordinates, the
other runners, the clock, the tide, or any other seat's notes. It learns about the water only
by seeing `~` in its window.

## Replies

Keeper: `{"transmit": true, "message": "Sprocket N; Gizmo E; Ratchet hold", "notes": "..."}`.
`transmit` absent is inferred from a non-empty message; an empty or whitespace-only message is
silence whatever the flag says. `message` is capped at 160 runes, `notes` at 400.

Runner: `{"move": "N", "notes": "..."}`. `move` is one of N, S, E, W, WAIT, case-insensitive,
with the aliases NORTH/UP, SOUTH/DOWN, EAST/RIGHT, WEST/LEFT and STAY/HOLD/H (`H` because the
rigid `<Alias>:<N|S|E|W|H>` grammar a keeper may use has to parse too). `notes` is capped
at 200 runes. Anything else is a parse failure: the seat is retried once with a hint and then
falls back to its role's scripted baseline. Every free-text field is truncated on RUNE
boundaries, never bytes.

## The two baselines

LANTERN (keeper). Breadth-first search from the exit and from every uncollected key over the
unflooded floor; assign each key to its nearest active runner, greedily, nearest pair first;
everyone else targets the exit. Order each runner the next step of its shortest path, aimed at
the tile it will stand on when the words land - a transmission arrives a tick late, so an order
for the tile the runner is on now is always one tile stale. Compose
`"<Alias> <N|E|S|W|hold>; ..."` and transmit on a rhythm of every other tick, breaking it when
a runner bumped, when the water has just come within two tiles of one, or when the gate has
just opened.

WALLHUG (runner). Blind. If the inbox - or, failing that, a standing order at most three ticks
old - names this runner's alias followed by a direction, and that direction is open and dry in
the window, take it. If the ordered direction is blocked, take the open, unflooded neighbour
nearest the ordered compass angle, clockwise on a tie. Otherwise follow the left-hand wall:
try left of the heading, then the heading, then right, then back. If everything is wall or
water, WAIT.

A lantern keeper with three wallhug runners is a competent filler team that a good prompt can
beat - which is the point of a baseline.
