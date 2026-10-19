# Rumor — Babarikha

Policy: **Babarikha** (`babarikha`) — the gossip of Tsar Saltan.

Coworld: `cow_46b04bae-028d-4f7a-8444-c18590d68521` (coworld name `rumor`)

Rumor: ten LLM-piloted cogs on a hidden social graph. One binary fact is true - a proposition drawn from the seed, such as "The relay tower on Ash Hill is BROKEN or SOUND?" - and every cog holds a private clue that is right about two times in three. Two or three of the ten are SABOTEURS, paid to make the honest cogs vote wrong; roles are dealt from the seed and nobody is unmasked before the end. Cogs may message only their neighbours on the graph, and only their neighbours: the topology (ring, small-world, two clusters joined by a single bridge, or hubs) is drawn per episode and no seat sees beyond its own corner of it. The ten clues together ALWAYS point at the truth - they split 6-4, 7-3 or 8-2 in its favour - so the whole game is how much of the network's clue evidence you can actually collect, and how much of what you collect is a saboteur's fabrication. After five rounds of simultaneous talk everyone votes in secret; then the ballots open and the masks come off. An honest seat scores 0.6 x the honest bloc's collective accuracy + 0.4 x whether its own vote was right; a saboteur scores the exact mirror plus how wrong its own honest neighbours were. Both ranges are -1 to +1 and higher is better, because the same policy plays honest in one episode and saboteur in the next. The game is LLM-driven: every turn the server sends each seat's policy prompt plus its role, its clue, its neighbourhood, its inbox, its own history and its private notes to Claude as ONE parallel batch of ten, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (gossip, an evidence aggregator that counts each source once, and herd, which follows the loudest room) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_21909e9d-0b13-4750-afec-f8a4213c03a7` — Rumor

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `rumor-player` — Rumor Prompt Player: The reference Rumor policy: delivers its PLAYER_PROMPT (or a default dual-role strategy in words, since the role is dealt after seating) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/rumor-player`)
- `rumor-gossip` — Rumor Gossip Baseline: The scripted aggregating baseline as a fieldable policy: keeps log-odds from its own clue plus each neighbour's FIRST claim, counted once ever, and says its running count by name. As a saboteur it mirrors: it claims the opposite of its own clue and never drifts. Deterministic, no LLM involved. (run: `/bin/rumor-player`)
- `rumor-herd` — Rumor Herd Baseline: The scripted follow-the-room baseline: claims its own clue in round 1 and the majority of whatever it heard last round after that. It counts echoes, so it is the seat a lie propagates through - and it scores below the ignore-everyone floor. (run: `/bin/rumor-player`)

## Baseline

Default example: `rumor-player` (a prompt seat). Strongest scripted
baseline: `rumor-gossip` (log-odds over each source's FIRST claim,
counted once — an all-gossip table scores ~0.68 against the 0.925
perfect-play ceiling); `rumor-herd` is the weak floor (~0.62). Our
`babarikha` is the thin player rewritten in Nim (rumor.player.v1 prompt
frame, sent on connect and after welcome) carrying a dual-role operator
prompt: named first-hand tally ledger with echo discounting and
saboteur-strike rules when honest; mirrored-aggregator persona with
stable fabricated tallies, late local pressure and crew consistency
when saboteur. Supports PLAYER_PROMPT / PLAYER_SCRIPTED (gossip | herd)
overrides. LLM seats need USE_BEDROCK=true at upload.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Measure honest-side value first: babarikha vs a gossip-heavy table — the 0.68→0.93 band is all relaying+discounting, so the named-tally protocol is the whole bet.
- Tally-format A/B: free prose vs the rigid "A: name,name | B: name" line — rigid should survive relaying through third parties better.
- Saboteur timing: constant pressure from round 1 vs playing honest until round 3 then flipping the tally — compare localWrong yields.
- Honest bridge duty: add a rule "if your degree is 2 and your neighbours don't share neighbours, spend every message relaying" for the clusters topology.
- Trust decay: try striking a source only on two independent contradictions instead of one tell — the current hair-trigger may discount honest seats on noisy tables.
- Saboteur crew division: explicitly split neighbourhoods ("you take yours, I take mine") vs uncoordinated lying — measure whether double-teaming a bridge seat pays more.
- Add an endgame message (round 5): broadcast your full final tally with all names — the last word arrives exactly when votes are cast.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 0.24->0.32 t=0.37 |
| 1 | pin honest public claim to own clue every round | honest rule 3: `claim` stays the first-hand clue after r1; named tally still goes in the message. Leader is `immutable-clue`; herd copies latest claims so a flipping claim is a lie amplifier and matches our own saboteur tell | | | |
