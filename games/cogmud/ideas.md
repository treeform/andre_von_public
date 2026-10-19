# Cogmud — Kot Bayun

Policy: **Kot Bayun** (`kot_bayun`) — the storytelling cat — text world.

Coworld: `cow_42773bd0-0a21-4cca-94b2-41cd26b2d6ed` (coworld name `cogmud`)

Cogmud: six LLM-piloted cogs loose in the nine-room town of Coppermarch for fourteen turns, where every move is ONE SENTENCE of plain English. There is no action menu anywhere in the stack: a seat's whole output is a sentence, which the server parses with a bounded intent grammar into exactly one of thirteen intents - go, take, drop, buy, sell, hand over, offer, accept, hire, rob, ask, speak, wait. Five shopkeepers hold stock whose prices move with it (a keeper charges more for what it is short of and pays about two thirds of what it charges), Guildmaster Vell at the Guildhall posts and settles two private commissions per seat that pay PARTIAL CREDIT per unit delivered, robbery works only in the two unlit rooms - The Docks and Cutpurse Alley - and only against a cog without a bodyguard, and hiring is the one promise the rules actually enforce: the coins move on acceptance and for three turns the hireling cannot rob its employer and guards it while they share a room. What a cog SAYS is enforced by nothing. Decisions inside a turn are simultaneous and resolve in a fixed class order - speech, shops, ground, cog to cog, robbery, movement - each class in a deterministic initiative rotation, so contention for the last unit of stock or the last item on the floor always goes to the earlier initiative. Information is strictly local: a seat sees its own purse, pack and commission book, the room it stands in with every referent named, and what was said and done there last turn - never another room, never another seat's coin or goods, never a price it is not standing next to. Score is coins plus the fixed reference value of everything carried plus 3 per commission point, so a seat that does nothing scores exactly 0.0 and a seat robbed blind scores negative. The game is LLM-driven: every turn the server sends each seat's policy prompt plus its whole observation to Claude in ONE parallel batch of six, so A POLICY IS JUST A PROMPT - build one by reusing the published cogmud-player runnable and setting PLAYER_PROMPT to your strategy. Two scripted baselines (factor, a competent quest-and-trade agent, and magpie, a thief-peddler) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_c8ba20f2-f4b2-4e68-b8ad-ba75c5eca66a` — Cogmud

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `cogmud-player` — Cogmud Prompt Player: The reference Cogmud policy: delivers its PLAYER_PROMPT (or a default commission-first strategy in words) to the game and spectates until the final frame. The game server sends that prompt plus the seat's whole observation to Claude every turn and plays back the one sentence it answers with. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/cogmud-player`)
- `cogmud-factor` — Cogmud Factor Baseline: The scripted quest-and-trade baseline as a fieldable policy: hands Vell what a commission still needs, buys what it is short of where it is stocked, sells surplus into a shop that is paying over the odds, picks up anything valuable, and otherwise walks the shortest path toward the next thing it needs. Never robs, never hires, never speaks. This is also the universal fallback for any failed LLM decision, so an episode always completes. (run: `/bin/cogmud-player`)
- `cogmud-magpie` — Cogmud Magpie Baseline: The scripted thief-peddler: ignores commissions entirely, jumps anyone carrying goods in an unlit room, hawks whatever is in its pack at a markup every third turn, works the spread when a shop is mispricing, and walks toward the dark when its hands are empty. Deliberately worse than factor and differently shaped, so a two-baseline table is not a mirror match - and its thieving means every offline episode exercises the robbery path. (run: `/bin/cogmud-player`)

## Baseline

`cogmud-factor` (scripted quest-and-trade agent, also the universal
fallback) is the stronger example; `cogmud-magpie` is the deliberately
weaker thief-peddler. The default `cogmud-player` is a prompt seat. Our
policy `kot_bayun` sends the standard
`{"type":"prompt","prompt","scripted"}` hello on connect and after
welcome, then spectates to `final`. Default `scripted` is `factor` (the
competent quest-and-trade baseline, and what the current leader fields
as `co-gas-cogmud-deterministic-factor-richard`): it runs inside the
sim, so it sees every shop's stock and walks BFS toward the nearest
fill. The unused operator prompt is still commission-first with the
five shopkeepers' fixed goods lists embedded. PLAYER_PROMPT /
PLAYER_SCRIPTED override. Factor seats need no Bedrock secret.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Corner Vell's rope: rope commissions can be bought AND delivered at
  the Guildhall in consecutive turns; teach the prompt this two-turn
  degenerate route explicitly.
- Magpie-hunter variant: with commissions done and 3+ turns left, carry
  nothing, walk the dark rooms, and rob carriers — the score swing of a
  relic mugging is 0.35 each way.
- Price-aware buying: the ask formula is deterministic
  (base + 6 - stock); embed it so the LLM can predict tomorrow's price
  from today's stock instead of paying stock-0 peaks.
- ask-intent economics: is one `ask` turn (cheapest current ask for a
  commission good) ever worth a turn of the 14? Test never-ask vs
  ask-on-turn-1.
- Retainer insurance: hire a bodyguard for the delivery walk only when
  carrying 20+ base value through the ring past the dark rooms.
- Floor sweeping: prompt currently takes free goods opportunistically;
  test an explicit end-of-game rule (turns 12-14: take anything, sell
  nothing under base).
- Relic flip: Fen sells relics in the dark Docks — test whether an
  empty-handed turn-1 relic buy at stock 3 (ask 17, above base) is ever
  worth it vs never touching the Docks at all.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | default to scripted factor | PLAYER_SCRIPTED default `"factor"` instead of LLM prompt; factor decides server-side with full stock/path knowledge the observation never shows, matching the #1 policy `co-gas-cogmud-deterministic-factor-richard` | | | |
