## Sirin — Cognames policy for Andre von Auto.
## Cognames (deployed coworld 0.5.11) seats TWO external players, one
## spymaster per team (slot 0 = RED, slot 1 = BLUE); Sonnet drives the
## operatives inside the game container, so a spymaster is scored purely on
## clue skill. This is the Nim rewrite of the default certification player
## (dist-server/baseline-player.js: a fixed off-board clue for 1) with an
## obviously stronger scripted line: instead of a nonsense word, clue a
## curated common-English association for one of our own uncontacted agents
## (392-entry table covering the full Codenames wordlist), and clue for 2
## when two of our agents share the same association.
##
## Wire protocol: the deployed lineage sits between two documented protocols,
## so Sirin speaks BOTH (see ideas.md, "Protocol confidence"):
##   cogame.player.v1    welcome / observation{id,seat,turn,view} /
##                       reply{id,decision} / final{scores}
##   cognames.player.v1  player_config / state{seq,subsystems} /
##                       submit{payload,seq} / episode_end (legacy)
## Clue legality (mirrors src/shared/reducers.ts giveClue): a single
## letters-only ENGLISH word (an-array-of-english-words; every table entry
## was validated against it), not equal to, a substring of, or a superstring
## of any unrevealed board word. An illegal clue forfeits the turn, so every
## candidate is re-checked against the live board before it is sent.
## No secret envs needed: Sirin is fully scripted (the game runs the LLMs).

import std/[json, strutils, tables], coworld_client

