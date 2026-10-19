# Coworld Mtg — Volkh Vseslavevich

Policy: **Volkh Vseslavevich** (`volkh`) — the sorcerer bogatyr — spell duels.

Coworld: `cow_dd386b56-17c1-4337-9f9b-0d6be60503e4` (coworld name `coworld-mtg`)

Two-player Magic: The Gathering powered by the Phase rules engine, with enforced mana, timing, priority, stack, combat, hidden information, scoring, and replay.

## Leagues

- `league_dddaa300-2cbd-4ce9-8362-73b9c57ed88d` — Coworld Mtg

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `coworld-mtg-goldfish` — Coworld MTG Phase Goldfish: A deterministic baseline that ranks and submits only the exact legal actions supplied by Phase. (run: `/app/goldfish`)

## Baseline

- Only example: `coworld-mtg-goldfish` (`/app/goldfish`, an opaque binary in the image; source is
  `crates/players/goldfish/src/lib.rs` in github.com/Metta-AI/coworld-mtg @ 265a8fed). It ranks
  the exact legal actions Phase supplies and submits the best: Keep mulligan > SelectCards >
  PlayLand > CastSpell > ActivateAbility > DeclareAttackers (largest) > DeclareBlockers
  (largest) > other > PassPriority; one in-flight command, gated on ack; a cancelled cast is not
  immediately retried.
- **Volkh is a faithful Nim port of that ranking** with two hardening changes: (1) Concede /
  SetAutoPass / CancelAutoPass / SetPhaseStops rank dead last (the Rust ranking would prefer
  any unknown "other" action — including a legal-set Concede — over PassPriority), and
  (2) a reject suppresses that exact action and re-plans instead of aborting the process.
- Protocol confidence: high — the wire spec (docs/protocol.md) and goldfish source were both
  read; frames are hello/state/ack/reject/game_end/match_end, replies are
  `{cmd_id, action}` with the action copied verbatim. Uncertainty: whether Concede appears in
  `legal_actions` (the spec says player payloads "include" it); ranking it last is safe either
  way.
- Upload: no secret-envs (scripted seat, no LLM).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Curve-aware casting: goldfish casts the FIRST legal spell; instead prefer the highest
  mana-value castable spell each main phase (read `spell_costs` object-id -> cost).
- Attack math: don't always swing everything — skip attacks where the defender's untapped
  potential blockers (battlefield toughness vs our power) make the trade negative.
- Block to survive: rank DeclareBlockers by damage prevented minus creatures lost, not by
  assignment count; chump-block only lethal damage.
- Hold up interaction: with an instant in hand and untapped mana, pass the first main phase
  cast opportunity and cast at end of the opponent's turn (track `phase` + `active_player`).
- Mulligan quality: goldfish always keeps; count lands in the visible hand and take a London
  mulligan below 2 or above 5 lands on 7.
- Target selection: when a CastSpell offer enumerates target variants, prefer the variant
  targeting the opponent's biggest battlefield threat (power+toughness) or their life total.
- Use SetPhaseStops/SetAutoPass to skip dead priority windows and save the decision clock
  (30s per decision, ~6 min game clock).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
