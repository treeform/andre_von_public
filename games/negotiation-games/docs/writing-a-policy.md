# Writing a policy

A policy is just a prompt. Upload the published player image with your
strategy in `PLAYER_PROMPT`:

    coworld upload-policy <image> --name my-negotiator \
      --run /bin/negotiation-player \
      --secret-env PLAYER_PROMPT="<your strategy>"

## What your prompt sees

Every turn the game server composes, for the acting seat only:

- its own alias and the opponent's alias, `match m of M`, `turn t of maxTurns`;
- the pool counts per item type, and ITS OWN private values per item type,
  with the reminder that the whole pool is worth 10 to it;
- the offer standing against it rendered from its own side ("they take ...,
  you get ...") with the worth to itself already computed, plus an explicit
  `ACCEPT IS LEGAL NOW: yes|no` line and the explicit per-type bounds;
- the full offer history of THIS match, both sides, each with its worth to
  this seat, and each side's messages;
- its own record so far this episode (per settled match: opponent alias,
  deal/no-deal, `u/10`);
- its own private notes, fed back verbatim;
- your prompt, under "GUIDANCE FROM YOUR OPERATOR".

It never sees the opponent's private values (or any function of them), the
opponent's notes, anything about matches it is not in, the seed, the future
schedule, or the policy name of any seat including its own.

## The reply schema

    {"action": "offer",  "take": {"books": 2, "hats": 0, "balls": 1},
     "message": "<= 200 characters", "notes": "<= 400 characters"}
    {"action": "accept", "message": "<= 200 characters", "notes": "<= 400 characters"}

Parsing is tolerant in exactly these ways: `action` is matched
case-insensitively after trimming (`accept|agree|deal` and
`offer|propose|counter` are synonyms); `action` absent with `take` present
means an offer; `take` may be the object above (missing keys are 0) or the
3-element array `[books, hats, balls]`, with JSON integers or
integer-valued strings. Anything else - a fractional count, an out-of-range
count, `accept` on turn 1, an unknown action, no JSON object in the reply -
is an invalid reply.

Both caps are measured and cut in RUNES, not bytes, with a trailing ellipsis
marking the cut.

## When a reply does not parse

An invalid or illegal reply is retried ONCE with an appended hint line. A
second failure, a transport error, a timeout, a refusal or missing
credentials falls back to the seat's scripted baseline, applied with
`scripted: true`, and increments `results.fallbacks[seat]`. A seat that
registered a prompt (or nothing) falls back to `haggler`. The scripted move
is always legal, so the turn always advances.

## The two baselines

Both are fieldable policies in their own right
(`PLAYER_SCRIPTED=haggler|hardliner`). Let `t` be the turn, `T = maxTurns`,
and `worth(x)` the bundle's value under this seat's own values.

**haggler** - a monotone conceder, and the universal fallback.

1. Reservation `R(t) = clamp(round(10 - 6 * (t - 1) / max(T - 1, 1)), 4, 10)`:
   10 on turn 1, decaying linearly to 4 on turn `T`.
2. Endgame override: on this seat's last turn of the match (`t > T - 2`),
   `R(t) = 1`.
3. If a standing offer exists and the complement is worth at least `R(t)`,
   accept.
4. Otherwise enumerate every legal `take` and choose the one with the
   SMALLEST `worth(take)` that is still at least `R(t)`; ties break by the
   fewest total items taken, then by the lexicographically smallest vector.
   (Taking the whole pool always qualifies, so the set is never empty.)
5. Never emits a message or notes; uses no RNG.

**hardliner** - identical except for the reservation: `R(t) = 8` while
`t <= T - 2`, and `R(t) = 3` on this seat's last turn. It refuses most splits
and gets its way against a conceder.
