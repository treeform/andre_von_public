# Kutuzov

The current champion is **v121**, owned by Andre von Houck. Softmax confirmed
it placed and active on October 18, 2026 (October 19 UTC). In seven games against
the top six and seven matched v117 controls, v121 averaged 0.147285 versus
0.128475, a 14.6 percent increase. The user authorized promotion on higher
observed scores. The paired interval crosses zero, so this remains limited
evidence of overall strength. See the [comparison report](nimified/runs/2026-10-18-top-six/report.md)
and [promotion verification](nimified/runs/2026-10-18-top-six/promotion/submission-verification.json).

The latest candidate, **v122**, was not promoted. Seven new country rotations
against the same six frozen opponents averaged 0.082072 versus v121's 0.147285
in its matched historical games, a 44.3 percent decline. Four rotations scored
higher, two lower and one tied. Russia fell from 12 centers in the control to
zero, outweighing the other gains. All 49 pods completed, all 401 candidate
model attempts succeeded, and all 106 active movement phases had timely Ready
saves. One stale guided result was safely rejected and one game-end HTTP 400
was recovered. The stale-policy cancellation fix has local regression tests
but has not been uploaded. See the
[guided-search report](nimified/runs/2026-10-18-guided-round/report.md).

A follow-up [additive search lab](nimified/runs/2026-10-19-additive-search/report.md)
preserves v121's complete fixed-work search and appends candidates in separate
processes. On 28 live policy snapshots, two fresh simulated judges measured
3.29 and 3.15 percent gains, with five improvements and no position-mean losses.
Only one selected change used a new branch. Using recorded opponent spring
orders instead produced a 0.37 percent gain with two losses, exposing a forecast
gap. The local experimental guide now only logs proposals while v121 continues
normally. Tests verify matching RNG, caches, search progress and orders. These
changes remain unpublished and v121 remains champion.

v121 adds unique-plan caching, diverse search starts and public-history
cooperation inference to the Nim port of Richard’s Python policy. Future
development starts in [nimified](nimified), preserving the frozen Python
source and v115 as the comparison oracle. Frozen v117 remains a comparison
control. Exact identities are in [baseline.json](baseline.json).

An offline [position and search laboratory](nimified/runs/2026-10-18-position-lab-v2/report.md)
now freezes public board/history inputs and compares local search without LLM
calls or hosted games. Run it from nimified with
`python3 tools/simlab/run.py --directory runs/NEW-EXPERIMENT --oracle-python /path/to/venv/bin/python`.
The oracle Python environment needs `diplomacy==1.1.2`. The positional evaluator
and frozen continuation policies run in Nim. The deeper selector improved
simulated autumn scores by 6.39 percent on a small exploratory panel. Production
remains v121; this is a local research result, not a league rating change.

The sections below record earlier experiments and their champion decisions.
The previous experimental candidate was **v120**, with resumable background
search between model wakes. Ten games used three v120 seats against four
v117 seats. It recorded 30.26 billion simulations, about 64.38 million per
playable movement phase, roughly 73 times v119's recorded work on its earlier
games. Background search averaged 140.47 seconds per phase. These live-position
ratios describe work volume, not a hardware speedup or unique-plan count.

Mean scores were 0.1035 for v120 and 0.1724 for v117. The game-cluster
95 percent interval for the difference was [-0.1336, 0.0036]. Extra computation
did not establish stronger play. Only 24 background improvements were saved
across 22 of 470 playable phases. v117 remains champion. See the
[continuous-search report](nimified/runs/2026-10-18-continuous-scans/report.md).

All 70 pods completed, all 70 native archives verified, and all 4,834 Sol
attempts succeeded with matching native returns. Every playable active-unit
phase had an accepted Ready before its deadline. Three new-bot HTTP 400s were
recovered at the server's brief 1909 transition after the configured 1908 end.
Old-bot phase, post-game and response-echo races remain documented separately.
The ten-game model spend was $21.6697. Correctly enabled Fluffy profiling
measured 11 allocations across 17,426 evaluation spans; the earlier zero-count
measurement lacked its tracking flag and is explicitly corrected in the report.

The previous experimental candidate is **v119**, with Fluffy-guided allocation
and copy reductions, ten times the opponent samples, and up to ten independent
search starts. Three benchmark searches were 1.94 to 2.97 times faster at the
same workload, with 93 to 96 percent fewer allocations. Eleven additional
three-v119-versus-four-v117 games bring the comparison to 21 games, with
country coverage exactly balanced. Combined mean scores are 0.1236 for v119
and 0.1573 for v117. The game-cluster 95 percent interval for the difference
is [-0.0894, 0.0231], so no reliable gain is established. v117 remains champion.
v119 completed 866.4 million expanded-search simulations across the 21 games.
See the [additional games and combined report](nimified/runs/2026-10-18-more-scans-replication/report.md)
and [performance report](nimified/runs/2026-10-18-more-scans/report.md).

All 77 additional-game pods exited successfully and all 4,971 Sol attempts
succeeded. Every active-unit movement phase had an accepted Ready before its
deadline. The audit retains 47 recovered phase-transition HTTP 400s. One old
bot archive has a partial diagnostic tail at game-over shutdown and a final
pending read request; 76 archives are complete and every recorded payload
reference in all 77 verifies. Sixteen provider completions lack a logged
native return at shutdown. There were no unexpected runtime failures or
rejected saved orders. New-batch provider spend was $22.7533.

