# Garble — Govorun

Policy: **Govorun** (`govorun`) — the talking bird, famed for intellect and wit — noisy channel.

Coworld: `cow_cb2293f4-2825-41d3-831b-7f3a690474a6` (coworld name `garble`)

Garble: five LLM-piloted cogs trade four commodities - ORE, OAT, TIN, TAR - over one shared radio and pairwise private lines, and EVERY channel is noisy. Each cog starts holding a pile of one commodity it does not need and a private contract that pays a premium for a different one, so there are real gains from trade and the only way to trade is to talk. Each turn a cog transmits one line, on the RADIO (all four others hear it) or on a PRIVATE LINE to one named cog (cleaner channel, one listener). Every transmission passes through the channel: words drop, swap for near-neighbours (5 -> 50, 5 -> 4, ORE -> OAT, FIVE -> NINE) or vanish under a static burst, and each recipient gets its own independent garbling, with intensity riding a public interference meter that swells and fades through the episode. The exchange scans terms out of the words - SELL or BUY, then AT, taking the most repeated number and commodity before AT as quantity and commodity and the most repeated number after AT as price - and opens a ticket. A deal executes when another cog CONFIRMS that ticket, and THE CONFIRMED TERMS ARE WHAT THE EXCHANGE ENFORCES, not the terms that were spoken: a misheard 'SELL 5 AT 12' can settle as 'SELL 50 AT 1'. The offerer's only defence is the redundancy shield - a field said twice binds exactly, a field said once can be confirmed as any of its published near-neighbours - and repeating costs AIRTIME, metered in characters, 900 per episode with a flat 40 per confirm. So the whole game is the tradeoff between protocol robustness and speed, plus strategic mishearing. Score is portfolio value at the horizon divided by what the seat would have been worth had it never traded: higher is better, 1.00 means traded to no effect, and nobody's score is anybody's mirror image. Seats play under anonymous cog aliases. The game is LLM-driven: the server sends each seat's policy prompt plus its inventory, contract, heard traffic, confirmable tickets and the public deal tape to Claude, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (quoter, the honest repeater; shark, the terse opportunist) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_4eb352ae-4a7e-42a2-a7a2-6b3a23dc0b4a` — Garble

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `garble-player` — Garble Prompt Player: The reference Garble policy: delivers its PLAYER_PROMPT (or a default trade-toward-your-contract strategy) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/garble-player`)
- `garble-quoter` — Garble Quoter Baseline: The honest repeater, as a fieldable policy: registers its seat as scripted so the game server plays it deterministically - it quotes its surplus and bids for its contract commodity, repeats every field once whenever the interference meter is at or above 50%, confirms exactly the reading it heard, and stops transmitting below 30 runes of airtime so it can always still confirm. No LLM involved. (run: `/bin/garble-player`)
- `garble-shark` — Garble Shark Baseline: The terse opportunist, as a fieldable policy: the same offers as the quoter but never repeated - fast, cheap and steal-able - and it confirms strategically, asserting the most favourable admissible reading of the ticket it takes. It voids often against a repeating counterparty and robs a terse one. No LLM involved. (run: `/bin/garble-player`)

## Baseline

Default example is `garble-player` (prompt seat with a stock
trade-toward-your-contract prompt). Of the scripted baselines `shark`
(terse opportunist, confirms the most favourable admissible reading) is
the more dangerous foil; `quoter` is the honest repeater and the seat
every unprompted/no-LLM slot plays. Our policy **Govorun**
(`govorun/govorun.nim`) is a Nim prompt seat: one `{"type":"prompt",
"scripted":bool,"baseline":str}` frame (garble.player.v1 — note the
scripted field is a BOOL here, unlike other games), sent on connect and
re-sent after `welcome`. The prompt plays shielded-quoter/selective-shark:
repeat every offered field (or use the no-neighbour spellings FOUR/SEVEN/
EIGHT/ELEVEN), transmit on published quiet turns over private lines, few
large quota-sized trades, 80-rune confirm reserve, gamble on neighbour
confirms only when the heard field appeared once. `PLAYER_PROMPT`
overrides, `PLAYER_SCRIPTED=quoter|shark` fields a baseline. Upload MUST
carry `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Quantify the shark gamble: from replays, how often does a heard-once
  field mean said-once? Set an explicit expected-value threshold for
  neighbour confirms in the prompt.
- No-neighbour number book: price and qty menus built only from values
  with drop-only spellings (4, 7, 8, 11) or double-said digits; measure
  airtime saved vs repeat-everything.
- Burst-turn discipline: bursts blank 2-4 contiguous words for every
  listener — teach the prompt to treat any turn where heard traffic looks
  truncated as a burst and re-request via private line.
- Counterparty inference: the tape names both parties of every deal —
  maintain a per-alias surplus/demand table in notes and direct private
  lines at the seat whose surplus is our demand from turn 2.
- Airtime split experiment: 1 big sale + 1 big buy vs 2 smaller each;
  compare mean score across an XP batch.
- Decoy tickets: transmit a deliberately unattractive terse offer to bait
  shark confirms into uncovered voids while our real offers go shielded
  on private lines.
- Endgame pricing: in the last two turns accept worse prices for the
  demand commodity — the premium (6-9/unit up to quota) dominates any
  plausible price walk.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 1.06->1.16 t=0.72 5/10 |
| 1 | off-contract neighbour-confirms are +EV | prompt: units of EVERY commodity mark at F[c], so shark a once-said field on any good (not just demand/surplus); drop "do not churn" | | | |
