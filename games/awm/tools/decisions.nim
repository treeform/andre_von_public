import
  std/[json, os, strutils, tables],
  zippy,
  sim, match, replays

const
  DefaultPolicy = "f36ab082-25e0-42d7-8b5f-b39fb96f34f0"
  DetailLimit = 30

type
  AwmError = object of CatchableError
  Episode = object
    request, id, job, replay, policy: string
    seat: int
    labels: seq[string]
  Summary = object
    games, decisions, passes: int
    hailAvailable, hailPlayed, hailHeld, hiddenHail, hiddenHailDecisions: int
    hiddenHailPower, hiddenIncomingPower: int
    hailPlayedHiddenOnly, hailPlayedNoKills, hailProxyUnavailable: int
    hiddenProxyDeclines: int
    predecessorMismatch, mismatchIncomingPower: int
    freeHeld, freePlayed, bouncers, bouncerZero, bouncerOwn: int
    bouncerLowCost, bouncerWrongPredecessor: int
    bubblePlayed, bubbleBounced, primordialPlayed: int
    cards: CountTable[string]

proc readText(path: string): string =
  ## Reads diagnostic input with a library-specific error.
  try:
    result = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read " & path & ": " & error.msg)

proc textField(node: JsonNode, name: string): string =
  ## Reads a required textual metadata field without permissive coercion.
  if node.kind != JObject or not node.hasKey(name):
    raise newException(AwmError, "XP metadata lacks field " & name)
  if node[name].kind == JNull:
    return ""
  if node[name].kind != JString:
    raise newException(AwmError, "XP metadata field is not text: " & name)
  node[name].getStr

proc numberField(node: JsonNode, name: string): int =
  ## Reads a required integer metadata field without permissive coercion.
  if node.kind != JObject or not node.hasKey(name) or
    node[name].kind != JInt:
      raise newException(AwmError, "XP metadata lacks integer " & name)
  node[name].getInt

proc arrayField(node: JsonNode, name: string): JsonNode =
  ## Reads a required metadata array with an explicit boundary error.
  if node.kind != JObject or not node.hasKey(name) or
    node[name].kind != JArray:
      raise newException(AwmError, "XP metadata lacks array " & name)
  node[name]

proc readEpisodes(path, policy: string): seq[Episode] =
  ## Reads participant seats from a saved hosted experience response.
  var data: JsonNode
  try:
    data = parseJson(readText(path))
  except JsonParsingError as error:
    raise newException(AwmError, "Invalid XP JSON: " & error.msg)
  for item in data.arrayField("episodes"):
    var episode = Episode(
      request: data.textField("id"),
      id: item.textField("id"),
      job: item.textField("job_id"),
      replay: item.textField("replay_url"),
      policy: policy,
      seat: -1
    )
    for participant in item.arrayField("participants"):
      let position = participant.numberField("position")
      if position notin 0 ..< MaxPlayers:
        raise newException(AwmError, "XP participant position is invalid")
      if position >= episode.labels.len:
        episode.labels.setLen(position + 1)
      episode.labels[position] = participant.textField("player_name") &
        "/" & participant.textField("label")
      if participant.textField("policy_version_id") == policy:
        episode.seat = position
    result.add episode

proc readReplay(path: string): ReplayData =
  ## Loads a compressed or raw hosted replay and checks its format.
  var bytes = readText(path)
  if bytes.len > 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    try:
      bytes = uncompress(bytes, dfGzip)
    except ZippyError as error:
      raise newException(AwmError, "Invalid compressed replay: " & error.msg)
  result = decodeReplayFile(ReplayGame, ReplayGameVersion, bytes, ReplayData)
  result.validate()

proc previousPlayer(game: GameState, seat: int): int =
  ## Finds the living seat whose automatic attacks next threaten this seat.
  for step in 1 .. game.playerCount:
    let candidate = (seat + game.playerCount - step) mod game.playerCount
    if not game.dead(candidate):
      return candidate
  seat

proc boardPower(game: GameState, seat: int): int =
  ## Sums the actual minion power in a seat's public board.
  for minion in game.players[seat].board:
    result += minion.power

proc hailTargets(game: GameState, seat: int): tuple[count, power: int] =
  ## Counts minions that one damage from Hail immediately kills.
  for minion in game.players[seat].board:
    if minion.card.kind == Minion and minion.currentToughness == 1:
      inc result.count
      result.power += minion.power

