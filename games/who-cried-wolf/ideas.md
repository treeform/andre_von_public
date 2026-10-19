# Mafia: Who Cried Wolf? — Volchok

Policy: **Volchok** (`volchok`), the little grey wolf of the Russian lullaby.

Coworld: `cow_2db310d1-7ebc-4f9e-97d4-e38dbf380aba` (`Mafia: Who Cried Wolf?`, 0.2.9, owner jt)

Nine-seat Mafia on the NewD3 setups: two wolves (Wolf, Alchemist or Track
Reader, or two Wolves) and seven town (Seer, Guard, Chef, Priest, Dairy
Maid, Nobles, Sheep). Wolves and Nobles chat privately, everyone debates,
a strict majority of the living (abstentions count) eliminates one player
per day, wolves kill at night. Every death reveals role and faction.

## Leagues

- `league_a10c10a8-46da-4f0f-bff6-4087c8dac619` — Who Cried Wolf Competition Pilot.
  Variant `standard` (bots mode, human-paced timers), one episode per round,
  rounds every 288 min, Elo k=32 on mean round score, 9 seats filled with
  `relh-wcw-filler:v1` (scripted).

Field at 2026-10-06 (round 64): EntropyFails `wcw-kimi:v7` (bundled LLM
player, Kimi), relh `relh-wcw-scripted:v1`, richard `richard-wcw-scripted:v1`.

## Scoring (from build/game.mjs, wcw.results/2)

`score = 0.75 * win + 0.25 * bonus`. Draw (8 nights) gives win 0 to all.
Town bonus `read` = mean over vote days of `max(0, 1 - Brier(report) /
Brier(know-nothing))`, a missing report scores 0. Wolf bonus `hidden` =
`max(0, (chance - mean town report on me) / chance)`, 0 when no town
reports exist.

## Field behaviour (replay of round 64)

- Scripted seats (bundled `build/player.mjs`) vote and target at random
  and speak a template line. They act on day 1, then disconnect after the
  first death reveal (the old strict schema rejects `elimination.role`).
  From day 2 every ballot is null and every night action passes.
- `wcw-kimi:v7` fails every request with `provider_error`.
- Result: draws at the day cap, every seat 0.

## Baseline

Default example is `scripted` (Node, random legal actions). Strongest is
the `llm` client (Bedrock or OpenRouter) but it is currently broken in the
league. `volchok/volchok.nim` is a deterministic command player:

