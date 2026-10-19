import
  std/[json, os],
  zippy,
  sim, match, replays

type
  AwmError = object of CatchableError
  Summary = object
    games, shieldDecisions, shieldPlays, fragileShieldPlays: int
    heldPasses, exhaustedChoices, heldPower, lostArmies, lostPower: int
  Exposure = object
    turn, tick: int
    minions: seq[tuple[id, power: int]]

proc readJson(path: string): JsonNode =
  ## Reads hosted participant metadata with a diagnostic boundary error.
  try:
    result = parseJson(readFile(path))
  except JsonParsingError as error:
    raise newException(AwmError, "Invalid hosted JSON: " & error.msg)

proc readReplay(path: string): ReplayData =
  ## Decodes a public replay without changing its canonical action tape.
  var bytes = readFile(path)
  if bytes.len > 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    try:
      bytes = uncompress(bytes, dfGzip)
    except ZippyError as error:
      raise newException(AwmError, "Invalid compressed replay: " & error.msg)
  result = decodeReplayFile(ReplayGame, ReplayGameVersion, bytes, ReplayData)
  result.validate()

proc fragile(game: GameState, seat: int): seq[tuple[id, power: int]] =
  ## Lists exact own minions that a one-damage Hail would destroy.
  for minion in game.players[seat].board:
    if minion.card.kind == Minion and minion.currentToughness == 1:
      result.add (minion.id, minion.power)

proc power(minions: seq[tuple[id, power: int]]): int =
  ## Sums public power in one diagnostic army snapshot.
  for minion in minions:
    result += minion.power

proc inspect(
  episode: JsonNode,
  directory: string,
  labels: var seq[string],
  summaries: var seq[Summary]
) =
  ## Confirms held Shields and later Hail losses against every replay hash.
  let
    job = episode["job_id"].getStr
    path = directory / job & ".replay"
  if not fileExists(path):
    return
  let data = readReplay(path)
  var
    game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
    mapping: array[7, int]
    passed: array[7, bool]
    exposed: array[7, Exposure]
    check: ReplayHashCheck
    tick = 0'u32
  for participant in episode["participants"]:
    let
      label = participant["label"].getStr
      seat = participant["position"].getInt
    var index = labels.find(label)
    if index < 0:
      index = labels.len
      labels.add label
      summaries.add Summary()
    mapping[seat] = index
    if game.players[seat].heroClass == Warrior:
      inc summaries[index].games
  for action in data.actions:
    let
      actor = action.playerId.int
      index = mapping[actor]
      decision = action.kind == ActionPlayCard or
        (action.kind in {ActionAttack, ActionEndTurn} and not passed[actor])
      selected =
        if action.kind == ActionPlayCard:
          game.players[actor].hand[action.handIndex.int].name
        else:
          "PASS"
    if decision and game.turnNumber != exposed[actor].turn:
      exposed[actor].minions.setLen(0)
    if decision and game.players[actor].heroClass == Warrior:
      let vulnerable = game.fragile(actor)
      var shield = false
      for i, card in game.players[actor].hand:
        if card.name == "Shields" and game.canPlay(i):
          shield = true
      if shield and vulnerable.power > 0:
        inc summaries[index].shieldDecisions
        echo "SHIELD_CHOICE job=", job, " policy=", labels[index],
          " tick=", action.tick, " turn=", game.turnNumber,
          " selected=", selected, " energy=", game.players[actor].energy,
          " fragileCount=", vulnerable.len,
          " fragilePower=", vulnerable.power
        let exhausts = action.kind == ActionPlayCard and
          game.players[actor].hand[action.handIndex.int].energyCost ==
            game.players[actor].energy
        if action.kind != ActionPlayCard or exhausts:
          if exhausts:
            inc summaries[index].exhaustedChoices
          else:
            inc summaries[index].heldPasses
          summaries[index].heldPower += vulnerable.power
          exposed[actor] = Exposure(
            turn: game.turnNumber,
            tick: action.tick.int,
            minions: vulnerable
          )
      if selected == "Shields":
        inc summaries[index].shieldPlays
        if vulnerable.power > 0:
          inc summaries[index].fragileShieldPlays
    if selected == "Hail of Arrows":
      for seat in 0 ..< game.playerCount:
        if seat == actor or game.dead(seat):
          continue
        var lost = 0
        for minion in exposed[seat].minions:
          let location = game.minionLocation(minion.id)
          if location.found and
            game.players[seat].board[location.index].currentToughness == 1:
              lost += game.players[seat].board[location.index].power
        if lost > 0:
          let owner = mapping[seat]
          inc summaries[owner].lostArmies
          summaries[owner].lostPower += lost
          echo "HELD_SHIELD_HAIL_LOSS job=", job,
            " policy=", labels[owner], " heldTick=", exposed[seat].tick,
            " hailTick=", action.tick, " archer=", labels[index],
            " lostPower=", lost
          exposed[seat].minions.setLen(0)
    if action.kind in {ActionAttack, ActionEndTurn}:
      passed[actor] = true
    if action.kind == ActionEndTurn:
      passed[actor] = false
    if not game.applyAction(action):
      raise newException(AwmError, "Refused hosted action at " & $action.tick)
    discard game.takeVisualEvents()
    tick = action.tick
    data.hashes.checkReplayHash(tick, game.stateHash, check)
  check.requireReplayComplete(tick, data.hashes.len)
  echo "VERIFIED job=", job, " ticks=", tick

proc main() =
  ## Reports diagnostic Shields opportunities without using local scores.
  if paramCount() != 2:
    raise newException(AwmError,
      "Usage: protections status.json public-replay-directory")
  let data = readJson(paramStr(1))
  var
    labels: seq[string]
    summaries: seq[Summary]
  echo "Hosted request=", data["id"].getStr,
    " coworld=", data["coworld_version"].getStr
  for episode in data["episodes"]:
    inspect(episode, paramStr(2), labels, summaries)
  for i, summary in summaries:
    echo labels[i], " ", summary
  echo "Diagnostic opportunities only; these are not policy scores."

main()
