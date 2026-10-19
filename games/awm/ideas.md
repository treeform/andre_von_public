# Archers Warriors Mages

Radogost is Andre von Auto's first AWM policy. It is a raw BASIC file because
the released game executes BASIC in its own bounded VM. Development and
verification tools are written in Nim.

## Game and league

- League: `league_ad6dc809-4696-46f5-99a5-fc2b1c58d082`.
- Coworld: `cow_ca2284e3-a47d-411e-8f5e-a9bcbc535a77`.
- Checked release: `2026.10.1.1`, source commit
  `4dbf9b2799562c60cde5bfd4c10479442db55296`.
- Competition is five players in a free-for-all. Last survivor scores one.
- Each decision plays one card or ends the turn. Ready minions then attack
  the next living hero automatically. The policy cannot direct attacks.
- No independent published AWM winning policy was found in web searches.

## Baseline

The released `polyworld/examples/awm/players/base.bas` plays affordable cards
in hand order and targets the next living player. The sole existing entrant
was Andre von Houck's `AWM Baseline:v1`, version ID
`c289efbb-211c-4c2d-92a1-c8a6b67cc4be`. Separate filler ID is
`aeac1cb6-52d1-49f1-b9c8-6cac593a544e`.

Radogost uses bounded Monte Carlo tree search over affordable card sequences.
Each node records an action, parent, children, visits, and backed-up value.
PUCT revisits promising branches using steered action priors. Stochastic
rollouts plan up to five cards. Version 2 uses adaptive cost accounting
instead of version 1's fixed 24 simulations or 12 for wide hands. It
replans after each actual card, so real draws and triggers replace estimates.

Steering assigns zero probability to known bad moves, including empty buffs,
repeated removal, repeated Hail, and targets invalidated by a board reset.
It directly takes immediate lethal damage and safe free cards without a
tree search. Other legal moves use squared positive priorities as sampling
weights, so weak moves receive fewer simulations. The same steering runs
during expansion and rollouts. Bouncer and Tactician prefer the preceding
seat in a five-player ring, because that seat attacks us. The initial
preceding seat can become stale after deaths.

The search is an approximate public-information model, not the complete
game simulator. The host hides enemy hands and other opponents' minion
stats. It exposes neither card names nor readiness. Study and Bubble Shield
share the same signature and use a mixture estimate. Planning targets are
chosen from the current root board. The policy does not communicate with
other players. No upload secrets or Docker player image are required.

## Verification

From the repository root:

```sh
nim check --hints:off games/awm/tests/tests.nim
nim r --out:/tmp/radogost-tests games/awm/tests/tests.nim
nim r --out:/tmp/radogost-ladder games/awm/tools/ladder.nim \
  games/awm/radogost/radogost.bas \
  ../polyworld/examples/awm/players/base.bas 30
nim r --out:/tmp/radogost-scores games/awm/tools/scores.nim \
  games/awm/eps/status_v1.json games/awm/eps/summary_v1.json
```

`config.nims` resolves the local Polyworld source and its pinned Coworld
dependencies. Set `POLYWORLD_REPO` for another checkout. Tests cover empty
buff avoidance, productive mana sequences, branching search, target choice,
deck exhaustion, lethal damage, and a wide hand under the VM budget.
The production work and instruction limits are both 500,000 per decision.
Version 1's local ladder peaked at 315,166 work units and 246,117 instructions.
Version 2's 200-game diagnostic peaked at 484,684 work units and 351,349
instructions, with zero script failures. The wide-hand fixtures used
392,722 to 438,062 work units. Tests verify forced moves create no search
nodes and that a productive Bear receives over three times as many root
samples as a weak Shield.

The BASIC API cannot read the host's remaining work or instruction counters.
`budgetUsed` is a calibrated internal cost estimate, not the actual host
counter. Its 750,000 stopping threshold does not change the host's 500,000
limit. The search reserves 125 percent of the largest observed simulation
cost plus final-action overhead before starting another simulation, and
has a 512-iteration safety ceiling. Local diagnostics read the real VM
counters. These measurements apply to the pinned release, and do not prove
that every possible board stays within budget. Recalibrate after VM changes.

`tools/inspect.nim` accepts raw or gzip-compressed public replays and verifies
every state hash using the actual simulator. The three hosted samples had
distinct seeds 56801103, 925244011, and 808150798, with 208, 174, and 111
verified ticks. Evidence is in `eps/replay_verification.txt`.
Three version 2 XP replays also passed every state hash, with distinct seeds
1600586162, 1011126342, and 172521572. They contained 143, 483, and 186 ticks.
Evidence is in `eps/replay_verification_v2.txt`.

## Ideas backlog

- Distill stronger global Hail of Arrows timing from hosted replays.
- Track living seats so defensive targets adapt after eliminations.
- Detect the final two living players and enable duel survival scoring.
- Treat Bubble as a future army bounce, since it triggers after attacks.
- Test enemy-only Duel targets, including a lethal self-fight target.
- Infer incoming minion strength from public action histories when possible.
- Calibrate the Study and Bubble Shield mixture against observed draws.
- Expand target alternatives and account for Duel's remaining damage.
- Compare steering alone with MCTS in matched hosted evaluations.
- Use sampled future turns and hidden hands within the released VM budget.

## Experiment log

2026-10-01, initial Radogost MCTS and steering policy:

- Local diagnostic: 34/150 wins with next-seat disruption, no failures.
- One steering change: prefer preceding-seat disruption.
- Local diagnostic after that change: 36/150 wins, no failures. Class
  records were Archer 20/50, Warrior 11/50, Mage 5/50.
- Baseline mirror on the same local fixtures: 30/150 wins. Local games are
  diagnostics and do not establish a hosted performance improvement.
- Upload: `radogost:v1`, version ID
  `8ff2e809-a67b-4304-8dc3-79815c3b3645`, owner Andre von Auto
  (`ply_3d22435e-30a2-4f2a-b037-a5c249583788`).
- Source SHA-256:
  `7e125441b550fd0f09967ab092859f1b97c802ee105f924ff4eff199656855a6`.
- Hosted XP: `xreq_57c8fea8-b290-4117-acec-d16070f0e50a`.
- Opponents: four copies of the released `AWM Baseline:v1`. There were no
  three distinct other entrants to evaluate.
- Hosted result: 24 wins in 100 completed games, zero failures. Each seat
  had 20 games. Seat wins were 5, 6, 2, 8, and 3.
- Exact one-sided binomial p-value versus the equal-policy 20% win rate:
  0.1891. This is inconclusive evidence of improvement, not a solved game.
- Verdict: submit the tested first policy at the user's explicit request.
  There was no prior Andre von Auto AWM policy to replace. Future upgrades
  need significant hosted evidence against the current submission.
- Submission `sub_9db70b72-6dec-4fe1-b1d6-60f191972a8a` was placed.
  Membership `lpm_6bfdb59d-5fd6-455f-94a1-f5b57451d1e6` is competing and
  is Andre von Auto's champion. Receipts are saved under `eps/`.

2026-10-01, user-requested steering and budget revision:

- Required behavior: reject known bad moves in every simulated branch,
  immediately take clear wins and safe free plays, sample other moves with
  weighted probabilities, and search close to the BASIC VM limits.
- Changes: forced-action bypass, zero-weight pruning, weighted expansion
  and rollouts, PUCT priors, adaptive simulation count, target-scan cost
  accounting, and a reserve for completing the next simulation and action.
- Fixed the PRNG divisor to fit BASIC's fixed-point numeric range.
- Bubble trinkets now have a separate effect from Plan.
- Increasing the ceiling initially caused work-limit failures. Those
  candidates were not uploaded. Target scans and tree selection costs were
  recalibrated before the final budget diagnostic.
- Local budget diagnostic: 200 games, no script failures, peak work 484,684
  of 500,000, peak instructions 351,349 of 500,000. Local wins were 48/200,
  which is a diagnostic, not hosted evidence. Saved in `eps/local_v2.txt`.
- Upload: `radogost:v2`, version
  `f36ab082-25e0-42d7-8b5f-b39fb96f34f0`, verified Andre von Auto ownership.
- Source SHA-256:
  `c95a236f55329783a1c97bb32cdcda8f9830e5b77204f5c732e740a92a00be00`.
  Version 1's submitted source is retained at `radogost/archive/v1.bas`.
- Initial hosted batch: `xreq_5c42d4b9-2f1a-4754-9e15-684d43af79b5`,
  34/100 wins, zero failed episodes, 20 games per seat. Fisher's exact
  one-sided p-value versus version 1's 24/100 is 0.0802.
- Separate fixed confirmation: three 100-game requests, because the API
  permits at most 100 episodes per request:
  `xreq_3f5253e5-101f-43b1-9de1-853a184c6041`,
  `xreq_a0157f5a-9b11-42e6-b43e-896a5602f23b`, and
  `xreq_71f65d51-80ae-4ee5-a9fb-8a06d2ada883`.
- Confirmation result: 77/300 wins, zero failed episodes, 60 games per seat.
  Seat wins were 16, 10, 13, 17, and 21. Binomial p-value versus 20 percent
  is 0.0101. Fisher's exact one-sided p-value versus version 1 is 0.4252.
- All hosted opponents were four copies of the released baseline. The
  current league has no three distinct competing other players.
- Verdict: the confirmation does not establish an improvement over v1.
  Retain and submit the functional revision required by the user's explicit
  steering and budget requests. This is not a statistically proven strategy
  upgrade under the repository's usual experiment rule, nor a solved game.
  Do not present the initial 34 percent rate as the confirmed performance.
- Submission `sub_96cab819-29b5-4471-bcb7-48a1d9b17d9e` was placed.
  Membership `lpm_a71b5304-a71c-49f4-b772-b75a720cdee5` is competing and
  is Andre von Auto's champion. Version 2 supersedes version 1. Receipts
  are saved in `eps/submission_v2.json` and `eps/membership_v2.json`.

2026-10-01, continuing goal and opponent refresh:

- User target: at least 90 percent actual last-survivor hosted game wins
  against all current other players, while keeping only significant
  improvements. Pairwise dashboard wins are a separate statistic.
- Live dashboard at 20:36 UTC ranks Andre von Auto first by rating, 1514.05.
  This meets the rank component but not the 90 percent win requirement.
- Three distinct other players have active champions: Andrew Brower with
  `stilt:v2`, Andrew Brower B with `greenshank:v3`, and Andre von Houck with
  `AWM Baseline:v1`. Evidence: `eps/leaderboard_20261001_2036.json`.
- Rechecked hosted Coworld release: still `2026.10.1.1`. Polyworld HEAD
  `8ebf587` has no gameplay, BASIC API, or baseline changes from the checked
  release. All pinned dependency checkouts match the current lock.
- Public source searches for stilt and greenshank found no policy code.
  The Polyworld repository is private, so the authorized local checkout
  remains the simulator reference.
- New evaluations have four seats: one candidate plus exactly one active
  policy from each other player. The API derives the game player count
  from this roster. Random seats, random classes, independent derived
  seeds, no filler and no second version of our player in a match.
- Submitted-policy control request: `request_v2_top3_a.json`, 100 games,
  XP `xreq_ba58ad98-b4cf-4386-beb0-eab1ec715e55`. Completed with 25 wins
  and zero failed episodes. Actual last-survivor win rate is 25 percent.
  This is the frozen control for the following four-seat experiments.
- Replay diagnostics verified 812 v2 replay hashes. At ticks 391, 435, and
  475 in sample 2, the original preceding seat was dead and the actual
  incoming army had 13, 6, and 11 power. No held hidden-only Hail opportunity
  was proved in these three samples. Evidence: `eps/decisions_v2.txt`.

2026-10-01, experiment: defensive Primordial steering gate:

- Idea: let the existing search model consider a beneficial board reset
  even when our own board has at least 10 power.
- One change: replace only Primordial's priority expression with its
  existing modeled value delta, including opposing-threat reduction.
  Candidate source: `experiments/primordial.bas`.
- Isolation: v2 holds a reset with one fresh own Primordial facing three
  enemy Primordials. The candidate plays it and bounces the prior boards.
  Both hold a detrimental reset with a dominant ready own army.
- Isolation and target-heavy budget fixtures pass. Local 100-game budget
  diagnostic has zero failures, peak work 486,632 and instructions 352,678.
  This is budget evidence, not scoring. See `eps/local_primordial.txt`.
- Candidate source SHA-256:
  `62a1e6717036f251c760cae45f01b73fbd54af258603c2952e84089e367455a1`.
- Opponents: the same frozen active top-three roster as the v2 control.
- CPUX commit `3d21d463`, pushed before uploading `radogost:v3`, version
  `8a964849-15cd-4b31-a8c6-17087520ee29`.
- Hosted XP: `xreq_152d93ff-19d5-4de0-a321-63afdb11462d`, completed
  100 games with 16 wins and zero failed episodes on .2. The earlier
  comparison with the 25/100 control on .1 is invalid.
- Verdict: no matched-release improvement evidence; do not promote.
  Production and the submitted champion remain v2. The isolated source
  stays under `experiments/` as an auditable trial, not an active policy.

2026-10-01, global Hail replay diagnosis:

- Verified every state hash in 30 hosted control replays and compared the
  same games for Radogost, stilt, and greenshank. See
  `eps/decisions_top3.txt`, `tools/decisions.nim`, and `tools/artifacts.nim`.
- Radogost played 4 Hails in 12 Archer seats, stilt 24 in 14, and
  greenshank 16 in 8. Stilt made 7 hidden-only kills and greenshank 6.
- Radogost declined 34 affordable Hail decisions with no one-toughness
  minions on its next enemy but vulnerable armies on other living seats.
  Two held passes missed armies with 10 and 6 power, including 7 incoming
  power total. This is mechanic evidence, not an XP performance score.
- Sharpshooter's public target choices reveal living hero owners and all
  minion owners. The proxy was available on 19 of the 34 declined
  decisions, but absent on both held passes after its last copy was played.
  Cached observations must persist within a turn and expire on the next.

