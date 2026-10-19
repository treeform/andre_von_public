# Chorus rules

## Seats and voices

- Four seats, four voices: 0 Bass (base MIDI 36), 1 Tenor (48), 2 Alto (60), 3 Soprano (72).
- The seat-to-voice assignment is a **seeded permutation**, redrawn every episode. This is the
  cross-author seating the game is built on: a policy cannot specialise on one register across a
  league round, and the same four policies re-seated write a different piece.
- Nobody else can write a note in your voice and you cannot write a note in theirs.

## The piece

- `bars` bars (default 8, range 4..16). Every bar is exactly **16 steps**.
- Key: a root pitch class drawn from C, D, E-flat, F, G, A.
- Mode: one of ionian, dorian, aeolian, mixolydian.
- Tempo: 84, 90, 96, 102 or 108 BPM.
- Chord plan: one chord per bar, from one of four progressions tiled across the piece
  (I IV V I / I vi IV V / I V vi IV / vi IV I V). The chord tones of a chord rooted on degree r are
  r, r+2 and r+4. **The whole plan is public from turn 0** - it is the shared score sheet.
- All of it is drawn from the seed, so a replay re-derives everything from the seed alone.

## Notation

A bar is 16 integer tokens, one per step:

- `-1` is a **rest**.
- `0..13` is a **scale degree**: 0 the tonic, 6 the seventh, 7 the tonic an octave up, 13 the
  seventh two octaves up. `midi = base + 12 * (d div 7) + scale[d mod 7]`, where `base` is your
  voice's base MIDI note in the episode's key; every legal token lands in `base .. base+23`.
- Every note lasts **exactly one step**. There are no ties, sustains, velocities or rests of
  length. A step is an onset if and only if its token is at least 0.

## A turn, in order

There are exactly `bars` turns, one per bar. Turn `t`:

1. **Open.** Every voice HOLDS its previous bar (`grid[v][t] := grid[v][t-1]`, or 16 rests at
   `t = 0`). Last turn's messages become this turn's `heard`.
2. **Observe.** Each seat is shown its voice, the complete grid, the whole chord plan, the live
   piece score and its four components, its OWN counterfactual credit, the other seats' lines from
   last turn, its private notes, and the exact list of legal targets.
3. **Decide.** All seats decide **simultaneously**; nobody sees another seat's bar for this turn
   until it resolves. All the LLM calls go out as one parallel batch.
4. **Validate.** A reply that times out, fails to parse or is illegal is retried once with an
   explicit hint; a seat still open after that plays the `arpeggio` baseline, which is legal by
   construction.
5. **Apply**, in seat order. `target` must satisfy `0 <= target <= t` and `steps` must be exactly
   16 tokens, each `-1` or `0..13`. Each seat writes only its own voice, so the resulting grid is
   order-independent.
6. **Resolve** once all four bars are in.

## Hold versus edit

`target = t` writes the new bar. `target < t` **rewrites one of your own earlier bars**, and the
hold at `grid[v][t]` stands unchanged - spending the turn on the past costs you the new bar. That
is the whole trade: repair a weak early bar, or add a new one.

## Caps

| field | rule | cap |
|---|---|---|
| `target` | `0 <= target <= t`; a MISSING target defaults to `t` | - |
| `steps` | array of exactly 16 integers, each `-1` or `0..13` | 16 |
| `say` | one line all three other cogs read next turn; forced to `""` when talk is off | 100 runes |
| `notes` | private, fed back to you verbatim next turn | 600 runes |

`steps` is also accepted as a string of 16 whitespace- or comma-separated tokens where `.`, `-`,
`r`, `R` and `rest` all mean a rest; floats are rounded and numeric strings are accepted. Every
string that reaches the replay is truncated on **rune** boundaries.

## What is hidden

Almost nothing. The metric, its weights, the chord plan, the key, the tempo and the whole grid are
public by design - this is co-composition against a known ruler, not a guessing game. Hidden from a
seat: the other seats' credits, the other seats' private notes, the other seats' move for the
current turn, and every policy display name (seats know each other only as cog aliases).

## Endings

| `reason` | when | scoring |
|---|---|---|
| `complete` | all `bars` turns resolved | over all `bars` bars |
| `deadline` | the play deadline was crossed between turns | over the bars actually written, which is always a well-formed piece |

There is no third path. An episode never ends because a seat disconnected (its bars simply hold),
never because the LLM is unavailable (the scripted fallback plays), and never mid-turn.
