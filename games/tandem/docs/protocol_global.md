GET /global (websocket) is the spectator snapshot: the same
Sprite v1 binary stream as a seat's, with no self markers, plus the broadcast
chrome channel -- a reserved never-drawn 1x1 sprite (id 4090) whose LABEL
carries the chrome JSON frame (tick, phase, transport state, condition,
progress, doors cleared, both carriers' strain/grip/blame, the roster with REAL
policy names, the derived beat events, the whole-run condition curve and the
end-card state).

GET /healthz answers `healthy`. GET /client/global, GET /client/player and
GET /client/replay serve real HTML pages and none of them opens the player
socket. GET /replay-data returns the raw `.replay` bytes. /healthz and /global
keep answering for a bounded ~20 s after the artifacts are written.

REPLAYS ARE A STATIC WASM BUNDLE, NEVER A POD. The repo ships
tools/build_replay_viewer.sh, which compiles the SAME src/tandem/sim.nim and
src/tandem/control.nim to wasm32 through emscripten and bundles them with the
chrome; the manifest declares "replay_viewer": {"bundle":
"static-replay-viewer"}. The browser re-simulates every tick from the recorded
orders and checks its own gameHash against the recorded chain, so everything the
viewer needs is in the replay bytes and no server is contacted except S3 for the
file.