In the original ten-game batch, all 70 pods and full archives verified,
and all 4,776 Sol attempts
succeeded. Every active-unit movement phase had an accepted Ready command
before its deadline. The audit retains 54 recovered phase-transition HTTP
400s; there were no unexpected operational failures or rejected saved orders.
Four earlier v118 pilots are separate, including the zero-unit error fixed
and tested in v119.

The original port comparison used ten final-build games with three independent
Nim seats versus four Richard seats, with countries rotated. Nim averaged 0.1343 score and 4.70 centers per
seat versus Python’s 0.1493 and 4.975. All ten ended in end-year draws. The
comparison was inconclusive, not proof of equal strength. All 30 Nim pods
completed successfully, all 30 archives were verified, and all 2,093 model
attempts succeeded. Two recovered phase-transition HTTP 400s remain counted;
there were no unexpected operational failures or rejected saved orders.
Three earlier logging pilots are reported separately. See the
[port and comparison report](nimified/runs/2026-10-18/report.md).

The production policy, scans, search, tools and HTTP client run in Nim. The
external official Python SDK owns WebSocket lifecycle, and Richard’s Node
model bridge and prompt assets remain unchanged. The adjudication kernel
benchmark measured a 9.41 times speedup. No tactics or negotiation rules were
added. The full differential tests and actual-game replay checks matched.

Version 115 remains the unchanged Python copy and reference baseline, from
GitHub commit `d395ce1b34680704803aa5f04666b89cea6925f1`. All 78 source files
and 44 packaged runtime files were verified. Its upstream suite has 119
passing tests, one skip and two stale failures, retained unchanged. See the
[copy report](runs/2026-10-18-richard-copy/report.md) and frozen
[Python source](runs/2026-10-18-richard-copy/source/players/users/relh/co-gas/webdiplomacy-budget).
The sections below describe earlier versions and historical runs.

Earlier Kutuzov versions use a separate Nim policy for WebDiplomacy. An LLM chooses its orders,
negotiation, brief memory and whether further inference is worthwhile. Sol is
the preferred model, with Luna available for cheaper calls when needed.
The host fetches observations, bounds context and spending, and verifies saved
orders. It has no tactical search, scripted opening or search-only fallback.

Version 114 includes operational fixes from the
[v112 league audit](runs/2026-10-16-v112-league-audit/report.md): verified
Ready restoration in both interfaces, phase refreshes, clearer target repair
errors, and spend reports scoped to the current job attempt. It was uploaded
under Andre von Houck and tested once against Scott v15. Scott's France
finished first with 9 centers, ahead of Kutuzov's Austria with 8, in an
end-year draw. Kutuzov model calls succeeded 239/239 and required phases
reached timely verified Ready 86/86. All four final autumn plans used Luna
after budget denials. Scott's 68 logged LLM calls all failed with HTTP 403,
while its tactical search continued. The
[v114 check report](runs/2026-10-16-imitation-phase-10/game-001/report.md)
records the result, errors and strategic findings. It was not promoted.
See also the
[fixes and strategic findings](runs/2026-10-16-v112-league-audit/fixes.md).

Before v115, Andre von Houck's champion was v112, an unchanged copy of v110's published
image, launcher and runtime settings. Andre von Auto's league entries were
deactivated when the user switched players. The
[transfer verification](runs/2026-10-16-houck-v110/verification.json) records
the active Houck membership. Upload experimental candidates with the explicit
`--player=houck` option to `tools/auto_player.nim`; uploading does not promote
them. The resumed v111 continuation fix is tracked in
[phase 9](runs/2026-10-16-imitation-phase-9/experiment.md).
Its published candidate is v113,
`d58d553f-814d-4634-b6d6-a6576b4f7b04`, owned by Andre von Houck.
It adds exact-prefix Sol continuation pacing, observed warm-cost history,
explicit rejection reasons and exact order-type help. Host checks, all 8,568
request-fit cases, the Linux release suite and installed launcher verification
passed. Its single fixed-country comparison is recorded in
[phase 9 game 1](runs/2026-10-16-imitation-phase-9/game-001/deployment.json).
This candidate has not been submitted as the league champion.
The [completed v113 audit](runs/2026-10-16-imitation-phase-9/game-001/report.md)
verified all 28 warm prefixes and seven admissions enabled by the separate
estimate. Model HTTP calls succeeded 232/232 and required phases reached timely
Ready 87/87. Four review handoffs remain, including two before a Sol commit.
The game ended in an end-year draw with Kutuzov centers 1/5/3/4 versus Scott's
7/9/5. Model spend was $1.617275. The champion remains the v110 copy, v112.

The starting design follows Scott's published v5 notes: `gpt-6.1-sol`, low
reasoning effort and concise DAIDE negotiation. The exact model in Scott's
current champion v15 is opaque, so those published notes do not establish its
current configuration. Kutuzov can also read and write English. In autumn,
Sol can review whether changing one order would capture another center. The
final-year instructions prioritize centers held after autumn retreats,
including exposed allied centers when doing so improves the final result.