const
  clueTable = [
    ("AFRICA", "safari"), ("AGENT", "espionage"), ("AIR", "breeze"),
    ("ALIEN", "extraterrestrial"), ("AMAZON", "rainforest"), ("ANGEL", "halo"),
    ("ANTARCTICA", "frozen"), ("APPLE", "orchard"), ("ARM", "elbow"),
    ("ATLANTIS", "sunken"), ("AUSTRALIA", "outback"), ("AZTEC", "empire"),
    ("BACK", "rear"), ("BALL", "bounce"), ("BAND", "drummer"),
    ("BANK", "vault"), ("BAR", "tavern"), ("BARK", "growl"),
    ("BAT", "nocturnal"), ("BATTERY", "voltage"), ("BEACH", "sand"),
    ("BEAR", "grizzly"), ("BEAT", "rhythm"), ("BED", "mattress"),
    ("BEIJING", "dynasty"), ("BELL", "chime"), ("BELT", "buckle"),
    ("BERLIN", "autobahn"), ("BERMUDA", "shorts"), ("BERRY", "currant"),
    ("BILL", "invoice"), ("BLOCK", "obstruct"), ("BOARD", "plank"),
    ("BOLT", "thunder"), ("BOMB", "explosion"), ("BOND", "glue"),
    ("BOOM", "sonic"), ("BOOT", "lace"), ("BOTTLE", "cork"),
    ("BOW", "arrow"), ("BOX", "carton"), ("BRIDGE", "span"),
    ("BRUSH", "bristles"), ("BUCK", "doe"), ("BUFFALO", "bison"),
    ("BUG", "beetle"), ("BUGLE", "trumpet"), ("BUTTON", "zipper"),
    ("CALF", "heifer"), ("CANADA", "moose"), ("CAP", "brim"),
    ("CAPITAL", "uppercase"), ("CAR", "sedan"), ("CARD", "poker"),
    ("CARROT", "vegetable"), ("CASINO", "gambling"), ("CAST", "plaster"),
    ("CAT", "kitten"), ("CELL", "nucleus"), ("CENTAUR", "mythology"),
    ("CENTER", "middle"), ("CHAIR", "seat"), ("CHANGE", "coins"),
    ("CHARGE", "electric"), ("CHECK", "chess"), ("CHEST", "ribs"),
    ("CHICK", "hatchling"), ("CHINA", "porcelain"), ("CHOCOLATE", "cocoa"),
    ("CHURCH", "steeple"), ("CIRCLE", "radius"), ("CLIFF", "precipice"),
    ("CLOAK", "invisibility"), ("CLUB", "membership"), ("CODE", "cipher"),
    ("COLD", "shiver"), ("COMIC", "cartoon"), ("COMPOUND", "chemical"),
    ("CONCERT", "orchestra"), ("CONDUCTOR", "baton"), ("CONTRACT", "clause"),
    ("COOK", "chef"), ("COPPER", "penny"), ("COTTON", "fabric"),
    ("COURT", "judge"), ("COVER", "lid"), ("CRANE", "stork"),
    ("CRASH", "collision"), ("CRICKET", "chirp"), ("CROSS", "crucifix"),
    ("CROWN", "tiara"), ("CYCLE", "pedal"), ("DANCE", "waltz"),
    ("DATE", "calendar"), ("DAY", "sunrise"), ("DEATH", "mortality"),
    ("DECK", "shuffle"), ("DEGREE", "diploma"), ("DIAMOND", "jewel"),
    ("DICE", "craps"), ("DINOSAUR", "fossil"), ("DISEASE", "infection"),
    ("DOCTOR", "physician"), ("DOG", "puppy"), ("DRAFT", "conscription"),
    ("DRAGON", "serpent"), ("DRESS", "gown"), ("DRILL", "dentist"),
    ("DROP", "plummet"), ("DUCK", "quack"), ("DWARF", "gnome"),
    ("EAGLE", "talon"), ("EGYPT", "pharaoh"), ("EMBASSY", "diplomat"),
    ("ENGINE", "motor"), ("ENGLAND", "monarchy"), ("EUROPE", "continent"),
    ("EYE", "iris"), ("FACE", "cheek"), ("FAIR", "carnival"),
    ("FALL", "autumn"), ("FAN", "ventilator"), ("FENCE", "picket"),
    ("FIELD", "meadow"), ("FIGHTER", "boxer"), ("FIGURE", "silhouette"),
    ("FILE", "folder"), ("FILM", "cinema"), ("FIRE", "flame"),
    ("FISH", "salmon"), ("FLUTE", "woodwind"), ("FLY", "buzz"),
    ("FOOT", "ankle"), ("FORCE", "gravity"), ("FOREST", "woods"),
    ("FORK", "prong"), ("FRANCE", "baguette"), ("GAME", "tournament"),
    ("GAS", "fumes"), ("GENIUS", "prodigy"), ("GERMANY", "sauerkraut"),
    ("GHOST", "haunt"), ("GIANT", "colossal"), ("GLASS", "shatter"),
    ("GLOVE", "mitten"), ("GOLD", "nugget"), ("GRACE", "elegance"),
    ("GRASS", "lawn"), ("GREECE", "mythology"), ("GREEN", "emerald"),
    ("GROUND", "soil"), ("HAM", "pork"), ("HAND", "fingers"),
    ("HAWK", "falcon"), ("HEAD", "skull"), ("HEART", "cardiac"),
    ("HELICOPTER", "rotor"), ("HIMALAYAS", "altitude"), ("HOLE", "crater"),
    ("HOLLYWOOD", "celebrity"), ("HONEY", "bees"), ("HOOD", "sweatshirt"),
    ("HOOK", "crochet"), ("HORN", "antler"), ("HORSE", "stallion"),
    ("HORSESHOE", "blacksmith"), ("HOSPITAL", "ambulance"), ("HOTEL", "lobby"),
    ("ICE", "glacier"), ("INDIA", "curry"), ("IRON", "forge"),
    ("IVORY", "tusk"), ("JACK", "knave"), ("JAM", "marmalade"),
    ("JET", "turbine"), ("JUPITER", "planet"), ("KANGAROO", "pouch"),
    ("KETCHUP", "mustard"), ("KEY", "ignition"), ("KID", "toddler"),
    ("KING", "throne"), ("KIWI", "fruit"), ("KNIFE", "blade"),
    ("KNIGHT", "armor"), ("LAB", "beaker"), ("LAP", "thigh"),
    ("LASER", "beam"), ("LAWYER", "attorney"), ("LEAD", "graphite"),
    ("LEMON", "citrus"), ("LEPRECHAUN", "clover"), ("LIFE", "existence"),
    ("LIGHT", "lamp"), ("LIMOUSINE", "chauffeur"), ("LINE", "queue"),
    ("LINK", "chain"), ("LION", "mane"), ("LITTER", "garbage"),
    ("LOCH", "lake"), ("LOCK", "combination"), ("LOG", "timber"),
    ("LONDON", "parliament"), ("LUCK", "fortune"), ("MAIL", "envelope"),
    ("MAMMOTH", "prehistoric"), ("MAPLE", "syrup"), ("MARBLE", "sculpture"),
    ("MARCH", "parade"), ("MASS", "kilogram"), ("MATCH", "tinder"),
    ("MERCURY", "thermometer"), ("MEXICO", "taco"), ("MICROSCOPE", "magnify"),
    ("MILLIONAIRE", "wealthy"), ("MINE", "shaft"), ("MINT", "menthol"),
    ("MISSILE", "warhead"), ("MODEL", "runway"), ("MOLE", "burrow"),
    ("MOON", "lunar"), ("MOSCOW", "vodka"), ("MOUNT", "saddle"),
    ("MOUSE", "rodent"), ("MOUTH", "lips"), ("MUG", "ceramic"),
    ("NAIL", "hammer"), ("NEEDLE", "thread"), ("NET", "mesh"),
    ("NIGHT", "evening"), ("NINJA", "stealth"), ("NOTE", "melody"),
    ("NOVEL", "fiction"), ("NURSE", "syringe"), ("NUT", "acorn"),
    ("OCTOPUS", "tentacle"), ("OIL", "petroleum"), ("OLIVE", "martini"),
    ("OLYMPUS", "gods"), ("OPERA", "soprano"), ("ORANGE", "tangerine"),
    ("ORGAN", "kidney"), ("PALM", "coconut"), ("PAN", "skillet"),
    ("PANTS", "trousers"), ("PAPER", "parchment"), ("PARACHUTE", "skydiving"),
    ("PARK", "playground"), ("PART", "portion"), ("PASS", "permit"),
    ("PASTE", "adhesive"), ("PENGUIN", "tuxedo"), ("PHOENIX", "rebirth"),
    ("PIANO", "pianist"), ("PIE", "crust"), ("PILOT", "cockpit"),
    ("PIN", "cushion"), ("PIPE", "plumber"), ("PIRATE", "parrot"),
    ("PISTOL", "holster"), ("PIT", "abyss"), ("PITCH", "tar"),
    ("PLANE", "fuselage"), ("PLATE", "dish"), ("PLATYPUS", "monotreme"),
    ("PLAY", "drama"), ("PLOT", "scheme"), ("POINT", "decimal"),
    ("POISON", "venom"), ("POLE", "arctic"), ("POLICE", "sheriff"),
    ("POOL", "billiards"), ("PORT", "harbor"), ("POST", "stamp"),
    ("POUND", "sterling"), ("PRESS", "journalism"), ("PRINCESS", "royalty"),
    ("PUMPKIN", "gourd"), ("PUPIL", "student"), ("PYRAMID", "sphinx"),
    ("QUEEN", "regal"), ("RABBIT", "hare"), ("RACKET", "tennis"),
    ("RAY", "manta"), ("REVOLUTION", "uprising"), ("RING", "wedding"),
    ("ROBIN", "nest"), ("ROBOT", "android"), ("ROCK", "boulder"),
    ("ROME", "gladiator"), ("ROOT", "turnip"), ("ROSE", "thorn"),
    ("ROULETTE", "wheel"), ("ROUND", "circular"), ("ROW", "paddle"),
    ("RULER", "centimeter"), ("SATELLITE", "orbit"), ("SATURN", "titan"),
    ("SCALE", "weigh"), ("SCHOOL", "classroom"), ("SCIENTIST", "research"),
    ("SCORPION", "stinger"), ("SCREEN", "monitor"), ("SCUBA", "snorkel"),
    ("SEAL", "walrus"), ("SERVER", "waiter"), ("SHADOW", "eclipse"),
    ("SHAKESPEARE", "playwright"), ("SHARK", "fin"), ("SHIP", "vessel"),
    ("SHOE", "sandal"), ("SHOP", "boutique"), ("SHOT", "espresso"),
    ("SINK", "faucet"), ("SKYSCRAPER", "elevator"), ("SLIP", "stumble"),
    ("SLUG", "snail"), ("SMUGGLER", "contraband"), ("SNOW", "blizzard"),
    ("SNOWMAN", "scarf"), ("SOCK", "laundry"), ("SOLDIER", "infantry"),
    ("SOLE", "flounder"), ("SOUND", "acoustic"), ("SPACE", "cosmos"),
    ("SPELL", "wizard"), ("SPIDER", "arachnid"), ("SPIKE", "cleats"),
    ("SPINE", "vertebrae"), ("SPOT", "freckle"), ("SPRING", "coil"),
    ("SPY", "covert"), ("SQUARE", "geometry"), ("STADIUM", "arena"),
    ("STAFF", "employees"), ("STAR", "constellation"), ("STATE", "governor"),
    ("STICK", "twig"), ("STOCK", "shares"), ("STRAW", "haystack"),
    ("STREAM", "brook"), ("STRIKE", "bowling"), ("STRING", "twine"),
    ("SUB", "sandwich"), ("SUIT", "blazer"), ("SUPERHERO", "cape"),
    ("SWING", "pendulum"), ("SWITCH", "lever"), ("TABLE", "furniture"),
    ("TABLET", "aspirin"), ("TAG", "graffiti"), ("TAIL", "wag"),
    ("TAP", "spigot"), ("TEACHER", "professor"), ("TELESCOPE", "astronomy"),
    ("TEMPLE", "shrine"), ("THEATER", "stage"), ("THIEF", "burglar"),
    ("THUMB", "knuckle"), ("TICK", "flea"), ("TIE", "knot"),
    ("TIME", "clock"), ("TOKYO", "sushi"), ("TOOTH", "molar"),
    ("TORCH", "pyre"), ("TOWER", "turret"), ("TRACK", "sprinter"),
    ("TRAIN", "locomotive"), ("TRIANGLE", "trigonometry"), ("TRIP", "journey"),
    ("TRUNK", "elephant"), ("TUBE", "cylinder"), ("TURKEY", "gobble"),
    ("UNICORN", "mythical"), ("VACUUM", "suction"), ("VAN", "camper"),
    ("VET", "clinic"), ("WAKE", "funeral"), ("WALL", "brick"),
    ("WAR", "battle"), ("WASHER", "dryer"), ("WASHINGTON", "president"),
    ("WATCH", "wrist"), ("WATER", "liquid"), ("WAVE", "tsunami"),
    ("WEB", "internet"), ("WELL", "bucket"), ("WHALE", "blubber"),
    ("WHIP", "lash"), ("WIND", "gust"), ("WITCH", "broomstick"),
    ("WORM", "wriggle"), ("YARD", "acre"),
  ]
  fallbackClues = ["oxygen", "cactus", "violin", "tornado", "pancake", "galaxy", "puzzle", "magnet", "candle", "harvest"]

