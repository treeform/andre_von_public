# Cogiavelli — Shamakhanskaya Tsaritsa

Policy: **Shamakhanskaya Tsaritsa** (`shamakhanskaya`) — the scheming queen.

Coworld: `cow_f54e03ab-39e9-4763-b46f-51556727bdd4` (coworld name `cogiavelli`)

Cogiavelli: Diplomacy's adjudicator on a Renaissance-Italy board, with a treasury bolted on. Six LLM-piloted powers - VENICE, MILAN, FLORENCE, the PAPACY, NAPLES and the TURK - contend for twenty-four Italian cities across three seasons a year. Every season each power writes press (non-binding), then submits, at the same moment as everyone else, one order per unit AND an expenditure sheet. Orders are Diplomacy's: HOLD, MOVE, SUPPORT and CONVOY, resolved by the full standard adjudicator (four strengths, cut supports, circular movement, the Szykman rule for convoy paradoxes). The expenditure sheet is what Diplomacy leaves out: GIFTS of ducats arrive instantly and irrevocably - the only promise in the game that cannot be broken; BRIBES disband an enemy unit for 9 ducats or buy it outright for 15; DEFEND payments raise what a briber must beat; and an ASSASSINATION of 6 to 30 ducats buys a two-dice roll that, if it lands, freezes a rival's whole court for a season. Money resolves BEFORE the armies move and is spent whether or not it works, and every ducat is published. Italy bites back: famine marks two provinces each Spring, plague empties one city each Summer, neglected cities rebel in Winter, and every unit costs upkeep. Whoever occupies a city owns it from that moment; hold 12 of the 24 and you win outright, otherwise you are scored on city share plus what is left in your vault. Seats play under anonymous power names and cog aliases, so no policy can recognise a counterparty across episodes and every side deal has to be paid for on the board. The game is LLM-driven: the server sends each seat's policy prompt plus the board, the city table, every treasury, the two-year ledger, the press it received, the complete list of its legal orders and the exact price of every bribable enemy unit to Claude - so A POLICY IS JUST A PROMPT: build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable. Two scripted baselines (condottiere, banker) play any seat that registers as scripted, and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_5ba37909-d5ac-4ba5-8c51-842326b999e4` — Cogiavelli

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `cogiavelli-player` — Cogiavelli Prompt Player: The reference Cogiavelli policy: delivers its PLAYER_PROMPT (or a default strategy) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/cogiavelli-player`)
- `cogiavelli-condottiere` — Cogiavelli Condottiere Baseline: The scripted expander as a fieldable policy: registers its seat as rule-based, so the server plays it deterministically with no LLM. It walks its units toward the nearest city it does not own, never stands itself off, disbands a threatening neighbour for nine ducats when it can afford to, and builds in Winter while upkeep stays covered. (run: `/bin/cogiavelli-player`)
- `cogiavelli-banker` — Cogiavelli Banker Baseline: The scripted hoarder as a fieldable policy: every unit holds or supports a neighbour's hold, four ducats of loyalty go onto each garrison while the vault is deep, and it builds only when very rich. It never attacks, never bribes and never assassinates - the wall that cannot be talked into anything. (run: `/bin/cogiavelli-player`)

## Baseline

`cogiavelli-condottiere` (scripted expander: walk at the nearest
unowned city, 9-ducat disbands, Winter builds) is the stronger example;
`cogiavelli-banker` never attacks and only walls up. The default
`cogiavelli-player` is a prompt seat. Our policy `shamakhanskaya` sends
the standard `{"type":"prompt","prompt","scripted"}` hello on connect
and after welcome, then spectates to `final`. The prompt plays
cities-first expansion (score = (c + min(d,24)/24)/24), Winter garrison
discipline, famine evacuation, defend-ducats on frontline units, and
gift-sealed one-flank diplomacy. PLAYER_PROMPT / PLAYER_SCRIPTED
override. Upload needs `--secret-env USE_BEDROCK=true` or the seat
silently plays scripted condottiere.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Defend-heavy variant: 4 ducats of standing defence on every
  city-holding unit (banker's trick) grafted onto the expander opening;
  measure cities lost to bribes with and without.
- Neutral-rush timing: order the prompt to name its two nearest
  neutrals in year 1 explicitly per power (VENICE->TRI/FER,
  MILAN->TUR/GEN, ...) instead of "nearest"; fewer LLM misroutes.
- Assassination as tempo: one 18-ducat attempt on the city leader in
  the penultimate Autumn (paralysed units hold through Winter's
  rebellion checks) — worth a city?
- Gift diplomacy A/B: open year 1 with a 2-ducat gift to the chosen
  ally vs pure words; does the stab rate against us drop?
- Upkeep austerity: never build past 4 units; condottiere over-builds
  and starves in bad Winters.
- Famine/plague hygiene line already in prompt — verify in replays the
  LLM actually evacuates famine provinces by Autumn, tighten wording
  if not.
- Endgame treasury cap: spend-above-24 rule vs plain hoarding over the
  last two seasons.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | defend-heavy expander (fitted 2d, not 4) | operator prompt: DEFEND 2 ducats on every city-garrison while treasury >= 10; rivals bid the 9/15 floor in the same batch and cannot see this season's defence | | | |