Version 106 embeds the user's five-page guide as
[strategy.txt](strategy.txt), joined to the native order and response contract
in [prompts.nim](prompts.nim). It preserves the guide's opening, negotiation,
tactical audit, endgame and turn checklist while removing links, reading lists
and unavailable references. Rules follow the hosted Classic implementation,
including configured scoring and end year, retreat restrictions and coasts.
The text is compiled into the stable prompt prefix for both models. It requires
no runtime file access or browsing. The compiled policy and complete request
size were verified before upload. Version 106 is
`b85ce236-bc23-4aeb-8252-5ab07c80c6cd`; its first same-country comparison with
Scott v15 is in [imitation phase 3](runs/2026-10-15-imitation-phase-3/experiment.md).
That [completed comparison](runs/2026-10-15-imitation-phase-3/report.md) lost:
England 1, Italy 4, Austria 3 and Russia 4 centers, versus France 9, Germany 6
and Turkey 7. It had 50 model HTTP 502s classified as provider transport errors.
Failure allowances exhausted England's pre-final budget. Italy's pod was deleted
before log collection, leaving its exact failure unknown. The guide was verified
in all 173 available request bodies, including one recovered Italian request.

Version 107 fixes request failures being treated as order repairs, keeps
public snapshot failures from terminating an active game, loads board/history
atomically, and logs allowlisted Softmax correlation headers. These changes
preserve uncertain costs and call caps; they do not claim to eliminate upstream
provider failures. Both recovery boundaries have permanent loopback regressions.
Verified movement decisions now own persistent strategic memory. Retreats and
builds preserve it, and observations include its originating phase. This keeps
diplomatic commitments from being replaced by a retreat summary while treating
the current board and dated press as authoritative.
The source, request-size fixtures and Linux image passed verification before
upload. Its evaluation is recorded in
[imitation phase 4](runs/2026-10-15-imitation-phase-4/experiment.md).
The uploaded version is `35b0f8a2-c567-4ed3-a0ef-bffbe9df6083`. Its one-game
same-country comparison with Scott v15 is XP request
`xreq_feb94c4c-b185-439f-8ea1-f77f66b40cab`. It completed at the 1908 limit:
England 4, Italy 5, Austria 1 and Russia 1 centers, versus France 4, Germany 9
and Turkey 10. Kutuzov did not qualify as a win. All four seats had verified
Sol reviews in every 1905–1907 movement and both final-year movements.
All 84 required phases saved accepted orders and marked Ready before deadline.
There was one upstream model HTTP 502, so the run was not error-free. The
platform recorded 19.25483675 credits of model and compute usage, above its
10.02088859-credit admission preview. Detailed audit findings are in the
[phase 4 report](runs/2026-10-15-imitation-phase-4/report.md).

The official player image owns the WebSocket lifecycle. Its Python launcher
starts `/opt/kutuzov`, passes the `WEBDIP_*` seat settings, archives press and
acknowledges game completion. The decision engine and HTTP clients are Nim.

The first hosted comparison, with four independent Kutuzov players and three
Scott players, was a loss: Kutuzov's best country finished with three centers
and Scott's best with 16. The [match report](runs/2026-10-15-four-v-three/report.md)
records the outcome, spending, caching and audit limitations.

The [v104 comparison](runs/2026-10-15-imitation-phase-1/report.md) also lost:
Kutuzov's best country had three centers and Scott's best had 14. Caching
improved to 74.95%, and all four detailed log archives were complete. The
audit found that conservative call reservations prevented all successful Sol
calls during 1905 through 1907, despite substantially lower measured spending.

## Build and check

The package requires Nim 2.2.4 or newer, `curly` and `jsony`. Docker uses the
checked-in `nimby.lock` to pin these libraries and their dependencies. The local
`nim.cfg` contains no machine-specific dependency paths. The repository's
existing Nim environment supplies them during local development.

From the repository root:

```sh
nim check --hints:off games/webdiplomacy/kutuzov/kutuzov.nim
nim r -f --hints:off games/webdiplomacy/kutuzov/tests/tests.nim
```

Force a rebuild after editing `strategy.txt`, because the guide is embedded at
compile time and an incremental Nim build can retain older `staticRead` text.
The Docker build uses a clean compilation and its verification checks the exact
compiled guide bytes.

An operator can build the image with:

```sh
games/webdiplomacy/kutuzov/build.sh
```

The build script only builds and prints the separate upload command. It does
not upload, submit or promote the policy. Follow the repository convention of
hosted XP before submission.

The printed upload command uses `tools/auto_player.nim` so the upload belongs
to Andre von Auto and its ownership is verified. It enables the hosted sidecar
with `--secret-env=COWORLD_LLM_ENABLED=true` and selects the main model with
`--secret-env=COWORLD_LLM_MODEL=openai/gpt-6.1-sol`. The current trial sets
`KUTUZOV_ECONOMY_MODEL=gpt-6-luna` for cheap openings and required fallbacks,
`KUTUZOV_RESERVE_USD=0.10`, `KUTUZOV_TOOL_LOOP=true`,
`KUTUZOV_MAX_PHASE_CALLS=12`, and `KUTUZOV_MAX_PRESS_CALLS=1` for the
published phase 8 version, v111. V110 uses the earlier four-call,
two-update interface. It sets `KUTUZOV_MAX_OUTPUT_TOKENS=3000`, matching
the cap observed in Scott's sample. Updates and reviews prefer Sol.
The league must allow the selected models. The legacy `--use-bedrock` upload
flag is incompatible with the current API: it sets the reserved `USE_BEDROCK`
key and is rejected with HTTP 422. Use the current `COWORLD_LLM_*` enablement
settings above.