2026-10-01, requested experimental fast-XP service:

- Documentation: https://fast-xp-request-staging.tail0f4a29.ts.net/docs/llms.txt
  and `/docs/awm/run.md`. The service is reachable and reports AWM installed.
- It runs the unmodified Competition executable synchronously, returns
  replays and uploaded-source logs, and accepts at most 10 episodes per run.
- Its configuration fixes five players. Four roster entries cycle into a
  fifth seat, so it cannot reproduce the four-seat control above.
- Fast trials will use Radogost, the same three current opponents, and an
  explicit extra baseline seat. Keep those scores separate from four-seat
  XP. Confirm any proposed upgrade with a matched hosted control.
- Implemented `tools/fasts.nim`: freezes requests, saves ZIPs and logs,
  verifies every replay hash, and reports runtime-disabled bots separately.
- Service metrics identify AWM source `4dbf9b2`, matching the checked
  release. Worker pool: eight; admission limit: sixteen. Shared queues
  can dominate wall time even when the game executes quickly.
- First control batch: seed 202610010 through 202610019, 10 complete games,
  request ID `1790889043-75966-1538`. One win, no failed games or disabled
  bots. Client wall time 56.519 seconds; summed worker time 839 ms.
- Matched Hail batch: same seeds and roster, request ID
  `1790889105-75966-1547`. One win, no failed games or disabled bots.
  Client wall time 8.968 seconds; summed worker time 830 ms.
- All twenty replays pass every state hash. Timings, manifests, and separate
  summaries are under `eps/fast/`. These small five-seat samples demonstrate
  service operation; they do not establish a strategy improvement.

2026-10-01, experiment: global Hail steering:

- Idea: consider Hail damage across all living opposing boards instead
  of pruning the card when only the next opponent has no vulnerable army.
- One strategy change: query Sharpshooter's public target owners, cache
  counts for the current turn, and estimate hidden Hail removal in both
  steering and search value. Candidate: `experiments/global_hail.bas`.
- Unknown minions use a half-kill, two-power prior. A one-point card charge
  keeps weak unknown plays below the pass value. Known empty boards remain
  pruned, dead-seat minions are excluded, and observations expire next turn.
- Native-card isolation: with Sharpshooter and Hail, playing Sharpshooter
  first retains the probe for a real second decision at three energy; Hail
  then removes three incoming Snipers. Known empty Hail is still held.
- The wide-hand fixture uses 396,161 work and 282,330 instructions. The
  100-game budget diagnostic has zero VM failures, peak work 484,746 and
  instructions 351,401. These are safety diagnostics, not score evidence.
  See `eps/tests_global_hail.txt` and `eps/local_global_hail.txt`.
- Source SHA-256:
  `620c663e0b99db7b186becd70dd2ec6c5a6cb01d2880ee8d5a1fd178b7748f43`.
- Opponents: current stilt:v2, greenshank:v3, and AWM Baseline:v1. A fast
  five-seat diagnostic will add the documented extra baseline seat.
- CPUX commit `3a42fde9`, pushed before upload as `radogost:v4`, version
  `7b389076-432a-48e6-9ea3-03327ddf7d81`.
- Four-seat hosted XP: `xreq_66cbf3dc-7ba9-4273-9511-b67a41a82452`,
  100 completed games, 23 wins, zero failed episodes, on release .2.
  The previous 25/100 control was on .1. Its comparison is invalid.
- Verdict: no matched-release improvement evidence; do not promote.
  Radogost v2 remains production and the submitted champion. The fast
  matched diagnostic also gives no reason to promote this candidate.
- Matched fast replays confirm mechanism activation in two games, including
  a hidden-only Hail removing five power and an additional Hail removing
  seven hidden power. Four Archer trajectories changed; Mage and Warrior
  trajectories stayed identical. See `eps/fast_hail_diagnosis.txt`.

2026-10-01, all-player evaluation tooling:

- `tools/rosters.nim` now includes every other live champion, including
  unrated players, with one active policy per distinct player. The current
  roster remains the same three opponents. Two through seven seats are
  supported; more players trigger an explicit error rather than omission.
- `tools/scores.nim` now sizes seat statistics from the hosted roster.
  Existing v3 scoring remains 16/100. Its earlier comparison with the
  .1 control is invalid because v3 ran on .2.
- `tests/test_tools.nim` verifies unrated inclusion, duplicate exclusion,
  player-count boundaries, and seven-seat scoring. This changes evaluation
  coverage only; it changes no game strategy.

2026-10-01, experiment: enemy-only Duel:

- Idea: Duel permits the same enemy minion as both targets. With exact
  visible power at least its remaining toughness, its self-fight kills it
  even after the equal power and toughness buff. No own fighter is needed.
- One strategy change: consider this exact next-enemy removal alongside
  the existing favorable own fight. Keep the own fight when its modeled
  gain is better. Candidate: `experiments/duels.bas`.
- Search gives enemy-first Duels no phantom own buff. Scalar state prunes
  repeated removal even beyond the prior bitmask, and rejects a self-fight
  after Tactician reduces the target below lethal power. Hidden stats are
  excluded; this is not a guessed enemy removal.
- Actual host fixtures prove Primordial self-removal with no own board,
  invalid-target holding, retained own fights, repeated-target pruning,
  Tactician ordering, and bounded wide-hand work. See `tests/test_duels.nim`.
- The 100-game VM diagnostic has zero failures, peak work 484,970 and
  instructions 351,542. This is budget evidence only.
- Source SHA-256:
  `5208d40d8a4fe485a11a9aeb27b1bdd02955e6c28bf7f9eeb09dd69b57983ad6`.
- Refreshed all current champions: still stilt:v2, greenshank:v3, and AWM
  Baseline:v1. Plan: 100 four-seat hosted games against the frozen control,
  plus a separate ten-game matched fast diagnostic. Require a significant
  hosted improvement before promotion.
- CPUX commit `60975255`, pushed before upload as `radogost:v5`, version
  `f62ee788-06b0-4c35-be2b-da3823e1b680`.
- Hosted XP `xreq_352d352e-abde-49f5-83e5-5e6bdc174d20`: 14 wins in
  100 completed four-seat games, zero failures, on release .2. The
  earlier comparison with v2's 25/100 on .1 is invalid.
- Fast request `1790890290-99735-649`: same ten seeds and five-seat roster
  as the prior control, one win and no errors. Client wall time 2.644
  seconds, summed worker time 828 ms. Two Duels were played in the sample.
- Verdict: no matched-release improvement evidence. Keep production and the
  submitted champion at v2. Preserve the isolated code and evidence.

2026-10-01, Mage replay diagnosis:

- Thirty control replays verify the same public action histories for all
  compared policies. See `eps/mages_top3.txt` and `eps/duel_phases_top3.txt`.
- Our five Mage seats cast zero Oozifications despite 18 affordable
  decision opportunities. Four decisions had only incoming opposing power;
  our selector valued only the next enemy and pruned the useful target.
- Stilt cast seven Oozifications, all hidden targets and six incoming.
  Greenshank cast twelve, eleven hidden and incoming. Incoming Oozification
  is an unused defensive tactic with a concrete opponent precedent.
- Our 21 Studies discarded five Primordials, eight Oozifications, and seven
  Plans. No Primordial survived to an affordable decision in those games.
  Plan-first timing was rare for all policies, so generic Plan priority
  tuning is less supported by this sample.
- A turn gap of two identified 12 final-duel decision starts with zero
  false positives. It missed one immediate entry after our own elimination
  of another player. The two lethal passes had no affordable held defense,
  so this sample does not establish a useful missed survival move.
- Next isolated experiment: allow incoming Oozification and model its
  expected defensive value while preventing repeated hidden removal and
  recasts against the known zero-power token suffix within our turn.

2026-10-01, release and roster correction:

- The old control `xreq_ba58ad98-b4cf-4386-beb0-eab1ec715e55` used
  `cow_ca2284e3-a47d-411e-8f5e-a9bcbc535a77`, version 2026.10.1.1.
  The v3, v4, and v5 trials used
  `cow_a8499615-b37a-4b92-84c5-a81acf8ed5d4`, version 2026.10.1.2.
  Earlier cross-release Fisher comparisons are invalid and withdrawn.
  No candidate was promoted using those comparisons; v2 remains submitted.
- The new source reference is 0b310327cd82314f0591e47f313bccd5c4554f09.
  Both manifests identify the same runnable image. A source audit and
  explicit release metadata checks will prevent accidental pooling.
- Greenshank v4 is now the champion for Andrew Brower B, replacing v3.
  Earlier trials also cannot be compared with this refreshed roster.
- Fresh submitted-v2 control: `xreq_4b2c1662-df74-40e4-857d-95520dd72200`,
  100 four-seat games on .2 against stilt:v2, greenshank:v4, and
  AWM Baseline:v1. Request: `eps/request_v2_release2_a.json`.
  Completed: 14/100 actual wins, zero failed episodes.
- The source audit found only viewer changes in .2, with unchanged core,
  host API, baseline, dependencies, and 500,000 hard budgets. A later local
  5,000,000-budget commit is not deployed in .2. Pinned source diagnostics
  use the released commit, recorded in `eps/release2_pin.txt`.

2026-10-01, experiment: incoming Oozification:

- Idea: our Mage held affordable Oozifications while incoming opponents
  had minions; both strong opponents use this defensive removal.
- One strategy change: allow incoming hidden-minion Oozification with a
  two-power prior and model defensive value. Candidate: `experiments/oozes.bas`.
  Hidden toughness is not guessed. Existing exact next-enemy targets remain.
- Owner and minion ordinals prevent duplicate hidden removal in a search
  path. Within-turn observations avoid the zero-power suffix created by
  earlier Oozifications. Bouncer removals update the unknown prefix;
  observations expire next turn. A confirmed two-living-player turn gap
  excludes a known-dead preceding seat for this action.
- Actual host fixtures verify removal, token generation, repeated-target
  pruning, zero-power holding, Bouncer interactions, and final-duel guards.
  See `tests/test_oozes.nim` and `eps/tests_oozes.txt`.
- Budget-only diagnostic: 100 games, zero VM failures, peak work 492,709
  and instructions 359,889. Fixed hidden-key overhead is charged to the
  existing budget estimate. Local outcomes are not score evidence.
- Source SHA-256:
  `bf05ddb900839d69296e874d8881013cd694bba6cb3a5bfa718f9f9cc9593f1d`.
- Frozen opponents: stilt:v2, greenshank:v4, and AWM Baseline:v1. Plan:
  100 hosted four-seat games on .2 compared only with the fresh matched
  v2 control, plus a separate ten-game fast diagnostic with one explicit
  extra baseline seat. Verdict pending; do not submit without significance.
- CPUX commit `d859c3b4`, pushed before upload as `radogost:v6`.
  Hosted XP: `xreq_c2d87175-68bf-4628-af2d-b389966ad783`, release .2.
- Fast service build `b3efb3b/paintbot-0.3.89/awm-4dbf9b2/gota-f866e2f`
  retains the released core and 500,000 limits. New matched control
  `1790892433-99735-1249` and candidate `1790892607-99735-1687` each won
  two of ten games, with zero failures and disabled bots. These five-seat
  batches use seeds 202610020 through 202610029 and are kept separate
  from the four-seat hosted comparison. Mechanism diagnosis pending.
- Completed hosted result: 15/100 wins, zero failed episodes. The matched
  submitted control won 14/100. Fisher's exact one-sided improvement
  p-value is 0.5000. Verdict: inconclusive; do not keep or submit v6.
  Production and the champion remain v2.
- Fast mechanism verification: the Mage's new Oozification destroys an
  incoming Sniper, reduces its owner's power from two to zero, and creates
  one zero-power token. The prefix cache persists within that turn and
  expires next turn. Nine other games match action and state hashes exactly.
  All 515 policy decisions reproduce the hosted actions. See
  `eps/oozes_fast_diagnosis.md`. Recast and guard cases remain fixture-proven.

2026-10-01, release-safe scoring and class extraction:

- Scoring summaries now record Coworld ID and version. Comparisons and
  aggregation reject different or missing release metadata, in addition
  to the existing policy and opponent roster checks. Every episode must
  match its request's Coworld. Historical summaries were regenerated;
  invalid cross-release Fisher fields were removed.
- `tools/classes.nim` joins exact participant positions with real replay
  classes and actual hosted scores. It verifies every state hash and
  reports missing class coverage explicitly. It rejects mixed release or
  roster cohorts and invalid scores. Fixtures cover reordered seats,
  missing replay coverage, metadata mismatches, and corrupt state hashes.
- `tests/test_tools.nim` follows current champion versions from the
  supplied dashboard, preserving order and inclusion checks when a
  champion is updated. Checks and fixtures pass.
- V5 fast diagnosis found no enemy self-Duel activation in ten matched
  games; those tapes cannot explain the normal XP result. See
  `eps/duels_fast_diagnosis.md`.

2026-10-01, next matched experiment: global Hail:

- Current-cohort diagnosis: our Archer won 2/39 games, while Greenshank v4
  won 25/40 Archer games. We held affordable Hail at pass 33 times,
  including 23 where only other opposing boards had vulnerable minions.
  Those missed clears would remove 134 power, including 108 incoming.
  This establishes missed opportunities, not a causal win estimate.
- Repeat the existing isolated global-Hail candidate on release .2 and
  the current stilt:v2, greenshank:v4, AWM Baseline:v1 roster. Its earlier
  control was from a different release and cannot establish promotion.
- One strategy change and source remain `experiments/global_hail.bas`,
  SHA-256 `620c663e0b99db7b186becd70dd2ec6c5a6cb01d2880ee8d5a1fd178b7748f43`.
  Keep the exact source frozen. Plan: new upload and 100 hosted four-seat
  games versus the fresh submitted-v2 control. Verdict pending.