proc actionLabel(game: GameState, action: ReplayAction): string =
  ## Labels the accepted card or the decision to begin automatic attacks.
  if action.kind == ActionPlayCard:
    game.players[action.playerId.int].hand[action.handIndex.int].name
  else:
    "PASS"

proc hailProxy(
    game: GameState,
    seat, next: int
): tuple[available: bool, hidden: int] =
  ## Counts hidden living minions using only Sharpshooter choice queries.
  for i, card in game.players[seat].hand:
    if card.name != "Sharpshooter":
      continue
    result.available = true
    let choices = game.availableChoices(i)
    var living: array[7, bool]
    for choice in choices:
      if choice.kind == HeroChoice:
        living[choice.owner] = true
    for choice in choices:
      if choice.kind == CreatureChoice and living[choice.owner] and
        choice.owner != seat and choice.owner != next:
          inc result.hidden
    return

proc reportDecision(
    game: GameState,
    action: ReplayAction,
    summary: var Summary,
    details: var int
) =
  ## Reports held cards and hidden threats at an actual policy decision.
  let
    seat = action.playerId.int
    next = game.nextPlayer(seat)
    previous = game.previousPlayer(seat)
    fixed = (seat + game.playerCount - 1) mod game.playerCount
    label = game.actionLabel(action)
    passing = action.kind != ActionPlayCard
    visible = game.hailTargets(next)
    incoming = game.hailTargets(previous)
    proxy = game.hailProxy(seat, next)
  var
    hail = false
    free = 0
    hiddenCount = 0
    hiddenPower = 0
  inc summary.decisions
  for i, card in game.players[seat].hand:
    if game.canPlay(i):
      if card.name == "Hail of Arrows":
        hail = true
      if card.energyCost == 0:
        inc free
  for i in 0 ..< game.playerCount:
    if i != seat and i != next and not game.dead(i):
      let targets = game.hailTargets(i)
      hiddenCount += targets.count
      hiddenPower += targets.power
  if hail:
    inc summary.hailAvailable
    if not proxy.available:
      inc summary.hailProxyUnavailable
    if visible.count == 0 and hiddenCount > 0 and
      label != "Hail of Arrows":
        inc summary.hiddenHailDecisions
        if proxy.available and proxy.hidden > 0:
          inc summary.hiddenProxyDeclines
        if details < DetailLimit:
          echo "  tick ", action.tick, " turn ", game.turnNumber,
            " seat ", seat, " HAIL_DECLINED selected=", label,
            " next=", next, " nextHp1=", visible.count,
            " otherLivingHp1=", hiddenCount,
            " otherKilledPower=", hiddenPower,
            " incomingKilledPower=", incoming.power,
            " queryProxyAvailable=", proxy.available,
            " queryProxyHiddenMinions=", proxy.hidden,
            " energy=", game.players[seat].energy
          inc details
  if passing:
    inc summary.passes
    if free > 0:
      inc summary.freeHeld
      if details < DetailLimit:
        echo "  tick ", action.tick, " turn ", game.turnNumber,
          " seat ", seat, " FREE_HELD count=", free,
          " energy=", game.players[seat].energy
        inc details
    if previous != fixed:
      inc summary.predecessorMismatch
      summary.mismatchIncomingPower += game.boardPower(previous)
      if details < DetailLimit:
        echo "  tick ", action.tick, " turn ", game.turnNumber,
          " seat ", seat, " PREDECESSOR fixed=", fixed,
          " living=", previous, " incomingPower=",
          game.boardPower(previous), " life=", game.players[seat].life
        inc details
    if hail:
      inc summary.hailHeld
      if visible.count == 0 and hiddenCount > 0:
        inc summary.hiddenHail
        summary.hiddenHailPower += hiddenPower
        summary.hiddenIncomingPower += incoming.power
        if details < DetailLimit:
          echo "  tick ", action.tick, " turn ", game.turnNumber,
            " seat ", seat, " HAIL_HELD next=", next,
            " nextHp1=", visible.count, " otherLivingHp1=", hiddenCount,
            " otherKilledPower=", hiddenPower,
            " incomingKilledPower=", incoming.power,
            " energy=", game.players[seat].energy
          inc details
  elif label == "Hail of Arrows":
    inc summary.hailPlayed
    if visible.count == 0 and hiddenCount > 0:
      inc summary.hailPlayedHiddenOnly
    if visible.count + hiddenCount == 0:
      inc summary.hailPlayedNoKills
    if details < DetailLimit:
      echo "  tick ", action.tick, " turn ", game.turnNumber,
        " seat ", seat, " HAIL_PLAYED nextHp1=", visible.count,
        " otherLivingHp1=", hiddenCount,
        " killedPower=", visible.power + hiddenPower,
        " incomingPower=", game.boardPower(previous),
        " life=", game.players[seat].life,
        " energy=", game.players[seat].energy
      inc details

