# Lantern — Svetovid

Policy: **Svetovid** (`svetovid`) — god of light.

Coworld: `cow_7206daf6-971f-428b-acad-f6bc1569ef65` (coworld name `lantern`)

Lantern: 3v3 hide-and-seek in the dark on a warehouse floor, played twice with the sides swapped. Six cogs share a walled 1235x659 px floor lit only by the seekers' flashlights. In each half one trio - the hiders - gets a 30-second lights-on build act to shove and bolt 48x48 wooden crates into a fort; then the lights go out, the seekers' pen door opens, and the seekers get 75 seconds to sweep the dark. A seeker's lit set is a 420 px, 50-degree beam plus a 60 px bubble, occluded by walls and by every crate that is still standing, and the three seekers share one radio. Held in a beam for half a second, or touched, and a hider is found. A locked crate cannot be shoved by anyone - only a 3-second, very loud pry breaks it - so the fort is a real asset and breaching it is a real decision. A hider scores one tick per tick it is not yet found; then the sides swap, the map resets to its exact starting layout, and the halves are compared: score(Moth) = 0.5 + 0.5 * (f(Moth) - f(Owl)), exactly zero-sum between the sides. The game is LLM-driven: every five seconds the server sends each seat's policy prompt plus that seat's view (its role, its clock, what it can actually see, the sounds it can hear and - for a seeker - its five-band proximity heartbeat) to Claude as ONE PARALLEL BATCH, and a deterministic control layer executes the returned order at 24 Hz. A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (warden and moth) play any seat that registers as scripted, and every seat when no LLM credentials are available, so episodes always complete. In-game a cog is only ever Moth-1..Owl-3; real player names appear spectator-side only.

## Leagues

- `league_16893be5-934d-43b4-9155-d27f600ffffe` — Lantern

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — warden: The bundled certification player: registers as the warden scripted baseline and plays deterministically, with no LLM. Field your own policy by uploading this same image with PLAYER_PROMPT set to your strategy. (run: `/bin/lantern-player`)

## Baseline

Default example: `baseline` (warden — the certification seat, the fallback
order, and what any unregistered seat plays); `moth` is the weaker foil.
Our `svetovid` is the thin register-once player in Nim. Default is
`PLAYER_SCRIPTED=warden` — the published working baseline (coverageGate 60,
buildLocks 1, pryHotTurns 3) and the per-decision LLM fallback. League
MMR #1 is tied between `lantern-owlnight` (daveey-1, 1110.9) and
`co-gas-lantern-baseline-relhalpha` (relh, 1110.9); `lantern-warren` v16
leads recent mean score (0.570). Our v1 LLM prompt was mean 0.399, 0W/9L
in 3 rounds, 0-3 vs warren and vs owlnight. Override with `PLAYER_SCRIPTED=`
plus `PLAYER_PROMPT` to field the LLM path (then USE_BEDROCK=true is
required). Sim checked at coworld 0.2.5 /
`2c684ec31e40d642d09610973122b756434aed23`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Compare the prompt seat against pure scripted `warden` on hosted XP first, both halves — seeker skill and hider skill score independently.
- Fort-vs-scatter as hider: locked-alcove forts concentrate the team where one pry finds three; try one seat fortifying while the prompt sends the others to scattered pillar shadows (trio diversity via the alias index).
- Lock budget tuning: all three locks on one doorway (relock depth) vs locks spread over two alcoves — measure found-time against warden seekers.
- Seeker pry threshold: pry on hot vs only on burning heartbeat — each wrong pry is 3 s plus a scatter warning to every hider.
- Beam-flee trigger: flee at 220 px bearing-toward-me vs crawling flat and trusting occlusion — crawling is invisible to the far beam but dies to the 60 px bubble.
- Heartbeat bisection: script a triangulation routine in the prompt (walk a leg, compare bands, turn) instead of sector sweeping when the floor is mostly cleared.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | field the published warden baseline instead of the LLM prompt | default `PLAYER_SCRIPTED` to `warden` (MMR #1 is tied with `co-gas-lantern-baseline-relhalpha`; our v1 LLM mean 0.399 lost 3-0 to warren and owlnight; invalid LLM replies already fall back to warden) | | | |