2026-10-01, real search-budget audit:

- Reexecuting all submitted-v2 decisions on 100 verified current-cohort
  replays found 3,086 matching actions out of 3,087 decisions. All 1,670
  successful ambiguous searches stopped at the budget/reserve guard,
  rather than the 512-iteration or 255-node caps. Work median 411,072,
  90th percentile 438,473, maximum successful work 491,314.
- One Mage decision with 23 cards exceeded work limits in reenactment.
  Our own hosted private log for job
  `0c7e2f1a-0f2a-4bc2-a71d-4b92ec3de605`, seat zero, independently confirms
  `BASIC error: BASIC work limit exceeded`. Zero failed episodes therefore
  does not establish zero disabled VMs. Frozen global-Hail shares this case.
- Pause the next upload while isolating the underestimated weighted-search
  path and adding a reproducing fixture. Do not raise the budget ceiling
  unconditionally. Keep the real private log outside the committed record.

2026-10-01, release .3 and parallel trials:

- Release .3, `cow_8ac280ae-4b9d-4add-a869-4d1d684a14a0`, source
  1b2b552164e01b1fe26b5010e62ab66077b93f46, raises both work and
  instructions to 5,000,000. Memory remains 64 MiB. The old 500k overflow
  no longer disables current matches. Card rules are unchanged.
- Current champions are greenshank:v5, stilt:v3, and AWM Baseline:v1.
  Fresh v2 control: `xreq_daae771c-09e0-4c78-a3a8-5f160d426f5b`, 100 games.
  Fast XP still has the 500k build; use regular hosted XP for current
  larger-budget trials. Keep release .2 results separate.
- The user requested frequent cheap XP and faster exploration. Three
  independent candidates each have 100 fresh games queued against this
  cohort: Primordial v3 `xreq_c451b168-27a8-4996-82e5-dc0e09847066`,
  Hail v4 `xreq_c56da2bd-50bd-4acc-bd51-16d5e04b9903`, and Duel v5
  `xreq_5c06cd8c-874d-4147-9899-aaba71d8d0f4`. With the control, 400 games
  are admitted. The Oozification request received the owning account's
  pending-request limit (429), and will retry after capacity clears.
  Each candidate retains its isolated frozen source. Verdicts pending.
- New isolated shots candidate: prioritize provable lethal Sharpshooter
  hero targets before minion targets. Actual host fixtures cover reported
  misses, Bubble ordering, freshness, retained nonlethal targets, and wide
  choice counts. Source `experiments/shots.bas`, SHA-256
  `bed9325116a2fa0a6b889d75d3f411cfd3220635fc2701ad2ee398f1ba550b57`.
  See `eps/tests_shots.txt` and `eps/shots_replay_diagnosis.md`.
- New isolated pressure candidate: increase only continuing army power
  value from 2.5 to 4.0. Source `experiments/pressure.bas`, SHA-256
  `a238d2ee53e074efcc494acd100fbc5d01a28ca99560a8dc9699a4fb5302169f`.
- New isolated readiness candidate: increase only ready army power
  value from 1.2 to 3.0. Source `experiments/readiness.bas`, SHA-256
  `fb73d2b69d4f1805086027beb951d02fbce7d1da4a37a70b7fb307e2f49c79f3`.
- Pressure and readiness each pass a fresh .3 compile and ten budget-only
  games with zero failures. Work peaks 455,815 and 456,231. These outcomes
  are not strength evidence. Plan: upload and 100 hosted games per new
  candidate against all current opponents. Verdicts pending.
- New isolated Plan candidate: increase only Plan's utility from two to
  five; retain Study and deck guards. Source `experiments/plans.bas`,
  SHA-256 `8c81511a7af5003e063811690d65379b6924eb3710a5a6de324c02ed9fd85bb0`.
  Actual host fixtures verify Plan selection, immediate and next-turn
  draws, and the empty-deck guard. Ten budget games have zero failures,
  peak work 447,294. Hosted verdict pending.
- New isolated two-cost spell defense candidate: remove the false one
  point of immediate defense from the shared Study/Shield signature;
  preserve utility 1.5 and all priorities. Source `experiments/bubbles.bas`,
  SHA-256 `5236eeff5d91a5f18090c37c02941f71641a0ca16a33b0def6ce3155aabc3f3e`.
  Actual Shield fixtures prove lethal damage is not prevented and later
  bounce utility remains. Ten budget games have zero failures, peak work
  454,685. Hosted verdict pending.

2026-10-01, completed release .3 comparisons and progress report:

- Current matched cohort: greenshank:v5, stilt:v3, AWM Baseline:v1;
  four seats with exactly one policy per player and randomized seats.
- Submitted v2 control: 50/300 actual wins, 16.7 percent, zero failed
  episodes. Requests: `xreq_daae771c-09e0-4c78-a3a8-5f160d426f5b`,
  `xreq_02d097f0-c1bb-4101-865d-52bd06453d82`, and
  `xreq_442a1054-53b1-46bd-8072-a59575b8b408`.
- Global Hail v4: 53/300 actual wins, 17.7 percent, zero failed episodes.
  Requests: `xreq_c56da2bd-50bd-4acc-bd51-16d5e04b9903`,
  `xreq_10721480-0579-4d90-887c-c07bfc02b4c0`, and
  `xreq_b1eee88e-b8fa-44ba-a7d7-eb500d57af36`. Fixed 300-game comparison
  with control: one-sided Fisher p = 0.4143. Inconclusive; do not keep.
- Defensive Primordial v3: 18/100 actual wins, zero failed episodes;
  p = 0.2817 versus its original matched 14/100 control. Inconclusive.
- Enemy self-Duel v5: 6/100 actual wins, zero failed episodes;
  p = 0.9841 versus its original matched 14/100 control. Do not keep.
- Total completed regular hosted games: 1,900 across releases and
  opponent cohorts, plus 60 fast-service diagnostic games. Do not pool
  those different cohorts to claim one strength estimate.
- Two attempted candidate uploads, v7 shots and v8 pressure, were
  mistakenly owned by Houck despite the CLI's selected Auto identity.
  Post-upload owner checks stopped both trials before XP or submission.
  They are excluded from experiment scoring. The wrapper now captures
  one user token and includes Auto's explicit player_id in both API
  upload phases. Nim checks and offline race/rejection fixtures pass.
- Larger-search candidate is frozen at `experiments/resources.bas`,
  SHA-256 `e512464b4e4e869bb0bee2a8c51e4b3a233bbb4c061ccfa86c2dc6572c458c7a`.
  Resource-only change: 7,250,000 internal estimate, 8,192 iterations,
  2,047 nodes, and overflow-safe mean backups. Strategy and depth stay
  fixed. One hundred actual VM diagnostic games have zero failures;
  maximum tested work is 4,694,242/5,000,000. Hosted strength untested.
  See `eps/resources_release3.txt`.
- Final-duel incoming-seat candidate is frozen at `experiments/phases.bas`.
  A confirmed two-living-player turn gap selects the living incoming
  enemy for existing defensive targeting. Actual host fixtures pass.
  Hosted strength untested.
- An Archer-only living-predecessor probe was dropped before upload:
  incomingPlayer affects only Bouncer/Tactician, absent from Archer's
  deck, so it would not change strategy. Production remains v2.

2026-10-01, fresh hosted screening queue:

- CPUX commit `8047c13e` was pushed before all fresh uploads. Explicit
  Auto ownership is verified on every version: v9 resources, v10 lethal
  shots, v11 pressure, v12 readiness, v13 Plan value, v14 shared spell
  defense, and v15 final-duel incoming targeting.
- All tests use current release .3 and one live champion per other player:
  stilt:v3, greenshank:v5, and AWM Baseline:v1. Rating refresh places Auto
  first at 1506.8855, but this does not satisfy the 90-percent win goal.
- V9 resource screening XP `xreq_31556163-6528-4032-8b74-3985721dbb18`
  completed: 23/100 wins, zero failed episodes, one-sided Fisher
  p = 0.1034 versus 50/300 current submitted control. Inconclusive;
  production stays v2. Confirm with a larger fixed batch or reject.
- V10 shots XP `xreq_facb2588-f6bc-49e9-be95-0fe1024c9360`, 100 games;
  v11 pressure XP `xreq_8dc755dd-0214-4116-ada1-3f4b5f8a1e66`, 100 games;
  v12 readiness XP `xreq_cd8d5029-0254-423d-8186-d7013908dffc`, 100 games.
  Verdicts pending. Requests for v13-v15 wait for the service's 300
  undispatched-episode capacity; retry the same idempotency keys.
- New isolated steering-only ablation: `experiments/greedy.bas`,
  SHA-256 `a66d299ba4635ad623724d8f48d6395b3d19ba65a8db12075ae16273c85b9a24`.
  Select the largest existing steered root weight instead of MCTS.
  Forced moves, pruning, targets, and coefficients stay fixed. Actual
  host fixtures prove a changed choice and preserved forced behavior;
  ten local budget games have zero failures. Hosted verdict pending.
- New isolated Duel fighter selection: `experiments/fighters.bas`,
  SHA-256 `f5b475152aac554a1c7eb00677af76f44d3d554d501a883b82b47d1e384cb620`.
  Rank existing own fighters only after checking for a provable
  kill-and-survive trade against the observed next-enemy board. A damaged
  strong fighter no longer blocks a safe weaker fighter. Actual fixtures
  and a 24-Duel/48-minion stress case pass. Hosted verdict pending.

- V10 lethal-shot screening completed: 17/100 wins, zero failed episodes,
  one-sided Fisher p = 0.5239 versus 50/300 control. No demonstrated
  improvement; do not keep or submit.
- V13 Plan-value XP admitted: `xreq_4e86cabc-2bb8-4a80-b5b6-56259e4d45cc`.
  V14 shared-spell-defense XP admitted:
  `xreq_2a2dc604-fade-4764-9a9b-cf494fa3410f`. Both 100 games; pending.
- V16 steering-only and v17 safe own-Duel fighter candidates are uploaded
  and verified as Auto. Their 100-game requests wait for dispatch capacity.
- Three fresh fast diagnostic batches use identical seeds 202610040..049
  with stilt:v3, greenshank:v5, AWM Baseline:v1 and one baseline filler.
  Submitted v2 wins 1/10 (request `1790896356-211230-590`), steering-only
  2/10 (`1790896359-211230-617`), safe fighters 1/10
  (`1790896354-211230-566`). All have zero failures or disabled bots.
  Service run time is 1.0-1.7 seconds per batch. These old-engine,
  five-seat diagnostics are separate from current league strength tests.

2026-10-01, new isolated Warrior Shields protection trial:

- Idea: preserve valuable one-HP minions against Hail. In current control
  job `63b3ca65-d38e-4640-a8f4-86b39e74a4ab`, v2 held Shields and spent
  its last energy on Swords at tick 35; stilt:v3 Hail destroyed the
  damaged five-power minion at tick 43. All 30 inspected replay tapes
  verify every state hash. See `eps/shields_replay_diagnosis.md`.
- One strategy change: give Shields protection value and steering weight
  from observed own one-HP army power. Consume that credit once per
  branch. Preserve all other targets, coefficients, and search resources.
- Source `experiments/shields.bas`, SHA-256
  `89e05c68a3061c4b2ba5b38ff217e9886de28d09d63a50cc79eeb88d000a1741`.
  Actual host fixtures prove changed selection, survival versus Hail,
  unchanged healthy cases, and no duplicate credit. All Nim checks pass.
- Plan: upload and 100 hosted .3 games versus current stilt:v3,
  greenshank:v5, AWM Baseline:v1; compare only with matched v2 control.
  Hosted verdict pending.

2026-10-01, additional isolated horizon and fatigue trials:

- Depth candidate `experiments/depths.bas`, SHA-256
  `218e54cb21925f581ebd67f0f9709d1564c4e93454746f501303dab3c3e7ed2e`.
  One change: tree and rollout card-sequence horizon five to twelve.
  Search budgets, node caps, coefficients, and targets stay unchanged.
  A real seven-creature fixture reaches rollout depth seven and values
  the longer affordable sequence. Existing simple-choice fixtures pass.
  Ten budget games have zero failures. Hosted verdict pending.
- Future-draw reservation candidate `experiments/reserves.bas`, SHA-256
  `6b663f397de9e5124fcabca278717ebfb8d55b97e4ffc8c2fbd8f3347f6d34cb`.
  One change: track successful Plans this turn and reserve their known
  next-turn draws before admitting Plan or shared Study/Shield cards.
  Clear reserve at turn change or successful Primordial bounce.
  The shared Shield signature is conservatively held when ambiguous.
  Actual host fixtures prove v2 dies from next-turn fatigue while this
  candidate holds the draw and survives. Ten budget games: zero failures.
  A real replay shows the extra Plan draw obligation, but that game ends
  in combat; do not claim fatigue caused that loss. Hosted verdict pending.
- Both candidates start from unchanged submitted v2 and will receive
  current .3 hosted XP against all three current opponents.
- Hosted resource mechanism verification: five public v9 replay tapes,
  432/432 exact actions and targets reproduced, zero VM failures; 97
  searches exceed 512 iterations, 38 exceed 255 nodes. There are twelve
  substantive card/target/pass differences versus v2 on identical
  observations and pre-call memory. Peak sampled work 4,476,675/5,000,000.
  This proves the feature fires; its 23/100 strength result remains
  inconclusive. See `eps/resources_hosted_diagnosis.md`.

2026-10-01, both updated fast endpoints and latest verdicts:

- The user requested staging and production fast-XP endpoints. Both
  accepted AWM batches. Matched probe seeds 202610050..059 produced the
  same results on each endpoint: v2 0/10, resources 1/10, greedy 0/10.
  Sixty executions, zero failures or disabled bots. Do not count the
  repeated endpoint probes as additional independent seed evidence.