- Answers every request immediately and re-dials the seat on disconnect.
- Town: exact Bayesian wolf probabilities with every vote, enumerated over
  all nine decks and every fixed fact (own role, Noble mates, death
  reveals, Seer inspects, Dairy Maid informs, Priest tracks, a 3x wolf
  weight for a tracked visitor of that night's victim). Votes a known wolf,
  a clear suspect, or a two-accusation wagon, otherwise abstains.
- Seer and Priest claim hard results in speech with the accusation field
  set, so LLM seats can follow.
- Since v2 no decision reads chat; ballots replace it (see Behaviour
  model below).
- Wolf: kills every night (Track Reader checked power roles, then players
  who voted the pack, then seats that vote at all), hands the knife to the
  partner so the Priest sees us visit nobody, never votes the pack, claims
  Sheep, joins the town wagon.
- Alchemist blocks, Track Reader checks unchecked town, Guard and Dairy
  Maid favour claimed power roles and working seats, Chef jails and Priest
  tracks the top suspect.
- No secret-envs, no LLM.

Expected edge in the current field: wolves need five kills for parity
and only our kills land, so wolf games become wins by night 5; town games
draw but collect `read` when we hold a result.

## Behaviour model (user strategy, 2026-10-06)

Ignore chat. Deduce from who votes, how, and when. `tools/wcw_xp.nim`
tallies ballots by voter faction; 40 functional episodes (Haiku seed,
aaron-wolfwright, co-gas relh bots) gave:

| voter | ballots | abstain | on a wolf | chance | on a packmate |
|---|---|---|---|---|---|
| town (all bots) | 874 | 52% | 122 | 133.6 | - |
| wolf (all bots) | 344 | 23% | - | - | 7 (chance ~45) |

Town LLM votes land on wolves at or below chance (no signal). Wolves
almost never vote a packmate and abstain far less than town
(aaron-wolfwright: 70% town abstain, 0% wolf). `volchok/beliefs.nim`
folds every ballot into the exact posterior as a likelihood (town abstain
0.52, wolf abstain 0.23, packmate weight 0.17). `tools/wcw_reads.nim`
replays those 40 games from every town seat: read 0.017 without ballots,
0.244 with (39/40 games better). The Haiku seed's real read was 0.099.
Calibration only, not the score.

## Field change (2026-10-06 evening)

New entrants: Andrew Brower `mono-wcw-whimbrel:v1` (functional, kills
every night as wolf, 4/8 wins; abstains MORE as wolf 50% than as town
33%; its town votes are at chance, read 0.02) and Andrew Brower B
`mono-wcw-sanderling:v1` (votes every day). Andrew ran XP requests with
two volchok:v3 seats against whimbrel: wolves won every full game, town
cannot reach a 5-of-9 majority. League round 66 also showed filler wolves
voting slot 0 (one of them itself) on all 8 days.

Offline read on 10 league games with the new bots: fixed rates 0.213,
averaged (v4) 0.347, grid allowing wolves to abstain more ("either way")
0.152 (functional 0.084, our XP 0.540). Rejected, the direction prior
carries the signal.

## Field change 2 (2026-10-06 night)

Six wcwl-* LLM players joined (kimi, chatgpt, gemini, mistral, llama, glm,
deepseek, haiku, gpt-oss), rounds every 15 min, 25 entrants. They vote in
day-1 bandwagons that usually reach a majority; wolves still win most
games in 2 to 5 days. Our league mean fell to 0.031 (rank 4 by Elo). LLM
town votes land on wolves well above chance (gemini 9/10). Tool:
`wcw_xp --story --rounds N` prints each recent league game day by day.

## Stats table 2026-10-07 (`tools/wcw_stats.nim`, gen_stats method)

126 league games, volchok:v4 vs wcwl-gemini, wcwl-chatgpt, wcwl-haiku
(stats/stats_2026-10-07.html). We are the table's target: lynched 0.65 vs
0.10 to 0.13, ballots received 1.98/day vs ~0.4. Direct-control gaps:
with_majority 0.12 vs 0.74 to 0.85, town ballot rate 0.43 vs ~0.95, day-1
ballot rate 0.26 vs ~0.9, speech length 92 vs ~200 chars, accusing
speeches 0.29 vs ~0.85, role claims 0.46 vs 0 (the wolf "I'm a Sheep"
line). The only pre-vote signal of the day's majority is the speeches'
accusation field, which the policy ignores (user: ignore chat).

## Spend (2026-10-07)

League rounds (usage source `tournament`) count against the league's
$50/day envelope; the LLM field alone spends ~$52/day, so rounds stall
daily once it is hit. XP requests (source `xp_request`) are credited to the
requesting user: ours cost $453.70 over Oct 6 to 7. User decision: no more
LLM-field XP for now; v9 stays champion.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict, see ../../auto.md)

- Wolf ballot camouflage: our wolves always vote and never vote the pack,
  which the ballot model (ours or a rival's) reads instantly (local
  9-Volchok smoke: town won on day 2). Abstain at the town rate as wolf
  and sometimes bus a doomed packmate.
- Per-player ballot types: fit abstain rates per seat within the game
  (always-voter vs. mostly-abstainer) instead of one pooled rate.
- Night retaliation, measured 2026-10-06 (`wcw_xp` kill table, 155 kills):
  town who voted a wolf that day die 1.32x their share, town voters 1.15x,
  abstainers 0.81x. Added as an optional kill term in `beliefs.nim`
  (`killWeights`, off in BallotModel). Offline on the 38 functional games:
  read 0.2428 with or without it, no gain. Left off.
- Guard self-check: when nobody died and we protected X, mark X as the
  kill target (town) in the posterior.
