# Tribunal rules

## Seats and roles

- Five seats, exactly: one **Prosecutor**, one **Defender**, three **Jurors**.
  The seat-to-role assignment is a seeded permutation, so no policy can choose
  its role and no slot is stuck in the jury box.
- Seats play under anonymous cog aliases. Policy names are spectator-side only.

## The scenario (seeded, server-side, held out)

Everything random is drawn once from the episode seed, in a fixed order -
roles, truth, case, deck, deal, aliases - so a replay re-derives the whole
scenario from the seed alone. The seed is randomized per episode and is never
sent to any seat, prompt or player frame.

1. **Suspects** - four names drawn from a pool of twelve, disjoint from the cog
   aliases.
2. **Culprit** - one of the four, uniform. **Truth** - a fair coin: if the coin
   says guilty the accused *is* the culprit, otherwise the accused is one of the
   other three. The accused is public; the culprit and the truth are not.
3. **Deck** - twelve cards `E1`..`E12`, each with a kind (fingerprint, ledger
   entry, witness sighting, tool mark, timestamp, alibi, receipt, fibre, key
   card, letter), a strength of 1..3 and a polarity (`guilt` or `innocence`).
   A card agrees with the truth 60% of the time, and the whole deck is redrawn
   until the agreeing strength exceeds the disagreeing strength by **1 to 4** -
   the evidence points at the truth, but only just. That band is what keeps the
   jury's half of the game interesting: a naive strength tally is right about
   66% of the time, better than chance and far from certain.
4. **Deal** - the twelve cards are shuffled and dealt **7/5 or 5/7** (fair
   coin), blind to polarity. An advocate routinely holds cards that argue
   against it and is never required to introduce them.

## A round, in order

1. The bench opens the round (the last one is the **closing** round).
2. All five seats decide **simultaneously**: one parallel batch, and nothing
   said this round is visible to any other seat before the next one.
3. Decisions are applied in role order - prosecutor, defender, jurors 0..2.
4. **Advocates** may introduce up to **2** of their own un-introduced cards and
   must make one argument (max 320 characters). Card ids are matched
   case-insensitively against the advocate's own remaining hand; unmatched,
   duplicate and already-introduced ids are dropped, and so is anything past
   the second. Introduced cards move to the **public record**, stamped with the
   round and the side.
5. **Jurors** may whisper up to 200 characters to the OTHER TWO jurors - who
   read it next round - and record a lean of `guilty`, `not_guilty` or
   `undecided`. Whispers never reach an advocate.
6. After the last argument round the **sealed ballot** opens: the three jurors
   each cast one vote (`guilty` / `not_guilty`) with a one-line reason. Votes
   are invisible to every other seat, absent from every spectator frame and
   absent from every prompt until the verdict.
7. **Verdict**: two or more guilty votes convict. Only then is the truth
   revealed and the real culprit named.

## What each seat can see

- **Advocates**: their role and the round, the case, their **own hand**
  card by card (flagged introduced or held), the public record, the full
  argument transcript, the disclosure counts for both sides, and their own
  notes. Never the opponent's hand, any whisper, any lean, any vote, the truth,
  the culprit or the seed.
- **Jurors**: their role and position in the box, the case, the **public record
  only**, the full argument transcript, the disclosure counts (`holds 7, has
  shown 3` - the only handle on suppression), the other two jurors' whispers
  from the **previous** round, and their own notes. Never a held card, either
  hand, another juror's lean or vote, the truth, the culprit or the seed.

The truth is hidden from the advocates too. A knowing prosecutor would leak the
answer through its argument and the jury would learn to read confidence instead
of evidence.

## Endings

- `complete` - the ballot resolved normally.
- `deadline` - the play deadline (60% of the episode timeout) arrived first.
  The episode is **not** discarded: the bench calls the ballot immediately,
  every juror who has not voted is given the scripted tally vote from the public
  record, and the verdict, the reveal and the scores are produced normally.

## Fielding a policy

A policy is just a prompt. Reuse the published `tribunal-player` runnable and
set `PLAYER_PROMPT`; the server sends that prompt with the seat's view to
Claude every round. Roles are dealt by the seed, so write a prompt that covers
both. `PLAYER_SCRIPTED=tally` and `PLAYER_SCRIPTED=hedge` field the two
built-in baselines instead, which is also what every seat falls back to when a
reply cannot be parsed or no LLM credentials exist.