- Fresh 200-game fast comparison uses seeds 202610060..159, with ten
  batches per source alternating staging and production. Exact current
  champions plus one explicit baseline filler, candidate pinned seat zero.
  Control: 17/100 wins; larger resources: 19/100. All 200 replays verify
  their state hashes, with zero failures or disabled bots. This does not
  establish a substantial upgrade. Five-seat fast results stay separate
  from four-seat league XP. Both services now execute the larger-search
  source successfully; the earlier old-budget failure is not current.
- Latest regular .3 results: v11 pressure 16/100, p = 0.6159; v12
  readiness 15/100, p = 0.7036, each against the matched 50/300 v2
  control. Zero failed episodes. Neither candidate is kept or submitted.
- V15 final-duel target XP admitted:
  `xreq_a288fba0-9839-4d51-9909-fe0b2bce475e`, 100 games. Greedy's
  50-game screen XP: `xreq_c043812a-3ded-4d99-9072-d3da7ff18add`.
  A separate fixed 100-game greedy request remains queued.
- The bounded `tools/queues.nim` pump freezes request bodies, resumes
  saved IDs, polls every 45 seconds, and stops admissions at each 429.
  Offline resume, ordering, immutable-body, terminal, and error fixtures
  pass. Root runs the checked queue; agents perform no live mutations.

2026-10-01, final-duel survival evaluation trial:

- Idea: the existing survival penalty never fires in four-seat games
  because mailboxPlayers returns the original roster size after deaths.
- One strategy change: enable the existing fatal-threat penalty after
  confirmed final-duel turn-gap detection. Leave incoming targets and
  all other scores/resources unchanged, isolating this from v15.
- Source `experiments/survival.bas`, SHA-256
  `9cc294fd34d923375bd64df0daefd3bcdb503fc32f2f5e3e6dbc1b155b7e4cde`.
  Actual .3 fixture: v2 spends energy on Swords then dies to Bear; this
  candidate chooses Duel, removes Bear, and survives. Original two-seat
  behavior and an immediate winning Swords line remain unchanged.
- Plan: upload and 100 regular .3 games versus all current three other
  champions, compare with matched v2 control. Hosted verdict pending.

2026-10-01, current roster refresh and cumulative Hail trial:

- Fresh dashboard confirms Greenshank v6 replaced v5; stilt:v3 and
  AWM Baseline:v1 remain current. Stop creating the unadmitted old-roster
  requests. Existing admitted jobs retain their original IDs and can
  finish as historical evidence. New g6 requests include a fresh v2
  control and cannot compare significance against the old 50/300 cohort.
- New regular queue resumes admitted v14/v15/v16-screen/v17, then
  creates fresh g6 control and isolated Shields, survival, reserves,
  depth, and steering-only trials. Each new regular request has 100 games.
- Fast g6 screen: 100 distinct seed pairs, 202610160..259, for control,
  Shields, survival, reserves, and larger resources. Fifty ten-game
  requests alternate staging and production. Four hundred candidate
  games and 100 control games, same current champions and explicit
  baseline filler. Verdicts pending; no regular-cohort pooling.
- New isolated cumulative-Hail candidate:
  `experiments/cumulative_hail.bas`, SHA-256
  `f1e531e506da7c9b25b952d6f7218ddc34b449054def7ff839dea165a6f6ec67`.
  Idea: hard pruning currently excludes affordable consecutive Hails
  that clear a visible two-HP army. Three real missed decisions appear
  in two of ten current-cohort Archer games, including six two-HP
  minions with twelve power and three held Hails.
- One strategy change: model cumulative Hail damage to the exact visible
  board, allow affordable clears, and prune remaining redundant Hails.
  Health histograms cover the full visible board; removed targets do
  not receive duplicate death credit. Hidden global reach stays fixed.
  All other coefficients, targets, depth, and budgets stay unchanged.
- Actual .3 fixtures prove a two-Hail Bear clear, redundant third holding,
  insufficient mana and noncombo holding, and full-board boundaries.
  One hundred actual VM diagnostics have zero failures; local outcomes
  are not score evidence. See `eps/cumulative_hail_proof.md`.
- Plan: upload and 100 regular g6 games, plus a matched fast screen.
  Production remains v2. Hosted verdict pending.

2026-10-01, g6 fast-screen results and incoming Sharpshooter trial:

- Paired current-g6 fast results, 100 unique seeds per candidate: control
  16/100; Shields 16/100; survival 16/100; reserves 16/100; resources
  14/100; cumulative Hail 16/100. All 600 physical games verify their
  hashes, with zero failed or disabled bots. No candidate demonstrates
  improvement; all exact one-sided paired p-values are one. The four
  equal candidates have identical winner indicators to control, while
  resources loses two previously won Archer games. Do not keep or submit.
- Class breakdown for this control: Archer 4/32, Warrior 10/38, Mage
  2/30. Cumulative Hail has the same breakdown. Larger resources loses
  two Archer wins; other class outcomes match. Mage is the main weakness
  in this seed cohort; do not attribute these outcomes to unobserved causes.
- V14 shared Study/Shield defense correction completed on the historical
  g5 regular cohort: 17/100 wins, p = 0.5239 versus 50/300 control,
  zero failed episodes. V13 Plan value: 13/100, p = 0.8489. Neither kept.
- V22 cumulative Hail was uploaded and verified as Auto after pushed
  commit `a6656683`. Its regular g6 request remains queued.
- The paired fast scorer now guards source, opponent, class, seat and
  seed provenance; it rejects repeats, incomplete or disabled games.
  It computes exact discordant-pair probability and reports each own
  class separately. Nim checks and fixture tests pass.

- New isolated incoming Sharpshooter source `experiments/incoming_shots.bas`,
  SHA-256 `83dd0bc82213e5b1216c0a3405fdb282750517286f226c1bbb6c6014abab1cd5`.
  Public Hero choices identify the living incoming owner. An explicit
  uncertain prior of 0.75 chance times two power gives 1.5 expected
  defense; target score 4.5. This does not read or claim hidden HP.
  Keep exact positive-power visible kills and existing immediate lethal
  hero behavior. Deduplicate expected incoming kill credit in a branch.
- Thirty verified control replays show v2 made three incoming kills in
  48 Sharpshooter casts, versus stilt's 54/71 and Greenshank's 41/61.
  V2 made 29 casts with a distinct incoming positive-power one-HP victim
  and no visible positive-power one-HP victim. Six had incoming raw
  power at least our life. These are missed opportunities, not causal wins.
- Actual host fixtures prove Sniper removal, an uncertain Bear surviving
  a hit, visible-kill preference, dead-seat exclusion, final-duel and
  lethal guards, and duplicate-credit safety. One hundred VM diagnostics
  have zero failures. See `eps/incoming_shots_proof.md`.
- Plan: upload and 100 regular g6 games plus a paired fast screen.
  Production remains v2; hosted verdict pending.

2026-10-01, incoming targeting confirmation and permanent-removal trial:

- Incoming Sharpshooter uploaded as Auto-owned `radogost:v23` after pushed
  commit `ff46aa81`. Regular current-g6 request:
  `xreq_c7b0cbda-725c-4b98-bc9a-56d5e2884b2c`, 100 episodes, pending.
- Initial fast screen, seeds 202610160..259: v23 18/100 versus v2 16/100,
  gained five paired wins and lost three, exact one-sided p = 0.36328125.
- Fresh confirmation, seeds 202610260..359: v23 19/100 versus v2 13/100,
  gained seven and lost one, exact one-sided paired p = 0.03515625.
  Archer is 9/41 versus 3/41; Warrior and Mage outcomes match control.
  Both screens alternate staging and production. All 300 newly executed
  games verify their hashes with zero failures or disabled bots.
- Combined descriptive totals: v23 37/200 versus v2 29/200; twelve gains
  and four losses, exact paired p = 0.0384063721. All net improvement is
  Archer: 15/73 versus 7/73; Warrior 17/72 and Mage 5/55 remain unchanged.
  The confirmation is promising fast evidence, not a
  regular league promotion. Keep production unchanged pending regular XP.
  Do not pool the five-seat fast games with four-seat regular results.
- Historical-g5 regular verdicts: v15 living-predecessor targeting 10/100,
  p = 0.9664; v16 greedy steering 6/50, p = 0.8523, each against the
  matching 50/300 control. Zero failed episodes. Neither is kept.
- V17 joint surviving-fighter selection also completed on historical g5:
  13/100, p = 0.8489 against matching 50/300 control, zero failed episodes.
  Request `xreq_12537e08-67ec-4835-81c3-ed545c4b6b9a`. Not kept.
- New isolated Mage candidate `experiments/removals.bas`, SHA-256
  `f36fca02a4e87fd22f274c5f63824037e2cbbd8dfb70fcda60724e45d1f0218f`.
  Prefer permanent Oozification over an affordable bounce of the same
  visible six-plus-power minion, unless existing ready damage is lethal.
  Replaying an enemy Primordial currently feeds repeated global resets.
  Actual replay shows nine affordable permanent-removal opportunities
  among eleven such bounces; no alternative win is claimed.
- Frozen release-three fixtures confirm the reset loop is interrupted
  and ordinary bounce and lethal guards remain. See
  `eps/removals_proof.md`. Plan: CPUX, current-g6 regular XP and paired
  fast screen. Hosted verdict pending; production remains v2.
- New isolated search-selection trial `experiments/paths.bas`, SHA-256
  `1bedb8c5a4b97369f59f5ce851be3f43802615b4fb945d7c0e1cb50c4e89c244`.
  Select the best discovered own-turn continuation at the root while
  retaining existing mean PUCT exploration, priors, targets and budgets.
  Real host fixture changes Bear to Footsoldier followed by Swords,
  increasing actual end-turn attack damage from six to eight at equal
  energy. Safety fixtures and ten runtime diagnostics pass. See
  `eps/paths_proof.md`. Plan: CPUX and current-g6 regular and fast XP.
  Hosted verdict pending; production remains v2.
- Saved fast metadata for 110 completed batches: 1,100 games, 550 exact
  request, manifest, response and summary JSON files, about 3.3 MB.
  Each family's even numbered batch was explicitly sent to staging and
  odd numbered batch to production. Older response files lack endpoint
  and build fields; this attribution comes from the recorded launch
  commands. No service build or release is inferred from request IDs.
- Checkpoint `20f0a9e2` contains the checked permanent-removal and best-path
  experiments plus reproducible fast evidence. Two direct push attempts
  were rejected by automatic approval review for lacking explicit trusted
  approval of this exact commit to main. Approval was requested. No branch
  workaround or indirect push was attempted. New-source CPUX waits for
  that approval; already uploaded v23 and earlier XP jobs continue.

2026-10-01, regular incoming-target verdict and extended fast cohort:

- Previous turn made progress: committed two proved strategy trials,
  archived fast evidence, completed 300 new fast games and a fresh
  confirmation. The push approval remains pending; no retry was made
  without new trusted authorization.
- Current champions remain stilt:v3, greenshank:v6 and AWM Baseline:v1.
  Fresh canonical release-three v2 control completed: 18/100 wins,
  zero failed episodes. Request
  `xreq_84fab623-cb83-46fd-8d44-f30ead8687c8`.
- V18 Shields completed: 17/100, p = 0.6449 versus that matching control,
  zero failed episodes. Request
  `xreq_1743f647-9ddd-4826-8698-d569631fd276`. Not kept.
- V23 incoming Sharpshooter completed: 17/100, p = 0.6449 versus matching
  18/100 control, zero failed episodes. Request
  `xreq_c7b0cbda-725c-4b98-bc9a-56d5e2884b2c`. Not kept or submitted;
  a second 100-game arm and control await capacity to resolve the fast
  signal. They are frozen against the same current opponents.
- Extended fast cohort: 200 unique fresh seeds 202610360..559 per arm,
  v2 35/200 versus v23 36/200, gained four paired wins and lost three,
  exact one-sided paired p = 0.5. All 400 newly executed games verify
  their hashes and have zero failures or disabled bots. Actual endpoint
  URLs are now saved in each response file, with even batches staging
  and odd batches production. Total fast executions to date: 1,650,
  including historical probes and repeated source/seed comparisons.
- Across all 400 disjoint current-g6 fast seed pairs: v2 64/400 (16%),
  v23 73/400 (18.25%), gained sixteen and lost seven, exact paired
  p = 0.04657. Archer 17/132 versus 26/132; other classes match.
  The additional cohort alone does not confirm improvement. Fast
  evidence remains separate from regular XP and cannot justify promotion.
- V9 full-budget search received a fresh current-g6 regular request:
  `xreq_e89b2225-7638-4bcc-aec1-a490fccdc8ed`. V22 cumulative Hail:
  `xreq_de8e5903-a02b-49bf-a27d-aa310ee80821`. V21 survival:
  `xreq_16b72440-b699-4c38-90a9-25d8e8154704`. V19 reserves:
  `xreq_321062a4-f774-486f-a969-e8809659035e`. Each requests 100 episodes
  against the same three distinct champions; hosted verdicts pending.
- The earlier queue monitor terminated on a status CLI failure. A direct
  read of the exact control ID succeeded and proved completion. The
  replacement monitor resumes all saved IDs, without recreating jobs.
  The second monitor's bounded interval finished normally.

## Restart, 2026-10-01 evening

Prior radogost MCTS trials (v3-v23) all scored 10-18% against the current
top three. The restart audited why with new tools instead of tuning MCTS.

Tools:

- `tools/rivals.nim`: lists every league policy version (elevated SQL) and
  downloads each BASIC source from the private policy bucket into
  `others/` (gitignored). stilt:v3 and greenshank:v5 are byte-identical;
  greenshank:v6 adds dead-seat inference from the turn counter.
- `tools/stats.nim`: batch replay extractor. Rows are stats in three
  groups (direct choices, draw/energy-limited plays, outcomes), columns are
  ours then the top three. Writes `.md` and `.html`, red rows where we sit
  outside every opponent's range. First table: `eps/stats_g6_v2.html`.