let clueLookup = block:
  var lookup = initTable[string, string]()
  for (target, clue) in clueTable:
    lookup[target] = clue
  lookup

## Clue selection

proc legalClue(candidate: string, unrevealed: seq[string]): bool =
  ## The half of the engine's clue gate we can check locally: letters only,
  ## and not equal to / a substring of / a superstring of any unrevealed
  ## board word. (The English-dictionary half is guaranteed by the table.)
  if candidate.len == 0:
    return false
  for letter in candidate:
    if letter notin {'a' .. 'z', 'A' .. 'Z'}:
      return false
  let word = candidate.toUpperAscii()
  for boardWord in unrevealed:
    if word == boardWord or boardWord.contains(word) or word.contains(boardWord):
      return false
  true

proc clueDecision(view: JsonNode): tuple[word: string, number: int, why: string] =
  ## Pick the curated association hinting at the most of our own uncontacted
  ## agents; clue for that many. Our team is the active team: only the
  ## active team's spymaster is ever asked to clue.
  let team = view{"activeTeam"}.getStr()
  var unrevealed: seq[string]
  var ownWords: seq[string]
  for card in view{"board"}:
    if not card{"revealed"}.getBool():
      let word = card{"word"}.getStr().toUpperAscii()
      unrevealed.add(word)
      if card{"role"}.getStr() == team:
        ownWords.add(word)
  var counts = initOrderedTable[string, tuple[count: int, targets: seq[string]]]()
  for word in ownWords:
    if word in clueLookup:
      let candidate = clueLookup[word]
      if candidate in counts:
        counts[candidate].count.inc()
        counts[candidate].targets.add(word)
      else:
        counts[candidate] = (1, @[word])
  var bestWord = ""
  var bestCount = 0
  var bestTargets: seq[string]
  for candidate, entry in counts:
    if entry.count > bestCount and legalClue(candidate, unrevealed):
      bestWord = candidate
      bestCount = entry.count
      bestTargets = entry.targets
  if bestWord != "":
    return (bestWord, bestCount, "sirin: hinting " & bestTargets.join(", "))
  for candidate in fallbackClues:
    if legalClue(candidate, unrevealed):
      return (candidate, 1, "sirin: no safe association, off-board clue")
  ("oxygen", 1, "sirin: last-resort clue")