The phase 8 tool loop lets the model request connections, refresh the board,
maintain explicit keyed notes, send press, commit a complete order set, and
finish a wake. A wake allows up to four model requests, with at most three
wakes per phase and one optional press wake. These ceilings do not override
spending or deadline limits. Notes survive until explicitly changed or deleted.
The new mode must be enabled explicitly; the legacy mode remains the default.
Its validation and bounded experiment plan are in
[phase 8](runs/2026-10-16-imitation-phase-8/experiment.md).
Version 111 is `b32c1006-bcc3-4d3d-a553-2f1c68e018db`. Its host checks,
request-size matrix, Linux release suite and installed-image verification
passed before upload. The user requested this latest version as Andre von
Auto's champion. Its historical submission and placement are recorded in
[champion verification](runs/2026-10-16-imitation-phase-8/champion/verification.json).
Its first hosted comparison completed at the 1908 cutoff. Kutuzov finished
with England 1, Italy 4, Austria 0 and Russia 1 centers, versus Scott's France
6, Germany 10 and Turkey 12. It did not qualify as a win. All 239 model calls
returned HTTP 200, all 90 required phases reached verified Ready on time,
and all four child processes exited zero. Model tool errors still occurred
and recovered. Seven review wakes switched from Sol to Luna mid-conversation
because of soft phase pacing; Austria's 1903 review exposed a resulting
proposal/order mismatch. Model charges totaled $1.62539414, with 21.7030114
credits of model and compute usage. Scott's external model calls failed with
HTTP 403, so this was not a healthy-model comparison. See the
[evaluation summary](runs/2026-10-16-imitation-phase-8/game-001/analysis-summary.json),
[operational audit](runs/2026-10-16-imitation-phase-8/game-001/operational-audit.md)
and [budget report](runs/2026-10-16-imitation-phase-8/game-001/budget-report.md).

The printed upload command and v105 observed-cost trial explicitly set
`KUTUZOV_BUDGET_MODE=empirical`. Omitting this setting selects the older
conservative admission mode. The trial's source and evaluation plan are recorded in
[imitation phase 2](runs/2026-10-15-imitation-phase-2/experiment.md).
The uploaded policy version is `eb845769-9279-42b0-913f-a4f4290a8fcb`.
Its [completed comparison](runs/2026-10-15-imitation-phase-2/report.md) restored
Sol activity during 1905–1907, with verified Sol reviews in 13 of 16 eligible
movement phases and no budget-default phases. Italy still lacked a verified
Sol review in 1905 because order repairs and phase pacing consumed that
opportunity. Kutuzov lost, finishing with only England on two centers.

The runtime base is pinned to the current official player image verified on
October 15, 2026:
`public.ecr.aws/q5f4m8t9/cogames@sha256:8b1779858fd1eb1c6394dad4a5e7c41131a1d9eec3a6c266e8a6bc7dbed8efd0`.
To use a freshly built official player image instead, pass
`--build-arg PLAYER_IMAGE=coworld-webdiplomacy-player:latest` to `docker build`.

The upload helper receives the complete launcher command after `--`, because
an explicit runner command replaces the inherited image entrypoint:

```text
/opt/.venv/bin/python -m players.launcher /opt/kutuzov
```

## Model connection and caching

On Coworld, `COWORLD_LLM_ENDPOINT` selects the hosted OpenAI-compatible proxy.
The client also accepts `AWS_ENDPOINT_URL_BEDROCK_RUNTIME` as its endpoint
fallback and normalizes the `/v1/chat/completions` suffix. The default hosted
model is `openai/gpt-6.1-sol`; a `COWORLD_LLM_MODEL` or `BEDROCK_MODEL` setting
can supply the hosted name. `KUTUZOV_MODEL` overrides either.

With no hosted endpoint, `OPENAI_API_KEY` selects the direct Responses API.
`OPENAI_BASE_URL` defaults to `https://api.openai.com/v1`. Direct requests use
explicit caching with a 30-minute lifetime and a breakpoint after the stable
instructions and map, plus breakpoints on selected user messages. Hosted
requests keep the same stable prefix for provider caching. Each phase starts
with the full observation and then appends model replies, verified host
actions and compact updates containing new press. The transcript is bounded
to 64 messages and the complete request to 60 KB by default. When it no longer
fits, the host restarts the transcript with the complete current board and
map, then trims older history and press as needed.

The prefix alone does not prove a cache hit. The `llm_call` log records
`cached_tokens`, `cache_reported`, `cache_write_tokens` and
`cache_write_reported`, using returned usage to measure actual caching.

Credentials remain environment variables. The host does not include them in
model observations or print them in diagnostics.

## Spend and context controls

The configured local ceiling defaults to $1.85, but the effective ceiling is
the lower of that setting and the live sidecar limit. The current hosted checks
reported a $0.50 per-player cap, so Scott's earlier $2 budget is not assumed.
The final-year reserve defaults to $0.30 and scales down to at most 30% of the
effective ceiling. With a $0.50 cap, that default becomes $0.15. The current
deployment trial explicitly lowers the reserve to $0.10 to give Sol more
budget for negotiations before the final year.

