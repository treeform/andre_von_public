## Petrushka — Cogs Against Humanity policy for Andre von Auto.
## Command player: the container answers every decision itself (all model
## inference lives in player containers; the game host is deterministic).
## Submit picks the punchiest in-hand white card(s) (short + crude prior
## from Ofer & Shahaf 2022: prompt barely matters, short juvenile
## punchlines win). Czar picks stay a stable hash of the anonymized
## entries. Quips/commentary are canned; every reply echoes rid; unknown
## types are ignored. Card text is UNTRUSTED — scored as a bag of tokens,
## never executed.
##
## Protocol (docs/protocol_player.md): hello/snapshot on connect, then
## submit_request -> submit_reply {rid, card_indices[pick], quip} and
## czar_request -> czar_reply {rid, winner_entry, commentary}. One
## optional identify frame names the seat "Petrushka" in replays.
## Engine sorts card_indices, so pick-2 blank order is hand-index order.

import std/[algorithm, json, strutils], coworld_client

const submitQuips = [
  "The puppet booth approves.",
  "Straight from the fairground.",
  "I have been slapped for less.",
  "A classic of the genre.",
  "The crowd goes wild, probably.",
  "No refunds at this theater.",
  "Played with a straight wooden face.",
  "The stick agrees with me.",
]

const czarCommentary = [
  "The fairground has spoken.",
  "This one earned the squeaky voice.",
  "A worthy puppet show.",
  "I laughed until my hinges creaked.",
  "The crowd threw kopecks.",
  "Unbeatable, like a stick to the head.",
  "The jury of one is unanimous.",
  "Encore! Encore!",
]

