# Raid — Ushkuynik

Policy: **Ushkuynik** (`ushkuynik`) — Novgorod river raider.

Coworld: `cow_978a7941-26c8-4fd7-886b-4bb7deb099ea` (coworld name `raid`)

Raid: five LLM-piloted cogs against SMELTER-9, a fully scripted foundry boss. The five seats are dealt one tank, one healer and three damage roles from the episode seed, so a policy cannot know its role when it is written and every prompt must cover all three. SMELTER-9 never adapts: it is bolted to the centre of a 300 px round pit with four sight-blocking pillars and runs a published, deterministic script of three phases - Forge, Slag and Meltdown - with a 90-degree telegraphed cleave, slag pours that leave burning pools, a Crucible Pour whose 240 damage is SPLIT between the bodies standing in it (nobody in it and the boss keeps a permanent +20% stack), an interruptible 4-second Overload that heals it 400 if it lands, waves of Slag Crawlers that make it hit 25% harder while four are alive, and a hard enrage at 240 seconds. Every five seconds each living seat issues ONE order - an intent, a target, a station and the reaction it pre-authorises for the next telegraph - and a deterministic control layer executes it at 24 Hz, so a policy chooses the reaction, not the dodge. The only channel between seats is a 32-character `say` that arrives one turn stale. Score is boss health removed divided by time spent, in units of the enrage timer (1.0 = killed it exactly on the timer), and every seat carries the identical number, so a healer who never touches the boss can be a champion. The game is LLM-driven: the server sends every living seat's prompt plus its view to Claude as ONE parallel batch per turn, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting PLAYER_PROMPT. Two scripted baselines (stalwart and greenhorn) play any seat that registers as scripted, and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_7a5e52fa-e85e-41ab-8a66-418653b02de2` — Raid

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — stalwart: The bundled certification player and the default baseline: the correct execution of the encounter, played by the server with no LLM involved. (run: `/bin/raid-player`)
- `greenhorn` — greenhorn: The weaker scripted baseline: everyone in melee, everyone dodging everything, nobody interrupting, nobody soaking, adds ignored. A clean floor for the ladder. (run: `/bin/raid-player`)
- `raid-player` — Raid Prompt Player: The reference raid policy: delivers its PLAYER_PROMPT to the game and spectates until the final frame. Field your own by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/raid-player`)

## Baseline

Default example: `baseline` = the scripted `stalwart` (the correct
execution: boss held north, triage healing, one owned interrupt,
crawler duty, stacked crucible soaks) — also the no-credential and
fallback player; `greenhorn` is the weak floor. Our `ushkuynik` is the
thin player rewritten in Nim (raid.player.v1 register frame, once on
connect) carrying an operator prompt that mirrors stalwart's assignments
and adds say-based job claims ("int:NAME", "soak:NAME"), a dead-soaker
fallback, and post-enrage burn priority. Supports PLAYER_PROMPT /
PLAYER_SCRIPTED (stalwart | greenhorn) overrides. LLM seats need
USE_BEDROCK=true at upload.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Verify the prompt actually beats scripted stalwart on hosted XP before iterating — the control layer may already saturate this encounter.
- Interrupt ownership A/B: alphabetically-first-dps rule vs "whoever said int: first" — measure Overload lands per episode.
- Score is hp/time: test a greedier opener (everyone burn_boss through phase 1, ignore the first crawler pair) for a faster clear.
- Healer mana line: tune the conserve threshold (85% raid hp) — an oom healer in Meltdown is the common wipe.
- Phase 3 stacking: loose ranged stack vs deliberate three-dps soak camp on the boss's south — count crucible zero-soaks.
- Tank cleave handling: on_telegraph hold (trust the north facing, keep uptime) vs dodge (side-step, lose position) — cleave hits on non-tanks per episode.
- Add a "boss below 10%: everyone burn, skip all mechanics" execute rule and measure clear time delta.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v3 | see git history | triage batch | paired vs champion | REVERT: 0.58->0.58 flat |
| 1 | tank is the crucible soaker | prompt: empty soak = +20% Spill; tank soaks alone at hp>60% (was "never soak / never soak alone"). Mixed with stalwart dps this was an empty soak: they only step in when tank hp<60%. | | | |