With the default `KUTUZOV_BUDGET_MODE=conservative`, the host synchronizes spend
before a model call and reserves a conservative
estimate including the allowed output tokens. Reported token usage replaces
that call's reservation. Missing usage retains the full reservation, and a
later lower sidecar meter does not remove that uncertainty. The local balance
can therefore exceed measured spend after transport failures. Unknown model
prices are rejected instead of silently using Sol's rates. Each final-spring
call can use at most half the then-remaining budget to leave room for autumn.
Final-autumn calls can use the remaining amount.

`KUTUZOV_BUDGET_MODE=empirical` instead uses observed call costs for admission
and divides available funds across the remaining movement phases. The cold
expected costs are $0.02 for Sol and $0.0015 for Luna; a request's reservation
is twice the larger of that prior and the model's largest observed cost.
Expected costs, smoothed after successful calls, determine phase pacing.
With exactly one known Sol cost sample, the pacing estimate is capped at
the $0.02 prior. Its actual charge, recorded mean and maximum remain intact;
after a second known sample, pacing uses the smoothed mean again.
Optional updates must leave room for the later Sol review. They use the
primary model only; when it cannot fit, the bot waits for review instead of
downgrading the update or immediately marking Ready. This also prevents a
post-review optional update from falling back to a cheaper model.

Empirical failures retain nonzero allowances separately from known spend,
including after restart. Neither an unchanged nor an advancing aggregate
meter clears those allowances. The stopping cushion is the largest of $0.05,
twice the largest observed call across either model, and the configured
pre-final year reserve. In the final autumn only, the minimum drops to $0.04,
including retreats; the observed maximum still applies. The year reserve
opens in the final year, while the stopping cushion remains.
These estimates can understate future charges and
do not guarantee that actual billing stays below the cap. Unresolved charges
may also be counted again in a later aggregate meter. See the
[governor notes](runs/2026-10-15-imitation-phase-1/empirical-governor-notes.md)
for the assumptions and tests. Changing modes while restoring the same saved
game is rejected.

The hosted sidecar exposes authoritative per-player episode spend through
`GET /spend`, relative to the proxy root rather than `/v1`. It returns
`spend_usd` and `spend_limit_usd`. Completion responses also report
`X-Coworld-Spend-Usd` and `X-Coworld-Spend-Limit-Usd` headers. Kutuzov reads both
sources. Direct API calls use local accounting because this sidecar endpoint
is unavailable there.

Press history is bounded per message, per opponent and in total. Duplicate
messages do not justify another model call. A talkative opponent cannot grow
the prompt or trigger unlimited replies. Outgoing press is capped at two
distinct messages per recipient per phase.

In conservative mode, `KUTUZOV_ECONOMY_MODEL=gpt-6-luna` uses Luna for initial plans before
the final year. Repairs, updates after new press, reviews and final-year
decisions prefer the main Sol model.
Before sending a paid request, the host checks whether the complete request
and output allowance fit the remaining budget. If Sol cannot fit, it tries
the configured economy model and then `gpt-6-luna`, including in the final
year. This selection logs an `economy_fallback` event and preserves the full
board and map. It does not spend money on an unaffordable Sol attempt.

The phase allows at most four model calls, including up to two updates after
new press and a reserved late review. Incoming press is batched until ten
seconds of quiet or twenty seconds since the batch began. Each update can
revise both orders and press; it is not a separate chat-only call.
`KUTUZOV_PRESS_MODEL` is retained for configuration compatibility but is not
used by the current engine. The printed upload command therefore omits it.
Both Sol and Luna use low reasoning effort.

Movement plans are saved without Ready while negotiation continues. The late
review normally starts with about 70 seconds left under the default model
timeout. Ready follows when at most 40 seconds remain, the call limit is
reached, or inference stops. A completed review alone does not immediately
mark Ready. Retreats and builds mark Ready after order verification. All
required countries being Ready lets the server advance before its deadline.
The [readiness analysis](runs/2026-10-15-imitation-phase-2/readiness-analysis.md)
quantifies the resulting delay in the completed v104 game.

Version 108 keeps empirical movement plans in 1901 on the configured
economy model or Luna. From 1902, plans prefer the primary Sol model when both
that call and a later review fit the expected phase cost and global request
allowance. If they do not fit, the required plan can still use the affordable
cheap fallback without the soft review hold. The host logs
`initial_review_unprotected` for that case. This preserves an affordable order
set; it does not guarantee a later Sol review. Final-year retreats prefer Sol
because they have no later review. Output stays capped at 3,000 tokens, with
at most four calls and two updates. The version is published, with evaluation in
[imitation phase 5](runs/2026-10-15-imitation-phase-5/experiment.md).
Its version UUID is `93424097-ab3d-4841-bfc8-d7a5d15bc2ef`. The single
same-country XP request is `xreq_0f7fea27-0bc7-409f-bfa0-c955729eace0`,
which finished at the 1908 limit. Kutuzov ended with England 2, Italy 6,
Austria 5 and Russia 1 centers, versus Scott's France 7, Germany 8 and Turkey 5.
It did not win. All 184 model calls and 10,628 logged HTTP exchanges succeeded.
All 88 required phases saved verified final orders and marked Ready on time.
All 24 late-game movements and eight final-year movements had verified Sol
reviews. Five attempted order sets were rewritten by the server, so successful
HTTP requests do not imply mistake-free play.
Model spend was $1.4985243 with an 81.14% cache-read share. Actual model and
compute usage was 20.135373 credits, versus the 10.22653971-credit preview.
Scott's external key reached its monthly limit in 1902. It had no successful
LLM calls afterward and continued with search, preventing a clean comparison
with its fully functioning policy. No second game was submitted. See the
[phase 5 report](runs/2026-10-15-imitation-phase-5/report.md).