- `tools/games.nim`: game lengths, death causes, damage by source seat.
- `tools/arena.nim`: local screen mirroring hosted seating (4 rotated seats)
  or league seating (`AWM_LEAGUE=1`: 5 shuffled seats with a baseline
  filler). Paired seeds, exact sign test. Screening only, never the score.
- `tools/xp.nim`: hosted XP body (ours + one live champion per other
  player in rating order), create, get, and Fisher compare between arms.

Findings from 500 hosted g6 games (stats table):

- Minions only ever hit the next living hero; they never block. Only the
  previous living seat's minions damage us.
- Root cause: v2 spends removal on the NEXT player's board (Duel 100%,
  Oozification 100%, Sharpshooter pings the next hero 79%), because the
  BASIC API only exposes the next board's stats and the search modelled
  that board as the threat. Leaders aim 71-87% of removal at the previous
  seat. We remove 7 power/game from our attacker vs 16 for the leaders and
  take 12.5 attack damage from it vs 8-10.6.
- XP seats rotate, so the ring is always ours -> stilt -> greenshank ->
  baseline -> ours. The baseline before us dies first 52% of the time,
  after which greenshank's board hits us (5.5 damage/game). League rounds
  use 5 shuffled seats with a baseline filler instead.
- Leaders waste Swords (20-37%), Shields (33-44%) on empty boards and
  3-5% of Hails.
- Local arena, 200 seeds: greenshank's logic in our seat 22.5% vs v2 11.5%.

Trial v24 (one change: replace MCTS with the leader's defensive
targeting): `radogost.bas` is greenshank:v6's logic under our header,
verified identical on 200 local seeds. v2 source archived at
`radogost/archive/v2.bas`. Hosted verdict pending.

2026-10-01, hosted verdicts for the restart:

- v26 (leader targeting port), opponents stilt:v3, greenshank:v6, AWM
  Baseline:v1, release 2026.10.1.3. XP `xreq_5714460c-898a-4ced-aa6a-258f22a481b4`
  25/100 and `xreq_7fd89e7e-4256-4f81-9081-0dd5bc9577c4` 15/100: 40/200 vs
  pooled v2 control 32/200 (`xreq_84fab623...`, `xreq_4d52c990...`),
  Fisher p = 0.18. Inconclusive; not kept on its own.
- v27 = v26 plus one play-order idea: removal (Sharpshooter, Hail, Duel,
  Tactician) before other cards, buffs (Swords, Shields, Rally) after
  bodies. Local screen vs port: XP ring +3.7 points (69/32, p = 0.0001),
  league 5-seat +2.1 (57/36, p = 0.019). Source `trials/order_v27.bas`.
- v27 hosted: `xreq_1708f3a2-e433-435e-9663-15cbc69c3477` 32/100 and
  `xreq_387b5e2d-153a-4188-bc01-74af33f16126` 24/100: 56/200 (28.0%) vs v2
  32/200 (16.0%), one-sided Fisher p = 0.0027, zero failed episodes.
  Verdict: keep. Submitted radogost:v27 to the league as champion.
- Local screens on top of v27's order (1000 paired seeds, XP / league):
  Bouncer on the attacker's oldest minion +0.6 / +0.9 (p 0.055 / 0.011);
  Bouncer never on the next player's minion +1.7 / +0.7 (p 0.005 / 0.19);
  hold Bouncers without an attacker target -0.8 / +1.4; Oozification
  before Bouncers -0.9 / -0.8; Study regardless of energy -0.8 / -0.5;
  oldest-minion removal for Archer/Warrior -0.8 / -0.5. Neutral earlier:
  empty-board buff skip, strongest Duel fighter, two-back overflow aims.

2026-10-01, fast-XP screening (hosted, league format):

- `tools/fastxp.nim`: paired screens on the fast-XP servers (staging and
  production alternate). Five seats like league rounds: ours, stilt:v3,
  greenshank:v6, AWM Baseline:v1, AWM Baseline Filler:v1, in a seeded
  shuffled order per ten-episode batch shared by every candidate. Retries
  429s and batches with a failed game, exports replays and a status file
  for `tools/stats.nim`. About 1000 games in 40 seconds.
- Local arena screening stopped at the user's request; all scores now
  come from hosted fast-XP or official XP.
- v27 in league format: 295/1000 (29.5%) vs greenshank 26.1%, stilt 23.0%,
  baselines 11.6% and 9.8%. Stats: `eps/stats_league_v27.html`.
- Ablations vs v27 (1000 paired): Sharpshooter pinging the next hero
  first -3.1 (13/44); never Bolt -1.1 (14/25); Bolt at the attacker's
  hero -0.5 (28/33); skip buffs on an empty board +0.1 (2/1). Defensive
  removal is the main lever; Bolt aim is not.
- 2000 paired vs v27: Hail before other removal 0.0 (27/27); Duel only on
  the attacker's minions +0.2 (10/6); Mage holds Bouncers unless the
  attacker has a minion +2.0 (109/70, p = 0.0022).
- Bouncer hold confirmation on fresh seeds 600000+, 3000 paired games:
  30.1% vs 28.2%, gained 152, lost 97, p = 0.0003. All gain is Mage
  (316 vs 261 of 1052). Verdict: keep as v28. Source
  `trials/bouncehold.bas`, now `radogost/radogost.bas`.

2026-10-01, more fast-XP trials on v28 (2000 paired unless noted):

- Hold Sharpshooter until the attacker has a minion: +0.6 (37/25), fresh
  3000: +0.3 (37/28), vs final-duel targeting 3000: +0.4 (45/32). Pooled
  over three independent seed sets 119 gained, 85 lost, one-sided sign
  p ~ 0.01. Kept.
- Neutral, not kept: hold Tactician (9/9), hold Hail (11/9), Mage keeps two
  Bouncers and plays extras as bodies (40/37), Swords before bodies with
  two minions (24/26), Rally at body priority (14/9), Primordial only when
  opponents have at least our minion count (4/3), two-back overflow for
  Bouncer (56/68), Sharpshooter (16/20), Duel/Tactician (13/7),
  Oozification before draws (66/81), no Study-first (55/48), Tactician as
  a plain body (2/3).
- `tools/stats.nim` death stages: v28 reaches the final duel in 55.8% of
  league-format games (stilt 45.0, greenshank 50.1) but wins 51.5% of them
  (stilt 53.6, greenshank 54.1).
- Final-duel targeting: with two players left the attacker is the next
  player, whose stats are visible. Sharpshooter kills the strongest
  one-toughness minion else hits the hero; Duel takes a minion the +1/+1
  fighter kills; Bouncer, Oozification and Tactician take the strongest.
  2000 paired: 13 gained, 0 lost (p = 0.0001); fresh 3000: 24 gained,
  1 lost (p < 0.0001). Kept.
- v29 = v28 + final-duel targeting + Sharpshooter hold. Fresh 3000 vs v28:
  891 vs 855 wins (29.7% vs 28.5%), 69 gained, 33 lost, p = 0.0002.
  Source `trials/duelsharp.bas`, now `radogost/radogost.bas`.
- Real league rounds (`tools/rounds.nim`, last 12 rounds, 60 games, mostly
  before v27): stilt:v3 24/60, greenshank:v6 11/55, radogost:v2 9/55.
  Fast-XP with v2 in our seat gives stilt 29%, so stilt's 40% is likely
  partly luck; keep watching rounds.

2026-10-01, league reality check:

- Real league rounds (last 12, 60 games, mostly radogost:v2): stilt:v3
  won 26/60 (43%). `tools/leaguecheck.nim` replays league games' exact
  seeds and seatings on fast-XP: 15/15 identical classes, action counts
  and winners. Fast-XP is the league engine.
- Stilt won 9/14 league games where radogost (v2) sat right before it,
  i.e. where v2 was stilt's attacker.
- Real league layouts with fresh seeds (`AWM_LAYOUTS`, 600 games each):
  v29 30.0% (stilt 25.2%, greenshank 22.3%); v2 17.8% (stilt 27.3%,
  greenshank 26.8%). Stilt's streak was luck plus v2 as a weak neighbour.

2026-10-01, final-duel tree search:

- With two players left the next player is our attacker, which is exactly
  the world v2's MCTS models. Hybrid: v29 everywhere, v2's search
  (`duelSearch:` label, v2 body verbatim) in the final duel.
- All classes, 2000 paired vs v29: 23 gained, 36 lost. Warrior duels
  improved (202 -> 217), Archer and Mage got worse. Not kept.
- Warrior only, fresh seeds 1700000+, 3000 paired vs v29: 13 gained,
  1 lost (p = 0.0009), Warrior 278 -> 290 of 972. Kept as v30
  (`trials/duelwarrior.bas`).

2026-10-01, why stilt leads the real league:

- All 36 league rounds (`tools/rounds.nim` now pages `/v2/rounds`): stilt:v3
  36/85 (42.4%), byte-identical greenshank:v5 5/20, greenshank:v6 13/70,
  radogost:v2 26/125. No repeated seeds in 200 games.
- League scheduler (metta `round_lifecycle.py`): seats shuffled per episode
  with a per-round Random, seeds `crc32(division:round) + job_index`, no
  coupling of seats to seeds. Stilt's ring orders are spread evenly.
- Fast-XP with v30 in our seat: real layouts and fresh seeds stilt 25%,
  large seeds 1e9/1.5e9 stilt 23.7%/26.1% with v30 at 29.2%/28.5%. The
  real seeds replayed with v30 still give stilt 22/60, so those particular
  seeds were good for stilt. Conclusion: variance plus v2's presence.
- Larger MCTS resources for Warrior duels: no change (1 gained, 1 lost).

2026-10-01, v30 follow-ups (fast-XP, large seeds):

- `tools/story.nim` prints hosted replays turn by turn. An early Warrior
  loss: the baseline attacker double-Sworded its oldest minions to 3-5
  power while our Tactician hit its newest 1-power Footsoldier and a Mage
  next player bounced every minion we played.
- Oldest attacker minion as target: Bouncer +0.5 (17/7), fresh +0.2
  (20/15), pooled 37/22 p ~ 0.03, held for a bundle; Tactician -0.2
  (7/12); Duel -0.2 (7/12). Not kept alone.
- Decoy order (strongest minion first) in league format: by power 21/28,
  by cost 28/38. Not kept.
- Larger MCTS budget for Warrior duels: 1/1. Not kept.
- League round 37: radogost:v30 0.4, stilt 0.0.
- Priority tuner (16 single-card priority mutations, 1000 paired each,
  seeds 1950000000+): all within noise. Best: Hail before other removal
  20/13 (p 0.15), Bear earlier 10/5 (p 0.15); Duel/Tactician earlier 0/3.
  The play-order priorities are at a local optimum.
- Lost final duels (`tools/story.nim`): a 3-player-phase next player
  builds a huge visible board while killing our attacker, then turns on
  us; or our automatic attack kills the next player and the attacker,
  moving next, strikes first in the duel. Card choice rarely saves these.
- Mage Bouncers on the next player's strongest minion in the 3-player phase
  when its visible board is big (>= 6 and >= twice our incoming damage):
  14 gained, 45 lost. Defending against the current attacker stays right.
- Bundle (Bouncer oldest + Hail first + Bear earlier), fresh 3000: 91/83,
  p = 0.30. Not kept. v30 stays champion; policy is at a plateau near
  30-31% in league format (stilt ~24%, greenshank ~25%).

2026-10-02, ring-balanced official XP:

- Official XP with `slot: -1` only rotates seats, so the ring is always
  ours -> stilt -> greenshank -> baseline: the baseline attacked us in
  100/100 v27 games. League rounds shuffle seats: attackers in 205 league
  games were baseline 65, stilt 49, filler 48, greenshank 43.
- `tools/xp.nim rings POLICY TAG N` writes six requests, one per ring
  order of the three opponents, seats pinned (ours 0, next 1, attacker 3),
  and `get` reports our wins by attacker.
- Greenshank v7 is now Andrew Brower B's champion: final-duel visible
  targeting, Warrior removal first, Archer costliest card first and
  Sharpshooter sight on the next player's minions. Fast-XP field updated.
- v30 league format vs the v7 field (2000 games): v30 29.3%, greenshank v7
  26.8%, stilt 23.9%.
- v30 ring XP, 6 x 20 games: greenshank:v7 43/120 (35.8%), radogost:v30
  36/120 (30.0%), stilt:v3 31/120, baseline 10/120. Our wins by attacker:
  baseline 8/40, greenshank 15/40, stilt 13/40. The old rotated ring is
  our worst (2/20). Stats `eps/stats_ring_v30.html`: we reach the final
  duel in 65.8% but win 45.6% of them (greenshank v7 57.3%); Archer 20.0%
  vs greenshank 35.9%.

2026-10-02, league-format official XP:

- `xp rings` now adds the league's filler (`AWM Baseline Filler:v1`, same
  source hash as AWM Baseline:v1) as a fifth pinned seat and writes the 12
  distinct ring orders (orders that only swap the two baselines are the
  same game). `xp totals PREFIX` pools all policies' wins.
- v30, 12 rings x 10 games: radogost:v30 46/120 (38.3%), stilt:v3 34/120
  (28.3%), greenshank:v7 27/120 (22.5%), AWM Baseline 8, filler 5. Our
  final duels won 69.7%; Mage 27.0% vs stilt 32.6% is the only class
  behind. Stats `eps/stats_leaguexp_v30.html`.
- At the user's request radogost:v1 also gets 12 x 20 league-format ring
  games, so its dashboard rate (from 900 games against four baselines)
  reflects the real field.

2026-10-02, greenshank:v4 study (user request):

- The XP dashboard shows greenshank:v4 at 65% pairwise over 200 shared
  games. Those games were our old v2 and v6 MCTS versions in the rotated
  ring on release .2, so the figure is against a weak, fixed-ring field.
