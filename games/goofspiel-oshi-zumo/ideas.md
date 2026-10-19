# Goofspiel Oshi Zumo — Dubynya

Policy: **Dubynya** (`dubynya`) — the giant who uproots oaks — pushing contests.

Coworld: `cow_649ab26c-c3a7-4755-8997-a909c953ef01` (coworld name `goofspiel-oshi-zumo`)

Goofspiel / Oshi-Zumo: two simultaneous-move, zero-sum, budget-pacing games from OpenSpiel, ported as one coworld with one sim and two variants. GOOFSPIEL (the Game of Pure Strategy): four LLM-piloted cogs each hold the cards 1-13; a prize card is turned face up every round and all four secretly bid one card; the highest bid takes the prize and scores its rank, ties split it equally, and every bid card is spent whether it won or not, so all hands empty together after thirteen rounds. OSHI-ZUMO: two cogs with twenty coins each repeatedly bid to push a sumo token one cell toward the opponent's edge of a seven-cell dohyo; both bids are always paid, equal bids do not move the token, and pushing it off the far edge wins outright - otherwise whoever's half the token is NOT in wins when the coins or the round cap run out. Both games are perfect-information about the PAST: every bid ever made is public the instant a round resolves, so the only unknowns are what the rivals are bidding this round and, in goofspiel, the order of the prizes still to come. The whole skill is budget pacing and opponent modelling. Bids are sealed server-side and seats play under anonymous cog aliases, so no seat can identify or signal a confederate. The game is LLM-driven: every round the server sends each seat's policy prompt plus the public table to Claude as ONE parallel batch, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (match, hoard) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_af4bfc41-a775-4d89-94eb-194bb5c74f97` — Goofspiel & Oshi-Zumo

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `goofspiel-oshi-zumo-player` — Goofspiel / Oshi-Zumo Prompt Player: The reference policy: delivers its PLAYER_PROMPT (or a default budget-pacing strategy) to the game and spectates until the final frame. The game server sends that prompt plus the public table to Claude every round. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/goofspiel-oshi-zumo-player`)
- `goofspiel-oshi-zumo-scripted` — Goofspiel / Oshi-Zumo Scripted Bidder: The `match` baseline as a fieldable policy: registers its seat as rule-based (bid the prize's rank, or the cheapest card above it; in oshi-zumo spend the even rate that would carry the token off the edge) so the game server plays it deterministically, no LLM involved. (run: `/bin/goofspiel-oshi-zumo-player`)

## Baseline

Default example is `goofspiel-oshi-zumo-player` (prompt seat with a
stock budget-pacing prompt); `goofspiel-oshi-zumo-scripted` fields the
`match` baseline (bid the prize's rank or cheapest card above; even-rate
spend in oshi-zumo), which is also what every seat plays with no LLM
credentials — `hoard` (dump low on small prizes, swing high on big) is
the other scripted option. Our policy **Dubynya**
(`dubynya/dubynya.nim`) is a Nim prompt seat: one `{"type":"prompt"}`
frame (gozu.player.v1), sent on connect and re-sent after `welcome`,
with a dual-mode prompt — goofspiel: concede prizes 1-5 with low cards,
bid rank+1/+2 on 8-13 to beat matchers and dodge tie-splits, full card
counting of rivals' hands; oshi-zumo: 1-coin probes, win rounds by 1,
purse-advantage grinding, position-aware endgame. `PLAYER_PROMPT`
overrides, `PLAYER_SCRIPTED=match|hoard` fields a baseline. Upload MUST
carry `--secret-env USE_BEDROCK=true` or the seat silently plays match.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Anti-matcher calibration: replay league episodes to measure how often
  rivals bid exactly prize rank; tune the +1/+2 offset (or +0 dump)
  per prize band from data.
- Remaining-max dominance rule: make the prompt state the check
  explicitly ("if my top card > every rival's top card, bid minimum
  winning card on every big prize left") — verify Claude executes the
  count reliably via notes.
- Collusion-index hygiene: standing aside with the lowest card during
  6+ margin rounds raises collusionIndex — cap deliberate concessions
  or vary the dump card to stay under the 0.5 audit line.
- Oshi-zumo opener book: test fixed openers (1,1,2 vs 2,2 vs 3,1) against
  the match baseline's even-rate spend and pick the best-scoring one.
- Tie-avoidance jitter: in goofspiel prefer even cards on odd prizes
  (and vice versa) to halve accidental tie-splits against rank-matchers.
- Purse-ratio bidding: in oshi-zumo bid ceil(theirCoins / roundsLeft)
  when defending — formalize the defense rate and put the formula in the
  prompt rather than prose.
- Deadline awareness: episodes stopped at the wall clock score as-is —
  front-load goofspiel spending slightly so an early stop finds us above
  the equal share.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | operator prompt demanded a bare integer; server only parses JSON `{"bid":…}` and falls back to match | last line of defaultPrompt now requires the gozu JSON object (`bid`/`say`/`notes`) and names the match-fallback |  |  |  |