proc reportCard(
    game: GameState,
    action: ReplayAction,
    summary: var Summary,
    details: var int
) =
  ## Reports accepted cards and measurable bounce target costs.
  let
    seat = action.playerId.int
    card = game.players[seat].hand[action.handIndex.int]
    incoming = game.previousPlayer(seat)
    fixed = (seat + game.playerCount - 1) mod game.playerCount
  summary.cards.inc(card.name)
  if card.energyCost == 0:
    inc summary.freePlayed
  case card.name
  of "Bubble":
    inc summary.bubblePlayed
  of "Primordial":
    inc summary.primordialPlayed
  of "Bouncer":
    inc summary.bouncers
    if action.choices.len == 0:
      return
    let pick = action.choices[0].toChoice
    if pick.kind != CreatureChoice:
      return
    let location = game.minionLocation(pick.creatureId)
    if not location.found:
      raise newException(AwmError, "Recorded Bouncer target is absent")
    let target = game.players[location.player].board[location.index]
    if target.power == 0:
      inc summary.bouncerZero
    if location.player == seat:
      inc summary.bouncerOwn
    if target.card.energyCost <= 1:
      inc summary.bouncerLowCost
    if incoming != fixed and location.player == fixed:
      inc summary.bouncerWrongPredecessor
    if details < DetailLimit and
      (target.power == 0 or target.card.energyCost >= 5 or
        (incoming != fixed and location.player == fixed)):
      echo "  tick ", action.tick, " turn ", game.turnNumber,
        " seat ", seat, " BOUNCER targetSeat=", location.player,
        " target=", target.card.name, " power=", target.power,
        " hp=", target.currentToughness,
        " replayCost=", target.card.energyCost,
        " next=", game.nextPlayer(seat), " incoming=", incoming,
        " fixedIncoming=", fixed
      inc details
  else:
    discard

proc inspect(
    path: string,
    episode: Episode,
    explicitSeat: int,
    summaries: var array[HeroClass, Summary]
) =
  ## Reconstructs every accepted action and verifies every hosted hash.
  let data = readReplay(path)
  var
    game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
    check: ReplayHashCheck
    tick = 0'u32
    passed: array[7, bool]
    details = 0
    seat = explicitSeat
  if seat < 0 and episode.seat >= 0:
    seat = episode.seat
  if seat >= game.playerCount:
    raise newException(AwmError, "Candidate seat exceeds replay seats")
  echo path, ": seed=", data.header.setup.seed,
    " classes=", data.header.setup.heroClasses, " candidateSeat=", seat
  if episode.id.len > 0:
    echo "  XP=", episode.request, " episode=", episode.id,
      " job=", episode.job
    for i, label in episode.labels:
      echo "  participant ", i, "=", label
  elif seat < 0:
    echo "  No participant mapping: all-seat diagnostics only."
  for i in 0 ..< game.playerCount:
    if seat < 0 or i == seat:
      inc summaries[game.players[i].heroClass].games
  for action in data.actions:
    let
      actor = action.playerId.int
      selected = seat < 0 or actor == seat
      hero = game.players[actor].heroClass
      decision = action.kind == ActionPlayCard or
        (action.kind in {ActionAttack, ActionEndTurn} and not passed[actor])
    if selected and decision:
      game.reportDecision(action, summaries[hero], details)
    if action.kind in {ActionAttack, ActionEndTurn}:
      passed[actor] = true
    if action.kind == ActionEndTurn:
      passed[actor] = false
    if selected and action.kind == ActionPlayCard:
      game.reportCard(action, summaries[hero], details)
    if not game.applyAction(action):
      raise newException(AwmError, "Refused hosted action at " & $action.tick)
    for event in game.takeVisualEvents():
      if event.kind == BounceVfx and event.card.name == "Bubble" and
        (seat < 0 or event.target.owner == seat):
          let owner = game.players[event.target.owner].heroClass
          inc summaries[owner].bubbleBounced
    tick = action.tick
    data.hashes.checkReplayHash(tick, game.stateHash, check)
  check.requireReplayComplete(tick, data.hashes.len)
  echo "  Verified ticks=", tick, " winnerSeat=", game.winner

