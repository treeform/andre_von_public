# Vasilisa — Paintbot Season 2 play-seat policy (Nim)

Season 2 (`battle-royale-s2`, coworld cow_f5c2437d, engine coworld-ctf) is
not the Season 1 sprite-protocol game morevna played. A seat is a PLAY seat:
input masks are ignored. The policy uploads WebAssembly play modules
(0xA0), sends an ordered ladder of play calls as canonical JSON (0xA1), acks
statuses (0xA2), may chat in the 600-tick lobby (0xA3), and reads a fogged
PlayView every 6 ticks (0xB1). The engine steps the plays in-process.

- `vasilisa.nim` — wire codec (byte goldens from coworld-ctf
  tests/fixtures/shell/packets pass under `-d:vasilisaTest`), canonical JSON,
  seat loop, and a scripted play-caller: target_law prefer weakened/isolated,
  supply_run when wounded with a medkit in view, loot when clear, scatter for
  the first 300 ticks, edge_ride margin 340 as the base (the cautious starter
  richard runs, which sits 6th).
- `playbook/*.wasm` — the engine's reference plays, built from
  coworld-ctf `play_sdk/reference` with wasi-sdk 33 inside Docker
  (`docker build --target playbook -f policies/starters/cautious/Dockerfile`
  in the coworld-ctf checkout, then `docker cp`). Rebuild when the SDK moves.
- `Dockerfile` / `build.sh` — nimby Nim 2.2.4 + whisky, debian-slim runtime.

Self-test: `nim c -d:vasilisaTest --path:$HOME/p/whisky/src -r vasilisa.nim`.
