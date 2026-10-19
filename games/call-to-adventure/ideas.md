# Call to Adventure

Polyworld's four-hero dungeon expedition, live 2026-09-09. A fighter, a
wizard, a rogue and a cleric descend six stacked 128x128 floors - Surface,
Old Halls, Caves, Flooded Deep, Lava Hall, Vault - kill for gold and gear,
then climb back out while monsters respawn above them.

- Coworld: `cow_e843c737-6683-4ce6-802b-106c649d8067` (`2026.9.9.3`)
- League: `league_9f1ea72c-89a7-4282-bfca-d8e96e53453b` (Competition,
  30-minute rounds, `swiss_neighbor`, filler policies complete short
  rosters)
- Source: `~/p/polyworld/examples/call_to_adventure` at commit `028cc5f`
- Ours: **Veles**, `veles/veles.bas`

## Runtime

`player_runtime` is `game-hosted`: one `.bas` file uploaded with
`coworld upload-policy --file`, no container. One VM per hero. Full host
surface in [docs/player.md](docs/player.md).

## Upload

There is nothing to build. The artifact is the `.bas` file itself, and it
goes up with `--file`. The bundled `uv --project ~/p/metta run coworld`
predates the game-hosted file-player workflow and has no such flag, so
run the CLI out of a metta `origin/main` worktree:

    git -C ~/p/metta worktree add /tmp/metta-main origin/main
    CW="uvx --from /tmp/metta-main/packages/coworld[auth] coworld"
    $CW upload-policy --file games/call-to-adventure/veles/veles.bas --name veles
    $CW submit veles:vN -l league_9f1ea72c-89a7-4282-bfca-d8e96e53453b

File policies take no `--run`, no `--secret-env` and no Bedrock flags.
**This league auto-champions**: `submit` reports `Auto champion: always`
without the flag being passed, so a submission that qualifies becomes the
champion. Submit only after hosted XP says the candidate is better.

## Scoring

This is the odd one of the three: the party is not a team. **Gold is
personal**, it only counts once that hero has walked it onto the surface,
and living heroes who returned with the highest personal banked gold each
score 1. Tied leaders share the win. Dead or unreturned heroes score 0,
and if nobody returns there is no winner.

So three heroes can play perfectly and score nothing. What the score
rewards is being the one holding the most gold, alive, above ground.

## Baseline

The bundled `players/base.bas` drinks under half health, heals a wounded
ally, attacks the nearest enemy, picks up the nearest loot, and otherwise
walks the objective the game hands it. It fights first and collects
whatever is left over - which, with four copies running, means the piles
go to whoever finished swinging first.

## Veles

The baseline with two changes:

1. **Loot outranks attacking.** The other three heroes will do the killing
   either way; every pile they leave on the floor is free score.
2. **Drink at 60 percent, not 50.** A dead hero banks nothing at all,
   however much it is carrying.

Healing an ally still comes first, because `woundedAlly` is refused
outright for anyone who is not a cleric with the spell up, so the call
costs nothing in a script that has to run in all four seats.

## Status

Smoke-tested locally only - it compiles, runs a full 28800-tick episode,
and the party returns alive. No A/B yet; hosted XP requests decide.

## Ideas backlog

1. **Bank before the clock.** The match ends wherever the party stands and
   carried gold is worth nothing. A hero that turns for the surface early,
   on its own if necessary, banks a purse that everyone else is still
   carrying. `worldTick` and `currentLevel` are both readable; the walk up
   from the vault takes real minutes.
2. **Let the party tank.** Aggro is 11 tiles. A hero that hangs back at
   the edge of a fight, lets three others take the damage, and moves in
   only to collect, risks nothing and banks the same gold.
3. **Crown hunting.** Crowns are 900 gold, idols 300, chalices 140 - one
   vault drop is worth more than a whole floor of 12-gold piles. Golems
   roll crowns too. `nearestLoot` gives no value, but floor depth is a
   good proxy for what is worth walking to.
4. **Item slots are blind.** There is no way to read the two slots, so
   `useItem` has to be tried and the return value read. Worth tracking
   what was picked up in a global so the script knows what it is holding.
5. **Encumbrance.** Speed drops to 100 / 85 / 70 / 50 percent with weight.
   Dropping gear before the climb out may bank more gold than carrying it,
   since only the purse counts and gear is not gold.
6. **Death is total.** Unlike the other two games there is no respawn -
   a dead hero scores zero no matter what it did. Retreat rules deserve
   far more care here than anywhere else.