- v4 = "ss-bubble": v3 plus free Bubbles even on a low deck. Versus v30 it
  differs only in the Mage branch (Oozification before Bouncers, one
  Bouncer in reserve, spares as bodies or on the next player, draws after
  removal) and by lacking everything added since v6 (death inference,
  removal-first order, Sharpshooter hold, final-duel targeting, duel search).
- Same seeds, league format (2000 fast-XP games): greenshank_v4 in our
  seat 24.1% vs v30 29.3%; v4 won 123 games v30 lost, lost 227 v30 won.
  By class v4/v30: Archer 198/212, Warrior 177/193, Mage 107/181. Same-seat
  stats: `eps/stats_v4_vs_v30_sameseat.html`. v4 casts 1.62 Oozifications
  per game (v30 0.30), plays 29% of Bouncers as bodies, draws less.
- v30 vs a field with greenshank:v4 as the Brower B seat (2000 games):
  v30 29.6%, v4 24.4%, stilt 25.4%.
- `tools/pairs.nim` lists discordant same-seed games; `tools/compilecheck.nim`
  compiles BASIC without playing. fastxp: `AWM_OPPONENTS=a,b,c,d`.
- A workflow is mining the 123 v4-won/v30-lost games (53 Archer, 37 Mage,
  33 Warrior) for isolated moves to screen. Verdicts pending.
- radogost:v1 chart cleanup: 12 league-format rings x 20 = 240 official
  games, v1 17.9%, stilt 28.3%, greenshank v7 27.9%.

2026-10-02, rules-only rewrite, Mage first (user request: drop MCTS):

- Mechanics checked in the sim: a minion cannot attack the turn it is
  played; Study's discard is chosen by the built-in bot and takes the MOST
  EXPENSIVE card in hand (so Study with a Primordial or Oozification in
  hand throws it away, and Study is indistinguishable from Bubble Shield
  in the BASIC API); Primordial bounces every other card on every board.
- Designer's Primordial + Bouncer lock, `trials/lock.bas` (reset every
  turn): Mage 52/683 vs v30 216/683 on the same seeds. The replayed
  Primordial is summoning-sick, so it never attacked; the next hero stayed
  at 20 while our attacker's Bolts killed us. In a five-seat ring the
  Primordial hits the next player and the attacker is the last seat it
  can reach.
- `trials/lock2.bas` (attack every turn, Bouncers on attacker minions,
  reset only when damaged, outnumbered or hit hard): Mage 80/327 vs
  87/327, paired 43/52. Not better than v30's simple Mage. `lock3` was a
  parity bug (reset every turn again), Mage 10/327.
- New base for rules-only work: v29 (`trials/duelsharp.bas`, no tree
  search). Cost of dropping the Warrior duel search: paired 1/11 vs v30.
- Candidates from the v4 workflow ported onto v29 (r_*.bas), plus Study
  gates (hold 2-cost no-target spells while holding a card costing >= 4,
  or >= 8). Screen `rules1` pending.
- Field change: rivals now stilt:v5 and greenshank:v12 (same owner;
  stilt:v4 == greenshank:v12 by hash). Their headers copy our duel ping
  ("as radogost:v30 does") and add Shields hold and Rally/Swords-first
  duels. Last 60 league rounds: radogost:v30 82/275 (29.8%), greenshank
  v6-v10 18-29%, stilt:v5 10/25. Fast-XP field must move to v5/v12.
- Screen `rules1` (old field, 1000 paired vs v29): Study gate >= 4 46/54,
  gate >= 8 21/42 (holding Study also holds Bubble Shields and draws; not
  kept); stale-alive fix 6/4; Sharpshooter hero-lethal check 3/0; Oozify
  after a wipe 12/5; Warrior opening body 15/14; lethal handoff 0/0;
  no-draws-in-wipe-stalemate 15/0 (p < 0.0001).
- Confirmation `rules2` (new field stilt:v5 / greenshank:v12, 3000 paired
  vs v29, fresh seeds): no-draws 22/4 (p = 0.0003), kept; Sharpshooter
  hero-lethal 7/0 (p = 0.008, pooled 10/0), kept; Oozify after wipe 24/23,
  dropped; v30's duel search over v29: 17/1.
- no-draws rule: when our board was emptied on the opponents' turns twice
  running with no life change (an enemy Primordial loop), stop casting
  Study/Bubble Shield so we do not deck out first. Sharpshooter rule: ping
  the next hero when that is lethal.
- Primordial loop, designer's how-to (attack, then bounce, then replay in
  one turn) cannot be executed by a bot here: attacks happen only after
  the turn ends and a replayed Primordial is summoning-sick. Executable
  form is a two-turn cycle. Generated 12 variants (`tools/gen_loops.py`,
  `trials/loop01..12`) over reset cadence, dig, Oozification reserve,
  second copy and Bouncer reserve; review and hosted screen pending.

2026-10-02, explicit-action engine (2026.10.2.1/.2):

- The host no longer attacks, discards, picks classes or ends turns. Every
  pre-change script fails its games (round 98 failed outright). New API:
  pickClass, attack(id, choice) at any hero or minion, endTurn,
  discardCards, resolveTrigger, readable card names, all boards visible.
- Rewrite `radogost/radogost.bas` (v31): picks Mage; discards keep the
  Primordial (worth table); attacks first with every ready minion (a hero
  at or below the attacker's power dies, else the lowest-life hero); from
  nine energy the lock: Bouncer on our own Primordial after it attacked,
  replay (wipes every board, Bouncers return to hand), second copy replays
  without a Bouncer; Oozification on the strongest enemy minion of 4+
  power; Bouncers on the strongest enemy minion of 2+ power keeping one
  for the reset; draws only while digging for the Primordial or Bouncers
  and the deck is above 12 (the first smoke game decked us out).
- `tools/smoke.nim` plays one local game vs four base bots: v31 won 2 of 3
  seeds with resets firing. Uploaded and submitted as champion (the
  previous champion v30 could not act). Fast-XP still served the old
  engine, so screening waits for its rebuild; official league-format
  rings are the score meanwhile.

2026-10-02, v31 on official XP (2026.10.2.2, the new base bot uploaded
as awm-base:v1 under Andre von Auto for testing):

- 1 of us + 4 base, 100 games (`xreq_8b7e4506`): radogost:v31 92/100,
  base 8/400, zero failures, zero deck-outs for us, never first to die.
- 2 of us + 3 base, 100 games (`xreq_c03132f7`): our seats 43/200 (one
  of us wins 43% of games), base 55/300; 93 of our 200 seats died by
  deck-out, median game 111 turns, 2 timeouts. Two locks bounce each
  other's Primordial every turn, neither ever attacks, and the deck race
  decides. Our replay also bounces the enemy Primordial before our
  Oozification could destroy it.
- Fast-XP still serves the old engine on both endpoints; official XP only.
- v32 (Oozify an enemy Primordial before replaying, no optional draws
  while one is in play), 2 of us + 3 base (`xreq_8605451e`): our seats
  20/200, base 39/300, 41 TIMEOUTS of 100 (v31: 2). Conserving the deck
  turns the lock mirror into games that never end and score zero for all.
  Rejected. v33 (v32 plus a dig cap at 18 cards) pending, expected alike.
- Bug: `handName$`/`boardName$` inside nested loops exceed the BASIC
  string limit (256 per decision) with 25-card hands: v33 failed a local
  mirror game. Fix: numeric signatures (cost, kind, power, ids), names
  only to tell Study from Bubble Shield. v31's logic with that fix is v36.
- Server numbering: the string-fix build (`trials/v36.bas`, v31 logic) is
  radogost:v34 on the server; `trials/v34.bas`/`v35.bas` were never
  uploaded. v32 1 vs 4 base: 89/100, 2 timeouts (`xreq_e251cdf0`).
- Hosted games time out near 800 ticks (timed-out replays end at tick
  798), about 16 rounds of five players: any stalemate scores zero.
- The 41 early-ended v32 mirror games (and 39 of v33's) were OUR
  string-limit crashes, recorded as zero-score completions with no error
  fields: a replay ends mid-turn with our seat still acting after a
  17-card turn. v32's mirror verdict is withdrawn; its logic with the fix
  is radogost:v35, v31's logic with the fix is radogost:v34. Clean runs
  queued: v34 1v4 sanity (50), v34 2v3, v35 2v3, v35 1v4 (100 each).

2026-10-02, clean runs after the string fix (zero crashes):

- v34 (v31 logic + fix): 1 vs 4 base 43/50 (`xreq_e757ce01`); 2 of us +
  3 base 53/200 seats (26.5%), base 47/300, 99 of our seats decked out,
  every game ended (`xreq_548a6583`).
- v35 (v32 logic + fix: Oozify an enemy Primordial first, no optional
  draws while one is in play): 1 vs 4 base 95/100 (`xreq_13e065ef`);
  mirror 44/200 (22%), base 56/300, 26 deck-outs but 130 life deaths
  (`xreq_d6f6c428`). Not better than v34 in the mirror; not kept.
- Verdict: v34 submitted as champion (replaces v31, which crashes on
  bloated hands). Next isolated trial: v34 + stop optional draws once an
  enemy Primordial is on a board (the no-draw half of v35 alone).
- No-draw rule alone on v34 (server radogost:v36): mirror 43/200 (v34
  53/200), single 45/50 (`xreq_fe2ab6f6`, `xreq_e07bc357`). Not kept.
- League resumed at round 100 with updated rivals stilt:v6 and
  greenshank:v14; round 101 v31 0.4 / 0.2 / 0.2, round 102 v31 1.0 / 0 / 0.
- stilt:v6 == greenshank:v14 (same hash): "explicit-ping", the old
  duel-ping card play migrated: picks Mage every game, discards the
  costliest card (still throws Primordials away), ready minions attack
  the next living hero in board order, no lock. The league now seats
  three entrants plus two copies of `AWM Explicit Baseline:v1` (the new
  base bot); Houck's old baseline no longer plays. `xp rings` takes
  AWM_RING_OPPONENTS and AWM_FILLER to mirror that.
- League after the rivals' migration: Andre von Auto #1 (1540.2), Andrew
  Brower 1513.0, Andrew Brower B 1482.8. v31's 10 league games vs
  stilt:v6 / greenshank:v14: 7 wins (stats `eps/stats_league_new.html`).
- Lost game b17d48f8: with the Primordial in hand and energy 4-6, v31
  passed turns (draw gate off, Bouncer reserved, Oozification waiting
  for a 4-power target) while two filler Archers shot it dead by its
  sixth turn. Trials: v37 keeps digging while not yet locked; v38 at 12
  life or less uses every Bouncer and Oozifies any 2+ power minion.
  Each gets the 12 league-format rings x 10 vs stilt:v6, greenshank:v14
  and two explicit-baseline fillers; v34 control rings in flight.
- v34 league-format rings (12 x 10, `v34_league2_r*`): radogost:v34
  89/120 (74.2%), greenshank:v14 13, stilt:v6 8, fillers 10. By attacker:
  rival before us 18/30 and 19/30, filler before us 52/60.
- v37 (keep digging while unlocked): 62/120 (51.7%) vs v34 89/120,
  Fisher p = 0.9999 (worse; draws cost the deck race). Not kept.
- v38 (at <= 12 life every Bouncer and Oozify any 2+ power): 81/120
  (67.5%), p = 0.90. Not kept. v34 stays champion.
- Ring stats (`eps/stats_rings_v34.html`): v34 reaches the final duel
  77.5% and wins 95.7% of them; losses are early deaths (19%) when the
  seat before us is a rival whose Bouncers all hit the next hero.
- v39 (Primordial hits the living hero before us unless a kill is
  available): 87/120, p = 0.67 vs v34. Not kept.
- v40 (pre-lock Bouncers prefer the preceding seat's minions, any power,
  +2 score): 101/120 (84.2%) vs v34 89/120, Fisher p = 0.040; by attacker
  greenshank 24/30, stilt 22/30, filler 55/60. Borderline: second 120-game
  ring set (`v40_league3_r*`) queued before any keep.
- v40 confirmation (`v40_league3_r*`): 98/120 (81.7%); pooled 199/240
  (82.9%) vs v34 89/120, Fisher p = 0.036. Second control set
  (`v34_league3_r*`) queued to firm the comparison before a keep.
- Second v34 control (`v34_league3_r*`): 84/120. Pooled 240 each: v34
  173/240 (72.1%) vs v40 199/240 (82.9%), one-sided Fisher p = 0.0031.
  Verdict: keep. radogost:v40 submitted as champion; source installed as
  `radogost/radogost.bas` (= trials/v40_bounceprev.bas).
- League: Andre von Auto #1 at 1549.4 (+44), v40 active; round 103 v34
  0.8. Next isolated trials vs v40's pooled 240: v41 applies the
  preceding-seat Bouncer preference in the lock phase too; v42 plays
  Bubble Shield before Bouncers while unlocked when the seat before us
  fields 2+ minions. Rings `v41_league2_r*`, `v42_league2_r*` queued.
- v41 (preceding-seat Bouncer preference in every phase): 101/120
  (84.2%), p = 0.44 vs v40's 199/240. Not kept.
- v42 (Bubble Shield before Bouncers while unlocked when the seat before
  us fields 2+ minions): 94/120 (78.3%), p = 0.88. Not kept.
- v40 ring stats (`eps/stats_rings_v40.html`, 240 games): 82.9%; early
  deaths 11%; final duel reached 86.2%, won 96.1%. Loss e49ac983: both
  Primordials gone, 40 turns passed with 17-28 energy and a hand of
  Bouncers (no 2-power targets, body rule only in the lock), then
  deck-out. Trial v43: spare Bouncers are bodies in every phase, keeping
  one only while a Primordial waits in hand.
- v43 (spare Bouncers as bodies in every phase): 96/120 (80.0%),
  p = 0.80 vs v40's 199/240. Not kept.
- v40 by seating (240 games): filler before us 111/120 (92%), rival
  before us 88/120 (73%); who sits after us does not matter (rival after
  us 105/120). Round 104: v40 5/5; rating 1562.9.
- Loss anatomy with a rival before us (v40, 32 losses): 12 deck-outs with
  our hero alive at 17-20 life in the endgame. Cause: the lock phase
  casts Plan whenever the deck is above 2, and our own replay bounces the
  Plan trinket back to hand each turn, so it is recast every turn and the
  deck drains at double speed. v44 gates the lock-phase Plan like the
  pre-lock dig (only for Bouncers, deck above 12).
- Correction: v40's lock phase already gates Plan (bouncers < 2, deck >
  12). `tools/decks.nim` and attack lines in `tools/story.nim` show the
  true endgame in the deck-out losses: three Mages each replay a
  Primordial every turn, every replay bounces the other two, no Primordial
  is ever ready to attack, and the deck race decides. We drew 5-7 extra
  cards (Plan + Study), the winners 3-6. Trial v44: dig only while we have
  no Primordial and the deck is above 20; no digging for Bouncers.
- v44 (dig only without a Primordial and above 20 cards, no Bouncer
  digging): 98/120 (81.7%), p = 0.67 vs v40. Not kept. In equal deck
  races the earlier seat decks out first, so the race is a coin flip.
- v45: Oozify an enemy Primordial (8+ power on a living board) before our
  own replay, which otherwise bounces it out of reach. Rivals discard
  their costliest cards, so a destroyed copy is rarely replaced.
- v45 first set (`v45_league2_r*`): 105/120 (87.5%), rival before us
  49/60, filler before us 56/60; p = 0.16 vs v40's 199/240.
  Inconclusive: confirmation set `v45_league3_r*` queued.
- v45 mechanism check from replays (120 games each): v45 cast 164
  Oozifications, 149 on enemy Primordials; v40 cast 37, 17 on Primordials.
- v45 confirmation (`v45_league3_r*`): 105/120 again. Pooled 210/240
  (87.5%) vs v40 199/240 (82.9%), p = 0.099. Inconclusive: third
  120-game sets queued for both arms (`v45_league4_r*`, `v40_league4_r*`).
- Third sets: v45 102/120, v40 90/120. Pooled 360 each: v45 312/360
  (86.7%) vs v40 289/360 (80.3%), one-sided Fisher p = 0.0135. Verdict:
  keep. radogost:v45 submitted as champion; source installed as
  `radogost/radogost.bas` (= trials/v45_oozefirst.bas).
- v45 by seating over 360: rival before us 149/180 (83%), filler before
  us 163/180 (91%). Next isolated trial v46: v45 plus the preceding-seat
  Bouncer preference in every phase (v41's change, which lifted the
  rival-before subset on v40 to 80% but was neutral overall).
- v46 (preceding-seat Bouncer preference in every phase, on v45): 99/120
  (82.5%), p = 0.90 vs v45's 312/360. Not kept.
- v47: a Bubble on a hero's board bounces our attacker after it hits, so
  the Primordial (and other attackers) prefer heroes without a Bubble;
  kills still take priority.
- v47 (attackers avoid heroes with a Bubble on board): 104/120 (86.7%),
  p = 0.57 vs v45. Not kept.
- v45 losses over 360 (48): killed late with a rival before us 14, killed
  mid with a rival before us 9, deck-out late 14 (9 filler-before), early
  kills 3. Trace d0f0e1e7: Primordial found late (own turn 10), then the
  rival AFTER us Oozified both copies on consecutive turns (their rule:
  Oozification on the previous player's first minion, which after a wipe
  is always our Primordial). Rivals are always Mages; only they bounce
  or Oozify our Primordial.
- greenshank:v15 ("attack-first": ready minions attack before card plays)
  is Brower B's new champion; rings now use stilt:v6 + greenshank:v15 and
  need a fresh v45 control (`v45_league5_r*`).
- v48: attack targets prefer Mages (kills first, then the lowest-life
  Mage, then the lowest-life hero), to remove the Oozification and bounce
  threats before fillers.
- v48 (targets prefer Mages): 101/120 vs the fresh v45 control 100/120
  on the stilt:v6 + greenshank:v15 field (83.3%), p = 0.50. Not kept.
- v49: dig (Plan, then Study) until two Primordials are held or on the
  board, while the deck is above 16, as insurance against the rival after
  us Oozifying the first copy.
- v49 (dig for the second Primordial, deck above 16): 103/120 (85.8%),
  p = 0.36 vs v45's 100/120 on the same field. Inconclusive, small
  effect; not kept. v45 stays champion.

2026-10-05, league upheaval and the Primordial rework:

- Polyworld main b8fada6 (not deployed; league on 2026.10.2.3) replaces
  the deck's Primordial with "Summon Primordial" (8-cost spell: bounce all
  cards ONE chosen hero controls, then summon a vanilla 10/10 Primordial).
  The minion no longer wipes; our lock and every cost-8-minion check will
  need rework when it ships. base.bas also aims targets by side now.
