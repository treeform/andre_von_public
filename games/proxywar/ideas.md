# Proxywar — Ivan Tsarevich

Policy: **Ivan Tsarevich** (`ivan_tsarevich`) — sends the Grey Wolf to fight for him — war by proxy.

Coworld: `cow_3bda6df6-28c1-47f8-8a7b-e8ad91e90f0a` (coworld name `proxywar`)

Territorial strategy game: agents fight over a world map — expansion, economy, nukes, alliances, and betrayal when it pays.

## Leagues

- `league_cb60d526-ecfd-4836-ab3a-81fc6cf7dc42` — Proxy War

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `proxywar-starter-websocket` — Proxy War Starter Websocket Player: Minimal websocket player that chooses one offered LegalAction.id. (run: `node /app/integration/src/starter-player.mjs`)

## Local baseline

~/p/proxywar — our Nim winner-take-all ladder bot (already Nim, strong).

## Baseline

- Default example: `proxywar-starter-websocket` — picks one offered
  LegalAction.id, certification-grade only, not competitive.
- Strongest available: our own ~/p/proxywar bot (`kutuzov`), whose V98
  champion holds live rank one on the Proxy War ladder (2063 MMR at the
  last snapshot). V98 = argmax action scoring with the
  `openingSoftPangaeaPeaceEconomyBatch` profile: soft Pangaea opening
  book, peace-leaning diplomacy, plus one funded economy-build batch
  companion when the protocol advertises maxActionsPerDecision > 1.
  Worktrees ~/p/proxywar-by-parts and ~/p/proxywar-starting-opening are
  older experiment lines already folded into or rejected by the main
  repo's gate history; the main repo is the strongest source.
- Ivan Tsarevich: V98 sources with a thin main (`ivan_tsarevich.nim`)
  that defaults the profile to `openingSoftPangaeaPeaceEconomyBatchGround`
  (V98 plus a closing-phase land companion; upstream binary defaults to
  weaker "base" weights). Retry
  loop inside the 120 s connect window, RFC 6455 close frame, and
  post-final linger are all kept — they exist because rounds died
  without them.
- Upload: command player, no USE_BEDROCK secret-env. One image serves
  every A/B arm via `--run --profile=<name>`.
- Rejected-by-gate features still in the code, off by default: second
  economy companion (V99), border chat (V100), structured deals (V101),
  spatial defense posts (V102). Selectable via their profiles for fresh
  gates against this league's own field.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

1. Re-gate the rejected V99/V100/V101/V102 profiles against THIS league's
   field: the kutuzov gates froze a different opponent set, and a feature
   that lost there (second economy build, border chat, structured deals,
   spatial defense) may pay against these entrants. One profile per
   experiment, paired seed blocks.
2. Field-size adaptation: the kutuzov weights were gated on 16-player
   Pangaea, but the manifest also ships a compact two-player default and
   4P/8P/12P variants. Confirm which variant this league actually runs
   from a round replay, and if it is small-field, test a profile that
   shortens the opening book and raises early aggression when
   aliveRivals is low — winner-take-all on a duel map should grind
   earlier than a 12-seat pool game.
3. Spawn ballot: we already parse protocol.maxSpawnPreferences=16 — rank
   spawn offers by distance-from-rival and coast access instead of
   taking the scalar best only, and measure on paired seeds.
4. Bounded-episode scoring hedge: this adapter pays normalized territory
   share when no one wins inside the bound. Add a late-game profile
   branch that switches from grind-to-kill to maximum tile share when
   turnNumber is near the cycle bound and no wipeout is in reach.
5. Deal slot policy per field size: in a two-seat game deal_* offers
   are pure tempo — test auto-rejecting every deal (never bind
   ourselves) versus V101's honor-the-pact logic, since
   betrayal-when-it-pays has no third-party reputation cost without
   witnesses; in big fields keep V101's compliance.
6. Decision-time budget audit: pull hosted policy logs and check the
   per-decision elapsed ms against the platform decision timeout on this
   variant; if headroom is large, deepen the batch companion search
   (V99's second build) only when the menu is small.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 2 | musl/scratch image restored (proxywar exception) | debian-slim 85MB -> scratch 1.1MB | league rounds | same-round comparison vs kutuzov:v98 | v2 mean 0.076 vs kutuzov 0.259 over same 14 rounds; big image forfeits seats (player_never_started); v3 = kutuzov's proven build |
| 1 | Closing-phase ground companion | Winner-take-all pays 1.0 only after 80% map control; V98 already suppresses economy at `closingShare` 0.35 but then sends a scalar-only batch, leaving layer-2 land unplayed. New default profile `openingSoftPangaeaPeaceEconomyBatchGround` keeps the V98 midgame economy companion and, only in that closing window, appends one remaining positive-scoring expand/attack. Not spawn-ballot / V99–V102 (those already lost). | | | |
