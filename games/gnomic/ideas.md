# Gnomic — Gnom Gnomych

Policy: **Gnom Gnomych** (`gnom_gnomych`) — the gnome of gnomic.

Coworld: `cow_31a8dfdf-3237-4582-8641-9206eddc00b7` (coworld name `gnomic`)

Three gnome elders of Heartleaf convene the Gnome Moot and rewrite Gnome Law while living under it: natural-language moves, self-amending rules, secret votes, deterministic Fate, and binding schema-checked Opus 4.7 rulings from the Elder. Point victory starts at 100, checked after full circuits, with a 45-turn cap.

## Leagues

- `league_4788bdc9-67da-4b00-a8e2-265a8169e7f7` — Gnomic

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Gnomic Baseline: Deterministic no-network gnome for certification; passes actions, proposes harmless enactments, and votes AYE. (run: `python -m gnomic.players.baseline`)

## Baseline

Only one example ships: `baseline` (deterministic, no network — passes
actions, proposes harmless enactments, votes AYE; also the certification
fixture, three copies). Our **Gnom Gnomych**
(`gnom_gnomych/gnom_gnomych.nim`) is a command player in the
nomic/tsar_gorokh shape with one sharpened edge: it passes every action
(and the one repair), cycles five clear harmless enactments (adoption
pays the proposer 3 points), debates mildly, and votes BY LEDGER — AYE
on its own measure, NAY on everybody else's. Under the opening
unanimity regime (two full circuits) one NAY rejects a rival measure
outright (-1 to its proposer) while AYE-voting baselines still adopt
ours (+3 to us); after the two-AYE regime begins our NAY is inert
against two cooperating seats, so the downside is bounded. Own-measure
detection needs no unspecified fields: the seat that received this
turn's proposal_request is this turn's proposer (reset on turn_start).
vote_intent in debate is private per the manifest, so the mild AYE-toned
debate text leaks nothing. `GNOM_FRIENDLY=1` reverts to
baseline-identical AYE-on-everything. Zero model calls — upload needs
NO secret-envs (the Elder judge LLM runs in the game pod).

Protocol-confidence caveats (no source repo; the manifest protocol page
is a summary, not a field-level spec — same situation as nomic):
- Confident: rid echo, vote `{vote:"aye"|"nay", reason}`, debate
  `{text, vote_intent}`, proposal kinds enact|amend|repeal|transmute,
  malformed action => pass, malformed vote => NAY (our NAY default is
  also the failure mode, so a wrong vote field name degrades to the
  intended behavior on rival measures and to a self-NAY on ours — watch
  the first hosted round's vote_reveal).
- Guessed: action reply field (both `action` and `text` = "pass" sent)
  and proposal reply shape `{rid, kind:"enact", text}`; if a hosted run
  shows our proposals defaulting, capture a /global exchange and fix.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Verify the vote ledger pays: run the same build with GNOM_FRIENDLY=1
  and compare game_points across a few hosted Moots — if vote_reveal
  shows retaliation from LLM entrants, friendly may dominate.
- Fate-proof victory math: 45 turns of +3 proposals caps near 45 points
  + Fate; propose an amendment lowering the 100-point victory threshold
  (or raising adoption reward) once per game — a passed threshold
  amendment converts our proposal-income lead into an actual
  constitution_victory instead of a turn-cap co-win.
- Anti-transmutation watch: parse proposal_made events for `transmute`
  and vote NAY always (even in friendly mode) — protected procedural
  rules are the opponent's path to rewriting victory in their favour.
- Action mining: the initial law may authorize point-earning actions
  beyond pass; try one conservative natural-language move ("I move
  along the circuit as the rules allow") and read the ruling — a
  rejected action costs nothing after its free repair to pass.
- Debate-informed voting: recompute the final vote after both rivals'
  debate statements (the manifest says to) — flip to AYE when both
  rivals' statements signal AYE on a measure that raises everyone
  equally, keeping the NAY for measures that name a beneficiary.
- Proposal text hardening: our five enactments are near-duplicates by
  circuit 3 and an Opus judge may veto repeats as incoherent with
  existing law; generate numbered variants ("Turn summaries, part N")
  to stay adoptable all 15 circuits.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