Version 108 was submitted as Andre von Auto's webDiplomacy champion on
October 15, 2026 (Pacific time). Softmax confirmed the submission as placed
and its membership as competing with `is_champion: true`. The
[promotion verification](runs/2026-10-15-champion/verification.json) records
the exact version, owner, submission and membership.

Version 109 adds outgoing press quotas and delivery facts attached to the
verified movement decision that wrote memory. The model sees which drafts
were confirmed, skipped, unconfirmed or not attempted, including after a
phase change or restart. The two-attempt recipient limit, model routing,
spending rules and call limits are unchanged. Exact draft text stays in
saved state and logs. Only the model-facing copy may use an explicitly
marked UTF-8 excerpt to bound JSON expansion.

The local and Linux suites passed, as did 4,416 request-fit cases from all
184 v108 requests. See the [delivery review](runs/2026-10-15-imitation-phase-6/delivery-review.md),
[request-fit evidence](runs/2026-10-15-imitation-phase-6/request-fit-report.json)
and [build verification](runs/2026-10-15-imitation-phase-6/build-verification.json).
The published version is `14a3277b-41cf-46f8-a58f-d60e55d57632`.
One operational game was submitted to measure actual cost, late Sol coverage
and delivery-memory behavior: `xreq_98f874ce-65a8-4db0-a3f4-cc9bd0125f3c`.
It finished at the 1908 limit: England 0, Italy 3, Austria 9 and Russia 8,
versus France 12, Germany 2 and Turkey 0. Kutuzov did not clearly win.
All 153 model calls succeeded, and all 84 required phases saved verified
orders and marked Ready on time. Three game HTTP 400s and six order rewrites
recovered. Accepted Sol reviews covered 19 of 20 eligible 1905-1907 movements
and five of six final-year movements. All 151 confirmed messages match the
press archives, with no observed delivery-memory inconsistency.
Model spend was $1.382170530, with a 75.55% raw-input cache-hit share.
Actual model and compute usage was 16.438205300 credits, versus the
10.027568558-credit admission preview. Scott had no successful LLM calls:
all 65 attempts hit its external monthly key limit, while search continued.
This result cannot establish strength against fully working Scott. See the
[phase 6 report](runs/2026-10-15-imitation-phase-6/report.md).

At the user's request, version 109 replaced version 108 as Andre von Auto's
webDiplomacy champion on October 15, 2026 (Pacific time). Softmax confirmed
the submission as placed and the membership as competing with
`is_champion: true`. The [v109 promotion verification](runs/2026-10-15-champion-v109/verification.json)
records the exact owner, version, submission and membership. The operational
game was still running at promotion, so promotion does not establish its result.

Version 110 preserves one bounded, explicitly unverified failed order candidate
through conversation resets and caught-failure restarts. Current server slots,
the last fully verified orders and the rejected candidate remain distinct.
Actual order HTTP 400s retain bounded, redacted diagnostic text and can schedule
repair within the existing deadline and four-call cap. Transport errors and
Ready-only failures do not become proven order rejections.

It also adds the single-sample pacing cap and final-autumn stopping floor
described above. The host and Linux suites, five runtime repair scenarios and
7,956 request-fit cases passed. The exact compiled policy, guide and installed
launcher were verified in the published image. The guide itself is unchanged.
See the [phase 7 experiment](runs/2026-10-15-imitation-phase-7/experiment.md)
and [build verification](runs/2026-10-15-imitation-phase-7/build-verification.json).
The published v110 UUID is `d9d18a12-fb19-4ed6-be49-79af41195a81`.
Its same-country comparison, `xreq_3a46fd77-0e64-4a5f-91cd-d5268502aaec`,
finished in an official end-year draw: England 2, Italy 4, Austria 13 and
Russia 4, versus France 11, Germany 0 and Turkey 0. Austria's two-center lead
improves on v109's result but does not meet the working clear-win criterion.
Scott had no successful model calls, with all 59 attempts denied by its
external monthly key limit; its tactical search continued.

All 93 required Kutuzov phases saved verified orders and marked Ready on time.
There were no game HTTP errors. One model HTTP 502 recovered, and six of seven
server order rewrites received verified repairs. The remaining fourth-call
rewrite retained the previous verified orders. Accepted Sol reviews covered
24 of 24 eligible 1905-1907 movements and seven of eight final-year movements.
The [combined report](runs/2026-10-15-imitation-phase-7/game-001/report.md)
links the operational, tactical and financial audits. Known successful model
spend was $1.596481860, with a 74.18% raw-input cache-read fraction. Each seat
stayed below its $0.50 cap. Model cost per eligible movement was about 5.14%
higher than v109, so this result does not establish a cost reduction.
Its admission preview was 9.432080913 credits. The preview is an estimate,
not a total-cost cap; total actual credits remain unknown because the final
compute-credit query had no rows.

