# Flatland — Konyok-Gorbunok

Policy: **Konyok-Gorbunok** (`gorbunok`) — the magic horse — transport.

Coworld: `cow_f29f97b1-da55-4662-8dbc-cefde73f528d` (coworld name `flatland`)

A 28x14 rail network with switches, sidings and a flat crossing. Twenty-four trains, each with a start platform, a target station, a speed class and a random breakdown clock. Four dispatchers command six trains each. A cell holds one train, so nothing ever collides - every would-be collision is a block, and a block that goes round in a circle is a deadlock, which on rails is permanent. The only number the league reads is how many of the twenty-four trains reached their station ON TIME, and everybody gets the same number.

## Leagues

- `league_b8ffbdda-2f8f-45af-b905-e600ba385cff` — Flatland

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `timetable` — Timetable: Pure greed, no yielding: release every train as early as possible and run it. The control that answers "did the LLM actually coordinate?". (run: `/bin/flatland-player`)
- `yielder` — Yielder: Stagger departures, side the lower-priority train of a stalled pair, and never enter a single-track section against oncoming traffic. Also the server-side fallback when an LLM seat misses its call. (run: `/bin/flatland-player`)

## Baseline

- Default/control example: `timetable` (pure greed, no yielding — the "did
  the LLM coordinate?" control). Strongest example: `yielder` (staggered
  departures, lower-id tie-break siding, never enters a single-track
  section against oncoming traffic); it is also the server-side fallback
  whenever an LLM seat misses its call, so `yielder` is the floor any
  submission must beat.
- Our policy `gorbunok/` (Konyok-Gorbunok) is a thin Sprite v1 registrar.
  **Default is scripted `yielder`** (the published example, the server
  fallback, and the mixed-table yield convention). Registration is
  `{"type":"register","policy","prompt","scripted"}` over a 0x81 chat
  frame (re-sent over the first ~10 s of frames), then Ready (0x85).
  The server sets `isLlm` from `prompt.len > 0` and skips any blob whose
  `type` is not `"register"`. Empty `PLAYER_SCRIPTED` restores the
  operator prompt (deadlock avoidance, two-turn-early sidings, radio
  claims). Env still overrides (`yielder` | `timetable` | empty).
- Upload secret-envs: none for the yielder default. The anthropic key is
  injected into the GAME pod (`secret://coworld/flatland/anthropic_api_key`);
  the player pod makes no LLM call. LLM override uses that game-pod key.
- Protocol confidence: registration keys and the re-send window are
  documented verbatim in PROTOCOL.md. The 0x81 chat framing (u16le length
  + ASCII payload) and the 0x85 Ready acknowledgement are inherited from
  the bitworld sprite protocol via coworld-ctf ("inherited from
  coworld-ctf unchanged in shape") — the same framing our atari-cabinet
  and cogball seats use — but flatland's doc does not spell the bytes out,
  so verify a hosted XP request seats us as `scripted` (results.policyKinds)
  with `deadSeats` false before submitting.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Verify seating first: one hosted XP request, then check
  `results.policyKinds` shows `llm` for our seat and `llmTurns` ≈ 31 —
  the cheap protocol-confidence gate before any tuning.
- Prompt the seat to publish a full release plan on turn 1 (all six
  trains, staggered 1-2 turns apart, worst conflicts first) and stick to
  it barring jams — pre-commitment beats per-turn improvisation when the
  radio is only heard one turn later.
- Encode the yielder tie-break verbatim in the prompt ("of an opposing
  pair, the higher global train id sides, the lower runs") vs the current
  softer phrasing; measure fleetOnTime across cross-play fields.
- Fixed radio grammar ("CLAIM J4-J5 T13 EB", "YIELD T09 S2", "FREE J4"),
  so two Gorbunok seats in the same episode parse each other reliably;
  the 120-rune cap fits ~3 claims.
- Add explicit slack arithmetic to the prompt: scheduled_arrival includes
  24 ticks of slack and a siding wait costs ~16-32 ticks, so one yield is
  usually still on time — push the model to yield more readily.
- Malfunction-aware releases: prompt to hold a waiting train whose first
  two sections contain a malfunctioning train (malfunction_left > ticks
  to reach it) instead of departing into a queue.
- Control run: submit the same container with PLAYER_SCRIPTED=yielder as
  a second entry once, to measure the LLM's true lift over the fallback
  in league conditions.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field built-in `yielder` as a live registered seat. We are 5/5 (rating 787.1). Server `readRegistrations` skips any blob whose `type` is not `"register"` (`src/flatland/server.nim`); our blob omitted it, so we never registered, `deadSeats` was set, and the fleet was dispatched by yielder only as the disconnected fallback. `isLlm = prompt.len > 0`, so a non-empty prompt would ignore a named baseline. Yielder is the sweep-tuned published default (`yieldAfter=12`, `lowerIdYields=false` — the LOWER id sides; our prompt had this backwards) and the mixed-table convention. Score is 1000*fleetOnTime (shared); a yield-convention mismatch deadlocks the network. | add `"type":"register"`, default PLAYER_SCRIPTED to `yielder`, send empty prompt while a baseline is named (env still overrides) | | | |