proc guessDecision(view: JsonNode): tuple[stop: bool, word: string] =
  ## Defensive only: deployed cognames never seats us as an operative, but
  ## the 4-slot protocol variant documented on main does. Mirror the
  ## baseline operative: guess once (first uncontacted card), then stop.
  if view{"guessesMadeThisTurn"}.getInt() >= 1:
    return (true, "")
  for card in view{"board"}:
    if not card{"revealed"}.getBool():
      return (false, card{"word"}.getStr())
  (true, "")

## Wire protocol

proc decideFromView(view: JsonNode): JsonNode =
  ## cogame.player.v1 decision for the seat's redacted view: a bare clue
  ## object in the clue phase, a tagged guess/stop in the guess phase.
  if view{"phase"}.getStr() == "clue":
    let (word, number, why) = clueDecision(view)
    result = %*{"word": word, "number": number, "reasoning": why}
  else:
    let (stop, word) = guessDecision(view)
    if stop:
      result = %*{"kind": "stop", "reasoning": "sirin: stopping"}
    else:
      result = %*{"kind": "guess", "word": word, "reasoning": "sirin: forced guess"}

proc submitFromState(message: JsonNode): JsonNode =
  ## Legacy cognames.player.v1: act only when awaitingAction is set.
  let subsystems = message{"subsystems"}
  if subsystems.isNil:
    return nil
  let awaiting = subsystems{"pending"}{"awaitingAction"}
  if awaiting.isNil or awaiting.kind != JObject:
    return nil
  let view = subsystems{"view"}
  var payload: JsonNode
  if awaiting{"kind"}.getStr() == "clue":
    let (word, number, why) = clueDecision(view)
    payload = %*{"kind": "clue", "word": word, "number": number, "reasoning": why}
  else:
    let canStop = awaiting{"canStop"}.getBool()
    let (stop, word) = guessDecision(view)
    if stop and canStop:
      payload = %*{"kind": "stop", "reasoning": "sirin: stopping"}
    elif word != "":
      payload = %*{"kind": "guess", "word": word, "reasoning": "sirin: forced guess"}
    else:
      payload = %*{"kind": "stop", "reasoning": "sirin: nothing to guess"}
  %*{"type": "submit", "payload": payload, "seq": message{"seq"}.getInt()}

proc main() =
  let client = newCoworldClient("sirin")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome", "player_config":
      echo "sirin: seated slot ", message{"slot"}.getInt(),
        " protocol ", message{"protocol"}.getStr()
    of "observation":
      let decision = decideFromView(message{"view"})
      client.send(%*{"type": "reply", "id": message{"id"}.getInt(),
                     "decision": decision})
    of "state":
      let submit = submitFromState(message)
      if submit != nil:
        client.send(submit)
    of "final", "episode_end":
      echo "sirin: final, scores ", message{"scores"}
      quit(0)
    of "error":
      echo "sirin: server error: ", message{"error"}.getStr()
    else:
      discard

main()