proc parseNumber(value, field: string): int =
  ## Parses a checked numeric command-line option.
  try:
    result = parseInt(value)
  except ValueError as error:
    raise newException(AwmError, "Invalid " & field & ": " & error.msg)
  if result < 0:
    raise newException(AwmError, field & " must be nonnegative")

proc findEpisode(path: string, episodes: seq[Episode]): Episode =
  ## Binds UUID-named downloads to their actual hosted participants.
  let name = path.extractFilename.changeFileExt("")
  result.seat = -1
  for episode in episodes:
    if name == episode.id or name == episode.job or
      name == episode.replay.extractFilename.changeFileExt(""):
        return episode

proc printSummary(hero: HeroClass, summary: Summary) =
  ## Prints diagnostic counts without treating them as a policy score.
  echo hero, ": seatReplays=", summary.games,
    " decisions=", summary.decisions, " passes=", summary.passes
  echo "  Hail affordableDecisions=", summary.hailAvailable,
    " played=", summary.hailPlayed, " heldAtPass=", summary.hailHeld,
    " hiddenOnlyDeclinedDecisions=", summary.hiddenHailDecisions,
    " hiddenOnlyHeldAtPass=", summary.hiddenHail,
    " hiddenKilledPower=", summary.hiddenHailPower,
    " incomingKilledPower=", summary.hiddenIncomingPower
  echo "  Predecessor mismatchPasses=", summary.predecessorMismatch,
    " actualIncomingPower=", summary.mismatchIncomingPower
  echo "  Hail playedHiddenOnly=", summary.hailPlayedHiddenOnly,
    " playedWithoutImmediateKills=", summary.hailPlayedNoKills,
    " affordableDecisionsWithoutSharpshooterProxy=",
    summary.hailProxyUnavailable,
    " hiddenOnlyDeclinesWithChoiceProxy=", summary.hiddenProxyDeclines
  echo "  Free cardsPlayed=", summary.freePlayed,
    " heldAtPass=", summary.freeHeld,
    " Bubble played=", summary.bubblePlayed,
    " bounced=", summary.bubbleBounced
  echo "  Bouncer played=", summary.bouncers,
    " targetPower0=", summary.bouncerZero,
    " targetReplayCost<=1=", summary.bouncerLowCost,
    " ownTarget=", summary.bouncerOwn,
    " deadFixedPredecessorTarget=", summary.bouncerWrongPredecessor,
    " Primordial played=", summary.primordialPlayed
  echo "  Cards: ", summary.cards

proc main() =
  ## Analyzes replay paths, optionally bound to saved XP participant metadata.
  var
    paths, xpPaths: seq[string]
    policy = DefaultPolicy
    explicitSeat = -1
    offset = -1
    episodes: seq[Episode]
    summaries: array[HeroClass, Summary]
  for argument in commandLineParams():
    if argument.startsWith("--xp="):
      xpPaths.add argument[5 .. ^1]
    elif argument.startsWith("--policy="):
      policy = argument[9 .. ^1]
    elif argument.startsWith("--seat="):
      explicitSeat = parseNumber(argument[7 .. ^1], "seat")
    elif argument.startsWith("--offset="):
      offset = parseNumber(argument[9 .. ^1], "episode offset")
    else:
      paths.add argument
  if paths.len == 0:
    raise newException(AwmError,
      "Usage: decisions [--xp=FILE] [--policy=UUID] " &
      "[--offset=N | --seat=N] REPLAY...")
  if offset >= 0 and xpPaths.len != 1:
    raise newException(AwmError, "Episode offset requires exactly one XP")
  for path in xpPaths:
    episodes.add readEpisodes(path, policy)
  if offset >= 0 and offset + paths.len > episodes.len:
    raise newException(AwmError, "Episode offset exceeds the saved XP")
  for i, path in paths:
    var episode = path.findEpisode(episodes)
    if offset >= 0:
      episode = episodes[offset + i]
    if episode.id.len > 0 and episode.seat < 0:
      raise newException(AwmError, "Candidate policy absent from " & episode.id)
    inspect(path, episode, explicitSeat, summaries)
  echo "Diagnostics only; opportunity counts are not hosted XP scores."
  for hero in HeroClass:
    if summaries[hero].games > 0:
      printSummary(hero, summaries[hero])

main()
