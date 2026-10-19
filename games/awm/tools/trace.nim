## Prints one local game's card plays and our seat's BASIC output.
##
##   trace SEED ROTATION ours.bas
##
## Seats match the arena's XP layout: the roster is ours, stilt:v3,
## greenshank:v6 and the baseline, rotated by ROTATION.

import
  std/[os, random, strutils],
  bassy, sim, bots, match, replays

const
  Opponents = ["stilt_v3.bas", "greenshank_v6.bas", "AWM_Baseline_v1.bas"]

proc main() =
  ## Plays one traced match.
  if paramCount() < 3:
    quit("Usage: trace SEED ROTATION ours.bas", 1)
  let
    seed = parseInt(paramStr(1)).int32
    rotation = parseInt(paramStr(2))
    others = currentSourcePath().parentDir / "../others"
  var roster = @[readFile(paramStr(3))]
  for name in Opponents:
    roster.add readFile(others / name)
  var sources = newSeq[string](4)
  for i in 0 ..< 4:
    sources[(i + rotation) mod 4] = roster[i]
  let ours = rotation mod 4
  var rng = initRand(seed.int64)
  var classes: seq[HeroClass]
  for _ in 0 ..< 4:
    classes.add rng.rand(HeroClass)
  let vms = loadBots(sources)
  var line = ""
  vms[ours].output = proc(event: PrintEvent) =
    if event.kind == NewlinePrint:
      echo "    ", line
      line = ""
    elif event.text.len > 0:
      line.add event.text & " "
    else:
      line.add $event.value & " "
  var setup = Setup(seed: seed, maximumTicks: 200_000)
  for c in classes:
    setup.classes.add c.ord.uint8
  let recorder = initReplayRecorder(setup, GameConfig())
  var played = initBotMatch(classes, seed.int64, vms, 200_000, recorder)
  played.scriptError = proc(player: int, message: string) =
    echo "seat ", player, " error: ", message
  echo "classes ", classes, " ours ", ours
  while true:
    let before = played.game
    if not played.step():
      break
    let action = played.recorder.data.actions[^1]
    if action.kind == ActionPlayCard:
      let card = before.players[action.playerId].hand[action.handIndex]
      echo "turn ", before.turnNumber, " seat ", action.playerId, " plays ",
        card.name, " ", action.choices.toChoices
  echo "winner ", played.game.winner

main()
