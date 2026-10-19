# Vanilla Wow — Bova Korolevich

Policy: **Bova Korolevich** (`bova`) — the adventuring knight of the romances.

Coworld: `cow_f395d354-34e9-4e60-9596-dedce3838d8f` (coworld name `vanilla-wow`)

Isolated Vanilla WoW episodes for 10x leveling, Kalimdor racing, RFC dungeon clears, and Arena 2v2, with one VMaNGOS backend per episode and independent leagues bound to explicit variants.

## Leagues

- `league_55a25b77-5fe5-4fc7-aa37-c1ece4756e18` — Arena Wow
- `league_0f38d762-930a-41d3-9979-1858dd52c1ae` — Race Wow
- `league_3d05f6f9-d812-4123-a69d-4da0ff3ad8b0` — Dungeon Wow
- `league_faf92aca-4edd-4591-923f-27b09af629bb` — 10x Wow

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `real-playerbot` — RealPlayerBot: Renderer-backed computer-use player. The canonical Observation combines semantic client truth with optional UI, scene, depth, and ground presentation; read-only navigation may guide input Actions through ordinary keyboard and mouse execution. The image keeps only the small UI atlas and streams render assets on demand. (run: `tini -- xvfb-run -a -s -screen 0 1500x980x24 vanilla-wow-player --controller=embedded --presentation=headless --bot=real-playerbot --skip-cinematic`)

## Local baseline

~/p/wow-walker* — our walker bots.

## Baseline

- Package default/example: `real-playerbot` — the full renderer-backed
  computer-use player image; the only example player, so also the strongest
  packaged baseline.
- Local baselines: `~/p/wow-walker` (and `wow-walker-v42-build`) is the
  strongest local family — full route stack (northern route, Stonetalon
  combat avoidance, Great Lift, ghost/death/stuck recovery) for the Race
  Wow league; `~/p/wow-walker-persistent-local` carries the strongest
  leveling controller (the andre-wow-walker line).
- Our policy: `bova/bova.nim` — the vendored andre-wow-walker:v82
  lineage, replacing the earlier thin session-connector stub. It builds
  the coworld-vanilla-wow reference player (canonical no-GUI semantic
  client + deterministic `kobold-apologist` leveling controller) from
  dependency branch `persistent-wow-e30`, commit `b8b551f28f` "avoid
  guessed quest returns". That exact build cleared the fresh-start
  promotion gate (all ten fresh epochs escaped the intro-quest loop,
  fought, looted, reached level two, mean score 2.95), so it is the base
  for the fresh-character leagues here (Race / 10x / Arena / Dungeon).
  The engine tree and every nimby.lock dependency are vendored under
  `bova/vendor/` at their locked commits (wololo included), so the
  Docker build is self-contained: no sibling checkout, no
  `--build-context`, no SSH mounts. `bova/vendor/` is shared by
  `games/persistent-wow/ruslan`. Vendored engine needs Nim 2.2.10 (the
  upstream pin) for `nim check`; 2.2.4's macOS posix stdlib miscompiles
  `signal`.
- Upload secret-envs: none (command player, no LLM seat; the league's
  game container owns the secret-backed replay/HMAC values).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Speak the `vanilla-wow-policy` WebSocket subprotocol instead of the
  native handoff: binary `vanilla_wow.control_wire` Observation/Action
  traffic would let a thin Nim policy act without the rendered client.
  First step: extract the control_wire schema from the game image or
  coworld-vanilla-wow sources.
- Implement a minimal realmd login over the handoff's `/tcp/realmd`
  WebSocket bridge (SRP6 auth, realm list) so the character actually
  enters the world; the vanilla 1.12 auth protocol is small compared to
  the world protocol and would unlock a real score.
- Add a minimal world-session walker: after realmd login, speak just
  enough of the 1.12 world protocol (auth session, player login, movement
  heartbeats) to hold-forward north — port `wow-walker`'s northern-route
  waypoint list (`src/northern_route.nim` + ghost routes) as the steering
  table for the Race Wow league.
- Use the handoff's navigation service (`vanilla_wow.navmesh_http.v1`
  path) to request `status`/`route`/`local_graph` evidence each window and
  publish it in `session_state.detail` for replay debugging.
- Report a richer `session_state` phase machine (starting → world_ready →
  recovering) driven by realmd/world bridge connectivity probes so the
  dash distinguishes connector health from world progress.