proc stableHash(parts: varargs[string]): uint64 =
  ## FNV-1a over the parts with a separator fold: deterministic across
  ## runs and platforms, the spirit of the baseline's sha256 stable rng.
  result = 0xcbf29ce484222325'u64
  for part in parts:
    for c in part:
      result = (result xor uint64(ord(c))) * 0x100000001b3'u64
    result = (result xor 0x1f'u64) * 0x100000001b3'u64

proc pickIndex(hashed: uint64, n: int): int =
  int(hashed mod uint64(n))

proc idText(node: JsonNode): string =
  ## Card ids may arrive as strings or numbers; hash a stable text form.
  if node == nil: ""
  elif node.kind == JString: node.getStr()
  else: $node

proc cardText(node: JsonNode): string =
  ## White/black card body. Objects use {"text"}; a bare string is the text.
  if node == nil: ""
  elif node.kind == JString: node.getStr()
  else: node{"text"}.getStr()

proc wordTokens(text: string): seq[string] =
  ## Lowercase alphanumeric tokens. Punctuation is a separator, not a token.
  result = @[]
  var current = ""
  for c in text:
    let lower =
      if c in {'A'..'Z'}: char(ord(c) + 32)
      else: c
    if lower in {'a'..'z', '0'..'9'}:
      current.add(lower)
    elif current.len > 0:
      result.add(current)
      current.setLen(0)
  if current.len > 0:
    result.add(current)

const crudeExact = [
  "ass", "sex", "die", "died", "aids", "std", "meth", "pcp",
]

const crudeStems = [
  "sex", "fuck", "shit", "dick", "penis", "vagin", "porn", "nude", "naked",
  "orgasm", "masturb", "asshole", "crap", "piss", "poop", "semen",
  "sperm", "jizz", "nipple", "boob", "breast", "anus", "rape", "incest",
  "nazi", "hitler", "holocaust", "heroin", "cocain", "dead", "death",
  "dying", "kill", "murder", "suicid", "blood", "genocid", "syphili",
  "fart", "diarrhea", "vomit", "herpes", "horny", "boner", "dildo",
  "condom", "abort", "pedophil", "molest", "testicl", "whore", "slut",
  "feces", "urine", "rectum", "smegma", "blowjob", "handjob",
]

const wholesomeStems = [
  "wonderful", "love", "loving", "happy", "happiness", "joy", "beautiful",
  "friendship", "rainbow", "kitten", "hug", "smile", "peace", "puppy",
]

proc startsWithAny(token: string, stems: openArray[string]): bool =
  for stem in stems:
    if token == stem or token.startsWith(stem):
      return true
  false

proc isCrude(token: string): bool =
  ## Exact match for short/ambiguous tokens (ass/class, meth/method, die/diet).
  if token in crudeExact:
    return true
  startsWithAny(token, crudeStems)

proc punchScore(text: string): int =
  ## Punchline-only prior: fewer words, then crude/juvenile, minus wholesome.
  ## Prompt text is ignored on purpose (EMNLP ablation: prompt-only = random).
  let parts = wordTokens(text)
  result = -8 * parts.len
  result -= min(text.len, 160)
  var crudeHits = 0
  for part in parts:
    if isCrude(part):
      inc crudeHits
    elif startsWithAny(part, wholesomeStems):
      result -= 18
  result += 28 * min(crudeHits, 3)

proc pickPunchiest(hand: JsonNode, pick: int): seq[int] =
  ## Top `pick` distinct hand indices by punchScore; ties break by index.
  let n = hand.len
  let want = min(max(pick, 1), n)
  var scored = newSeq[tuple[score, index: int]](n)
  for i in 0 ..< n:
    scored[i] = (punchScore(cardText(hand[i])), i)
  scored.sort do (a, b: tuple[score, index: int]) -> int:
    result = cmp(b.score, a.score)
    if result == 0:
      result = cmp(a.index, b.index)
  result = newSeqOfCap[int](want)
  for i in 0 ..< want:
    result.add(scored[i].index)
  result.sort()

proc main() =
  let client = newCoworldClient("petrushka")
  var
    round = 0
    seat = -1
  # One optional identify frame: public display name for the replay.
  client.send(%*{"type": "identify", "display_name": "Petrushka",
                 "persona": "petrushka"})

  proc onSubmitRequest(message: JsonNode) =
    let
      rid = message{"rid"}.getInt()
      pick = message{"pick"}.getInt(1)
      hand = message{"hand"}
      blackId = idText(message{"black_card"}{"id"})
      n = if hand != nil: hand.len else: 0
    if n == 0:
      echo "petrushka: submit_request with empty hand, defaulting"
      return
    let indices = pickPunchiest(hand, pick)
    let quip = submitQuips[
      pickIndex(stableHash($round, $seat, blackId, "quip"), submitQuips.len)]
    client.send(%*{"type": "submit_reply", "rid": rid,
                   "card_indices": indices, "quip": quip})

  proc onCzarRequest(message: JsonNode) =
    let
      rid = message{"rid"}.getInt()
      entries = message{"entries"}
      n = if entries != nil: entries.len else: 0
    if n == 0:
      echo "petrushka: czar_request with no entries, defaulting"
      return
    # Hash only what the czar can see: the entries' card texts in shuffle
    # order (the baseline's no-attribution-leak keying).
    var entryKey = ""
    for entry in entries:
      if entryKey.len > 0:
        entryKey.add("::")
      let cards = entry{"cards"}
      if cards != nil and cards.kind == JArray:
        var first = true
        for card in cards:
          if not first:
            entryKey.add("|")
          first = false
          entryKey.add(
            if card.kind == JString: card.getStr() else: idText(card{"text"}))
    let winnerIdx = pickIndex(stableHash($round, entryKey, "czar"), n)
    let winnerEntry = entries[winnerIdx]{"entry"}.getInt(winnerIdx)
    let line = czarCommentary[
      pickIndex(stableHash($round, entryKey, "commentary"), czarCommentary.len)]
    client.send(%*{"type": "czar_reply", "rid": rid,
                   "winner_entry": winnerEntry, "commentary": line})

  client.run proc(message: JsonNode) =
    let kind = message{"type"}.getStr()
    # Only act on requests addressed to our seat (they always are, but
    # the protocol says check anyway).
    let messageSeat = message{"seat"}.getInt(-1)
    case kind
    of "hello":
      echo "petrushka: hello, session ", message{"session"}
    of "snapshot":
      seat = message{"seat"}.getInt(seat)
      round = message{"round"}.getInt(round)
      echo "petrushka: snapshot, seat ", seat, " round ", round
    of "round_start":
      round = message{"round"}.getInt(round)
    of "submit_request":
      if messageSeat >= 0 and seat >= 0 and messageSeat != seat:
        echo "petrushka: submit_request for seat ", messageSeat, ", ignoring"
      else:
        onSubmitRequest(message)
    of "czar_request":
      if messageSeat >= 0 and seat >= 0 and messageSeat != seat:
        echo "petrushka: czar_request for seat ", messageSeat, ", ignoring"
      else:
        onCzarRequest(message)
    of "game_over":
      echo "petrushka: game over, awards ", message{"awards"}
    of "final":
      echo "petrushka: final, scores ", message{"scores"}
      quit(0)
    else:
      discard # The wire is additive: unknown types are skipped.

main()