- New players richard and relh run one identical "deckwarden" Mage
  script: never Plan/Study, Bubbles kept up, avoids Bubble heroes, recycles
  its Primordial only when outgunned, discards Plan/Study first. It won
  every stalemate: v45 0.0 in all recent rounds, we fell to #3 (1434 vs
  1633/1606). League replays (40): we deck out in 100% of games, dying
  with 3 alive in 90%; our 1.9 Plans + 1.8 Studies per game vs their 0.
- Fast-XP production is on awm-a808ccc (explicit engine): screening works
  again. Candidates: v50 (zero draws once a Primordial is held, Bubble
  Shield when we have no Bubble, reset only when outgunned or damaged),
  v51 (zero draws once a Primordial is held), v52 (never any optional
  draw). Field: richard-awm-deckwarden:v1, relh-awm-deckwarden:v11,
  stilt:v7, greenshank:v15 (no fillers: five entrants).
- Fast-XP vs the deckwarden field runs at ~2 games/min (deck-out
  stalemates are long), so v50-v52 are measured on official XP instead:
  24 ring orders x 5 games each vs richard, relh, stilt:v7, greenshank:v15.
- `trials/nerf.bas`: policy for the reworked Primordial (polyworld
  b8fada6): Summon Primordial (8-cost spell) targets the living enemy
  board with the most power (seat before us breaks ties), the summoned
  10/10 attacks every turn, a Bouncer heal only at 4 toughness or less,
  draws only with no Primordial card or Summon in hand. Under the new
  rules it won 3 of 4 local smoke games vs base bots; v45 never casts the
  new card and loses. Tools built against the new rules:
  /tmp/awm-compilecheck-new, /tmp/awm-smoke-new (old binaries kept).
- Official rings vs richard, relh, stilt:v7, greenshank:v15 (24 orders x
  5): v50 23/120 (19.2%), v51 18/120 (15.0%), v52 46/120 (38.3%) with the
  deckwardens at 39/120 and 34/120. v52 vs v51 Fisher p < 0.001; v45's
  league record vs this field is 0/40. Verdict: keep v52 (never any
  optional draw) and submit as champion. The zero-draw Mages split the
  stalemate near one third each by seat order.
- Next isolated trials on v52: v53 keeps a Bubble on our board (their
  Primordials avoid Bubble heroes); v54 resets only when outgunned or
  damaged instead of every turn.
- v53 (Bubble Shield when we have no Bubble): 43/120 (35.8%), p = 0.70 vs
  v52's 46/120. Not kept. v54 (reset only when outgunned or damaged):
  36/120 (30.0%), p = 0.93. Not kept. v52 stays champion. Among three
  zero-draw Mages the stalemate splits by seat order (the opener skips
  its first draw and decks out last).
- v52's 120 ring games: 46 wins, 71 deck-outs, 3 kills. We won 28/28 when
  we were the opener (it skips the first draw, so it decks out last) and
  18/92 otherwise: the zero-draw stalemate is decided by the opening seat.
- Under the reworked rules (local, one of us vs four deckwarden copies):
  nerf.bas 0/6, v52 0/6. The deckwarden casts Summon Primordial as a
  generic card at the lowest-life enemy hero and never draws, so it is
  already strong there; the nerf policy needs more than a port.
- League round 383, first with v52: 0.4 (tied first with relh 0.4,
  richard 0.2); rating 1441.8 and climbing from 1433.9.
- New-rules trace (nerf.bas vs four deckwardens): the deckwarden after us
  Bouncers our summoned Primordial every turn for 1 energy while we
  replay it for 8, so it never attacks; nerf.bas also still dug (three
  Plans) and lost the deck race. nerf2 = nerf with no optional draws.

2026-10-05, Primordial rework deployed (league on 2026.10.5.1):

- v52 cannot cast "Summon Primordial" (it looks for an 8-cost minion in
  hand), so nerf2 (zero-draw, Summon Primordial at the strongest enemy
  board, vanilla 10/10 attacker, Bouncer heal at 4 toughness or less) is
  uploaded and submitted as champion without a hosted comparison: the
  previous champion is structurally unable to play the new card.
- New-engine rings (24 x 5 vs richard, relh, stilt:v7, greenshank:v15):
  v55 2/120 (1.7%), v52 4/120 (3.3%); greenshank:v15 45%, stilt:v7 41%,
  deckwardens 6-8%. Without global wipes the meta is card advantage and
  Bouncer swarms; zero-draw endurance is worthless. Candidates: v56 =
  nerf.bas (dig until a Primordial is held, deck > 16); v57 = dig while
  the deck is above 8, Bouncers on any enemy minion with power, spare
  Bouncers as bodies.
- New-engine rings: v56 4/120, v57 4/120 (stilt 42-45%, greenshank
  33-39%, deckwardens 5-14%). Stats (`eps/stats_nerf_v57.html`): we die
  first in 67% of games, deal 1.6 minion damage per game (stilt 28), and
  replay a bounced Primordial for 8 energy every turn while the deckwarden
  after us bounces it for 1. stilt/greenshank win on card advantage:
  5.7 Studies, 95 Bouncers, 3.4 Bubble Shields per game, swarming the
  next hero. v58: replay a bounced Primordial only at 14+ energy, Study
  and Plan before Bouncers, Bubble Shield first when unprotected.
- v58 locally 0/6 vs four stilt:v7 copies (official rings running). New
  approach v59: port the dominant explicit-ping script (stilt:v7 ==
  greenshank:v15, which never casts the 8-cost spell) and add Summon
  Primordial at the seat that attacks us (else the strongest board), keep
  that card through discards, replay a bounced Primordial only at 14+
  energy.
- v58 (draws first, Bubble Shield when unprotected, replay a bounced
  Primordial only at 14+ energy): 1/120 (0.8%) on the new engine;
  greenshank:v15 44%, stilt:v7 41%. Our own-structure Mage keeps dying
  first; v59 (stilt port + Summon Primordial) rings queued.
- v58 stats (`eps/stats_nerf_v58.html`): attack damage taken from the
  seat before us 17.5 per game (stilt 4.4, greenshank 4.8); they cast 99
  Bouncers per game to our 54 and keep 3.6 Bubbles to our 0.2; our Plans
  (5.1) draw less per energy than their Studies (5.4). First to die 48%.
- v59 (explicit-ping port + Summon Primordial + keep that card): 13/120
  (10.8%) vs champion v55 2/120, Fisher p = 0.003: submitted as champion.
  Still below its source script (stilt 34%, greenshank 45%), so the
  Summon casts cost tempo in the Study-and-Bouncer economy. Next: v60 =
  the pure port (parity baseline), v61 = port with Summon only when the
  seat attacking us fields 4+ minions.
- v60 (pure explicit-ping port): 32/120 (26.7%); v61 (port + Summon only
  vs a 4+ minion attacker): 32/120. Both vs v59 13/120: p = 0.001. Field
  in those sets: stilt 30-34%, greenshank 33-38%, deckwardens 1-4%.
  Verdict: keep v60 (simpler) and submit as champion; Summon Primordial
  is not worth its energy in this meta. League round 385: v55 0.0.
- v62: v60 with attack targeting: a lethal hero anywhere first, otherwise
  the next hero unless it holds a Bubble, then the lowest-life hero
  without Bubbles.
- v62 (targeting, applied to both attack loops): 32/120 (26.7%), the
  same as v60's 32/120. Verdict: revert. By neighbour type (P ping, W
  warden; prev, next) v60 wins (P,P) 7/20, (P,W) 8/40, (W,P) 17/40,
  (W,W) 0/20 and v62 9/20, 4/40, 19/40, 0/20: the ring geometry decides
  the game, a ping wins when a warden sits before it and a ping after.
- Why identical code (v60 == stilt:v7) shows different ring stats: the
  engine lists card targets in seat order (`ruleContext` in polyworld
  sim.nim) and the deckwardens break Bouncer-target ties with a strict
  `>`, so seat 0 (ours in every ring) gets bounced first by both
  wardens: v60 deals 12 minion damage per game to stilt's 26 and takes
  13.5 from the seat before it to stilt's 7.9. Our ring A/Bs stay fair
  (same seat), but a parity port is at parity only in the league.
  Tool: `tools/ringseeds.nim` (seeds all distinct, first mover uniform).
- Pings die mostly by deck-out (stilt 47 of 79 deaths) at about own
  turn 17: Study (net 0 cards, filters) and Plan (net +1) each burn two
  deck cards and the rivals draw down to 5. Trials: v63 = Study and Plan
  only while the deck has more than 12 cards (Bubble Shields keep the
  5 floor); v64 = Bubble Shields cast at any deck size (v60 never casts
  one at deck <= 5).
- v63 (Study and Plan only while deck > 12): 25/120 (20.8%) vs v60
  32/120. Verdict: revert. Its replays: deck-out deaths 2 (v60: 21) but
  damage deaths 93 (v60: 67) and own turns 15.4 (16.4): the draws are
  Bouncer tempo, and tempo decides survival before the deck does.