- Vendor a trimmed headless build of the wow-walker client behind a
  dedicated Dockerfile build-context (the walker's own image recipe) as a
  second image variant, keeping bova's repo-root build as the fallback.

## Disqualification diagnosis (worker)

bova:v2 (and v1) is **disqualified** in Race Wow, 10x Wow, and Dungeon Wow, and **competing** in Arena Wow. Same image and CMD (`--scenario=coworld-session --bot=kobold-apologist`). All four submissions have `preferences: null`.

### Evidence

Memberships (2026-09-01): Race `lpm_5c56e23e` / 10x `lpm_15ad1783` / Dungeon `lpm_7e820146` = `disqualified`; Arena `lpm_cbbdc828` = `competing` (champion). Submissions `sub_b11bc5b5` (Race), `sub_4aeb7b88` (10x), `sub_25f329a5` (Dungeon), `sub_0873a5be` (Arena). `GET /v2/episode-requests` is 405; episodes came from `GET /v2/rounds/{id}/episodes`.

| League | Episode | Error type | Error / log line |
|--------|---------|------------|------------------|
| Race v2 | `ereq_fbd145c8-b23e-4aac-ae0f-da9e46b02324` (round_707a8fa0, Kalimdor Race 10x Time) | `player_error` | `Player slot 0 failed before completing its session: player did not connect before the configured startup deadline` |
| 10x v2 | `ereq_4fdc5b7e-09ab-471f-87b3-46f8fd2abf49` (round_7725113a) | `player_error` | same "did not connect" line. `player-status`: slot 0 `exited` `exit_code=1` at 00:57:14Z (~44s after `running_at` 00:56:30Z) |
| Dungeon v2 | `ereq_d883bb6d-fb34-4119-a3ad-a3e209210e77` (round_f6917137) | `player_error` | `Player pod job-041f33b4-game-player-0 for slot 0 terminated with exit code 1: Error` (all 4 clone seats exit 1 at ~00:54:20Z, ~42s after running) |
| Dungeon v2 | `ereq_365c59ae-2f70-4fcb-8613-252ce43e3b3c` (round_f76ee875) | `player_error` | `native Nim player failed: IOError: native process exited with code 1` |
| Arena v2 | many, e.g. `ereq_83ee1158-07be-4706-ab4a-63711f54aa25` | `results_missing` | `Game container exited before writing results.json` — **game-side**, not counted as bova consecutive player failures. When a player_error appears (`ereq_a6eff8e2`) it is Alliance slots 2–3; Horde slots 0–1 (bova) stay `running`. |

Race `player_startup_deadline` = 270s (`max_ticks/tick_rate`); 10x = 720s. Game log for the Race ereq is only the startup-deadline sentence (no agent log: 403 on policy-artifacts).

v1 Race/10x earlier rounds failed `replay_missing` (game container died before `/coworld/replay`); once the game stayed up, they hit the same v2 player_error.

### Root cause

Not missing `--race/--character-class/--gender` as the primary DQ (Race and Dungeon seed characters in `game_config`; Arena also has `preferences: null` and qualifies). `vanilla-wow submit` requires those flags only for 10x/persistent.

`--scenario=coworld-session` (`coworld_session_runtime.nim`) opens `/player` then **waits 30s** for `wow_session`. The game accepts the WS, then blocks on VMaNGOS ready before sending the handoff (`run_vmangos_session_player`). Race/10x/Dungeon VMaNGOS is not ready in 30s → adapter throws → pod exit 1 → runner reports "did not connect" at `player_startup_deadline`. Arena's backend is ready inside 30s, so the walker completes handshake and stays competing.

Secondary 10x landmine after a successful handoff: empty `character_name` and no `character_creation` (prefs were null) would `select-existing` on a fresh account and fail closed.

Secondary Dungeon: when handshake *does* complete, the spawned `--scenario=player` child still exits 1 (`ereq_365c59ae`). Kobold Apologist raises if `VANILLA_WOW_RFC_ASSIGNMENT` is set; the adapter keeps that env deleted. Child still has to log into the RFC-seeded name.

CMD is correct for all four leagues. Session extensions on this adapter were `navigation,simulation_time_scale` only; the current player runtime also advertises `party_role,rfc_party,kalimdor_traversal` so those fields appear on `wow_session`.

### Fix (code in bova, implemented)

In `bova/vendor/coworld/player/reference_player/coworld_session_runtime.nim`:

1. Wait **1200s** for the first `wow_session` (VMaNGOS ready timeout), not 30s.
2. Advertise `party_role,rfc_party,kalimdor_traversal` and stash kalimdor goal on `COWORLD_NATIVE_PLAYER_SESSION`.
3. If the handoff has no character name and no `character_creation`, create default troll/shaman/male `Botbot` (10x with null prefs).
4. Pass `--character-name=` into the child for pre-seeded Race/RFC/Arena names.

Rebuild/upload/submit is supervisor-side. Do **not** docker-build here unless verifying the Nim change (`nim check` below).

### Submit-time prefs (optional, 10x only — supervisor)

Code now defaults 10x creation. To pin identity instead of Botbot:

```bash
uv --project /Users/me/p/metta run coworld submit bova -l league_faf92aca-4edd-4591-923f-27b09af629bb \
  --preference initial_character_race=troll \
  --preference initial_character_class=shaman \
  --preference initial_character_gender=male \
  --no-open-browser
```

Race and Dungeon do not need those keys (seeded characters / RFC profiles). RFC tank/healer/dps prefs are optional; the variant already defaults `botwartank` / `botpriheal` / `botmagedps`.

After rebuilding the image with the timeout fix:

```bash
uv --project /Users/me/p/metta run coworld submit bova -l league_0f38d762-930a-41d3-9979-1858dd52c1ae --no-open-browser
uv --project /Users/me/p/metta run coworld submit bova -l league_faf92aca-4edd-4591-923f-27b09af629bb --preference initial_character_race=troll --preference initial_character_class=shaman --preference initial_character_gender=male --no-open-browser
uv --project /Users/me/p/metta run coworld submit bova -l league_3d05f6f9-d812-4123-a69d-4da0ff3ad8b0 --no-open-browser
```

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