- Town abstain vs. vote: measure whether voting the top suspect at chance
  level helps once LLM seats work again.
- Wolf `hidden`: mirror the town speech style exactly (claim Sheep with
  the same text a town Sheep uses) so LLM reports stay below chance.
- Wolf counterclaim: when a Seer claim accuses the pack, claim Seer and
  accuse the claimer.
- Register a display name (`registerName=1`) only if LLM seats treat
  named players differently.
- Speech evidence for `read`: weight LLM accusations into the posterior
  only after measuring calibration on replays.

## Experiment log

| version | change | XP id | opponents | verdict |
|---|---|---|---|---|
| v1 | first bot: exact posterior, chat claims, wolf kills nightly | xreq_17150e53 (12 eps) | wcw-kimi:v7, relh-wcw-scripted:v1, richard-wcw-scripted:v1, 5x relh-wcw-filler:v1 | 12/12 done: mean 0.125 (2/2 wolf wins, 10 town draws, read 0, no Seer seat dealt), field 0.000 (filler 0.025 as our wolf partner). valid_actions 1.0 except one evicted pod. Submitted as champion (sub_2d0cc94a). |
| v2 | ballot-likelihood posterior, all chat inputs removed | - | - | superseded by v3 before XP |
| v3 | v2 + clean exit after end, legal fallback on errors | xreq_4f416524 (24 eps) | same field | KEEP. Town 19 games mean 0.064 (read 0.81 to 0.84 in 7, town votes hit a wolf 42/42) vs v1 0.000 in 10; wolf 5/5 wins vs 2/2. Faction-stratified Welch (`wcw_xp --compare`): +0.050 per game, t 2.88, df 18, p 0.0099. Cause: scripted wolves keep voting (40% of ballots) while scripted town abstain 100%, v1 ignored it. Submitted. |
| v4 | ballot likelihood averaged over a town/wolf abstain-rate grid (wolves abstain less) instead of fixed pooled rates. Offline read: functional 0.2428 to 0.2475, broken-field XP 0.523 to 0.714 | xreq_61f9b8f9 (24 eps) | same field | KEEP. Survivor read (town, alive past night 1) split by wolves that cast any ballot (their behaviour, exogenous): both wolves voted v3 0.814 (n 6) vs v4 0.871 (n 6), Welch t 11.1, p 0.0001, at the 0.875 ceiling (day 1 never informative); one wolf voted v4 0.373 (n 2) = info ceiling, no v3 games. Pooled survivor read 0.747 vs 0.814 p 0.44 is a deal-mix artefact. Score test underpowered: +0.012, p 0.64. Submitted. |
| v5 | speech only: drop the "Seer, Priest, Chef: share your results" / "claim it now" lines (LLM tables lynched us day 1 for it: ereq_ee851d97, 6 of 9 vote notes cite it), calm rotating lines, accuse only on a ballot read from day 2, Seer/Priest still claim a caught wolf | xreq_f7931d45 (24 eps) vs baseline v4 xreq_c48f2faf (24 eps), same roster | LLM field: wcwl-kimi:v2, wcwl-chatgpt:v3, wcwl-gemini:v4 (top 3), wcwl-mistral:v2, mono-wcw-sanderling:v1, wcwl-llama:v2, wcwl-glm:v2, mono-wcw-whimbrel:v3 | REVERT. 48 vs 48 (v4 xreq_c48f2faf+3d247d9a, v5 xreq_f7931d45+cb1b8902): stratified score -0.063, t -0.89, p 0.37. Day-1 lynch fell (7/24 to 1/24 in the first half) but total lynches did not. |
| v6 | v4 code + never-abstain town ballots (top posterior suspect, stable pick on day 1); built from 1c6e263f in a worktree, single change vs v4 | xreq_083606e3 (24 eps) | same LLM roster | REVERT. 19 done: -0.106, t -1.35, p 0.19, town 0.064 vs 0.208. Voting our own pick alone does not join majorities (stats: with_majority 0.12 vs rivals 0.78). |
| v7 | v4 code + town-aim ballot term (town ballot lands on a wolf with weight aim, averaged over 0.5/1/2/4); LLM town ballots hit wolves 1.5 to 2x chance (gemini 12 vs 5.6, chatgpt 16 vs 11). Offline read: functional 0.248 to 0.259, LLM league 0.166 to 0.212, our XP 0.714 to 0.719. Built from 1c6e263f | xreq_80e4352f (24 eps) | same LLM roster | REVERT as standalone. 47 vs 48 pooled: +0.036, t 0.47, p 0.64. The aim term lives on inside v8 and v9. |
| v8 | user-directed bundle (2026-10-07): social-graph solver (accusations weighed like ballots in the posterior: accusing a cleared player reads wolfish, accusing the accuser reads clearer; offline read on 234 LLM games 0.182 to 0.224), per-player stat engine (Profile), town votes every day joining the most wolf-likely supported wagon, accusatory ~200-char speech with record-based reasons and replyTo, no role claims, wolves push the biggest town wagon and bus a doomed packmate, kill pack hunters. Built on v7 | xreq_cd231732 (24 eps) vs baseline v4 xreq_87c3e357 (24 eps) | current top 3: wcwl-gemini:v4, wcwl-chatgpt:v3, wcwl-haiku:v3, + wcwl-kimi:v2, mono-wcw-sanderling:v4, wcwl-glm:v2, mono-wcw-whimbrel:v8, wcwl-deepseek:v2 | NOT KEPT. 24 vs 24: stratified +0.032, p 0.69. Town 0.184 vs 0.092 (votes now join wagons) but wolf 0.002 (0 of 7) vs 0.180. Direct stats now match the LLMs (ballots 1.00, 185 chars, accusing 1.00, role claims 0) yet lynched 0.92 vs v4 0.67, day-1 lynched 0.54. LLM notes cite 4 tells: silence-based opener ("unsubstantiated silence wagon"), pre-linking ("if X flips town my next look is Y" = agenda-setting), OMGUS retaliation, defensive retort. |
| v9 | v8 minus those 4 tells: no silence reason, no pre-link line, public choices ignore accusations on us (private reports keep them), no defensive line, waiting line when no grounded case, wagon-first town ballots (most accusers today, 2+) | xreq_02ca7e08 (48 eps) vs baseline v4 xreq_87c3e357+xreq_194ad674 (48 eps) | same top-3 roster | KEEP. vs v4 (48 each): +0.288, t 4.04, p 0.0001 (town 0.385 vs 0.096, wolf 0.500 vs 0.215). On par with the top 3 in the same games (score 0.41 vs 0.40 to 0.44). Submitted (sub_097bcd11), now champion. |
| v10 | v9 plus stat matching from the new style rows (v8 vs top 3: replies 0.44 vs 0.69 to 0.93, questions 0 vs 0.08 to 0.30, extra targets per day 0.54 vs ~0.18, ballot on own accusation 0.60 vs 0.72 to 0.84, accusations on the lynched seat 0.07 vs ~0.64): one target per day unless it reads town or a wagon 2+ bigger forms, structural day-1 reasons from the accusation graph (retaliation, switching, fence-sitting, late hops), replies to the target or its latest accuser, a pointed question in about a third of speeches | xreq_7dfd2489 (48 eps) vs baseline v4 xreq_87c3e357+xreq_194ad674 | same top-3 roster | NOT KEPT. vs v4: +0.181 p 0.009, but vs v9: -0.107 p 0.19 (wolf 0.150 vs 0.500: wolves kept their own target instead of riding the town wagon). |
| v11 | v9 plus named accusers in the wagon line, replies to the target or its latest accuser, a question in about a third of speeches (targeting unchanged) | xreq_fe218d88 (42 of 48 finished before cancel) vs v9 xreq_02ca7e08 | same top-3 roster | REVERT. -0.175, t -2.16, p 0.033 (town 0.265 vs 0.385, wolf 0.132 vs 0.500). Matching the reply/question/names style made us a bigger target. |
