# Werecog — Volkolak

Policy: **Volkolak** (`volkolak`) — the Slavic werewolf.

Coworld: `cow_684dcc82-a5c0-45d6-804a-8fc8dd2b77db` (coworld name `werecog`)

A five-player hidden-role social-deduction benchmark (One Night Ultimate Werewolf): agents reason about secret roles and night card-swaps, bluff or coordinate through a discussion, and vote to find the werewolves.

## Leagues

- `league_01dfa32d-0587-4793-8a29-b917cec01fde` — Werecog

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `werecog-scripted` — werecog Scripted Baseline: Deterministic no-LLM baseline (skips the night, votes the next seat). Certifies the contract offline. (run: `node dist-server/coworld/baseline-player.js`)
- `werecog-llm` — werecog LLM Baseline: A Bedrock-driven policy that plays the seat through the game's autopilot (system prompt + per-turn tool). (run: `node dist-server/coworld/llm-player.js`)

## Baseline

Default example is `werecog-scripted` (Node): wolfPeek center 0 / seer looks
at the next seat / robber & troublemaker skip / speaks "I have nothing to
add." / votes the next seat. Strongest is `werecog-llm` (Bedrock through the
game's autopilot) — not portable to a deterministic Nim seat.

`volkolak/volkolak.nim` is a command player on cogweb.player.v1 that covers
the scripted baseline's contract and upgrades it with the seat's private
night knowledge: the Seer inspects the next player and publicly names a
caught wolf (LLM tables act on named accusations), the Robber robs the next
seat (known team at dawn; the target is then provably village), any
wolf-holding seat bluffs Villager and never votes a fellow wolf, and votes
follow hard evidence (seer-seen wolf) before the baseline next-seat vote.
Rejected replies fall back to the upstream always-legal baseline decision.
No secret-envs needed on upload (no LLM).

Protocol confidence: pinned from Metta-AI/metta werecog at the
coworld-tournament commit 70a6a77f58, which matches the shipped manifest
docs exactly (night/speak/vote decisions, round-robin day). NOTE: metta
HEAD has since removed the `speak` decision (day became free-form comms
talk); if the deployed image is ever rebuilt from HEAD, day observations
stop arriving and Volkolak keeps working (it only answers what is asked),
but the speak branch goes dead — re-verify after any game-image bump.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Parse the day `discussion` transcript for counterclaims: if another seat
  also claims Seer/Robber against our own dealt role, vote them (a
  contradicted claim is the strongest deterministic wolf signal).
- Seer center-peek variant: look at two center cards instead of a player;
  when both wolves are in the center, speak it and vote to spread (1 vote
  each kills nobody, village wins) — measure vs the player-peek build.
- Vote herding: in the last discussion round repeat the vote target by name
  ("Vote X") — LLM opponents follow explicit late instructions more often.
- Troublemaker swap of the two loudest accusers instead of skipping; wolves
  who counterclaim get their cards moved, flipping the dawn teams.
- As lone wolf, counterclaim Seer with the peeked center card as "evidence"
  (a concrete false sighting beats a bare Villager claim).
- Robber target selection: rob the previous seat instead of the next so the
  seer (next-seat inspection convention) and we cover different seats.
- Insomniac/dealt-wolf tie: when we END as village but were dealt wolf,
  reveal the dealt-wolf-swapped-away story — it pins the card's new holder.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | vote unique-role counterclaimers | parse `view.discussion` for another seat claiming our unique dealt role (Seer/Robber/Troublemaker/Insomniac) and vote them ahead of seer-seen-wolf / next-seat; LLM autopilot tells wolves to fake Seer/Robber, and a second claimer of a once-per-deck role is lying | | | |
