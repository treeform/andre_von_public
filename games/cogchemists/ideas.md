# Cogchemists — Vasilisa Premudraya

Policy: **Vasilisa Premudraya** (`vasilisa`) — the wise — deduction.

Coworld: `cow_a9d9a26c-cf74-403a-85f9-542ca3bd61c9` (coworld name `cogchemists`)

Cogchemists: eight ingredients, a hidden chemistry, and a career built on publishing first. Four LLM-piloted cogs share one laboratory for six rounds. Behind the game sits a secret bijection from the eight ingredients (Nightcap, Emberroot, Fen Lily, Widow's Salt, Copper Fern, Gravebloom, Sunmoss, Rime Thistle) to the eight alchemical SIGNATURES - triples of signs over RED, GREEN and BLUE, written R+G-B+. Mixing two ingredients yields a potion that leaks exactly one constraint about that bijection: if the two signatures disagree on exactly one aspect the potion takes that colour and its sign is the product of the two aspects they agree on; otherwise it is MUD. Each round has two simultaneous-decision phases. In LAB a seat forages, tests a pair on a paid student (result private), drinks it itself (the sign class becomes public and a negative potion poisons you), transmutes a card for coin, or passes. In MARKET it sells a potion to an adventurer who named a specific result, PUBLISHES a wax-sealed theory about one ingredient for immediate reputation and royalties, endorses a rival's seal, DEBUNKS one by public demonstration - which burns the seal only if the attacker brought a reagent that exposes it, and costs the attacker reputation if it does not - buys an artifact, or passes. After the last round the exhibition opens every standing seal against the truth: true pays the author +5 reputation, false costs -6. SCORE = reputation + 0.2 x coin, higher is better, and it may be negative. The ingredients a seat burns are public and its results are not, so every seat sees a different world; the replay shows all four private deduction grids like a hole-cam, so spectators can see who actually knows and who is bluffing. The game is LLM-driven: every phase the server sends each seat's policy prompt plus its hand, the board, the public record and its exact deduction grid to Claude as ONE parallel batch, so A POLICY IS JUST A PROMPT - build one by reusing the published cogchemists-player runnable with PLAYER_PROMPT set to your strategy. Two scripted baselines (assayer, quack) play any seat that registers as scripted, and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_7a7ba378-a709-4b1a-b8c1-b21b6577025a` — Cogchemists

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `cogchemists-player` — Cogchemists Prompt Player: The reference Cogchemists policy: delivers its PLAYER_PROMPT (or a default alchemy strategy in words) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/cogchemists-player`)
- `cogchemists-assayer` — Cogchemists Assayer Baseline: The scripted competent scientist as a fieldable policy: picks the experiment whose worst case leaves the fewest chemistries standing, publishes only ingredients its grid has SOLVED, and attacks a rival's seal only with a reagent whose demonstration must expose it. The game server plays it deterministically, no LLM involved. (run: `/bin/cogchemists-player`)
- `cogchemists-quack` — Cogchemists Quack Baseline: The scripted reckless careerist: drinks whatever is in its hand and publishes the lowest candidate for the lowest unclaimed ingredient the moment it has a coin. Certainty be damned; it reliably finishes last, and it is what the game is a satire of. (run: `/bin/cogchemists-player`)

## Baseline

`cogchemists-assayer` (scripted competent scientist) is the strongest
example and the fallback for any failed LLM decision; `cogchemists-quack`
reliably finishes last. The default `cogchemists-player` is a prompt
seat. Our policy `vasilisa` sends the standard
`{"type":"prompt","prompt","scripted"}` hello on connect and after
welcome, then spectates to `final`. The prompt is assayer-plus:
worst-case-minimizing tests, publish only SOLVED grid entries (beat the
13.2 pass floor), sell only known demand matches, debunk/endorse only on
grid-proof certainty. PLAYER_PROMPT / PLAYER_SCRIPTED override. Upload
needs `--secret-env USE_BEDROCK=true` or the seat silently plays
scripted assayer.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Royalty race: force a round-0 publish path (test_student round 0 lab,
  publish the moment anything is SOLVED) and measure vs the current
  patient prompt — the worked landmark scores 22.2 mostly on royalties.
- Debunk-hunter variant: explicitly target seats that publish in rounds
  0-1 with zero tests burned; quantify +3 burn income vs -2 misfires.
- Printing Press economics: always-buy-press-by-round-2 vs never-buy;
  royalties double and publish pays +3, but -5 coin is a full point.
- test_self-only information diet: never pay the student coin, accept
  the sign-class leak; does the saved coin beat the leaked evidence?
- Endorse farming: endorse every seal the grid proves true, not just
  opportunistically — each is +2 at exhibition for -1 coin.
- Demand-aware selling: hold a known coloured pair in hand until the
  round whose demand matches instead of selling immediately.
- Note discipline: structure notes as a fact ledger (pairs burned per
  rival, sign leaks seen) and test whether the grid narration in notes
  reduces bad publishes.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | round-0 test, not forage (royalty race) | prompt: forage only at hand < 2 (was < 4). StartHand is 3 and a test needs 2, so the old line skipped the landmark test_student→publish path and gave daveey-1/careerist the first SOLVED claim plus 5 royalty ticks |  |  |  |
