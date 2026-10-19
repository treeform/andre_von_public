# Cogplomacy — Vladimir Krasno Solnyshko

Policy: **Vladimir Krasno Solnyshko** (`vladimir`) — the prince whose court every bogatyr serves — diplomacy.

Coworld: `cow_9f7d3cbd-97fa-4d04-a835-1ad0661ca3a1` (coworld name `cogplomacy`)

Cogplomacy is Allan Calhamer's Diplomacy for seven LLM-piloted cogs: the 1901 map of Europe, seven great powers (Austria, England, France, Germany, Italy, Russia, Turkey), armies and fleets, and the classic simultaneous-orders adjudication. Each game-year runs a Spring and a Fall movement phase, and before each one there is a PRESS phase in which all seven powers write, simultaneously and in free text, one public broadcast and up to six private letters. Nothing said in press binds anything. Then all seven submit an order set at the same time and the adjudicator resolves it: supports, convoys, standoffs, cut supports, dislodgements, retreats and Winter builds. There is no randomness anywhere - outcomes are entirely a function of what seven agents promised each other and what they actually ordered. A power that holds 18 of the 34 supply centres wins outright; otherwise the episode is scored at the turn cap by supply-centre share, so handing your centres to an ally at the end lowers your own score one for one. Powers are dealt from the seed and seats address each other only as FRANCE or RUSSIA, never by policy name, so no one can recognise a friend across episodes. A power may attach machine-checkable PLEDGES to its press (peace, keep out of a province, support someone); breaking one is recorded as a STAB and stamped on the map. The game is LLM-driven: every phase the server sends each seat's policy prompt plus the whole board, the ownership table, two years of history, the press that seat received and its private notes to Claude, as ONE parallel batch for all seven seats - so A POLICY IS JUST A PROMPT. Build one by reusing the published player runnable and setting PLAYER_PROMPT to your strategy. Two scripted baselines (expander and hedgehog) play any seat that registers as scripted, and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_cb035e15-dbab-4478-9528-64a997be502a` — Cogplomacy

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `cogplomacy-player` — Cogplomacy Prompt Player: The reference Cogplomacy policy: delivers its PLAYER_PROMPT (or a default Diplomacy strategy in words) to the game and spectates until the final frame. Every decision - press, orders, retreats and builds - is made by Claude from that prompt plus the seat's view of the board. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/cogplomacy-player`)
- `cogplomacy-expander` — Cogplomacy Expander Baseline: The scripted greedy baseline as a fieldable policy: registers its seat as rule-based (take an unowned neutral centre, else an undefended rival centre, else close the distance to one; never stand yourself off; support a neighbour when there is nothing better) so the game server plays it deterministically, no LLM involved. It is also the fallback for any decision that fails. (run: `/bin/cogplomacy-player`)
- `cogplomacy-hedgehog` — Cogplomacy Hedgehog Baseline: The scripted wall: every unit holds, and a unit next to one of its own units sitting on a centre it owns props that unit up instead. It never attacks anybody and never grows past its start - the partner a prompt can safely ignore and the neighbour that cannot be talked into anything. (run: `/bin/cogplomacy-player`)

## Baseline

`cogplomacy-expander` (scripted greedy: unowned neutral > undefended
rival centre > close distance, never self-standoff, support when
nothing is better, always build) is the stronger example and the
fallback for every failed LLM decision; `cogplomacy-hedgehog` only
holds and props. The default `cogplomacy-player` is a prompt seat.
Our policy `vladimir` sends the standard
`{"type":"prompt","prompt","scripted"}` hello on connect and after
welcome, then spectates to `final`. **v2 defaults `PLAYER_SCRIPTED` to
`expander`**: score is `c/34` (or 1.0 on a solo of 18), ownership
flips only after Fall, and an illegal order is a HOLD — expander is
that scoring function as a bot. The unused operator prompt is still
centre-share Diplomacy (year-1 neutrals, Spring position / Fall
occupation, one ally + one victim). `PLAYER_PROMPT` / `PLAYER_SCRIPTED`
override; empty `PLAYER_SCRIPTED` restores the prompt as an LLM seat.
The default scripted seat needs no Bedrock secret; LLM override still
needs `--secret-env USE_BEDROCK=true` or the seat silently plays
expander.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Power-specific openings: append a table of classic year-1 neutral
  grabs per power (England: NWY; Turkey: BUL...) so the LLM does not
  re-derive them each phase.
- Anti-leader trigger tuning: coalition threshold at 10 centres vs the
  current 15 — in 4-year games the runaway usually shows by year 2.
- Pledge-heavy trust build: pledge peace with every non-victim in
  Spring year 1 and measure how often we get stabbed vs the no-pledge
  prompt.
- Never-stab control: a fully honest variant (no stab clause at all) —
  in short games the stab may never pay; measure mean centre count.
- Fall-cover audit: replays likely show home centres left open during
  Fall pushes; strengthen the cover rule to "never fewer units home
  than adjacent enemy units" and compare centres lost.
- Convoy usage: England/Turkey seats may underuse convoys; add one
  line naming VIA CONVOY for army landings and check order legality
  rates in replays.
- Notes schema: force notes into "PROMISES:/PLANS:/GRUDGES:" sections
  and test decision consistency across phases.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field the published scripted `expander` instead of the LLM prompt. Score is c/34 (1.0 only on a solo of 18, rare in 4 years); unclaimed neutrals dilute everyone equally so the cheap centre is the right centre; illegal orders become HOLD and unbuilt Winter entitlement is waived. Expander is that math: (a) unowned neutral (b) empty rival centre (c) close distance, never self-standoff, support a neighbour when nothing is better, always build. Failed LLM replies already fall back to expander, so a last-place prompt (876.9, #6/6 vs daveey-1 diplomat 1091) can only lose units relative to this floor. League leaders are diplomat/opportunist/gambit LLM seats, not expander — this is the scoring bot, not a prompt copy. | default PLAYER_SCRIPTED to `expander` in vladimir.nim (env still overrides; PLAYER_SCRIPTED="" forces the prompt) | | | |
