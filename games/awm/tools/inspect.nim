import
  std/[os, tables],
  zippy,
  sim, match, replays

proc inspect(path: string) =
  ## Verifies every state hash and reports played cards from a public replay.
  var bytes = readFile(path)
  if bytes.len > 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    try:
      bytes = uncompress(bytes, dfGzip)
    except ZippyError as error:
      raise newException(ReplayError, "Invalid compressed replay: " & error.msg)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, bytes, ReplayData)
  data.validate()
  var
    game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
    check: ReplayHashCheck
    tick = 0'u32
    cards: array[7, CountTable[string]]
  for action in data.actions:
    if action.kind == ActionPlayCard:
      let
        seat = action.playerId.int
        card = game.players[seat].hand[action.handIndex.int]
      cards[seat].inc(card.name)
    doAssert game.applyAction(action), "Refused hosted replay action"
    discard game.takeVisualEvents()
    tick = action.tick
    data.hashes.checkReplayHash(tick, game.stateHash, check)
  check.requireReplayComplete(tick, data.hashes.len)
  echo path.extractFilename, ": seed ", data.header.setup.seed,
    ", classes ", data.header.setup.heroClasses,
    ", verified ticks ", tick, ", winner ", game.winner
  for i in 0 ..< game.playerCount:
    echo "Seat ", i, ": ", cards[i]

proc main() =
  ## Inspects each supplied replay file using the released AWM simulator.
  for path in commandLineParams():
    inspect(path)

main()
