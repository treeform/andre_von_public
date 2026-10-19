# Heartleaf — Alyonushka

Policy: **Alyonushka** (`alyonushka`) — the gentle village sister.

Coworld: `cow_78096b95-a6f2-4371-b1d2-d8a7195cdc66` (coworld name `heartleaf`)

A cozy BitWorld garden dinner game where players grow food, collect vegetables, and gather in the evening. Every gnome is played by the game itself from the soul file its player uploads.

## Leagues

- `league_f831ba75-e81b-4796-b8c6-cd10be18c0bf` — Heartleaf

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `shy_villager` — Shy Villager: Shy Heartleaf gnome soul that gathers quietly, speaks softly, and honors party invitations. (run: `/bin/soul_player`)
- `chatty_villager` — Chatty Villager: Chatty Heartleaf gnome soul that greets everyone, talks constantly, and spreads party invitations. (run: `/bin/soul_player`)
- `friendly_villager` — Friendly Villager: Friendly Heartleaf gnome soul that welcomes everyone, shares food, and hosts warm dinners. (run: `/bin/soul_player`)
- `fatherly_villager` — Fatherly Villager: Fatherly Heartleaf gnome soul that checks on others, shares food, and makes sure nobody dines alone. (run: `/bin/soul_player`)

## Local baseline

~/p/coolbot — our scripted host/guest banquet bot, v10 champion (stronger than the soul_player villagers).

## Baseline

Heartleaf players are soul files: since 0.2.0 the game pod plays every
gnome from the uploaded `soul.md` (line 1 is `#!<bedrock model id>`, the
rest is the system prompt) and runs the LLM harness itself. The player
container is only a thin uploader over the `/player` text-frame protocol
(soul → `soul accepted` → `log-ready` → model-log stream).

- Default examples: the four `soul_player` villagers (shy / chatty /
  friendly / fatherly). Certification fields all four with a mock reply.
- Strongest known baseline: our ~/p/coolbot soul (v10 was league
  champion) — jolly host-in-chief on
  `us.anthropic.claude-haiku-4-5-20251001-v1:0`: gather hard all
  morning, pitch dinner at your own house by name with two real foods,
  lock a yes before mid-afternoon, guest for unseen foods on thin days,
  never repeat a line.
- Our policy: `alyonushka/` — Nim port of the shared soul_player
  (whisky websocket, validate + upload + log-cursor resume) carrying the
  coolbot champion soul plus the 8-food host gate, embedded via
  `staticRead` and overridable with `HEARTLEAF_SOUL_PATH`.
- Upload secret-envs: pass `--use-bedrock` on upload. Historically the
  bot quit and failed the round without it; since 0.2.0 the game pod
  holds the Bedrock sidecar so coolbot's README calls it unnecessary,
  but it is harmless — keep it (see `alyonushka/build.sh`).
- Scoring (pinned 0.2.3 `ca56ea8c`): host score = pantry size x visitors
  at 6pm dinner, plus eating (+3 per never-eaten food type, +1 leftovers,
  3 bites each); guests only eat. HostPantryMinimum is 8. Curfew still
  applies: -3 if not inside your own house at 9pm (master docs dropped
  it; the league image has not). League variant: 7 days, ~22 minutes,
  fresh seed per episode, 9 seats.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Model swap: shebang to `us.anthropic.claude-sonnet-4-6` (then maybe
  `us.anthropic.claude-fable-5`) — better negotiation and line variety
  for the same soul; the platform pays the LLM cost either way.
- Always set `commitParty` + `untilTime` on the host path too (guest
  commit is already in the 8-food gate): the sim keeps the promise if
  the model cannot be asked at departure time.
- Curfew home: pinned 0.2.3 still subtracts CurfewPenalty=3 if not inside
  your own house at 9pm. Soul is silent; MechanicsBlock already says go
  home after dinner. If logs show we eat the -3, add an explicit 9pm
  go_home line.
- Eating-variety hunt: track "Food looking for" explicitly — instruct
  the gnome to name-check missing food types when picking a table
  (+3 per unseen type vs +1 leftovers is a 3x eating swing).
- Replay/log extractor in `tools/`: parse the streamed model log and
  round replays for dinner attendance, host pantry size at 6pm, and
  per-line repetition of the top players; copy what the leaders do.
- Guest-poaching counter-pitch tuning: the soul already fights for
  guests; try an explicit rule to re-pitch every gnome seen heading to
  a rival's crowd after 5pm (visible house crowds are in the state
  report).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | numeric 8-food + confirmed-yes host gate | soul.md: host only with >=8 foods AND a yes (host_score = pantry x visitors, sim HostPantryMinimum=8); else commit as guest. Replaces "always host / fat enough", which contradicted the pinned MechanicsBlock and emptied thin pantries for tiny host scores. | | | |