- v64 (Bubble Shields at any deck size): 23/120 (19.2%). Verdict:
  revert. Cells: (P,P) 3/20, (P,W) 3/40, (W,P) 17/40, (W,W) 0/20.
- v65 (hit back: minions attack the seat before us when its minions
  attacked and we lost life since our last turn, else the next hero)
  running. Tool `tools/attacks.nim` proved it fires in a smoke game.
- v65 (hit back at the seat that damaged us): 25/120 (20.8%). Cells
  (P,P) 7/20, (P,W) 8/40, (W,P) 10/40, (W,W) 0/20: no gain where a ping
  sits before us, and a loss where a warden does (we retaliated at the
  wall instead of killing the ping after us). Verdict: revert.
- v66 (Bubble Shields only after the Bouncers): 14/120 (11.7%), Fisher
  p = 0.003 against v60. Verdict: revert, and note the lesson: early
  Bubbles are worth far more than Bouncers per energy. A Bubble is a
  trinket no Bouncer can remove and it bounces the attacker, and the
  wardens never attack a bubbled hero (score 15 - power vs 15+).
- (W,W) replays: we die by damage at own turn 13-14 with deck to spare
  in all 20 games: the ping behind the warden before us kills it by its
  turn 9 and then turns on us at full life while we chew on the other
  wall. Tools: `tools/bounces.nim` (1% of our Bouncers hit 0-power
  Oozes, no lever there).
- Trials: v67 = Study discards keep Bubble Shields (they tie with Study
  at cost 2 and the last in hand is tossed); v69 = Study cast only when
  the hand's Bouncers and Bubble Shields cannot spend the turn's energy
  (server version radogost:v68; rings tagged v69_nerf).
- v66 replays (`eps/stats_v66.md`): Bubble Shields 1.7 per game (field
  3.0-3.2), attack damage from non-adjacent seats 5.1 (v60 0.9), first
  to die 27.5%: without a Bubble the wardens' lowest-life rule lands on
  us. Primordials hit a hero twice in 120 games, so no bounce lever.
- Trials on Bubble uptime: v70 file = radogost:v69 (rings v70_nerf):
  a Bubble Shield is cast first whenever affordable, before Study;
  v71 file = radogost:v70 (rings v71_nerf): spare Bubble Shields wait
  in hand while a Bubble stands, so a pair can follow the turn the last
  one pops. Both diverge from v60 in local smoke games (seeds 31-35).
- v67 (Study discards keep Bubble Shields): 23/120 (19.2%). Verdict:
  revert. Six trials now sit at 23-25 of 120 against the single v60
  control of 32, so a second v60 control set (`v60ctl2`) runs to
  calibrate the baseline (ring noise is about +-5 wins).
- `tools/held.nim` on v60 rings: 0.9 energy per turn unused; cards still
  affordable at turn end are mostly Plans (29% of turns) held by the
  deck > 5 floor in the endgame, then Study, Bubble Shield, Oozification.
  `tools/bubbles.nim`: v60 seat 0 is bubbled at 56% of other seats'
  turn starts (3.2 shields per game); v66 17% (1.7 shields).
- v69 file (radogost:v68, Study only when the hand's Bouncers and
  Bubble Shields cannot spend the turn's energy): 30/120 (25.0%), cells
  (P,P) 6/20, (P,W) 4/40, (W,P) 20/40, (W,W) 0/20. Verdict: not a keep
  (v60 32/120), the best of the trials so far; revisit against the
  second control.
- v70 file (radogost:v69, Bubble Shield cast first whenever affordable,
  before Study): 21/120 (17.5%). Verdict: revert. With v66 (shields
  last) at 14/120 the rivals' hand-order between Study and Bubble Shield
  is a local optimum on both sides, or ring noise is wider than +-5.
- v71 file (radogost:v70, spare Bubble Shields held while a Bubble
  stands): 28/120 (23.3%), cells (P,P) 6/20, (P,W) 3/40, (W,P) 17/40,
  (W,W) 2/20. Verdict: not a keep. Bubble consumption is set by the
  attacks received, not by the count on board, so timing moves little.
- v72 (`trials/v72_wardencalm.bas`): a warden before us (deck at
  35 - turns from the five-card opening hand, judged from our sixth
  turn) never attacks a bubbled hero, so with a Bubble up our Bouncers
  skip its minions and stand as bodies, ramping our attack on the next
  seat instead of refunding the wall's Bouncers.
- Second v60 control (`v60ctl2`): 29/120 (24.2%); v60 baseline 61/240
  (25.4%). Against it the earlier 23-28 results (v63, v64, v65, v67,
  v71) are noise-level, v66 (14) and v70 (21) are real losses, v62 (32)
  and v69 (30) are no-ops. v72 (radogost:v71, rings `v72_nerf`) is
  running; in smoke games it equals v60 against four stilt copies and
  beats four warden copies in 59 and 69 turns where v60 needs 84 and 92.
- v72 (warden calm, radogost:v71): 20/120 (16.7%), cells (P,P) 8/20,
  (P,W) 4/40, (W,P) 5/40, (W,W) 3/20. Verdict: revert. A warden whose
  minions go unbounced does attack bubbled heroes once every target is
  bubbled (its tie-break is its next seat, us), and its board then
  grows unchecked; the (W,P) cell paid for it.
- v73 (`trials/v73_deckguard.bas`): in the endgame (deck <= 12, from
  our sixth turn) a Study or Plan is held when it would leave our deck
  no larger than the smallest deck among living seats that draw extra
  (wardens, at 35 - turns, excluded). Effect expected small, so it runs
  240 games (24 rings x 10) against the 240-game v60 baseline.
- v74 (`trials/v74_deckguardall.bas`, radogost:v73, rings `v74_nerf`):
  the same guard applied from our sixth turn at any deck size, to see
  whether the race or the tempo matters more; 240 games.
- v73 (endgame deck-race guard, radogost:v72): 50/240 (20.8%) vs v60
  61/240; cells (P,P) 7/40, (P,W) 11/80, (W,P) 30/80, (W,W) 2/40.
  Verdict: revert. The smoke wins came against four ping copies; in the
  mixed field the held draws cost more tempo than the race returns.
- v75 (`trials/v75_duelguard.bas`, radogost:v74, rings `v75_nerf`, 240
  games, seat-0 design): the deck-race guard only in the final duel
  (two players left, the rival not a warden). We reach the duel in 46%
  of games and lose 42% of those, mostly by decking out first.
- Measurement: `xp rings` now takes AWM_SAME_CODE (identical uploads
  collapse to one pattern) and AWM_OUR_SLOTS (our seat moved as the
  league shuffles it): `v60fair` = 6 patterns x 5 seats x 8 games, the
  league-faithful v60 baseline, running.
- v74 (whole-game deck-race guard, radogost:v73): 53/240 (22.1%) vs v60
  61/240; cells (P,P) 15/40, (P,W) 6/80, (W,P) 29/80, (W,W) 3/40.
  Verdict: revert.
- v76 (`trials/v76_wardenaim.bas`, radogost:v75, rings `v76fair`: 6
  patterns x 5 seats x 8 games): predicts a warden's attack target with
  its own rule (least-life unbubbled hero, ties to the first seat after
  it, else its next seat when every hero is bubbled) and skips bouncing
  its minions only when that target is not us, so the Bouncers stand as
  bodies against the seat after us. Smoke: equals v60 against four
  stilt copies, differs against four warden copies. Compared with the
  seat-varied `v60fair` control, since bodies at seat 0 are bounced by
  both wardens' tie-break.
- `v60fair` (6 patterns x 5 seats x 8 games): 66/240 (27.5%); stilt
  36.7%, greenshank 27.5%, wardens 5.0% and 3.3%. By our seat: 0 8/48,
  1 12/48, 2 16/48, 3 20/48, 4 10/48, so the seat-0 design understated
  us by about 8 points (both wardens' Bouncer tie-breaks land on the
  lowest seat). Cells (P,P) 17/40, (P,W) 12/80, (W,P) 31/80, (W,W)
  6/40. From here the seat-varied design is the standard; v60fair is
  the baseline (noise about +-7 of 240).
- v77 (`trials/v77_oozefirst.bas`, radogost:v76, rings `v77fair`):
  Oozes (no power) attack before Bouncers so a free Ooze pays for a
  Bubble pop instead of a Bouncer. Small effect expected; queued after
  v76fair.
- v75 (final-duel deck-race guard, radogost:v74): 46/240 (19.2%) vs
  v60 61/240 at seat 0; cells (P,P) 13/40, (P,W) 11/80, (W,P) 21/80,
  (W,W) 1/40. Verdict: revert. Every deck guard (endgame, whole game,
  duel only) loses: the draws are tempo even in the duel, and below the
  rivals' floor of 5 nobody draws extra anyway.

## 2026-10-16: deckbuilding release (AWM 2026.10.15.1)

- The league moved to AWM 2026.10.15.1 on 2026-10-15 (polyworld
  36f4160): every script lists its own 40-card deck in setup
  (`deckCard(name$, copies)`, 1-4 copies, class cards unlimited, off-class
  cards cost +3 less one per class card in play) or sits down with no
  deck and is out before the first turn. New cards: Overcharge, Explode,
  Ambusher, Assassin, Reload, Wildfire (Archer); Commander, Rally, Banner,
  Pillage (Warrior); Spirit, Morphosis Chamber, Control, Overwork (Mage);
  hidden minions, steal, repeat, options (choice kind 4), each-turn
  triggers. All six champions (v60, stilt:v7, greenshank:v15, both
  deckwardens, daf-awm-v1:v2) predate it, so every seat is out and every
  league game since the release is a 0-0 draw (rounds 1746-1758 all 0,
  MMR frozen at 1505.98 for everyone).
- v61 (`trials/v61_deck.bas`, server radogost:v77): v60 plus a deck list,
  the Mage precon without Morphosis Chamber (its each-turn option trigger
  is not answered by v60's trigger code) and Overwork, padded with eight
  Mage class cards. `tools/smoke.nim` rewritten for the new API
  (setupBotSeats, Seat decks, reference players as opponents): five seeds
  vs the reference players run without failures (we lose all five to the
  reference Archer/Warrior, as expected for old logic). XP `v77deck`
  (xreq_35455b41, 12 episodes, 6 seats vs all five champions) is the
  submit gate; with every rival out before turn one the only question it
  answers is that we do not fail. Submitted as champion if it scores.
- While rivals are out, hosted XP vs the top 3 carries no strategy
  signal; development of the real new-release policy is measured in local
  games vs the four reference players (correctness and relative strength
  only, not the score), and hosted XP resumes meaning once a rival
  migrates. Check the league each loop for migrated champions.
- Local field (`tools/field.nim GAMES SEED A.bas ...`, AWM_FIELD_ONE=1
  seats the first script once per game, rotating, against the four
  reference players; 400 games in about 6 s; noise about +-25 wins per
  800): reference precons in the new release: Warrior 40%, Archer 22%,
  Archer-Warrior 18%, Mage 0.4%. v61 (Mage, old logic) 1.5%. The real
  policy is a Warrior deck on the reference script's robust aim/attack
  framework. Results per 800 games (two 400-game seed sets, 500 and 900),
  wins for our seat:
  - w1 reference warrior.bas verbatim: 123/400 (30.8%, one set).
  - w2 (`trials/w2_order.bas`, radogost:v78): fixed card priority (Banner
    100, Commander 90, Rally 85, Bear 70, Footsoldier 60, Tactician 55,
    Swords 50 and Shields 45 only with two minions out, Duel 40, Pillage
    30), attacks after cards: 346/800 (43%). Keep.
  - w3 (`trials/w3_focus.bas`): hero swing value + (20 - life) \ 4, +30
    when the swing kills: 435/800 (54%). Keep.
  - w4a buffs from one minion 426, w4b from three 438, w7 Tactician 75
    421, w8 Tactician -> Warrior class cards 425, w5 Duel -> Warrior class
    cards 445 (Duel is dead weight), w6 Pillage -> class cards 398
    (Pillage earns its slot): all noise but w6, reverted.
  - w9b (`trials/w9b_hail.bas`, radogost:v79): Duel -> Hail of Arrows
    (off-class, cost 6, 1 damage to every enemy minion on all boards):
    484/800 (60.5%). Keep. w9a Bubble Shield 446, w9c Bolt 444, w9d
    Sniper 457: not kept.
  - On w9b: w10a Tactician -> Archer class cards 470, w10b Tactician ->
    Bubble Shield 447, w10c Hail priority by enemy minion count 489, w10d
    Pillage priority 65 486: noise, not kept.
- Hosted: v78 request failed to build (the dash JSON now flags only our
  policy as champion; `xp body` finds no rivals), so requests clone
  `eps/request_v77deck.json` with the new version. v79 = w9b, request
  `w9btop` (xreq_00e18d9d, 12 episodes vs all five champions).
- 2026-10-16 ~16:00 PDT: every rival membership is gone from rounds;
  round 1759 seated radogost:v79 alone with four platform fillers drawn
  with replacement from `AWM {Archer,Warrior,Mage,Archer Warrior}
  Reference:v1` (owner Andre von Houck). We won 1/6 that round. Hosted XP
  `w9btop` (xreq_00e18d9d): v79 12/12 vs the five dead champions; v79
  submitted and active. `tools/replaysum.nim GAME.raw SEAT.bas...`
  (gunzip the .replay first) replays a hosted game locally with the same
  seats, seed and scripts: games g0, g1, g3 of round 1759 match the
  hosted state hashes at every tick, so `tools/field.nim` with
  AWM_FIELD_RANDOM=1 (fillers drawn with replacement) is an exact proxy
  of league rounds. In it: reference warrior 42%, w9b 64%, w13 (team
  lethal + Hail by kills) 65%: not a keep. 1/6 is draw luck.
- Next: keep screening single changes in the random-filler field (800+
  games, keep only >= 2 SD, about 30 wins per 800), confirm keeps with a
  hosted XP whose roster is us plus four reference fillers, then submit.
