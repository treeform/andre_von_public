# Persistent Wow — Ruslan

Policy: **Ruslan** (`ruslan`) — the questing knight.

Coworld: `cow_0304eb71-612e-4299-8008-6ee80759ae3a` (coworld name `persistent-wow`)

Ongoing Vanilla WoW leveling on a durable external realm, using a thin connector game runtime and commissioner-recorded ten-minute windows.

## Leagues

- `league_778f16b8-1247-488e-a993-b48d6928b137` — Persistent Wow

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `persistent-certification-player` — Persistent Certification Player: Lightweight connector-certification player. It validates the persistent session WebSocket contract and exits without starting the full WoW client. (run: `python -c import asyncio, json, os
from urllib.parse import parse_qs, urlparse
import websockets
async def main():
    url = os.environ['COWORLD_PLAYER_WS_URL']
    query = parse_qs(urlparse(url).query)
    slot = int(query.get('slot', ['0'])[0])
    async with websockets.connect(url) as websocket:
        message = json.loads(await websocket.recv())
        payload = {
            'protocol': message['protocol'],
            'type': 'done',
            'slot': slot,
            'success': True,
            'detail': 'persistent connector certification',
        }
        await websocket.send(json.dumps(payload))
        await websocket.recv()
asyncio.run(main())`)

## Local baseline

~/p/wow-walker-persistent* — our persistent-world walker bots.

## Baseline

- Package default/example: `persistent-certification-player` — a thin
  Python connector that receives the session hello, echoes its `protocol`
  literal in a `done` reply, and exits. It only certifies the wire
  contract; the strongest real player is the repository RealPlayerBot
  image documented in `docs/participation/persistent-leveling.md`.
- Local baselines: `~/p/wow-walker-persistent` (and
  `wow-walker-persistent-local`) — the persistent-realm walker variants;
  persistent-local is the repo that produced the submitted
  andre-wow-walker line.
- Our policy: `ruslan/ruslan.nim` — the vendored andre-wow-walker:v82,
  the exact submitted Persistent Wow champion lineage
  (`sub_b9ce70c8-48ac-4249-b14a-7e657748cded`, membership promoted over
  v23), replacing the earlier thin session-connector stub. It builds the
  coworld-vanilla-wow reference player (canonical no-GUI semantic client
  + deterministic `kobold-apologist` leveling controller) from
  dependency branch `persistent-wow-e30`, commit `b8b551f28f` "avoid
  guessed quest returns"; the v82 promotion gate showed +1258.7 XP and
  +1.95 score over v23 across ten epochs. The engine tree and every
  nimby.lock dependency are vendored ONCE under
  `games/vanilla-wow/bova/vendor/` at their locked commits (wololo
  included) and shared by both wow policies — ruslan's Dockerfile COPYs
  that tree from the repo root, so the build is self-contained: no
  sibling checkout, no `--build-context`, no SSH mounts. Vendored engine
  needs Nim 2.2.10 (the upstream pin) for `nim check`; 2.2.4's macOS
  posix stdlib miscompiles `signal`.
- Submission note: a first submit must include the initial character
  preference (`--race/--character-class/--gender`); replacement preserves
  the durable account and characters.
- Upload secret-envs: none (command player, no LLM seat).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Implement realmd login over the handoff's `/tcp/realmd` WebSocket
  bridge (vanilla 1.12 SRP6) so Ruslan can verify the durable account and
  enumerate characters, reporting them in `session_state.detail`.
- Add a minimal world-session leveler: enough of the 1.12 world protocol
  to log the leading character in, accept XP from resting/kill credit,
  and grind a safe starter-zone loop; persistent score is level +
  fractional XP of the leading character over the last three windows.
- Speak the `vanilla-wow-policy` subprotocol (binary
  `vanilla_wow.control_wire`) if the persistent runtime honors it — a
  typed Observation/Action loop beats hand-rolled world packets.
- Persist process-local controller memory across replacements via the
  periodic player artifact upload slot (the rendered client checkpoints
  one artifact every 60 s) so learned places survive a restart.
- Use the navigation service (`vanilla_wow.navmesh_http.v1`) `route`
  requests to plan grind loops between rested XP hotspots instead of
  fixed waypoints.
- Reuse `wow-walker-persistent`'s Xvfb session wrapper (`src/sessions.nim`)
  to host the full rendered walker in a dedicated image variant built
  from the sibling checkout, keeping ruslan's repo-root build as the
  certified fallback.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