The unchanged v110 repeat, `xreq_f3f7842d-9cfc-47ef-b46e-ef710504f292`,
finished with England 0, Italy 3, Austria 8 and Russia 7 centers, versus
France 16, Germany 0 and Turkey 0. This result did not reproduce the first
game's lead. The final ledger records $1.585836 of model cost and 18.52165
credits of model and compute usage. Two Luna caller timeouts were later
provider-billed, so successful-response usage alone understates actual spend.
All final artifacts were collected and verified. See the
[repeat report](runs/2026-10-15-imitation-phase-7/game-002/report.md).
Both allowed games in phase 7 are complete and analyzed in the
[phase report](runs/2026-10-15-imitation-phase-7/report.md).

Version 110 was Andre von Auto's WebDiplomacy champion before v111. Softmax verified
the submission as placed and its membership as active, competing and
`is_champion: true`. That historical recheck confirmed v110 was then the latest
published Kutuzov version. See the
[v110 champion verification](runs/2026-10-15-champion-v110/recheck-current/verification.json).

The model can stop future inference with a concrete reason when further calls
cannot plausibly improve the result. Being behind or unable to reach an
18-center solo is not enough: the default scoring still rewards center share.
After inference stops or the budget is exhausted, future phases use engine
defaults. This is not a replacement tactical policy.

| Environment variable | Default | Purpose |
| --- | --- | --- |
| `KUTUZOV_MODEL` | `gpt-6.1-sol` or hosted equivalent | Main model. |
| `KUTUZOV_REASONING` | `low` | Reasoning effort. |
| `KUTUZOV_BUDGET_MODE` | `conservative` | Byte-based reservation or opt-in `empirical` observed-cost pacing. |
| `KUTUZOV_BUDGET_USD` | `1.85` | Local ceiling, at most `2.0`. |
| `KUTUZOV_RESERVE_USD` | `0.30` | Final-year reserve, at most 30% of the live cap. |
| `KUTUZOV_ECONOMY_MODEL` | Empty | Cheap opening plans and required-call fallback; empirical 1901 plans default to Luna. |
| `KUTUZOV_PRESS_MODEL` | Empty | Legacy setting, unused by the current engine. |
| `KUTUZOV_MAX_PHASE_CALLS` | `4` | Total model calls allowed per phase. |
| `KUTUZOV_MAX_PRESS_CALLS` | `2` | Updates allowed after new press per phase. |
| `KUTUZOV_MAX_OUTPUT_TOKENS` | `4096` | Output cap including reasoning. |
| `KUTUZOV_TIMEOUT_SECONDS` | `45` | Maximum model request duration. |
| `KUTUZOV_GAME_TIMEOUT_SECONDS` | `10` | Maximum game request duration. |
| `KUTUZOV_MAX_CONTEXT_BYTES` | `60000` | Complete serialized model request cap. |
| `KUTUZOV_MAX_PRESS_CHARACTERS` | `5000` | Combined incoming press cap. |
| `KUTUZOV_MAX_OPPONENT_CHARACTERS` | `800` | Incoming press cap per opponent. |
| `KUTUZOV_MAX_MESSAGE_CHARACTERS` | `400` | Incoming message cap. |
| `KUTUZOV_MAX_MESSAGES_PER_OPPONENT` | `2` | Recent messages retained per peer. |
| `KUTUZOV_STATE_PATH` | Temporary `kutuzov-state.json` | Atomic spend and phase journal. |
| `KUTUZOV_LOG_DIR` | Temporary `kutuzov/logs`; `/tmp/kutuzov/logs` in Docker | Durable redacted JSONL files; an empty value disables file output. |

If necessary, the host drops older adjudications and then older press until
the request fits. It preserves the full current board and order slots. Tool
mode supplies a stable map catalog and retrieves adjacency through connections;
legacy mode supplies the full map directly.

## Hosted evaluation

`tools/hosted.py` requires an explicit analysis phase for new games. Initialize
a phase with `--directory PHASE phase --max-games 2`; the accepted limit is
one through seven games. Prepare each game in a child directory such as
`PHASE/game-001`, passing `--analysis-phase-dir PHASE` and the uploaded policy
version UUID. Submission checks the phase cap under a lock. Repeating a
submission in its original directory reuses its idempotency key, and an
ambiguous earlier submission must be resolved before another game starts.
Analyze the phase's evidence before starting another phase.

After downloading a completed game's artifacts, run `tools/audit.py` for
log coverage, `tools/analyze.py --directory RUN` for results and operations,
and `tools/tactics.py --directory RUN` for public-order patterns. These
analysis commands are offline and do not launch games or call a model.
Transport errors with no HTTP status count as failed attempts. Missing
Saved/Ready samples are reported as sampling gaps, not assumed missed turns.

`tools/budget_forensics.py --directory RUN` joins complete model exchanges to
their tasks, years, costs, failure allowances and budget skips. It writes
`budget-analysis.json` and `budget-report.md`; use `--output-directory DIR`
to preserve an existing curated report. It supports both accounting modes
and reports missing log coverage as unknown rather than zero calls.

## Diagnostics

