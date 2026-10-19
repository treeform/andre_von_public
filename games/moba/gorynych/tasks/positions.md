Deepen leader replay analysis in games/moba/gorynych/research only.
Your existing action-direction evidence cannot prove actual trajectories.
Write a Nim extractor that replays recorded actions through the EXACT
pinned sim and extracts positions/health, skill activations and tower
proximity. This is reconstruction of hosted games, never local scoring.
Use existing whisky Nim wasm runtime (/Users/me/p/whisky if present,
or repo dependency paths) and read sims/moba/server/cogame_moba wasm
initialization/replay and sim exports. Do not author Python, JS, C or bash.
Existing engine artifacts and libraries can be invoked from Nim.
Replay files research/evidence/replays already contain seeds, configs,
sim_wasm_sha256 and all 10 heroes' actions. Match recorded final ticks
and result before trusting reconstructed positions. If exact reconstruction
is blocked, report that honestly and do not infer real positions from
direction votes. Bound work to useful proof first, e.g. one daveey-vs-richard
game. Then quantify opening lane concentration, tower deaths, tower-target
exposure/cover and actual assassin E activations. Produce trajectories.md
with concrete observations and one-change policy ideas. No scoring local
games, no uploads/submissions. Nim checks/test for extractor only. Preserve
other workers' files and don't commit. Work independently while XP runs.
