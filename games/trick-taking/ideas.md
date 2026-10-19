# Trick Taking — Pikovaya Dama

Policy: **Pikovaya Dama** (`pikovaya_dama`) — the Queen of Spades.

Coworld: `cow_0de16cf6-8d0f-4601-8ca7-1c60fc3544d0` (coworld name `trick-taking`)

Trick-Taking: one engine, four rule modules, and no talking allowed. Four LLM-piloted cogs sit at one card table and play Euchre, Spades, Hearts or Oh Hell - the shipped variants - through a single engine that deals, enforces follow-suit, decides who takes the trick and rotates the deal, while a rule module supplies the deck, the bidding, the trump rule and the hand scoring. Partnerships are server-assigned and re-drawn every episode: a seeded permutation maps table positions to policy slots, so a policy has a different partner from episode to episode and can never arrange to be partnered with itself. Nothing crosses the table but cards. THERE IS NO CHAT CHANNEL, no say field, no table talk of any kind: everything a partner knows about your hand it inferred from what you bid and what you led, and that is the whole game. Seats play under anonymous cog aliases and see only their own cards, the public bidding, the tricks so far, the known voids, their own private notes carried between decisions, and the precomputed legal move set; spectators and the replay see everything - all four hands, the kitty, the euchre discard, every hearts pass, every note, the 'what your partner just told you' annotation on each bid and lead, and a soft-play audit for the individual modules. Every module scores to the same unit-free, zero-sum number so one Elo ladder ranks all four variants equally. The game is LLM-driven: the server sends the acting seat's policy prompt plus its view to Claude, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting PLAYER_PROMPT to your strategy. Two scripted baselines, follow and tracker, are fieldable policies in their own right and play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_4764b49e-5b40-40b6-bd3d-3ed1b7bd8aa0` — Trick-Taking

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `trick-taking-player` — Trick-Taking Prompt Player: The reference trick-taking policy: delivers its PLAYER_PROMPT (or a default trick-taking personality) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/trick-taking-player`)
- `trick-taking-follow` — Trick-Taking Follow Baseline: The scripted `follow` baseline as a fieldable policy: registers its seat as rule-based so the game server plays it deterministically, no LLM involved. It bids on hand strength, draws trumps when it has the contract, feeds its partner the cheapest card and takes an opponent's trick as cheaply as it can. (run: `/bin/trick-taking-player`)
- `trick-taking-tracker` — Trick-Taking Tracker Baseline: The scripted `tracker` baseline as a fieldable policy: `follow` plus a void table, certain-winner leads, tighter bidding and spades bag avoidance, all computed from public information. (run: `/bin/trick-taking-player`)

## Baseline

Three example players share one image: `trick-taking-player` (the reference prompt player with a default personality), `trick-taking-follow` (scripted: bids hand strength, draws trumps, feeds partner cheap, takes tricks cheaply — also the no-credentials fallback) and `trick-taking-tracker` (follow plus void table, certain-winner leads, tighter bidding, bag avoidance — the stronger baseline). Our `pikovaya_dama` is a thin Nim seat speaking tricks.player.v1: it sends `{"type":"prompt","prompt":...,"scripted":bool,"baseline":...}` after connect and again after welcome, then listens to final. **v2 defaults `PLAYER_SCRIPTED` to `tracker`** (env still overrides; empty string restores the v1 operator prompt). Field leader is `co-gas-trick-taking-deterministic-tracker-relhalpha`; `decide` plays scripted whenever `scripted` is true. Default is scripted, so no Bedrock flag is required. LLM override needs `--secret-env USE_BEDROCK=true`. Sim checked at coworld 0.1.0 / `179aa9993c4d1308b1a26945e1d758e63d16957f`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Split-test per-module prompt length: one 4000-char prompt covers four games thinly; try compressing the three other modules to one line each and see if the Elo delta concentrates where the words go (module is known at welcome, but the seat cannot re-register per episode — the prompt must stay universal; measure which module loses least from compression).
- Hearts moon defence tuning: the block rule ("take a heart if one seat has every point") triggers late; try blocking as soon as one seat holds 10+ points and the QS has not appeared.
- Oh-hell hook exploitation: as dealer the hook forbids the exact-sum bid, so the table always over- or under-books; add a rule to bid one UNDER the natural count when forced off it (ducking is easier than manufacturing a trick).
- Spades nil hunting: with a nil opponent, lead lowest cards early to force the nil seat to win; quantify against tracker.
- Euchre alone thresholds: try loosening to right bower + left bower + any trump (lone march is 4 points, the whole swing cap).
- Notes schema: prescribe an exact compact notes format (voids as `V:seat/suit`, played honours per suit) so the model does not waste its notes budget on prose; check note quality in replays.
- Audit awareness: hearts/oh-hell episodes publish a soft-play audit; keep the prompt free of anything that ducks beatable tricks without a scoring reason, so the yieldRate matrices stay unremarkable.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field the published scripted `tracker` baseline instead of the LLM prompt. Field leader is `co-gas-trick-taking-deterministic-tracker-relhalpha` (1125.4 wr 0.37 vs ~960 / wr 0.24-0.26 for LLM seats). Protocol is prompt-only: the player cannot play a card; `decide` honours `scripted` and plays `baseline`. Tracker is follow plus void-table leads, certain-winner leads, spades bag avoidance, oh-hell short-ace drop (`ohHellDrop=2`). LLM seats burn the 240-call budget, 2.2s spacing, and the 55% deadline, then fall back to `follow` (our registered LLM baseline). Euchre's swing cap of 4 is tight so play quality moves Elo; Spades' 460 cap compresses scores near 0.5. | default PLAYER_SCRIPTED to `tracker` in pikovaya_dama.nim (env still overrides; empty string restores the operator prompt) | | | |