The v103 four-versus-three match retained only partial stdout tails. The v104
build addressed this with durable files under
`KUTUZOV_LOG_DIR=/tmp/kutuzov/logs` and compact summaries on stdout. All four
v104 archives were complete, with matching manifest hashes and uninterrupted
event sequences from process start through clean return. See the
[operational report](runs/2026-10-15-imitation-phase-1/game-001/operational-report.md).

`details.jsonl` retains redacted request and response payloads, while
`events.jsonl` retains compact events with omitted-payload hashes and byte
counts. Both include UTC timestamps, sequence numbers and process IDs. Each
append is flushed and closed. Correlated HTTP events include response status
and elapsed time. Identical polling bodies reference their earlier request.
Individual detailed payloads are bounded to 256 KiB with truncation markers.

The detail file is capped at 128 MiB and ends with an `artifact_body_limit`
marker when full; compact events and stdout continue. The compact file is
capped at 32 MiB and ends with `artifact_event_limit`; stdout continues after
that cap. The console records whether the detailed artifact entry was saved.

Events also cover phase transitions, model selection, context trimming,
budget reservations and synchronization, token and cache usage, parsed
decisions, order verification, press, retries and exits. Errors retain the
exception type, message and available stack trace. Known credential values,
credential fields, authorization text and absolute URLs are redacted. These
player logs still contain game observations, private press and model output.

The packaging hook makes the official launcher archive these files before its
game-over acknowledgement, alongside `private-press.json`. The ZIP adds
`logs/details.jsonl`, `logs/events.jsonl` and `logs/manifest.json`; the manifest
records source and archived byte counts, completeness, truncation and skipped
files. Archiving has separate size and time bounds, so the manifest is the
record of what was preserved. Focused ZIP tests pass locally and inside the
pinned Docker image, including interrupted completion, byte integrity and
size/time-limit behavior. The v104 hosted match also verified complete archives
for all four Kutuzov seats.

Version 106 also archives `logs/launcher-shutdown.json` after the launcher reaps
the child and before collection. It records the actual child return code or
signal, whether it was running before shutdown, the shutdown reason and the
separate launcher status. This distinguishes requested game-over termination
from a natural Nim return. Telemetry write failures do not change shutdown
control flow. Older archives without this record cannot establish the child
outcome from launcher exit zero alone.

The code and offline checks are a starting policy. Caching effectiveness,
turn latency, total spend and playing strength require hosted evaluation.

## References

- [Scott's policy and v5 notes](https://github.com/Metta-AI/coworld-webdiplomacy-policies-macromackie/tree/main/workspaces/pidip#how-v5-differs-from-stock-castlereagh).
- [Scott's overview slides](https://github.com/Metta-AI/agent-artifacts/blob/main/presentations/2026-10-14-diplomacy-game-of-the-week/preview.pdf).
- [Official player packaging and HTTP contract](https://github.com/Metta-AI/coworld-webdiplomacy/blob/main/docs/write-a-policy.md).
- [Official lifecycle protocol](https://github.com/Metta-AI/coworld-webdiplomacy/blob/main/docs/protocol.md).
- [OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching).
- [OpenAI pricing](https://developers.openai.com/api/docs/pricing), used for conservative Sol and Luna estimates on October 15, 2026.


### Replay statistics

For behavioral comparisons across completed games, run
`python3 tools/replaystats/run.py` from `nimified`, then open the printed
`BROWSER_URL` in Codex's built-in browser. Always include that browser step when
running stats. Existing report tabs refresh automatically on regeneration.
See `nimified/tools/replaystats/usage.md` for manifests, metric definitions,
coverage rules and checks. The current manifest keeps v121 and v122 separate
and compares each with the original panel's three top ranked policies.


### v123 matched live search test, October 19

Current Andre von Houck champion is kutuzov:v123, UUID
f849da00-3f0a-4500-8a1b-c37be0bb7b41. Seven matched country rotations averaged
0.153316 versus v121 0.147285 (+4.09% observed). Promoted under the user's
higher-score rule; read-back confirms active champion. This is not demonstrated
search improvement: 13 helper starts, eight interrupted by press, five complete
with baseline retained, zero applied changes. Native operational audit is clean:
444 Sol returns, 55,680 successful game HTTP requests, 106/106 timely Ready
phases, all 49 player pods completed. Own total model bill was $2.10447.

Report: nimified/runs/2026-10-19-additive-round/report.md. The replay statistics
runner now defaults to all 21 games across v121, v122 and v123 and keeps versions
separate. Show http://127.0.0.1:8767/ after running it.


### Local Richard integration port, October 22

Richard's active champion is still co-gas v4, which we already copied. The newer
GitHub directory is explicitly source-only and unvalidated. Its updated behavior
is now ported locally to Nim: coordinated hold/support pairs, exact private
proposal acceptance, one shared bounded extra wake, late reduced-mode review,
proposal tracking and commitment search traces. v123 remains the live champion.
No hosted games or uploads were started for this port.

Evidence and commands: nimified/runs/2026-10-22-richard-update/report.md.
Use that folder's candidate-environment.json for faithful comparisons and set
KUTUZOV_REFERENCE_BASELINE to its reference.json for the fresh Python oracle.
Disable the older Kutuzov continuous/guided/additive experiments and set both
sample multiplier and restarts to one. The new local source is unreleased.
