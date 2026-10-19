## Vendored unchanged from ~/p/terra src/terra/nodes.nim at commit
## 8869f83 (terra:v268 champion lineage). Only edit: this header.
import
  std/[algorithm, sequtils, sets, strutils]

when defined(release):
  {.push checks: off.}

const
  Rows* = 3
  Cols* = 5
  NumSpaces* = Rows * Cols
  TotalRounds* = 14
  HandSize* = 7
  NoPlayer* = -1
  NoSpace* = -1
  MaxFamily* = 5
  MaxStables* = 4
  MaxFences* = 15
  MaxLegalMoves* = 128
  HEdgeCount* = (Rows + 1) * Cols
  VEdgeCount* = Rows * (Cols + 1)
  VEdgeBase* = HEdgeCount
  NumEdges* = HEdgeCount + VEdgeCount
  HarvestRounds* = [4, 7, 9, 11, 13, 14]
  EdgeCells = block:
    var cells: array[NumEdges, tuple[a, b: int]]
    for edge in 0 ..< NumEdges:
      if edge < VEdgeBase:
        let
          row = edge div Cols
          col = edge mod Cols
        cells[edge].a =
          if row - 1 >= 0:
            (row - 1) * Cols + col
          else:
            NoSpace
        cells[edge].b =
          if row < Rows:
            row * Cols + col
          else:
            NoSpace
      else:
        let
          offset = edge - VEdgeBase
          row = offset div (Cols + 1)
          col = offset mod (Cols + 1)
        cells[edge].a =
          if col - 1 >= 0:
            row * Cols + col - 1
          else:
            NoSpace
        cells[edge].b =
          if col < Cols:
            row * Cols + col
          else:
            NoSpace
    cells
  CellEdges = block:
    var edges: array[NumSpaces, array[4, int]]
    for space in 0 ..< NumSpaces:
      let
        row = space div Cols
        col = space mod Cols
      edges[space] = [
        row * Cols + col,
        (row + 1) * Cols + col,
        VEdgeBase + row * (Cols + 1) + col,
        VEdgeBase + row * (Cols + 1) + col + 1
      ]
    edges

type
  SolverError* = object of CatchableError
  Resource* = enum
    Wood, Clay, Reed, Stone, Grain, Vegetable, Food
  Animal* = enum
    Sheep, Boar, Cattle
  FarmKind* = enum
    Empty, Room, Field
  Crop* = enum
    NoCrop, GrainCrop, VegetableCrop
  HouseMaterial* = enum
    HouseWood, HouseClay, HouseStone
  Phase* = enum
    Work, Feeding, Finished
  ActionId* = enum
    FarmExpansion, MeetingPlace, GrainSeeds, Farmland, Lessons,
    DayLaborer, Forest, ClayPit, ReedBank, Fishing, Copse, Grove,
    Hollow, QuarryStall, ResourceMarket, TravelingPlayers, LessonsB,
    RImprovement, RSheep, RFences, RSowBake, RWestQuarry,
    RRenovateImprove, RFamilyGrowth, RVegetable, RBoar, REastQuarry,
    RCattle, RUrgentFamily, RCultivation, RRedevelop
  ImprovementKind* = enum
    NoImprovement, MajorImprovement, MinorImprovement
  MoveKind* = enum
    PlacementMove, FeedingMove
  CardId* = enum
    NoCard,
    MajFireplace2, MajFireplace3, MajHearth4, MajHearth5,
    MajClayOven, MajStoneOven, MajJoinery, MajPottery,
    MajBasketmaker, MajWell,
    OccLumberjack, OccClayDigger, OccReedGatherer,
    OccQuarryman, OccAngler, OccSeasonalHand, OccPeddler,
    OccGreengrocer, OccQuarryForeman, OccShepherdsFriend,
    OccWayfarer, OccButcher, OccCharcutier, OccMuttonCook,
    OccFieldCook, OccBaker, OccMiller, OccPlowwright,
    OccFurrowMaster, OccStablemaster, OccSwineherd, OccCowherd,
    OccShepherd, OccCarpenter, OccBricklayer, OccMason,
    OccThatcher, OccHedgeWarden, OccStableBoy, OccMidwife,
    OccPatriarch, OccForager, OccGleaner, OccMilkman,
    OccCheesemaker, OccSwineKeeper, OccGrainSteward,
    OccWaterCarrier, OccWoodward, OccVagrant, OccJourneyman,
    OccSeedMerchant, OccVegPeddler, OccSchoolmaster, OccElder,
    OccSurveyor, OccAnimalBreeder, OccMasterBuilder,
    OccHorticulturist, OccCompostCarter, OccFenceHand,
    MinWoodenPlow, MinHeavyPlow, MinHearthStones,
    MinDoughTrough, MinCookingCorner, MinSmokehouse, MinStewpot,
    MinAnimalPen, MinPigSty, MinCattleShed, MinSheepFold,
    MinPaddock, MinCarpPond, MinReedPond, MinClayDeposit,
    MinWoodCache, MinSeedStock, MinWoodCart, MinClayPitClaim,
    MinMarketStall, MinStoneCart, MinThreshingBoard,
    MinFishWeir, MinHandcart, MinShepherdsCrook, MinPigTrough,
    MinCattleProd, MinTimberYard, MinClayWorks, MinStoneYard,
    MinFencePosts, MinHerbGarden, MinMilkPail,
    MinShearingShears, MinDryingShed, MinDovecote, MinRainBarrel,
    MinCradle, MinToyChest, MinCarvedChest, MinPewterJug,
    MinGabledHouse, MinGrainLoft, MinRootCellar,
    MinHuntingTrophies, MinScarecrow, MinWellBucket,
    MinLendingCart, MinTravelingTinker, MinSeedSwap

  ResourceCounts* = array[Resource, int]
  AnimalCounts* = array[Animal, int]
  EdgeId* = int
  EdgeMask* = uint64
  CellSet* = uint16

  Goods* = object
    resources*: ResourceCounts
    animals*: AnimalCounts

  FarmSpace* = object
    kind*: FarmKind
    stable*: bool
    crop*: Crop
    cropCount*: int

  FamilyMember* = object
    bornRound*: int
    placed*: bool

  ScheduledGoods* = object
    round*: int
    playerIdx*: int
    goods*: Goods

  ActionSpace* = object
    id*: ActionId
    occupiedBy*: int
    pile*: Goods

  PlayerState* = object
    idx*: int
    resources*: ResourceCounts
    animals*: AnimalCounts
    spaces*: array[NumSpaces, FarmSpace]
    fences*: seq[EdgeId]
    fencesBuilt*: int
    houseMaterial*: HouseMaterial
    family*: seq[FamilyMember]
    beggingCards*: int
    startingPlayerMarker*: bool
    handOccupations*: seq[CardId]
    handMinors*: seq[CardId]
    occupations*: seq[CardId]
    minors*: seq[CardId]
    majors*: seq[CardId]

  GameState* = object
    seed*: int
    numPlayers*: int
    solo*: bool
    round*: int
    phase*: Phase
    startingPlayer*: int
    currentPlayer*: int
    toFeed*: seq[int]
    actionSpaces*: seq[ActionSpace]
    roundDeck*: seq[ActionId]
    majorsAvailable*: seq[CardId]
    scheduled*: seq[ScheduledGoods]
    players*: seq[PlayerState]
    scores*: seq[int]

  SpaceDef* = object
    id*: ActionId
    accumulates*: Goods
    fixedGoods*: Goods
    stage*: int

  BakePower* = object
    perGrain*: int
    maxGrain*: int

  HarvestFood* = object
    resource*: Resource
    food*: int
    maxCount*: int

  SowChoice* = object
    space*: int
    crop*: Crop

  BakeChoice* = object
    card*: CardId
    grain*: int

  ImprovementChoice* = object
    kind*: ImprovementKind
    card*: CardId
    bake*: seq[BakeChoice]

  FeedConversion* = object
    via*: CardId
    resource*: Resource
    animal*: Animal
    usesAnimal*: bool
    count*: int

  FeedDecision* = object
    conversions*: seq[FeedConversion]

  FeedingRisk* = object
    foodNeeded*: int
    food*: int
    foodGap*: int
    begging*: int
    animalsCooked*: AnimalCounts
    totalAnimalsCooked*: int
    animalScoreLoss*: int

  Move* = object
    kind*: MoveKind
    playerIdx*: int
    action*: ActionId
    rooms*: seq[int]
    stables*: seq[int]
    fields*: seq[int]
    plow*: int
    sow*: seq[SowChoice]
    bake*: seq[BakeChoice]
    edges*: seq[EdgeId]
    occupation*: CardId
    improvement*: ImprovementChoice
    feed*: FeedDecision

  MoveBuffer* = object
    len*: int
    moves*: array[MaxLegalMoves, Move]

  GameNode* = object
    state*: GameState
    move*: Move
    depth*: int
    value*: float

  Pasture* = object
    cells*: array[NumSpaces, int]
    cellMask*: CellSet
    cellCount*: int
    stables*: int
    capacity*: int

  PastureLayout* = object
    pastures*: array[NumSpaces, Pasture]
    pastureCount*: int
    pastureCells*: CellSet

  FencePlan* = object
    edges*: seq[EdgeId]
    cost*: int
    cellCount*: int
    cells*: seq[int]

  FenceCandidate = object
    cellMask: CellSet
    edgeMask: EdgeMask
    cellCount: int

  CapacitySlot* = object
    typed*: bool
    animal*: Animal
    capacity*: int

  AnimalHolding* = object
    retained*: AnimalCounts
    total*: int

  Rng* = object
    state*: uint32

const
  MajorCards* = [
    MajFireplace2, MajFireplace3, MajHearth4, MajHearth5,
    MajClayOven, MajStoneOven, MajJoinery, MajPottery,
    MajBasketmaker, MajWell
  ]
  OccupationCards* = [
    OccLumberjack, OccClayDigger, OccReedGatherer,
    OccQuarryman, OccAngler, OccSeasonalHand, OccPeddler,
    OccGreengrocer, OccQuarryForeman, OccShepherdsFriend,
    OccWayfarer, OccButcher, OccCharcutier, OccMuttonCook,
    OccFieldCook, OccBaker, OccMiller, OccPlowwright,
    OccFurrowMaster, OccStablemaster, OccSwineherd, OccCowherd,
    OccShepherd, OccCarpenter, OccBricklayer, OccMason,
    OccThatcher, OccHedgeWarden, OccStableBoy, OccMidwife,
    OccPatriarch, OccForager, OccGleaner, OccMilkman,
    OccCheesemaker, OccSwineKeeper, OccGrainSteward,
    OccWaterCarrier, OccWoodward, OccVagrant, OccJourneyman,
    OccSeedMerchant, OccVegPeddler, OccSchoolmaster, OccElder,
    OccSurveyor, OccAnimalBreeder, OccMasterBuilder,
    OccHorticulturist, OccCompostCarter, OccFenceHand
  ]
  MinorCards* = [
    MinWoodenPlow, MinHeavyPlow, MinHearthStones,
    MinDoughTrough, MinCookingCorner, MinSmokehouse, MinStewpot,
    MinAnimalPen, MinPigSty, MinCattleShed, MinSheepFold,
    MinPaddock, MinCarpPond, MinReedPond, MinClayDeposit,
    MinWoodCache, MinSeedStock, MinWoodCart, MinClayPitClaim,
    MinMarketStall, MinStoneCart, MinThreshingBoard, MinFishWeir,
    MinHandcart, MinShepherdsCrook, MinPigTrough, MinCattleProd,
    MinTimberYard, MinClayWorks, MinStoneYard, MinFencePosts,
    MinHerbGarden, MinMilkPail, MinShearingShears, MinDryingShed,
    MinDovecote, MinRainBarrel, MinCradle, MinToyChest,
    MinCarvedChest, MinPewterJug, MinGabledHouse, MinGrainLoft,
    MinRootCellar, MinHuntingTrophies, MinScarecrow, MinWellBucket,
    MinLendingCart, MinTravelingTinker, MinSeedSwap
  ]
  CellBits = block:
    var bits: array[NumSpaces, CellSet]
    for cell in 0 ..< NumSpaces:
      bits[cell] = CellSet(1) shl cell
    bits
  EdgeBits = block:
    var bits: array[NumEdges, EdgeMask]
    for edge in 0 ..< NumEdges:
      bits[edge] = EdgeMask(1) shl edge
    bits
  CellNeighborMasks = block:
    var masks: array[NumSpaces, CellSet]
    for space in 0 ..< NumSpaces:
      let
        row = space div Cols
        col = space mod Cols
      if row > 0:
        masks[space] = masks[space] or CellBits[(row - 1) * Cols + col]
      if row < Rows - 1:
        masks[space] = masks[space] or CellBits[(row + 1) * Cols + col]
      if col > 0:
        masks[space] = masks[space] or CellBits[row * Cols + col - 1]
      if col < Cols - 1:
        masks[space] = masks[space] or CellBits[row * Cols + col + 1]
    masks
  FenceCandidateCount = (Rows * (Rows + 1) div 2) *
    (Cols * (Cols + 1) div 2)
  FenceCandidates = block:
    var
      candidates: array[FenceCandidateCount, FenceCandidate]
      index = 0
    for row1 in 0 ..< Rows:
      for row2 in row1 ..< Rows:
        for col1 in 0 ..< Cols:
          for col2 in col1 ..< Cols:
            var
              candidate: FenceCandidate
              counts: array[NumEdges, int]
            for row in row1 .. row2:
              for col in col1 .. col2:
                let cell = row * Cols + col
                candidate.cellMask = candidate.cellMask or CellBits[cell]
                inc candidate.cellCount
                for edge in CellEdges[cell]:
                  inc counts[edge]
            for edge in 0 ..< NumEdges:
              if counts[edge] == 1:
                candidate.edgeMask = candidate.edgeMask or EdgeBits[edge]
            candidates[index] = candidate
            inc index
    candidates

proc fail(message: string) {.raises: [SolverError].} =
  ## Raises a solver-specific exception.
  raise newException(SolverError, message)

proc req(condition: bool, message: string) {.raises: [SolverError].} =
  ## Raises when one game-rule precondition is not met.
  if not condition:
    fail(message)

proc clear*(moves: var MoveBuffer) {.inline.} =
  ## Clears a reusable move buffer without reallocating.
  moves.len = 0

proc add*(moves: var MoveBuffer, move: Move) {.raises: [SolverError].} =
  ## Appends one move to a fixed legal-move buffer.
  if moves.len >= MaxLegalMoves:
    fail("Legal move buffer overflow.")
  moves.moves[moves.len] = move
  inc moves.len

proc toSeq*(moves: var MoveBuffer): seq[Move] =
  ## Copies buffered moves into a sequence for compatibility callers.
  result = newSeqOfCap[Move](moves.len)
  for i in 0 ..< moves.len:
    result.add moves.moves[i]

proc copy*(player: PlayerState): PlayerState =
  ## Copies one player so child nodes do not alias parent state.
  result = player

proc copy*(state: GameState): GameState =
  ## Copies one game state for independent node expansion.
  result = state

proc initRng*(seed: int): Rng =
  ## Creates the same mulberry32 random source as Agricogla.
  result.state = uint32(seed)

proc nextU32(rng: var Rng): uint32 =
  ## Returns the next mulberry32 value.
  rng.state += 0x6D2B_79F5'u32
  var t = rng.state
  t = (t xor (t shr 15)) * (t or 1'u32)
  t = t xor (t + ((t xor (t shr 7)) * (t or 61'u32)))
  t xor (t shr 14)

proc randInt*(rng: var Rng, limit: int): int =
  ## Returns a deterministic integer in 0 ..< limit.
  if limit <= 0:
    return 0
  int((uint64(rng.nextU32()) * uint64(limit)) shr 32)

proc shuffled*[T](rng: var Rng, input: openArray[T]): seq[T] =
  ## Returns a shuffled copy of one array-like input.
  result = @[]
  for item in input:
    result.add item
  if result.len <= 1:
    return
  for i in countdown(result.high, 1):
    let j = rng.randInt(i + 1)
    swap result[i], result[j]

proc resourceName*(resource: Resource): string =
  ## Returns the Agricogla protocol name for one resource.
  case resource
  of Wood:
    "wood"
  of Clay:
    "clay"
  of Reed:
    "reed"
  of Stone:
    "stone"
  of Grain:
    "grain"
  of Vegetable:
    "vegetable"
  of Food:
    "food"

proc animalName*(animal: Animal): string =
  ## Returns the Agricogla protocol name for one animal.
  case animal
  of Sheep:
    "sheep"
  of Boar:
    "boar"
  of Cattle:
    "cattle"

proc actionName*(action: ActionId): string =
  ## Returns the Agricogla protocol id for one action space.
  case action
  of FarmExpansion:
    "farm_expansion"
  of MeetingPlace:
    "meeting_place"
  of GrainSeeds:
    "grain_seeds"
  of Farmland:
    "farmland"
  of Lessons:
    "lessons"
  of DayLaborer:
    "day_laborer"
  of Forest:
    "forest"
  of ClayPit:
    "clay_pit"
  of ReedBank:
    "reed_bank"
  of Fishing:
    "fishing"
  of Copse:
    "copse"
  of Grove:
    "grove"
  of Hollow:
    "hollow"
  of QuarryStall:
    "quarry_stall"
  of ResourceMarket:
    "resource_market"
  of TravelingPlayers:
    "traveling_players"
  of LessonsB:
    "lessons_b"
  of RImprovement:
    "r_improvement"
  of RSheep:
    "r_sheep"
  of RFences:
    "r_fences"
  of RSowBake:
    "r_sow_bake"
  of RWestQuarry:
    "r_west_quarry"
  of RRenovateImprove:
    "r_renovate_improve"
  of RFamilyGrowth:
    "r_family_growth"
  of RVegetable:
    "r_vegetable"
  of RBoar:
    "r_boar"
  of REastQuarry:
    "r_east_quarry"
  of RCattle:
    "r_cattle"
  of RUrgentFamily:
    "r_urgent_family"
  of RCultivation:
    "r_cultivation"
  of RRedevelop:
    "r_redevelop"

proc add*(target: var Goods, extra: Goods) =
  ## Adds all goods in extra to target.
  for resource in Resource:
    target.resources[resource] += extra.resources[resource]
  for animal in Animal:
    target.animals[animal] += extra.animals[animal]

proc goods*(resource: Resource, count: int): Goods =
  ## Creates one resource bundle.
  result.resources[resource] = count

proc animalGoods*(animal: Animal, count: int): Goods =
  ## Creates one animal bundle.
  result.animals[animal] = count

proc totalAnimals*(animals: AnimalCounts): int =
  ## Counts all animals in an animal array.
  for animal in Animal:
    result += animals[animal]

proc goodsText*(goods: Goods): string =
  ## Formats goods for debug output.
  var parts: seq[string]
  for resource in Resource:
    let count = goods.resources[resource]
    if count > 0:
      parts.add $count & " " & resource.resourceName()
  for animal in Animal:
    let count = goods.animals[animal]
    if count > 0:
      parts.add $count & " " & animal.animalName()
  if parts.len == 0:
    return "nothing"
  parts.join(", ")

proc spaceIndex*(row, col: int): int =
  ## Returns the flat farmyard index for one row and column.
  row * Cols + col

proc rowOf*(space: int): int =
  ## Returns the farmyard row for one flat space index.
  space div Cols

proc colOf*(space: int): int =
  ## Returns the farmyard column for one flat space index.
  space mod Cols

proc hEdge*(row, col: int): EdgeId =
  ## Returns the horizontal edge id above one row.
  row * Cols + col

proc vEdge*(row, col: int): EdgeId =
  ## Returns the vertical edge id left of one column.
  VEdgeBase + row * (Cols + 1) + col

proc edgeName*(edge: EdgeId): string =
  ## Returns the TypeScript/server string for one edge id.
  if edge >= 0 and edge < VEdgeBase:
    let
      row = edge div Cols
      col = edge mod Cols
    return "h-" & $row & "-" & $col
  if edge >= VEdgeBase and edge < NumEdges:
    let
      offset = edge - VEdgeBase
      row = offset div (Cols + 1)
      col = offset mod (Cols + 1)
    return "v-" & $row & "-" & $col
  "edge-" & $edge

proc parseSmallUInt(value: string, pos: var int): int =
  ## Parses one unsigned integer inside a compact edge id.
  result = -1
  if pos >= value.len or value[pos] < '0' or value[pos] > '9':
    return
  result = 0
  while pos < value.len and value[pos] >= '0' and value[pos] <= '9':
    result = result * 10 + ord(value[pos]) - ord('0')
    inc pos

proc parseEdgeId*(value: string): tuple[ok: bool, edge: EdgeId] =
  ## Parses one TypeScript/server edge id into the solver representation.
  if value.len < 5 or value[1] != '-':
    return
  var pos = 2
  let row = parseSmallUInt(value, pos)
  if row < 0 or pos >= value.len or value[pos] != '-':
    return
  inc pos
  let col = parseSmallUInt(value, pos)
  if col < 0 or pos != value.len:
    return
  case value[0]
  of 'h':
    if row >= 0 and row <= Rows and col >= 0 and col < Cols:
      return (true, hEdge(row, col))
  of 'v':
    if row >= 0 and row < Rows and col >= 0 and col <= Cols:
      return (true, vEdge(row, col))
  else:
    discard

proc allEdges*(): seq[EdgeId] =
  ## Returns every valid farmyard edge id.
  for edge in 0 ..< NumEdges:
    result.add edge

proc isValidEdge*(edge: EdgeId): bool =
  ## Returns true when one edge id is inside the farmyard grid.
  edge >= 0 and edge < NumEdges

proc contains*(cells: CellSet, cell: int): bool {.inline.} =
  ## Returns true when a farmyard cell is marked.
  cell >= 0 and cell < NumSpaces and
    (cells and CellBits[cell]) != CellSet(0)

proc incl*(cells: var CellSet, cell: int) {.inline.} =
  ## Marks one farmyard cell when it is inside the board.
  if cell >= 0 and cell < NumSpaces:
    cells = cells or CellBits[cell]

proc intersects(cells, other: CellSet): bool {.inline.} =
  ## Returns true when two farmyard cell masks overlap.
  (cells and other) != CellSet(0)

proc countEdges(mask: EdgeMask): int {.inline.} =
  ## Counts marked edge bits.
  var remaining = mask
  while remaining != EdgeMask(0):
    remaining = remaining and (remaining - EdgeMask(1))
    inc result

proc edgeMaskOf(fences: seq[EdgeId]): tuple[ok: bool, mask: EdgeMask] =
  ## Converts a fence sequence into a compact edge mask.
  result.ok = true
  for edge in fences:
    if not edge.isValidEdge():
      result.ok = false
      return
    result.mask = result.mask or EdgeBits[edge]

proc maskEdges(mask: EdgeMask): seq[EdgeId] =
  ## Converts an edge mask to a sorted edge sequence.
  for edge in 0 ..< NumEdges:
    if (mask and EdgeBits[edge]) != EdgeMask(0):
      result.add edge

proc edgesOfCell*(space: int): array[4, EdgeId] {.inline.} =
  ## Returns the four edge ids around one farmyard cell.
  CellEdges[space]

proc cellsOfEdge*(edge: EdgeId): tuple[a, b: int]
    {.inline, raises: [SolverError].} =
  ## Returns the two cells touching an edge, using -1 for the exterior.
  if not edge.isValidEdge():
    fail("Invalid edge id: " & edge.edgeName())
  EdgeCells[edge]

proc neighborsOf*(space: int): seq[int] =
  ## Returns orthogonal farmyard neighbors of one space.
  let
    row = rowOf(space)
    col = colOf(space)
  if row > 0:
    result.add spaceIndex(row - 1, col)
  if row < Rows - 1:
    result.add spaceIndex(row + 1, col)
  if col > 0:
    result.add spaceIndex(row, col - 1)
  if col < Cols - 1:
    result.add spaceIndex(row, col + 1)

proc computePastures*(spaces: array[NumSpaces, FarmSpace], fences: EdgeMask):
    PastureLayout =
  ## Computes enclosed pasture regions from a compact fence mask.
  if fences == EdgeMask(0):
    return
  var
    outside: CellSet
    stack: array[NumSpaces, int]
    stackLen = 0
  for cell in 0 ..< NumSpaces:
    for edge in CellEdges[cell]:
      if (fences and EdgeBits[edge]) != EdgeMask(0):
        continue
      let edgeCells = EdgeCells[edge]
      if edgeCells.a == NoSpace or edgeCells.b == NoSpace:
        if (outside and CellBits[cell]) == CellSet(0):
          outside = outside or CellBits[cell]
          stack[stackLen] = cell
          inc stackLen
        break
  while stackLen > 0:
    dec stackLen
    let cell = stack[stackLen]
    for edge in CellEdges[cell]:
      if (fences and EdgeBits[edge]) != EdgeMask(0):
        continue
      let edgeCells = EdgeCells[edge]
      let neighbor =
        if edgeCells.a == cell:
          edgeCells.b
        else:
          edgeCells.a
      if neighbor == NoSpace:
        continue
      if (outside and CellBits[neighbor]) == CellSet(0):
        outside = outside or CellBits[neighbor]
        stack[stackLen] = neighbor
        inc stackLen
  var assigned = outside
  for start in 0 ..< NumSpaces:
    if (assigned and CellBits[start]) != CellSet(0):
      continue
    var
      regionMask: CellSet
      regionCount = 0
    assigned = assigned or CellBits[start]
    regionMask = regionMask or CellBits[start]
    stack[0] = start
    stackLen = 1
    while stackLen > 0:
      dec stackLen
      let cell = stack[stackLen]
      for edge in CellEdges[cell]:
        if (fences and EdgeBits[edge]) != EdgeMask(0):
          continue
        let edgeCells = EdgeCells[edge]
        let neighbor =
          if edgeCells.a == cell:
            edgeCells.b
          else:
            edgeCells.a
        if neighbor == NoSpace:
          continue
        if (assigned and CellBits[neighbor]) == CellSet(0):
          assigned = assigned or CellBits[neighbor]
          regionMask = regionMask or CellBits[neighbor]
          stack[stackLen] = neighbor
          inc stackLen
    var pasture = Pasture(
      cellMask: regionMask
    )
    var cellIndex = 0
    for cell in 0 ..< NumSpaces:
      if (regionMask and CellBits[cell]) == CellSet(0):
        continue
      pasture.cells[cellIndex] = cell
      inc cellIndex
      inc regionCount
      if spaces[cell].stable:
        pasture.stables += 1
    pasture.cellCount = regionCount
    pasture.capacity = 2 * pasture.cellCount * (1 shl pasture.stables)
    result.pastureCells = result.pastureCells or pasture.cellMask
    result.pastures[result.pastureCount] = pasture
    inc result.pastureCount

proc computePastures*(spaces: array[NumSpaces, FarmSpace], fences: seq[EdgeId]):
    PastureLayout {.raises: [SolverError].} =
  ## Computes enclosed pasture regions from the current fence set.
  let mask = fences.edgeMaskOf()
  if not mask.ok:
    fail("Invalid edge id in fence set.")
  computePastures(spaces, mask.mask)

proc bordersPasture(edge: EdgeId, layout: PastureLayout): bool
    {.raises: [SolverError].} =
  ## Returns true when an edge touches any enclosed pasture cell.
  if not edge.isValidEdge():
    fail("Invalid edge id: " & edge.edgeName())
  let cells = EdgeCells[edge]
  (
    cells.a != NoSpace and
      (layout.pastureCells and CellBits[cells.a]) != CellSet(0)
  ) or (
    cells.b != NoSpace and
      (layout.pastureCells and CellBits[cells.b]) != CellSet(0)
  )

proc validateFenceMask(
  player: PlayerState,
  existing,
  newMask: EdgeMask,
  newCount: int,
  before: PastureLayout
): bool {.raises: [SolverError].} =
  ## Returns true when a compact new fence mask can be added.
  if newCount == 0:
    return false
  if player.fencesBuilt + newCount > MaxFences:
    return false
  if (existing and newMask) != EdgeMask(0):
    return false
  let combined = existing or newMask
  let layout = computePastures(player.spaces, combined)
  if layout.pastureCount == 0:
    return false
  for i in 0 ..< layout.pastureCount:
    let pasture = layout.pastures[i]
    for j in 0 ..< pasture.cellCount:
      let cell = pasture.cells[j]
      if player.spaces[cell].kind != Empty:
        return false
  for edge in 0 ..< NumEdges:
    if (combined and EdgeBits[edge]) != EdgeMask(0) and
        not edge.bordersPasture(layout):
      return false
  if before.pastureCount > 0:
    for i in 0 ..< layout.pastureCount:
      let pasture = layout.pastures[i]
      var
        overlapsOld = false
        touchesOld = false
      for j in 0 ..< pasture.cellCount:
        let cell = pasture.cells[j]
        if (before.pastureCells and CellBits[cell]) != CellSet(0):
          overlapsOld = true
        if before.pastureCells.intersects(CellNeighborMasks[cell]):
          touchesOld = true
      if not overlapsOld and not touchesOld:
        return false
  true

proc validateFenceMask(
  player: PlayerState,
  existing,
  newMask: EdgeMask,
  newCount: int
): bool {.raises: [SolverError].} =
  ## Returns true when a compact new fence mask can be added.
  let before = computePastures(player.spaces, existing)
  player.validateFenceMask(existing, newMask, newCount, before)

proc validateFencePlan*(player: PlayerState, newEdges: seq[EdgeId]): bool
    {.raises: [SolverError].} =
  ## Returns true when adding these fences is legal enough for the solver.
  let existing = player.fences.edgeMaskOf()
  if not existing.ok:
    return false
  var newMask: EdgeMask
  for edge in newEdges:
    if not edge.isValidEdge():
      return false
    if (existing.mask and EdgeBits[edge]) != EdgeMask(0) or
        (newMask and EdgeBits[edge]) != EdgeMask(0):
      return false
    newMask = newMask or EdgeBits[edge]
  player.validateFenceMask(existing.mask, newMask, newEdges.len)

proc fencePlanScore(plan: FencePlan): int =
  ## Returns a simple value for efficient fence coverage.
  plan.cellCount * 16 - plan.cost * 5

proc compareFencePlans(a, b: FencePlan): int =
  ## Sorts better fence plans before weaker ones.
  result = cmp(b.fencePlanScore(), a.fencePlanScore())
  if result == 0:
    result = cmp(a.cost, b.cost)
  if result == 0:
    result = cmp(b.cellCount, a.cellCount)

proc hasHarvest*(round: int): bool =
  ## Returns true when a round ends in harvest.
  for harvestRound in HarvestRounds:
    if round == harvestRound:
      return true

proc turnsToHarvest*(round: int): int =
  ## Returns the number of rounds until the next harvest round.
  for harvestRound in HarvestRounds:
    if round <= harvestRound:
      return harvestRound - round
  0

proc fixedBoardActions*(numPlayers: int): seq[ActionId]
    {.raises: [SolverError].} =
  ## Returns action spaces present at setup for one player count.
  req(numPlayers >= 1 and numPlayers <= 4, "Supported player counts: 1-4.")
  result = @[
    FarmExpansion, MeetingPlace, GrainSeeds, Farmland, Lessons,
    DayLaborer, Forest, ClayPit, ReedBank, Fishing
  ]
  if numPlayers == 3:
    result.add @[Grove, Hollow, QuarryStall, LessonsB]
  elif numPlayers == 4:
    result.add @[
      Copse, Grove, Hollow, ResourceMarket, TravelingPlayers, LessonsB
    ]

proc roundCardsForStage*(stage: int): seq[ActionId] =
  ## Returns round cards in one Agricogla stage.
  case stage
  of 1:
    @[RImprovement, RSheep, RFences, RSowBake]
  of 2:
    @[RWestQuarry, RRenovateImprove, RFamilyGrowth]
  of 3:
    @[RVegetable, RBoar]
  of 4:
    @[REastQuarry, RCattle]
  of 5:
    @[RUrgentFamily, RCultivation]
  of 6:
    @[RRedevelop]
  else:
    @[]

proc buildRoundDeck*(rng: var Rng): seq[ActionId] =
  ## Builds the randomized round-card deck, shuffled within each stage.
  for stage in 1 .. 6:
    result.add rng.shuffled(roundCardsForStage(stage))

proc spaceDef*(id: ActionId, numPlayers: int): SpaceDef =
  ## Returns static action-space data copied from Agricogla.
  result.id = id
  case id
  of FarmExpansion, MeetingPlace:
    discard
  of GrainSeeds:
    result.fixedGoods.resources[Grain] = 1
  of Farmland, Lessons:
    discard
  of DayLaborer:
    result.fixedGoods.resources[Food] = 2
  of Forest:
    result.accumulates.resources[Wood] =
      if numPlayers == 1:
        2
      else:
        3
  of ClayPit:
    result.accumulates.resources[Clay] = 1
  of ReedBank:
    result.accumulates.resources[Reed] = 1
  of Fishing:
    result.accumulates.resources[Food] = 1
  of Copse:
    result.accumulates.resources[Wood] = 1
  of Grove:
    result.accumulates.resources[Wood] = 2
  of Hollow:
    result.accumulates.resources[Clay] =
      if numPlayers == 4:
        2
      else:
        1
  of QuarryStall:
    result.fixedGoods.resources[Stone] = 1
  of ResourceMarket:
    result.fixedGoods.resources[Reed] = 1
    result.fixedGoods.resources[Stone] = 1
    result.fixedGoods.resources[Food] = 1
  of TravelingPlayers:
    result.accumulates.resources[Food] = 1
  of LessonsB:
    discard
  of RImprovement:
    result.stage = 1
  of RSheep:
    result.stage = 1
    result.accumulates.animals[Sheep] = 1
  of RFences:
    result.stage = 1
  of RSowBake:
    result.stage = 1
  of RWestQuarry:
    result.stage = 2
    result.accumulates.resources[Stone] = 1
  of RRenovateImprove:
    result.stage = 2
  of RFamilyGrowth:
    result.stage = 2
  of RVegetable:
    result.stage = 3
    result.fixedGoods.resources[Vegetable] = 1
  of RBoar:
    result.stage = 3
    result.accumulates.animals[Boar] = 1
  of REastQuarry:
    result.stage = 4
    result.accumulates.resources[Stone] = 1
  of RCattle:
    result.stage = 4
    result.accumulates.animals[Cattle] = 1
  of RUrgentFamily:
    result.stage = 5
  of RCultivation:
    result.stage = 5
  of RRedevelop:
    result.stage = 6

proc freshFarm*(): array[NumSpaces, FarmSpace] =
  ## Creates the starting farmyard.
  for i in 0 ..< NumSpaces:
    result[i] = FarmSpace(kind: Empty, crop: NoCrop)
  result[spaceIndex(1, 0)].kind = Room
  result[spaceIndex(2, 0)].kind = Room

proc cardName*(id: CardId): string =
  ## Returns the Agricogla protocol id for one solver card.
  case id
  of NoCard:
    ""
  of MajFireplace2:
    "fireplace2"
  of MajFireplace3:
    "fireplace3"
  of MajHearth4:
    "hearth4"
  of MajHearth5:
    "hearth5"
  of MajClayOven:
    "clay_oven"
  of MajStoneOven:
    "stone_oven"
  of MajJoinery:
    "joinery"
  of MajPottery:
    "pottery"
  of MajBasketmaker:
    "basketmaker"
  of MajWell:
    "well"
  of OccLumberjack:
    "occ_lumberjack"
  of OccClayDigger:
    "occ_clay_digger"
  of OccReedGatherer:
    "occ_reed_gatherer"
  of OccQuarryman:
    "occ_quarryman"
  of OccAngler:
    "occ_angler"
  of OccSeasonalHand:
    "occ_seasonal_hand"
  of OccPeddler:
    "occ_peddler"
  of OccGreengrocer:
    "occ_greengrocer"
  of OccQuarryForeman:
    "occ_quarry_foreman"
  of OccShepherdsFriend:
    "occ_shepherds_friend"
  of OccWayfarer:
    "occ_wayfarer"
  of OccButcher:
    "occ_butcher"
  of OccCharcutier:
    "occ_charcutier"
  of OccMuttonCook:
    "occ_mutton_cook"
  of OccFieldCook:
    "occ_field_cook"
  of OccBaker:
    "occ_baker"
  of OccMiller:
    "occ_miller"
  of OccPlowwright:
    "occ_plowwright"
  of OccFurrowMaster:
    "occ_furrow_master"
  of OccStablemaster:
    "occ_stablemaster"
  of OccSwineherd:
    "occ_swineherd"
  of OccCowherd:
    "occ_cowherd"
  of OccShepherd:
    "occ_shepherd"
  of OccCarpenter:
    "occ_carpenter"
  of OccBricklayer:
    "occ_bricklayer"
  of OccMason:
    "occ_mason"
  of OccThatcher:
    "occ_thatcher"
  of OccHedgeWarden:
    "occ_hedge_warden"
  of OccStableBoy:
    "occ_stable_boy"
  of OccMidwife:
    "occ_midwife"
  of OccPatriarch:
    "occ_patriarch"
  of OccForager:
    "occ_forager"
  of OccGleaner:
    "occ_gleaner"
  of OccMilkman:
    "occ_milkman"
  of OccCheesemaker:
    "occ_cheesemaker"
  of OccSwineKeeper:
    "occ_swine_keeper"
  of OccGrainSteward:
    "occ_grain_steward"
  of OccWaterCarrier:
    "occ_water_carrier"
  of OccWoodward:
    "occ_woodward"
  of OccVagrant:
    "occ_vagrant"
  of OccJourneyman:
    "occ_journeyman"
  of OccSeedMerchant:
    "occ_seed_merchant"
  of OccVegPeddler:
    "occ_veg_peddler"
  of OccSchoolmaster:
    "occ_schoolmaster"
  of OccElder:
    "occ_elder"
  of OccSurveyor:
    "occ_surveyor"
  of OccAnimalBreeder:
    "occ_animal_breeder"
  of OccMasterBuilder:
    "occ_master_builder"
  of OccHorticulturist:
    "occ_horticulturist"
  of OccCompostCarter:
    "occ_compost_carter"
  of OccFenceHand:
    "occ_fence_hand"
  of MinWoodenPlow:
    "min_wooden_plow"
  of MinHeavyPlow:
    "min_heavy_plow"
  of MinHearthStones:
    "min_hearth_stones"
  of MinDoughTrough:
    "min_dough_trough"
  of MinCookingCorner:
    "min_cooking_corner"
  of MinSmokehouse:
    "min_smokehouse"
  of MinStewpot:
    "min_stewpot"
  of MinAnimalPen:
    "min_animal_pen"
  of MinPigSty:
    "min_pig_sty"
  of MinCattleShed:
    "min_cattle_shed"
  of MinSheepFold:
    "min_sheep_fold"
  of MinPaddock:
    "min_paddock"
  of MinCarpPond:
    "min_carp_pond"
  of MinReedPond:
    "min_reed_pond"
  of MinClayDeposit:
    "min_clay_deposit"
  of MinWoodCache:
    "min_wood_cache"
  of MinSeedStock:
    "min_seed_stock"
  of MinWoodCart:
    "min_wood_cart"
  of MinClayPitClaim:
    "min_clay_pit_claim"
  of MinMarketStall:
    "min_market_stall"
  of MinStoneCart:
    "min_stone_cart"
  of MinThreshingBoard:
    "min_threshing_board"
  of MinFishWeir:
    "min_fish_weir"
  of MinHandcart:
    "min_handcart"
  of MinShepherdsCrook:
    "min_shepherds_crook"
  of MinPigTrough:
    "min_pig_trough"
  of MinCattleProd:
    "min_cattle_prod"
  of MinTimberYard:
    "min_timber_yard"
  of MinClayWorks:
    "min_clay_works"
  of MinStoneYard:
    "min_stone_yard"
  of MinFencePosts:
    "min_fence_posts"
  of MinHerbGarden:
    "min_herb_garden"
  of MinMilkPail:
    "min_milk_pail"
  of MinShearingShears:
    "min_shearing_shears"
  of MinDryingShed:
    "min_drying_shed"
  of MinDovecote:
    "min_dovecote"
  of MinRainBarrel:
    "min_rain_barrel"
  of MinCradle:
    "min_cradle"
  of MinToyChest:
    "min_toy_chest"
  of MinCarvedChest:
    "min_carved_chest"
  of MinPewterJug:
    "min_pewter_jug"
  of MinGabledHouse:
    "min_gabled_house"
  of MinGrainLoft:
    "min_grain_loft"
  of MinRootCellar:
    "min_root_cellar"
  of MinHuntingTrophies:
    "min_hunting_trophies"
  of MinScarecrow:
    "min_scarecrow"
  of MinWellBucket:
    "min_well_bucket"
  of MinLendingCart:
    "min_lending_cart"
  of MinTravelingTinker:
    "min_traveling_tinker"
  of MinSeedSwap:
    "min_seed_swap"

proc parseCardId*(value: string): CardId =
  ## Parses one protocol card id into the compact solver enum.
  case value
  of "fireplace2":
    MajFireplace2
  of "fireplace3":
    MajFireplace3
  of "hearth4":
    MajHearth4
  of "hearth5":
    MajHearth5
  of "clay_oven":
    MajClayOven
  of "stone_oven":
    MajStoneOven
  of "joinery":
    MajJoinery
  of "pottery":
    MajPottery
  of "basketmaker":
    MajBasketmaker
  of "well":
    MajWell
  of "occ_lumberjack":
    OccLumberjack
  of "occ_clay_digger":
    OccClayDigger
  of "occ_reed_gatherer":
    OccReedGatherer
  of "occ_quarryman":
    OccQuarryman
  of "occ_angler":
    OccAngler
  of "occ_seasonal_hand":
    OccSeasonalHand
  of "occ_peddler":
    OccPeddler
  of "occ_greengrocer":
    OccGreengrocer
  of "occ_quarry_foreman":
    OccQuarryForeman
  of "occ_shepherds_friend":
    OccShepherdsFriend
  of "occ_wayfarer":
    OccWayfarer
  of "occ_butcher":
    OccButcher
  of "occ_charcutier":
    OccCharcutier
  of "occ_mutton_cook":
    OccMuttonCook
  of "occ_field_cook":
    OccFieldCook
  of "occ_baker":
    OccBaker
  of "occ_miller":
    OccMiller
  of "occ_plowwright":
    OccPlowwright
  of "occ_furrow_master":
    OccFurrowMaster
  of "occ_stablemaster":
    OccStablemaster
  of "occ_swineherd":
    OccSwineherd
  of "occ_cowherd":
    OccCowherd
  of "occ_shepherd":
    OccShepherd
  of "occ_carpenter":
    OccCarpenter
  of "occ_bricklayer":
    OccBricklayer
  of "occ_mason":
    OccMason
  of "occ_thatcher":
    OccThatcher
  of "occ_hedge_warden":
    OccHedgeWarden
  of "occ_stable_boy":
    OccStableBoy
  of "occ_midwife":
    OccMidwife
  of "occ_patriarch":
    OccPatriarch
  of "occ_forager":
    OccForager
  of "occ_gleaner":
    OccGleaner
  of "occ_milkman":
    OccMilkman
  of "occ_cheesemaker":
    OccCheesemaker
  of "occ_swine_keeper":
    OccSwineKeeper
  of "occ_grain_steward":
    OccGrainSteward
  of "occ_water_carrier":
    OccWaterCarrier
  of "occ_woodward":
    OccWoodward
  of "occ_vagrant":
    OccVagrant
  of "occ_journeyman":
    OccJourneyman
  of "occ_seed_merchant":
    OccSeedMerchant
  of "occ_veg_peddler":
    OccVegPeddler
  of "occ_schoolmaster":
    OccSchoolmaster
  of "occ_elder":
    OccElder
  of "occ_surveyor":
    OccSurveyor
  of "occ_animal_breeder":
    OccAnimalBreeder
  of "occ_master_builder":
    OccMasterBuilder
  of "occ_horticulturist":
    OccHorticulturist
  of "occ_compost_carter":
    OccCompostCarter
  of "occ_fence_hand":
    OccFenceHand
  of "min_wooden_plow":
    MinWoodenPlow
  of "min_heavy_plow":
    MinHeavyPlow
  of "min_hearth_stones":
    MinHearthStones
  of "min_dough_trough":
    MinDoughTrough
  of "min_cooking_corner":
    MinCookingCorner
  of "min_smokehouse":
    MinSmokehouse
  of "min_stewpot":
    MinStewpot
  of "min_animal_pen":
    MinAnimalPen
  of "min_pig_sty":
    MinPigSty
  of "min_cattle_shed":
    MinCattleShed
  of "min_sheep_fold":
    MinSheepFold
  of "min_paddock":
    MinPaddock
  of "min_carp_pond":
    MinCarpPond
  of "min_reed_pond":
    MinReedPond
  of "min_clay_deposit":
    MinClayDeposit
  of "min_wood_cache":
    MinWoodCache
  of "min_seed_stock":
    MinSeedStock
  of "min_wood_cart":
    MinWoodCart
  of "min_clay_pit_claim":
    MinClayPitClaim
  of "min_market_stall":
    MinMarketStall
  of "min_stone_cart":
    MinStoneCart
  of "min_threshing_board":
    MinThreshingBoard
  of "min_fish_weir":
    MinFishWeir
  of "min_handcart":
    MinHandcart
  of "min_shepherds_crook":
    MinShepherdsCrook
  of "min_pig_trough":
    MinPigTrough
  of "min_cattle_prod":
    MinCattleProd
  of "min_timber_yard":
    MinTimberYard
  of "min_clay_works":
    MinClayWorks
  of "min_stone_yard":
    MinStoneYard
  of "min_fence_posts":
    MinFencePosts
  of "min_herb_garden":
    MinHerbGarden
  of "min_milk_pail":
    MinMilkPail
  of "min_shearing_shears":
    MinShearingShears
  of "min_drying_shed":
    MinDryingShed
  of "min_dovecote":
    MinDovecote
  of "min_rain_barrel":
    MinRainBarrel
  of "min_cradle":
    MinCradle
  of "min_toy_chest":
    MinToyChest
  of "min_carved_chest":
    MinCarvedChest
  of "min_pewter_jug":
    MinPewterJug
  of "min_gabled_house":
    MinGabledHouse
  of "min_grain_loft":
    MinGrainLoft
  of "min_root_cellar":
    MinRootCellar
  of "min_hunting_trophies":
    MinHuntingTrophies
  of "min_scarecrow":
    MinScarecrow
  of "min_well_bucket":
    MinWellBucket
  of "min_lending_cart":
    MinLendingCart
  of "min_traveling_tinker":
    MinTravelingTinker
  of "min_seed_swap":
    MinSeedSwap
  else:
    NoCard

proc knownOccupation*(id: CardId): bool =
  ## Returns true when this occupation exists in the solver card table.
  id >= OccLumberjack and id <= OccFenceHand

proc knownMinor*(id: CardId): bool =
  ## Returns true when this minor exists in the solver card table.
  id >= MinWoodenPlow and id <= MinSeedSwap

proc knownMajor*(id: CardId): bool =
  ## Returns true when this major exists in the solver card table.
  id >= MajFireplace2 and id <= MajWell

proc cardKind*(id: CardId): ImprovementKind =
  ## Returns the broad card kind used by improvement choices.
  if id.knownMinor():
    return MinorImprovement
  if id.knownMajor():
    return MajorImprovement
  NoImprovement

proc knownOccupation*(id: string): bool =
  ## Returns true when this occupation exists in the solver card table.
  id.parseCardId().knownOccupation()

proc knownMinor*(id: string): bool =
  ## Returns true when this minor exists in the solver card table.
  id.parseCardId().knownMinor()

proc knownMajor*(id: string): bool =
  ## Returns true when this major exists in the solver card table.
  id.parseCardId().knownMajor()

proc cardCost*(id: CardId): Goods =
  ## Returns the resource cost for a card id.
  case id
  of MajFireplace2:
    result.resources[Clay] = 2
  of MajFireplace3:
    result.resources[Clay] = 3
  of MajHearth4:
    result.resources[Clay] = 4
  of MajHearth5:
    result.resources[Clay] = 5
  of MajClayOven:
    result.resources[Clay] = 3
    result.resources[Stone] = 1
  of MajStoneOven:
    result.resources[Clay] = 1
    result.resources[Stone] = 3
  of MajJoinery:
    result.resources[Wood] = 2
    result.resources[Stone] = 2
  of MajPottery:
    result.resources[Clay] = 2
    result.resources[Stone] = 2
  of MajBasketmaker:
    result.resources[Reed] = 2
    result.resources[Stone] = 2
  of MajWell:
    result.resources[Wood] = 1
    result.resources[Stone] = 3
  of MinWoodenPlow, MinDoughTrough, MinAnimalPen, MinPigSty,
    MinSheepFold, MinFencePosts, MinHerbGarden, MinMilkPail,
    MinShearingShears, MinRainBarrel, MinCradle, MinToyChest,
    MinHuntingTrophies, MinShepherdsCrook, MinPigTrough,
    MinScarecrow, MinWellBucket:
      result.resources[Wood] = 1
  of MinHeavyPlow, MinSmokehouse:
    result.resources[Wood] = 1
    result.resources[Stone] = 1
  of MinHearthStones, MinRootCellar, MinPewterJug:
    result.resources[Stone] = 1
  of MinCookingCorner, MinStewpot, MinDryingShed:
    result.resources[Clay] = 1
  of MinCattleShed, MinGabledHouse:
    result.resources[Wood] = 1
    result.resources[Reed] = 1
  of MinPaddock, MinHandcart, MinCarvedChest:
    result.resources[Wood] = 2
  of MinCarpPond, MinReedPond, MinClayDeposit, MinWoodCache,
    MinSeedStock, MinWoodCart, MinClayPitClaim, MinTimberYard,
    MinClayWorks, MinStoneYard:
      result.resources[Food] = 1
  of MinMarketStall:
    result.resources[Grain] = 1
  of MinStoneCart, MinThreshingBoard:
    result.resources[Wood] = 1
  of MinFishWeir:
    result.resources[Reed] = 1
  of MinCattleProd:
    result.resources[Wood] = 1
    result.resources[Stone] = 1
  of MinDovecote:
    result.resources[Stone] = 2
  of MinGrainLoft:
    result.resources[Wood] = 1
    result.resources[Clay] = 1
  else:
    discard

proc cardCost*(id: string): Goods =
  ## Returns the resource cost for a protocol card id.
  cardCost(id.parseCardId())

proc cardVp*(id: CardId): int =
  ## Returns printed victory points for a card id.
  case id
  of MajFireplace2, MajFireplace3, MajHearth4, MajHearth5,
    MinHeavyPlow, MinSmokehouse, MinCattleShed, MinPaddock,
    MinCarpPond, MinReedPond, MinThreshingBoard, MinHandcart,
    MinCattleProd, MinTimberYard, MinClayWorks, MinStoneYard,
    MinHerbGarden, MinShearingShears, MinCradle, MinPewterJug,
    MinGrainLoft, MinRootCellar, MinScarecrow:
      1
  of MajClayOven, MajJoinery, MajPottery, MajBasketmaker,
    MinDovecote, MinCarvedChest:
      2
  of MajStoneOven, MinGabledHouse:
    3
  of MajWell:
    4
  else:
    0

proc cardVp*(id: string): int =
  ## Returns printed victory points for a protocol card id.
  cardVp(id.parseCardId())

proc cardPrereqOccs*(id: CardId): int =
  ## Returns the minimum occupations needed to play a card.
  case id
  of OccMiller, OccVegPeddler, MinWoodCart, MinPaddock,
    MinCattleProd, MinCarvedChest:
      1
  of MinCarpPond, MinStoneCart, MinThreshingBoard, MinTimberYard,
    MinClayWorks, MinStoneYard:
      2
  of MinReedPond:
    3
  else:
    0

proc cardPrereqOccs*(id: string): int =
  ## Returns the minimum occupations needed for a protocol card id.
  cardPrereqOccs(id.parseCardId())

proc bakePower*(id: CardId): BakePower =
  ## Returns the bread-baking power for a card.
  case id
  of MajFireplace2, MajFireplace3:
    BakePower(perGrain: 2, maxGrain: 99)
  of MajHearth4, MajHearth5:
    BakePower(perGrain: 3, maxGrain: 99)
  of MajClayOven:
    BakePower(perGrain: 5, maxGrain: 1)
  of MajStoneOven:
    BakePower(perGrain: 4, maxGrain: 2)
  of OccBaker, MinDoughTrough:
    BakePower(perGrain: 2, maxGrain: 1)
  of OccMiller:
    BakePower(perGrain: 3, maxGrain: 1)
  of MinHearthStones:
    BakePower(perGrain: 2, maxGrain: 2)
  else:
    BakePower()

proc bakePower*(id: string): BakePower =
  ## Returns the bread-baking power for a protocol card id.
  bakePower(id.parseCardId())

proc harvestFood*(id: CardId): HarvestFood =
  ## Returns the harvest feeding conversion for a card.
  case id
  of MajJoinery:
    HarvestFood(resource: Wood, food: 2, maxCount: 1)
  of MajPottery:
    HarvestFood(resource: Clay, food: 2, maxCount: 1)
  of MajBasketmaker:
    HarvestFood(resource: Reed, food: 3, maxCount: 1)
  else:
    HarvestFood()

proc harvestFood*(id: string): HarvestFood =
  ## Returns the harvest feeding conversion for a protocol card id.
  harvestFood(id.parseCardId())

proc cookRate*(id: CardId, animal: Animal): int =
  ## Returns the animal cooking rate for a card.
  case id
  of MajFireplace2, MajFireplace3, OccButcher:
    case animal
    of Sheep, Boar:
      2
    of Cattle:
      3
  of MinStewpot:
    case animal
    of Sheep, Boar:
      2
    of Cattle:
      0
  of MajHearth4, MajHearth5:
    case animal
    of Sheep:
      2
    of Boar:
      3
    of Cattle:
      4
  of OccCharcutier:
    if animal == Boar: 3 else: 0
  of OccMuttonCook:
    if animal == Sheep: 3 else: 0
  of MinCookingCorner:
    if animal == Sheep: 2 else: 0
  of MinSmokehouse:
    case animal
    of Sheep:
      2
    of Boar:
      3
    of Cattle:
      0
  else:
    0

proc cookRate*(id: string, animal: Animal): int =
  ## Returns the animal cooking rate for a protocol card id.
  cookRate(id.parseCardId(), animal)

proc vegetableCookRate*(id: CardId): int =
  ## Returns the vegetable cooking rate for a card.
  case id
  of MajFireplace2, MajFireplace3, OccFieldCook,
    MinCookingCorner, MinStewpot:
      2
  of MajHearth4, MajHearth5:
    3
  else:
    0

proc vegetableCookRate*(id: string): int =
  ## Returns the vegetable cooking rate for a protocol card id.
  vegetableCookRate(id.parseCardId())

proc hasPlayed*(player: PlayerState, id: CardId): bool =
  ## Returns true when a card is in front of the player.
  id in player.occupations or id in player.minors or id in player.majors

proc hasPlayed*(player: PlayerState, id: string): bool =
  ## Returns true when a protocol card id is in front of the player.
  player.hasPlayed(id.parseCardId())

iterator playedCards*(player: PlayerState): CardId =
  ## Iterates over all cards in front of the player.
  for id in player.occupations:
    yield id
  for id in player.minors:
    yield id
  for id in player.majors:
    yield id

proc canAfford*(player: PlayerState, cost: Goods): bool =
  ## Returns true when the player can pay a resource cost.
  for resource in Resource:
    if player.resources[resource] < cost.resources[resource]:
      return false
  true

proc pay(player: var PlayerState, cost: Goods) {.raises: [SolverError].} =
  ## Pays a resource cost.
  req(player.canAfford(cost), "Cannot afford " & cost.goodsText() & ".")
  for resource in Resource:
    player.resources[resource] -= cost.resources[resource]

proc bestCookRate*(player: PlayerState, animal: Animal): int =
  ## Returns the best active cooking rate for one animal type.
  for id in player.playedCards():
    result = max(result, cookRate(id, animal))

proc bestCookCard*(player: PlayerState, animal: Animal):
    tuple[id: CardId, rate: int] =
  ## Returns the best active cooking card for one animal type.
  for id in player.playedCards():
    let rate = cookRate(id, animal)
    if rate > result.rate:
      result = (id, rate)

proc bestVegetableCookRate*(player: PlayerState): int =
  ## Returns the best active cooking rate for vegetables.
  for id in player.playedCards():
    result = max(result, vegetableCookRate(id))

proc bestBakePower*(player: PlayerState): BakePower =
  ## Returns the most efficient active baking power.
  for id in player.playedCards():
    let power = bakePower(id)
    if power.perGrain > result.perGrain:
      result = power

proc bestBakeCard*(player: PlayerState): tuple[id: CardId, power: BakePower] =
  ## Returns the most efficient active baking card.
  for id in player.playedCards():
    let power = bakePower(id)
    if power.perGrain > result.power.perGrain:
      result = (id, power)

proc capacitySlots*(player: PlayerState): seq[CapacitySlot] =
  ## Returns card-based animal capacity slots.
  for id in player.playedCards():
    case id
    of OccStablemaster:
      result.add CapacitySlot(capacity: 1)
    of OccSwineherd:
      result.add CapacitySlot(typed: true, animal: Boar, capacity: 2)
    of OccCowherd:
      result.add CapacitySlot(typed: true, animal: Cattle, capacity: 2)
    of OccShepherd:
      result.add CapacitySlot(typed: true, animal: Sheep, capacity: 2)
    of MinAnimalPen:
      result.add CapacitySlot(capacity: 2)
    of MinPigSty:
      result.add CapacitySlot(typed: true, animal: Boar, capacity: 2)
    of MinCattleShed:
      result.add CapacitySlot(typed: true, animal: Cattle, capacity: 2)
    of MinSheepFold:
      result.add CapacitySlot(typed: true, animal: Sheep, capacity: 2)
    of MinPaddock:
      result.add CapacitySlot(capacity: 3)
    else:
      discard

proc maxRetention*(player: PlayerState, counts: AnimalCounts): AnimalHolding
    {.raises: [SolverError].} =
  ## Returns the best animal retention under current housing.
  let layout = computePastures(player.spaces, player.fences)
  var
    typedExtra: AnimalCounts
    anySlots: seq[int]
    best: AnimalHolding
  for slot in player.capacitySlots():
    if slot.typed:
      typedExtra[slot.animal] += slot.capacity
    else:
      anySlots.add slot.capacity
  anySlots.add 1
  for i, space in player.spaces:
    if space.stable and space.kind == Empty and
        not layout.pastureCells.contains(i):
      anySlots.add 1
  anySlots.sort(SortOrder.Descending)
  let options = [NoSpace, ord(Sheep), ord(Boar), ord(Cattle)]
  var assign: array[NumSpaces, int]

  proc evaluate() =
    ## Evaluates one pasture-type assignment.
    var
      pastureCap: AnimalCounts
      retained: AnimalCounts
      leftover: AnimalCounts
    for i in 0 ..< layout.pastureCount:
      let choice = assign[i]
      if choice == NoSpace:
        continue
      pastureCap[Animal(choice)] += layout.pastures[i].capacity
    for animal in Animal:
      retained[animal] = min(counts[animal], pastureCap[animal] + typedExtra[animal])
      leftover[animal] = counts[animal] - retained[animal]
    for cap in anySlots:
      var bestAnimal = Sheep
      var found = false
      for animal in Animal:
        if leftover[animal] > 0 and (
            not found or leftover[animal] > leftover[bestAnimal]):
          bestAnimal = animal
          found = true
      if not found:
        break
      let taken = min(cap, leftover[bestAnimal])
      retained[bestAnimal] += taken
      leftover[bestAnimal] -= taken
    var total = 0
    for animal in Animal:
      total += retained[animal]
    if total > best.total:
      best.retained = retained
      best.total = total

  proc search(i: int) =
    ## Enumerates pasture assignments recursively.
    if i == layout.pastureCount:
      evaluate()
      return
    for choice in options:
      assign[i] = choice
      search(i + 1)

  search(0)
  result = best

proc canAccommodate*(player: PlayerState, counts: AnimalCounts): bool
    {.raises: [SolverError].} =
  ## Returns true when the player can house the supplied animal totals.
  let holding = player.maxRetention(counts)
  for animal in Animal:
    if holding.retained[animal] < counts[animal]:
      return false
  true

proc takeAnimals(state: var GameState, player: var PlayerState, gained: AnimalCounts)
    {.raises: [SolverError].} =
  ## Adds animals, cooking overflow when possible.
  var counts = player.animals
  for animal in Animal:
    counts[animal] += gained[animal]
  let holding = player.maxRetention(counts)
  for animal in Animal:
    let overflow = counts[animal] - holding.retained[animal]
    player.animals[animal] = holding.retained[animal]
    if overflow > 0:
      let rate = player.bestCookRate(animal)
      if rate > 0:
        player.resources[Food] += overflow * rate

proc gainGoods(state: var GameState, player: var PlayerState, source: ActionId,
    gained: Goods) {.raises: [SolverError].} =
  ## Adds action-space goods to a player.
  var goods = gained
  if goods.resources[Wood] > 0 and player.hasPlayed(OccLumberjack):
    goods.resources[Wood] += 1
  if goods.resources[Clay] > 0 and player.hasPlayed(OccClayDigger):
    goods.resources[Clay] += 1
  if goods.resources[Reed] > 0 and player.hasPlayed(OccReedGatherer):
    goods.resources[Reed] += 1
  if goods.resources[Stone] > 0 and player.hasPlayed(OccQuarryman):
    goods.resources[Stone] += 1
  if source == Fishing and player.hasPlayed(OccAngler):
    goods.resources[Food] += 2
  if source == DayLaborer and player.hasPlayed(OccSeasonalHand):
    goods.resources[Grain] += 1
  if source == DayLaborer and player.hasPlayed(OccPeddler):
    goods.resources[Clay] += 1
  if source == GrainSeeds and player.hasPlayed(OccGreengrocer):
    goods.resources[Vegetable] += 1
  if goods.resources[Stone] > 0 and player.hasPlayed(OccQuarryForeman):
    goods.resources[Food] += 1
  if goods.animals[Sheep] > 0 and player.hasPlayed(OccShepherdsFriend):
    goods.animals[Sheep] += 1
  if source == TravelingPlayers and player.hasPlayed(OccWayfarer):
    goods.resources[Food] += 1
    goods.resources[Wood] += 1
  for resource in Resource:
    player.resources[resource] += goods.resources[resource]
  state.takeAnimals(player, goods.animals)

proc roomCount*(player: PlayerState): int =
  ## Counts rooms in one player's farmyard.
  for space in player.spaces:
    if space.kind == Room:
      result += 1

proc stableCount*(player: PlayerState): int =
  ## Counts built stables in one player's farmyard.
  for space in player.spaces:
    if space.stable:
      result += 1

proc roomCost*(player: PlayerState): Goods =
  ## Returns the current room cost.
  case player.houseMaterial
  of HouseWood:
    result.resources[Wood] = 5
  of HouseClay:
    result.resources[Clay] = 5
  of HouseStone:
    result.resources[Stone] = 5
  result.resources[Reed] = 2
  if player.houseMaterial == HouseWood and player.hasPlayed(OccCarpenter):
    result.resources[Wood] = max(0, result.resources[Wood] - 2)
  if player.houseMaterial == HouseClay and player.hasPlayed(OccBricklayer):
    result.resources[Clay] = max(0, result.resources[Clay] - 2)
  if player.houseMaterial == HouseStone and player.hasPlayed(OccMason):
    result.resources[Stone] = max(0, result.resources[Stone] - 2)
  if player.hasPlayed(OccThatcher):
    result.resources[Reed] = max(0, result.resources[Reed] - 1)
  if player.houseMaterial == HouseWood and player.hasPlayed(MinTimberYard):
    result.resources[Wood] = max(0, result.resources[Wood] - 1)
  if player.houseMaterial == HouseClay and player.hasPlayed(MinClayWorks):
    result.resources[Clay] = max(0, result.resources[Clay] - 1)
  if player.houseMaterial == HouseStone and player.hasPlayed(MinStoneYard):
    result.resources[Stone] = max(0, result.resources[Stone] - 1)

proc renovationCost*(player: PlayerState): Goods {.raises: [SolverError].} =
  ## Returns the current renovation cost.
  req(player.houseMaterial != HouseStone, "House is already stone.")
  case player.houseMaterial
  of HouseWood:
    result.resources[Clay] = player.roomCount()
  of HouseClay:
    result.resources[Stone] = player.roomCount()
  of HouseStone:
    discard
  result.resources[Reed] = 1

proc legalRoomSpaces*(player: PlayerState): seq[int]
    {.raises: [SolverError].} =
  ## Returns spaces where a room can be built.
  let layout = computePastures(player.spaces, player.fences)
  for i, space in player.spaces:
    if space.kind != Empty or space.stable or layout.pastureCells.contains(i):
      continue
    for neighbor in neighborsOf(i):
      if player.spaces[neighbor].kind == Room:
        result.add i
        break

proc legalFieldSpaces*(player: PlayerState): seq[int]
    {.raises: [SolverError].} =
  ## Returns spaces where a field can be plowed.
  let
    layout = computePastures(player.spaces, player.fences)
    hasField = player.spaces.anyIt(it.kind == Field)
  for i, space in player.spaces:
    if space.kind != Empty or space.stable or layout.pastureCells.contains(i):
      continue
    if not hasField:
      result.add i
      continue
    for neighbor in neighborsOf(i):
      if player.spaces[neighbor].kind == Field:
        result.add i
        break

proc legalStableSpaces*(player: PlayerState): seq[int] =
  ## Returns spaces where a stable can be built.
  for i, space in player.spaces:
    if space.kind == Empty and not space.stable:
      result.add i

proc sowableFields*(player: PlayerState): seq[int] =
  ## Returns empty fields that can receive crops.
  for i, space in player.spaces:
    if space.kind == Field and space.cropCount == 0:
      result.add i

proc findActionIndex*(state: GameState, action: ActionId): int =
  ## Returns the index of an action space or -1 when absent.
  for i, space in state.actionSpaces:
    if space.id == action:
      return i
  NoSpace

proc isAvailable*(state: GameState, action: ActionId): bool =
  ## Returns true when an action space can be selected now.
  if state.phase != Work:
    return false
  let index = state.findActionIndex(action)
  index >= 0 and state.actionSpaces[index].occupiedBy == NoPlayer

proc occupationCost*(state: GameState, player: PlayerState, action: ActionId): int =
  ## Returns the food cost to play an occupation on one lessons space.
  if action == Lessons:
    if player.occupations.len == 0:
      return 0
    return 1
  if state.numPlayers == 3:
    return 2
  if player.occupations.len < 2:
    return 1
  2

proc familyGrowthOk*(player: PlayerState): bool =
  ## Returns true when normal family growth is legal.
  player.family.len < MaxFamily and player.roomCount() > player.family.len

proc urgentGrowthOk*(player: PlayerState): bool =
  ## Returns true when urgent family growth is legal.
  player.family.len < MaxFamily

proc cardSpecialPrereqOk*(player: PlayerState, id: CardId): bool =
  ## Returns true when non-occupation card prerequisites are met.
  case id
  of MinGabledHouse:
    player.houseMaterial == HouseStone
  else:
    true

proc playerCanPlayCard*(player: PlayerState, id: CardId): bool =
  ## Returns true when cost and card prerequisites are met.
  if not id.knownMinor() and not id.knownMajor():
    return false
  player.canAfford(cardCost(id)) and
    player.occupations.len >= cardPrereqOccs(id) and
    player.cardSpecialPrereqOk(id)

proc cardSpecialPrereqOk*(player: PlayerState, id: string): bool =
  ## Returns true when protocol-card prerequisites are met.
  player.cardSpecialPrereqOk(id.parseCardId())

proc playerCanPlayCard*(player: PlayerState, id: string): bool =
  ## Returns true when a protocol card can be played.
  player.playerCanPlayCard(id.parseCardId())

proc actionSpaceStates*(numPlayers: int): seq[ActionSpace]
    {.raises: [SolverError].} =
  ## Builds initial action-space state for one player count.
  for action in fixedBoardActions(numPlayers):
    result.add ActionSpace(id: action, occupiedBy: NoPlayer)

proc newGame*(seed: int, numPlayers: int): GameState
    {.raises: [SolverError].} =
  ## Creates a new Agricogla game state with randomized decks.
  req(numPlayers >= 1 and numPlayers <= 4, "Supported player counts: 1-4.")
  var rng = initRng(seed)
  var
    occupationDeck = rng.shuffled(OccupationCards)
    minorDeck = rng.shuffled(MinorCards)
    occupationIdx = 0
    minorIdx = 0
  result.seed = seed
  result.numPlayers = numPlayers
  result.solo = numPlayers == 1
  result.phase = Work
  result.actionSpaces = actionSpaceStates(numPlayers)
  for idx in 0 ..< numPlayers:
    var player = PlayerState(
      idx: idx,
      spaces: freshFarm(),
      houseMaterial: HouseWood,
      family: @[
        FamilyMember(bornRound: 0),
        FamilyMember(bornRound: 0)
      ]
    )
    for _ in 0 ..< HandSize:
      if occupationIdx < occupationDeck.len:
        player.handOccupations.add occupationDeck[occupationIdx]
        inc occupationIdx
      if minorIdx < minorDeck.len:
        player.handMinors.add minorDeck[minorIdx]
        inc minorIdx
    result.players.add player
  result.startingPlayer = rng.randInt(numPlayers)
  result.currentPlayer = result.startingPlayer
  result.roundDeck = rng.buildRoundDeck()
  result.majorsAvailable = @MajorCards
  for idx in 0 ..< result.players.len:
    var player = result.players[idx]
    player.startingPlayerMarker = idx == result.startingPlayer
    player.resources[Food] =
      if result.solo:
        0
      elif idx == result.startingPlayer:
        2
      else:
        3
    result.players[idx] = player

proc startRound*(state: var GameState) {.raises: [SolverError].} =
  ## Reveals a round card, replenishes spaces, and starts work.
  if state.round >= TotalRounds:
    state.phase = Finished
    state.scores = @[]
    return
  state.round += 1
  state.phase = Work
  state.toFeed = @[]
  for space in state.actionSpaces.mitems:
    space.occupiedBy = NoPlayer
  if state.roundDeck.len > 0:
    let revealed = state.roundDeck[0]
    state.roundDeck.delete(0)
    state.actionSpaces.add ActionSpace(id: revealed, occupiedBy: NoPlayer)
  var remaining: seq[ScheduledGoods]
  for scheduled in state.scheduled:
    if scheduled.round == state.round:
      var player = state.players[scheduled.playerIdx]
      state.gainGoods(player, MeetingPlace, scheduled.goods)
      state.players[scheduled.playerIdx] = player
    else:
      remaining.add scheduled
  state.scheduled = remaining
  for space in state.actionSpaces.mitems:
    space.pile.add spaceDef(space.id, state.numPlayers).accumulates
  state.currentPlayer = state.startingPlayer

proc startGame*(state: var GameState) {.raises: [SolverError].} =
  ## Starts round one after setup.
  if state.round == 0:
    state.startRound()

proc buildRooms(state: var GameState, player: var PlayerState, rooms: seq[int])
    {.raises: [SolverError].} =
  ## Builds rooms for one player.
  for space in rooms:
    req(space in player.legalRoomSpaces(), "Cannot build room at " & $space & ".")
    player.pay(player.roomCost())
    player.spaces[space].kind = Room

proc buildStables(player: var PlayerState, stables: seq[int])
    {.raises: [SolverError].} =
  ## Builds stables for one player.
  for space in stables:
    req(player.stableCount() < MaxStables, "Maximum stables already built.")
    req(space in player.legalStableSpaces(), "Cannot build stable at " & $space & ".")
    var cost: Goods
    cost.resources[Wood] = 2
    player.pay(cost)
    player.spaces[space].stable = true

proc plowFields(player: var PlayerState, fields: seq[int])
    {.raises: [SolverError].} =
  ## Plows one or more fields.
  req(fields.len >= 1, "Must plow at least one field.")
  for space in fields:
    req(space in player.legalFieldSpaces(), "Cannot plow at " & $space & ".")
    player.spaces[space].kind = Field
    player.spaces[space].crop = NoCrop
    player.spaces[space].cropCount = 0

proc sow(player: var PlayerState, choices: seq[SowChoice])
    {.raises: [SolverError].} =
  ## Sows crops into empty fields.
  var seen: HashSet[int]
  for choice in choices:
    req(not seen.contains(choice.space), "Cannot sow one field twice.")
    seen.incl choice.space
    req(choice.space >= 0 and choice.space < NumSpaces, "Bad sow space.")
    req(player.spaces[choice.space].kind == Field, "Sow space is not a field.")
    req(player.spaces[choice.space].cropCount == 0, "Field is already sown.")
    case choice.crop
    of GrainCrop:
      req(player.resources[Grain] > 0, "No grain to sow.")
      player.resources[Grain] -= 1
      player.spaces[choice.space].crop = GrainCrop
      player.spaces[choice.space].cropCount = 3
    of VegetableCrop:
      req(player.resources[Vegetable] > 0, "No vegetable to sow.")
      player.resources[Vegetable] -= 1
      player.spaces[choice.space].crop = VegetableCrop
      player.spaces[choice.space].cropCount = 2
    of NoCrop:
      fail("Cannot sow NoCrop.")

proc bake(player: var PlayerState, choices: seq[BakeChoice])
    {.raises: [SolverError].} =
  ## Bakes grain into food.
  var used: HashSet[CardId]
  for choice in choices:
    req(not used.contains(choice.card), "Cannot bake twice with one card.")
    used.incl choice.card
    req(player.hasPlayed(choice.card), "Baking card is not in play.")
    let power = bakePower(choice.card)
    req(power.perGrain > 0, "Card cannot bake.")
    req(choice.grain >= 1 and choice.grain <= power.maxGrain, "Bad bake amount.")
    req(player.resources[Grain] >= choice.grain, "Not enough grain.")
    player.resources[Grain] -= choice.grain
    player.resources[Food] += choice.grain * power.perGrain

proc renovate(player: var PlayerState) {.raises: [SolverError].} =
  ## Renovates a player's home to the next material.
  player.pay(player.renovationCost())
  case player.houseMaterial
  of HouseWood:
    player.houseMaterial = HouseClay
  of HouseClay:
    player.houseMaterial = HouseStone
  of HouseStone:
    fail("House is already stone.")

proc buildFences(player: var PlayerState, edges: seq[EdgeId])
    {.raises: [SolverError].} =
  ## Adds a legal fence plan to a farmyard.
  req(player.validateFencePlan(edges), "Illegal fence plan.")
  var freeFences = 0
  if player.hasPlayed(OccHedgeWarden):
    freeFences += 2
  if player.hasPlayed(MinFencePosts):
    freeFences += 1
  var cost: Goods
  cost.resources[Wood] = max(0, edges.len - freeFences)
  player.pay(cost)
  player.fences.add edges
  player.fencesBuilt += edges.len

proc growFamily(player: var PlayerState, stateRound: int, needRoom: bool)
    {.raises: [SolverError].} =
  ## Adds one family member.
  req(player.family.len < MaxFamily, "Family is already 5.")
  if needRoom:
    req(player.roomCount() > player.family.len, "No free room.")
  player.family.add FamilyMember(bornRound: stateRound, placed: true)

proc applyOnPlay(state: var GameState, player: var PlayerState, id: CardId) =
  ## Applies a small subset of immediate and scheduled card effects.
  case id
  of MajWell:
    for round in state.round + 1 .. min(TotalRounds, state.round + 5):
      state.scheduled.add ScheduledGoods(
        round: round,
        playerIdx: player.idx,
        goods: goods(Food, 1)
      )
  of MinCarpPond:
    for round in state.round + 1 .. min(TotalRounds, state.round + 4):
      state.scheduled.add ScheduledGoods(
        round: round,
        playerIdx: player.idx,
        goods: goods(Food, 1)
      )
  of MinReedPond:
    for round in state.round + 1 .. min(TotalRounds, state.round + 3):
      state.scheduled.add ScheduledGoods(
        round: round,
        playerIdx: player.idx,
        goods: goods(Reed, 1)
      )
  of MinClayDeposit:
    for round in state.round + 1 .. min(TotalRounds, state.round + 3):
      state.scheduled.add ScheduledGoods(
        round: round,
        playerIdx: player.idx,
        goods: goods(Clay, 1)
      )
  of MinWoodCache:
    for round in state.round + 1 .. min(TotalRounds, state.round + 3):
      state.scheduled.add ScheduledGoods(
        round: round,
        playerIdx: player.idx,
        goods: goods(Wood, 1)
      )
  of MinSeedStock:
    for round in state.round + 1 .. min(TotalRounds, state.round + 2):
      state.scheduled.add ScheduledGoods(
        round: round,
        playerIdx: player.idx,
        goods: goods(Grain, 1)
      )
  of MinWoodCart:
    player.resources[Wood] += 3
  of MinClayPitClaim:
    player.resources[Clay] += 2
  of MinMarketStall:
    player.resources[Vegetable] += 1
    player.resources[Food] += 1
  of MinStoneCart:
    player.resources[Stone] += 2
  of OccGrainSteward:
    player.resources[Grain] += 2
  of OccWaterCarrier:
    player.resources[Food] += 2
  of OccWoodward:
    player.resources[Wood] += 2
  of OccSeedMerchant:
    player.resources[Grain] += 1
  of OccVegPeddler:
    player.resources[Vegetable] += 1
  else:
    discard

proc playOccupation(state: var GameState, player: var PlayerState, id: CardId,
    foodCost: int) {.raises: [SolverError].} =
  ## Plays one occupation from hand.
  req(id.knownOccupation(), "Occupation is unknown to solver.")
  let index = player.handOccupations.find(id)
  req(index >= 0, "Occupation is not in hand.")
  req(player.occupations.len >= cardPrereqOccs(id), "Occupation prerequisite failed.")
  var cost: Goods
  cost.resources[Food] = foodCost
  player.pay(cost)
  player.handOccupations.delete(index)
  player.occupations.add id
  state.applyOnPlay(player, id)

proc playMinor(state: var GameState, player: var PlayerState, id: CardId)
    {.raises: [SolverError].} =
  ## Plays one minor improvement from hand.
  req(id.knownMinor(), "Minor is unknown to solver.")
  let index = player.handMinors.find(id)
  req(index >= 0, "Minor is not in hand.")
  req(player.playerCanPlayCard(id), "Minor is not playable.")
  player.pay(cardCost(id))
  player.handMinors.delete(index)
  player.minors.add id
  state.applyOnPlay(player, id)

proc buyMajor(state: var GameState, player: var PlayerState, id: CardId)
    {.raises: [SolverError].} =
  ## Buys one available major improvement.
  req(id.knownMajor(), "Major is unknown to solver.")
  let index = state.majorsAvailable.find(id)
  req(index >= 0, "Major is not available.")
  req(player.playerCanPlayCard(id), "Major is not playable.")
  player.pay(cardCost(id))
  state.majorsAvailable.delete(index)
  player.majors.add id
  state.applyOnPlay(player, id)

proc playImprovement(state: var GameState, player: var PlayerState,
    choice: ImprovementChoice, allowMajor: bool, allowMinor: bool)
    {.raises: [SolverError].} =
  ## Plays or buys one improvement choice.
  case choice.kind
  of MajorImprovement:
    req(allowMajor, "Major is not allowed here.")
    state.buyMajor(player, choice.card)
    if choice.bake.len > 0:
      player.bake(choice.bake)
  of MinorImprovement:
    req(allowMinor, "Minor is not allowed here.")
    state.playMinor(player, choice.card)
  of NoImprovement:
    discard

proc takeSpaceGoods(state: var GameState, player: var PlayerState, action: ActionId)
    {.raises: [SolverError].} =
  ## Takes accumulated and fixed goods from an action space.
  let index = state.findActionIndex(action)
  req(index >= 0, "Action is not in play.")
  var goods = state.actionSpaces[index].pile
  goods.add spaceDef(action, state.numPlayers).fixedGoods
  state.actionSpaces[index].pile = Goods()
  state.gainGoods(player, action, goods)

proc finishGame*(state: var GameState) =
  ## Finishes the game and writes final scores.
  state.phase = Finished
  state.scores = @[]

proc startHarvest*(state: var GameState) =
  ## Harvests fields and starts the feeding phase.
  for player in state.players.mitems:
    for space in player.spaces.mitems:
      if space.kind == Field and space.crop != NoCrop and space.cropCount > 0:
        space.cropCount -= 1
        case space.crop
        of GrainCrop:
          player.resources[Grain] += 1
        of VegetableCrop:
          player.resources[Vegetable] += 1
        of NoCrop:
          discard
        if space.cropCount == 0:
          space.crop = NoCrop
  state.phase = Feeding
  state.toFeed = @[]
  for player in state.players:
    state.toFeed.add player.idx

proc advanceWork*(state: var GameState) {.raises: [SolverError].} =
  ## Advances to the next worker or the next phase.
  let n = state.numPlayers
  for offset in 1 .. n:
    let idx = (state.currentPlayer + offset) mod n
    if state.players[idx].family.anyIt(not it.placed):
      state.currentPlayer = idx
      return
  for player in state.players.mitems:
    for member in player.family.mitems:
      member.placed = false
  if state.round.hasHarvest():
    state.startHarvest()
  else:
    state.startRound()

proc resolvePlacement(state: var GameState, player: var PlayerState, move: Move)
    {.raises: [SolverError].} =
  ## Resolves the payload of one worker placement.
  case move.action
  of FarmExpansion:
    req(move.rooms.len + move.stables.len > 0, "Build action needs payload.")
    state.buildRooms(player, move.rooms)
    player.buildStables(move.stables)
  of MeetingPlace:
    state.startingPlayer = player.idx
    player.startingPlayerMarker = true
    for other in state.players.mitems:
      other.startingPlayerMarker = other.idx == player.idx
    state.playImprovement(player, move.improvement, false, true)
  of Farmland:
    player.plowFields(move.fields)
  of Lessons, LessonsB:
    state.playOccupation(
      player,
      move.occupation,
      state.occupationCost(player, move.action)
    )
  of GrainSeeds, DayLaborer, Forest, ClayPit, ReedBank, Fishing, Copse,
    Grove, Hollow, QuarryStall, ResourceMarket, TravelingPlayers, RSheep,
    RWestQuarry, RVegetable, RBoar, REastQuarry, RCattle:
      state.takeSpaceGoods(player, move.action)
  of RImprovement:
    state.playImprovement(player, move.improvement, true, true)
  of RFences:
    player.buildFences(move.edges)
  of RSowBake:
    req(move.sow.len + move.bake.len > 0, "Sow/bake needs payload.")
    player.sow(move.sow)
    player.bake(move.bake)
  of RRenovateImprove:
    player.renovate()
    state.playImprovement(player, move.improvement, true, true)
  of RFamilyGrowth:
    player.growFamily(state.round, true)
    state.playImprovement(player, move.improvement, false, true)
  of RUrgentFamily:
    player.growFamily(state.round, false)
  of RCultivation:
    req(move.plow != NoSpace or move.sow.len > 0, "Cultivation needs payload.")
    if move.plow != NoSpace:
      player.plowFields(@[move.plow])
    player.sow(move.sow)
  of RRedevelop:
    player.renovate()
    if move.edges.len > 0:
      player.buildFences(move.edges)

proc applyPlacementInPlace*(state: var GameState, move: Move)
    {.raises: [SolverError].} =
  ## Applies one placement directly to a mutable game state.
  req(state.phase == Work, "Not in work phase.")
  req(state.currentPlayer == move.playerIdx, "Wrong current player.")
  req(state.isAvailable(move.action), "Action is unavailable.")
  var player = state.players[move.playerIdx]
  var memberIndex = NoSpace
  for i, member in player.family:
    if not member.placed:
      memberIndex = i
      break
  req(memberIndex != NoSpace, "No family member left.")
  state.resolvePlacement(player, move)
  let actionIndex = state.findActionIndex(move.action)
  state.actionSpaces[actionIndex].occupiedBy = move.playerIdx
  player.family[memberIndex].placed = true
  state.players[move.playerIdx] = player
  state.advanceWork()

proc applyPlacement*(state: GameState, move: Move): GameState
    {.raises: [SolverError].} =
  ## Applies one placement and advances the game.
  result = state.copy()
  result.applyPlacementInPlace(move)

proc foodNeeded*(state: GameState, player: PlayerState): int =
  ## Returns food needed in the current harvest.
  let perAdult =
    if state.solo:
      3
    else:
      2
  for member in player.family:
    if member.bornRound == state.round:
      result += 1
    else:
      result += perAdult

proc computeAutoFeed*(state: GameState, playerIdx: int): FeedDecision =
  ## Computes the TypeScript auto-feeding decision for node walking.
  var player = state.players[playerIdx].copy()
  let needed = state.foodNeeded(player)
  var
    decision: FeedDecision
    have = player.resources[Food]

  proc addResource(via: CardId, resource: Resource, count, foodEach: int) =
    ## Adds one resource conversion to the feeding decision.
    decision.conversions.add FeedConversion(
      via: via,
      resource: resource,
      count: count
    )
    player.resources[resource] -= count
    have += count * foodEach

  proc addAnimal(via: CardId, animal: Animal, count, foodEach: int) =
    ## Adds one animal conversion to the feeding decision.
    decision.conversions.add FeedConversion(
      via: via,
      animal: animal,
      usesAnimal: true,
      count: count
    )
    player.animals[animal] -= count
    have += count * foodEach

  for id in player.playedCards():
    if have >= needed:
      break
    let harvest = harvestFood(id)
    if harvest.food <= 0:
      continue
    let spare = max(0, player.resources[harvest.resource] - 2)
    let wanted = (needed - have + harvest.food - 1) div harvest.food
    let count = min(harvest.maxCount, min(spare, wanted))
    if count > 0:
      addResource(id, harvest.resource, count, harvest.food)
  while have < needed and player.resources[Grain] > 0:
    addResource(NoCard, Grain, 1, 1)
  for animal in Animal:
    let cook = player.bestCookCard(animal)
    if cook.rate <= 0:
      continue
    while have < needed and player.animals[animal] > 2:
      addAnimal(cook.id, animal, 1, cook.rate)
  while have < needed and player.resources[Vegetable] > 0:
    addResource(NoCard, Vegetable, 1, 1)
  for animal in Animal:
    let cook = player.bestCookCard(animal)
    if cook.rate <= 0:
      continue
    while have < needed and player.animals[animal] > 0:
      addAnimal(cook.id, animal, 1, cook.rate)
  result = decision

proc breed*(state: var GameState) {.raises: [SolverError].} =
  ## Breeds animals after all players feed.
  let priority = [Cattle, Boar, Sheep]
  for player in state.players.mitems:
    for animal in priority:
      if player.animals[animal] < 2:
        continue
      var counts = player.animals
      counts[animal] += 1
      if player.canAccommodate(counts):
        player.animals[animal] += 1

proc applyFeedingInPlace*(state: var GameState, move: Move)
    {.raises: [SolverError].} =
  ## Applies one feeding decision directly to a mutable game state.
  req(state.phase == Feeding, "Not in feeding phase.")
  req(move.playerIdx in state.toFeed, "Player has already fed.")
  var player = state.players[move.playerIdx]
  for conversion in move.feed.conversions:
    if conversion.usesAnimal:
      req(player.hasPlayed(conversion.via), "Cooking card is not in play.")
      let rate = cookRate(conversion.via, conversion.animal)
      req(rate > 0, "No animal cooking rate.")
      req(player.animals[conversion.animal] >= conversion.count,
        "Not enough animals.")
      player.animals[conversion.animal] -= conversion.count
      player.resources[Food] += rate * conversion.count
    else:
      if conversion.via == NoCard:
        req(conversion.resource in {Grain, Vegetable},
          "Only crops convert raw.")
        req(player.resources[conversion.resource] >= conversion.count,
          "Not enough resources.")
        player.resources[conversion.resource] -= conversion.count
        player.resources[Food] += conversion.count
        continue
      req(player.hasPlayed(conversion.via), "Conversion card is not in play.")
      req(player.resources[conversion.resource] >= conversion.count,
        "Not enough resources.")
      if conversion.resource == Grain:
        fail("Grain can only convert raw during feeding.")
      elif conversion.resource == Vegetable:
        let rate = vegetableCookRate(conversion.via)
        req(rate > 0, "No vegetable cooking rate.")
        player.resources[conversion.resource] -= conversion.count
        player.resources[Food] += rate * conversion.count
      else:
        let harvest = harvestFood(conversion.via)
        req(harvest.food > 0, "No harvest conversion rate.")
        req(harvest.resource == conversion.resource,
          "Harvest conversion resource mismatch.")
        req(conversion.count <= harvest.maxCount,
          "Harvest conversion count is too high.")
        player.resources[conversion.resource] -= conversion.count
        player.resources[Food] += harvest.food * conversion.count
  let needed = state.foodNeeded(player)
  let paid = min(needed, player.resources[Food])
  player.resources[Food] -= paid
  let missing = needed - paid
  if missing > 0:
    player.beggingCards += missing
  state.players[move.playerIdx] = player
  state.toFeed = state.toFeed.filterIt(it != move.playerIdx)
  if state.toFeed.len == 0:
    state.breed()
    state.startRound()

proc applyFeeding*(state: GameState, move: Move): GameState
    {.raises: [SolverError].} =
  ## Applies one feeding decision and advances after the last feeder.
  result = state.copy()
  result.applyFeedingInPlace(move)

proc applyMoveInPlace*(state: var GameState, move: Move)
    {.raises: [SolverError].} =
  ## Applies a placement or feeding move directly to a mutable state.
  case move.kind
  of PlacementMove:
    state.applyPlacementInPlace(move)
  of FeedingMove:
    state.applyFeedingInPlace(move)

proc applyMove*(state: GameState, move: Move): GameState
    {.raises: [SolverError].} =
  ## Applies a placement or feeding move.
  result = state.copy()
  result.applyMoveInPlace(move)

proc scoreTier(count: int, tiers: openArray[(int, int)], negativeBelow: int):
    int =
  ## Scores one Agricogla tiered category.
  if count < negativeBelow:
    return -1
  for tier in tiers:
    if count >= tier[0]:
      result = tier[1]

proc scorePlayer*(state: GameState, player: PlayerState): int
    {.raises: [SolverError].} =
  ## Scores one player with Agricogla's implemented categories.
  let layout = computePastures(player.spaces, player.fences)
  var fields = 0
  for space in player.spaces:
    if space.kind == Field:
      fields += 1
  result += scoreTier(fields, [(2, 1), (3, 2), (4, 3), (5, 4)], 2)
  result += scoreTier(layout.pastureCount, [(1, 1), (2, 2), (3, 3),
    (4, 4)], 1)
  var grain = player.resources[Grain]
  var vegetable = player.resources[Vegetable]
  for space in player.spaces:
    if space.crop == GrainCrop:
      grain += space.cropCount
    elif space.crop == VegetableCrop:
      vegetable += space.cropCount
  result += scoreTier(grain, [(1, 1), (4, 2), (6, 3), (8, 4)], 1)
  result += scoreTier(vegetable, [(1, 1), (2, 2), (3, 3), (4, 4)], 1)
  result += scoreTier(player.animals[Sheep], [(1, 1), (4, 2), (6, 3),
    (8, 4)], 1)
  result += scoreTier(player.animals[Boar], [(1, 1), (3, 2), (5, 3),
    (7, 4)], 1)
  result += scoreTier(player.animals[Cattle], [(1, 1), (2, 2), (4, 3),
    (6, 4)], 1)
  var unused = 0
  var fencedStables = 0
  for i, space in player.spaces:
    if space.kind == Empty and not space.stable and
        not layout.pastureCells.contains(i):
      unused += 1
    if space.stable and layout.pastureCells.contains(i):
      fencedStables += 1
  result -= unused
  result += fencedStables
  let rooms = player.roomCount()
  case player.houseMaterial
  of HouseWood:
    discard
  of HouseClay:
    result += rooms
  of HouseStone:
    result += rooms * 2
  result += player.family.len * 3
  result -= player.beggingCards * 3
  for id in player.playedCards():
    result += cardVp(id)

proc scoreGame*(state: var GameState) {.raises: [SolverError].} =
  ## Writes all current player scores into the state.
  state.scores = @[]
  for player in state.players:
    state.scores.add state.scorePlayer(player)

proc scoreValue*(state: GameState, playerIdx: int): int
    {.raises: [SolverError].} =
  ## Returns one player's current or final score.
  req(
    playerIdx >= 0 and playerIdx < state.players.len,
    "Player index out of range."
  )
  if state.scores.len == state.players.len:
    return state.scores[playerIdx]
  state.scorePlayer(state.players[playerIdx])

proc scoreMargin*(state: GameState, playerIdx: int): int
    {.raises: [SolverError].} =
  ## Returns a player's margin over the best other player.
  let ownScore = state.scoreValue(playerIdx)
  if state.players.len <= 1:
    return ownScore
  var bestOther = low(int)
  for i in 0 ..< state.players.len:
    if i != playerIdx:
      bestOther = max(bestOther, state.scoreValue(i))
  ownScore - bestOther

proc animalScoreValue(animal: Animal, count: int): int =
  ## Returns the endgame score for one animal category.
  case animal
  of Sheep:
    scoreTier(count, [(1, 1), (4, 2), (6, 3), (8, 4)], 1)
  of Boar:
    scoreTier(count, [(1, 1), (3, 2), (5, 3), (7, 4)], 1)
  of Cattle:
    scoreTier(count, [(1, 1), (2, 2), (4, 3), (6, 4)], 1)

proc feedingRisk*(state: GameState, playerIdx: int): FeedingRisk
    {.raises: [SolverError].} =
  ## Projects immediate auto-feed risk for one player.
  req(
    playerIdx >= 0 and playerIdx < state.players.len,
    "Player index out of range."
  )
  let
    player = state.players[playerIdx]
    decision = state.computeAutoFeed(playerIdx)
  result.foodNeeded = state.foodNeeded(player)
  result.food = player.resources[Food]
  result.foodGap = max(0, result.foodNeeded - result.food)
  var afterAnimals = player.animals
  for conversion in decision.conversions:
    if not conversion.usesAnimal:
      continue
    result.animalsCooked[conversion.animal] += conversion.count
    result.totalAnimalsCooked += conversion.count
    afterAnimals[conversion.animal] -= conversion.count
  for animal in Animal:
    let scoreLoss =
      animal.animalScoreValue(player.animals[animal]) -
      animal.animalScoreValue(afterAnimals[animal])
    result.animalScoreLoss += max(0, scoreLoss)
  var check = state.copy()
  check.phase = Feeding
  check.toFeed = @[playerIdx]
  let
    beforeBegging = check.players[playerIdx].beggingCards
    after = check.applyMove(Move(
      kind: FeedingMove,
      playerIdx: playerIdx,
      feed: decision
    ))
  result.begging = after.players[playerIdx].beggingCards - beforeBegging

proc roomProgress*(player: PlayerState): float =
  ## Returns how close one player is to affording a new room.
  let cost = player.roomCost()
  var
    required = 0
    ready = 0
  for resource in Resource:
    let needed = cost.resources[resource]
    if needed <= 0:
      continue
    required += needed
    ready += min(player.resources[resource], needed)
  if required == 0:
    return 0
  ready.float / required.float

proc evaluateState*(state: GameState, perspective: int): float
    {.raises: [SolverError].} =
  ## Returns a heuristic value from one player's perspective.
  if state.phase == Finished:
    return state.scoreMargin(perspective).float
  let player = state.players[perspective]
  let
    rooms = player.roomCount()
    family = player.family.len
    roundsLeft = max(0, TotalRounds - state.round)
    growthSlots = max(0, MaxFamily - family)
    freeRooms = min(max(0, rooms - family), growthSlots)
  result = state.scoreMargin(perspective).float
  for resource in Resource:
    result += player.resources[resource].float * 0.15
  result += family.float * 2.0
  result += player.animals.totalAnimals().float * 0.2
  result += roundsLeft.float * family.float * 0.12
  result += freeRooms.float * (2.0 + roundsLeft.float * 0.35)
  if growthSlots > 0 and freeRooms == 0 and state.round <= 10:
    result += player.roomProgress() * 5.0
  let
    risk = state.feedingRisk(perspective)
    harvestWait = state.round.turnsToHarvest()
    foodUrgency =
      if state.phase == Feeding or harvestWait == 0:
        1.0
      elif harvestWait == 1:
        0.75
      elif harvestWait == 2:
        0.35
      else:
        0.1
  result -= risk.begging.float * 8.0
  if risk.begging > 0 or harvestWait <= 1:
    result -= risk.animalScoreLoss.float * 0.45 * foodUrgency
    result -= risk.totalAnimalsCooked.float * 0.12 * foodUrgency
  if risk.begging > 0:
    result -= risk.foodGap.float * 0.25 * foodUrgency

proc addMove(moves: var MoveBuffer, playerIdx: int, action: ActionId)
    {.raises: [SolverError].} =
  ## Adds a bare placement move.
  moves.add Move(
    kind: PlacementMove,
    playerIdx: playerIdx,
    action: action,
    plow: NoSpace
  )

proc topCards(cards: seq[CardId], limit: int): seq[CardId] =
  ## Returns a small prefix of card choices for branching control.
  for i in 0 ..< min(cards.len, limit):
    result.add cards[i]

proc totalCost(cost: Goods): int =
  ## Returns the total resource count in a card cost.
  for resource in Resource:
    result += cost.resources[resource]

proc hasAnimalCooker(player: PlayerState): bool =
  ## Returns true when the player can cook at least one animal.
  for animal in Animal:
    if player.bestCookRate(animal) > 0:
      return true

proc cropCount(player: PlayerState, crop: Crop): int =
  ## Counts stored and planted crops of one type.
  case crop
  of GrainCrop:
    result = player.resources[Grain]
  of VegetableCrop:
    result = player.resources[Vegetable]
  of NoCrop:
    return
  for space in player.spaces:
    if space.crop == crop:
      result += space.cropCount

proc fieldCount(player: PlayerState): int =
  ## Counts field spaces.
  for space in player.spaces:
    if space.kind == Field:
      inc result

proc hasCropPipeline(player: PlayerState, crop: Crop): bool =
  ## Returns true when a crop has more than a one-shot supply.
  player.cropCount(crop) >= 2 or
    (player.cropCount(crop) > 0 and player.fieldCount() > 0)

proc majorBranchPriority(
  state: GameState,
  player: PlayerState,
  id: CardId
): int =
  ## Returns a branch ordering score for major improvements.
  result = cardVp(id) * 20 - totalCost(cardCost(id))
  case id
  of MajFireplace2:
    if player.hasAnimalCooker():
      result += 20
    else:
      result += 125
  of MajHearth4:
    if player.hasAnimalCooker():
      result += 24
    else:
      result += 120
  of MajWell:
    if state.round <= 9:
      result += 80
    elif state.round <= 11:
      result += 45
    else:
      result += 20
  of MajJoinery, MajPottery, MajBasketmaker:
    if state.round <= 11:
      result += 55
    else:
      result += 25
  of MajStoneOven, MajClayOven:
    if player.hasCropPipeline(GrainCrop):
      result += 45
    else:
      result += 8
  of MajFireplace3:
    if player.hasAnimalCooker():
      result += 12
    else:
      result += 90
  of MajHearth5:
    if player.hasAnimalCooker():
      result += 14
    else:
      result += 85
  else:
    discard

proc minorBranchPriority(player: PlayerState, id: CardId): int =
  ## Returns a branch ordering score for minor improvements.
  result = cardVp(id) * 20 - totalCost(cardCost(id))
  case id
  of MinCookingCorner, MinStewpot, MinSmokehouse:
    if player.hasAnimalCooker():
      result += 16
    else:
      result += 80
  of MinCarpPond, MinReedPond, MinClayDeposit, MinWoodCache,
      MinSeedStock, MinWoodCart, MinClayPitClaim, MinHerbGarden,
      MinMilkPail, MinDryingShed, MinDovecote, MinRainBarrel:
    result += 28
  of MinWoodenPlow, MinHeavyPlow, MinHandcart, MinThreshingBoard,
      MinGrainLoft:
    if player.fieldCount() < 4:
      result += 24
  of MinAnimalPen, MinPigSty, MinSheepFold, MinShearingShears,
      MinShepherdsCrook, MinPigTrough, MinCattleShed, MinPaddock,
      MinCattleProd:
    result += 18
  of MinGabledHouse, MinCarvedChest, MinPewterJug, MinRootCellar,
      MinScarecrow:
    result += 12
  else:
    discard

proc affordableMajors*(state: GameState, player: PlayerState): seq[CardId] =
  ## Returns currently affordable major improvements.
  for id in state.majorsAvailable:
    if id.knownMajor() and player.playerCanPlayCard(id):
      result.add id
  result.sort do (a, b: CardId) -> int:
    result = cmp(
      state.majorBranchPriority(player, b),
      state.majorBranchPriority(player, a)
    )
    if result == 0:
      result = cmp(ord(a), ord(b))

proc affordableMinors*(player: PlayerState): seq[CardId] =
  ## Returns currently affordable minor improvements.
  for id in player.handMinors:
    if id.knownMinor() and player.playerCanPlayCard(id):
      result.add id
  result.sort do (a, b: CardId) -> int:
    result = cmp(
      player.minorBranchPriority(b),
      player.minorBranchPriority(a)
    )
    if result == 0:
      result = cmp(ord(a), ord(b))

proc cardPlayableWithCost(
  player: PlayerState,
  id: CardId,
  extraCost: Goods,
  afterRenovation: bool
): bool =
  ## Returns true when a card is playable after an extra action cost.
  if not id.knownMinor() and not id.knownMajor():
    return false
  var cost = extraCost
  cost.add cardCost(id)
  if not player.canAfford(cost):
    return false
  var check = player
  if afterRenovation:
    check = player.copy()
    case check.houseMaterial
    of HouseWood:
      check.houseMaterial = HouseClay
    of HouseClay:
      check.houseMaterial = HouseStone
    of HouseStone:
      discard
  check.occupations.len >= cardPrereqOccs(id) and
    check.cardSpecialPrereqOk(id)

proc comboMajors(
  state: GameState,
  player: PlayerState,
  extraCost: Goods,
  afterRenovation: bool
): seq[CardId] =
  ## Returns major improvements playable as part of another action.
  for id in state.majorsAvailable:
    if id.knownMajor() and
        player.cardPlayableWithCost(id, extraCost, afterRenovation):
      result.add id
  result.sort do (a, b: CardId) -> int:
    result = cmp(
      state.majorBranchPriority(player, b),
      state.majorBranchPriority(player, a)
    )
    if result == 0:
      result = cmp(ord(a), ord(b))

proc comboMinors(
  player: PlayerState,
  extraCost: Goods,
  afterRenovation: bool
): seq[CardId] =
  ## Returns minor improvements playable as part of another action.
  for id in player.handMinors:
    if id.knownMinor() and
        player.cardPlayableWithCost(id, extraCost, afterRenovation):
      result.add id
  result.sort do (a, b: CardId) -> int:
    result = cmp(
      player.minorBranchPriority(b),
      player.minorBranchPriority(a)
    )
    if result == 0:
      result = cmp(ord(a), ord(b))

proc addImprovementCombos(
  moves: var MoveBuffer,
  state: GameState,
  player: PlayerState,
  playerIdx: int,
  action: ActionId,
  extraCost: Goods,
  afterRenovation,
  allowMajor,
  allowMinor: bool
) {.raises: [SolverError].} =
  ## Adds capped improvement payloads for one combo action.
  if allowMajor:
    let majors = state.comboMajors(player, extraCost, afterRenovation)
    for id in majors.topCards(3):
      moves.add Move(
        kind: PlacementMove,
        playerIdx: playerIdx,
        action: action,
        improvement: ImprovementChoice(kind: MajorImprovement, card: id),
        plow: NoSpace
      )
  if allowMinor:
    let minors = player.comboMinors(extraCost, afterRenovation)
    for id in minors.topCards(3):
      moves.add Move(
        kind: PlacementMove,
        playerIdx: playerIdx,
        action: action,
        improvement: ImprovementChoice(kind: MinorImprovement, card: id),
        plow: NoSpace
      )

proc simpleSowChoices*(player: PlayerState): seq[SowChoice] =
  ## Builds one greedy sowing payload.
  var
    grain = player.resources[Grain]
    vegetable = player.resources[Vegetable]
  for space in player.sowableFields():
    if vegetable > 0:
      result.add SowChoice(space: space, crop: VegetableCrop)
      vegetable -= 1
    elif grain > 0:
      result.add SowChoice(space: space, crop: GrainCrop)
      grain -= 1

proc simpleSowChoicesWithField(
  player: PlayerState,
  field: int
): seq[SowChoice] =
  ## Builds one greedy sowing payload including a newly plowed field.
  var
    grain = player.resources[Grain]
    vegetable = player.resources[Vegetable]
    fields = player.sowableFields()
  if field != NoSpace:
    fields.add field
  for space in fields:
    if vegetable > 0:
      result.add SowChoice(space: space, crop: VegetableCrop)
      vegetable -= 1
    elif grain > 0:
      result.add SowChoice(space: space, crop: GrainCrop)
      grain -= 1

proc suggestFencePlans*(player: PlayerState, limit = 12): seq[FencePlan]
    {.raises: [SolverError].} =
  ## Suggests rectangular fence plans for node expansion.
  let existing = player.fences.edgeMaskOf()
  if not existing.ok:
    return
  var blocked: CellSet
  for cell, space in player.spaces:
    if space.kind != Empty:
      blocked = blocked or CellBits[cell]
  let before = computePastures(player.spaces, existing.mask)
  for candidate in FenceCandidates:
    if candidate.cellCount > 6:
      continue
    if candidate.cellMask.intersects(blocked):
      continue
    let edgeMask = candidate.edgeMask and not existing.mask
    if edgeMask == EdgeMask(0):
      continue
    let edgeCount = edgeMask.countEdges()
    if player.validateFenceMask(existing.mask, edgeMask, edgeCount, before):
      result.add FencePlan(
        edges: edgeMask.maskEdges(),
        cost: edgeCount,
        cellCount: candidate.cellCount
      )
  result.sort compareFencePlans
  if limit > 0 and result.len > limit:
    result.setLen(limit)

proc legalMoves*(state: GameState, moves: var MoveBuffer) {.raises: [SolverError].} =
  ## Generates solver-friendly legal moves into a reusable buffer.
  moves.clear()
  if state.phase == Finished:
    return
  if state.phase == Feeding:
    if state.toFeed.len > 0:
      let playerIdx = state.toFeed[0]
      moves.add Move(
        kind: FeedingMove,
        playerIdx: playerIdx,
        feed: state.computeAutoFeed(playerIdx),
        plow: NoSpace
      )
    return
  let
    playerIdx = state.currentPlayer
    player = state.players[playerIdx]
  for space in state.actionSpaces:
    if space.occupiedBy != NoPlayer:
      continue
    case space.id
    of FarmExpansion:
      let rooms = player.legalRoomSpaces()
      if rooms.len > 0 and player.canAfford(player.roomCost()):
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: FarmExpansion,
          rooms: @[rooms[0]],
          plow: NoSpace
        )
      let stables = player.legalStableSpaces()
      var stableCost: Goods
      stableCost.resources[Wood] = 2
      if stables.len > 0 and player.stableCount() < MaxStables and
          player.canAfford(stableCost):
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: FarmExpansion,
          stables: @[stables[0]],
          plow: NoSpace
        )
    of MeetingPlace:
      moves.addMove(playerIdx, MeetingPlace)
      for id in player.affordableMinors().topCards(3):
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: MeetingPlace,
          improvement: ImprovementChoice(kind: MinorImprovement, card: id),
          plow: NoSpace
        )
    of Farmland:
      let fields = player.legalFieldSpaces()
      if fields.len > 0:
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: Farmland,
          fields: @[fields[0]],
          plow: NoSpace
        )
    of Lessons, LessonsB:
      let foodCost = state.occupationCost(player, space.id)
      if player.resources[Food] >= foodCost:
        for id in player.handOccupations.topCards(4):
          if id.knownOccupation() and
              player.occupations.len >= cardPrereqOccs(id):
            moves.add Move(
              kind: PlacementMove,
              playerIdx: playerIdx,
              action: space.id,
              occupation: id,
              plow: NoSpace
            )
    of RImprovement:
      for id in state.affordableMajors(player).topCards(4):
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: RImprovement,
          improvement: ImprovementChoice(kind: MajorImprovement, card: id),
          plow: NoSpace
        )
      for id in player.affordableMinors().topCards(4):
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: RImprovement,
          improvement: ImprovementChoice(kind: MinorImprovement, card: id),
          plow: NoSpace
        )
    of RFences:
      var plans: seq[FencePlan]
      for plan in player.suggestFencePlans(0):
        var cost: Goods
        cost.resources[Wood] = plan.cost
        if player.canAfford(cost):
          plans.add plan
      plans.sort compareFencePlans
      if plans.len > 8:
        plans.setLen(8)
      for plan in plans:
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: RFences,
          edges: plan.edges,
          plow: NoSpace
        )
    of RSowBake:
      let sow = player.simpleSowChoices()
      if sow.len > 0:
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: RSowBake,
          sow: sow,
          plow: NoSpace
        )
      let bakeCard = player.bestBakeCard()
      if bakeCard.power.perGrain > 0 and player.resources[Grain] > 0:
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: RSowBake,
          bake: @[BakeChoice(
            card: bakeCard.id,
            grain: min(player.resources[Grain], bakeCard.power.maxGrain)
          )],
          plow: NoSpace
        )
    of RRenovateImprove:
      if player.houseMaterial != HouseStone and
          player.canAfford(player.renovationCost()):
        let cost = player.renovationCost()
        moves.addMove(playerIdx, RRenovateImprove)
        moves.addImprovementCombos(
          state,
          player,
          playerIdx,
          RRenovateImprove,
          cost,
          true,
          true,
          true
        )
    of RFamilyGrowth:
      if player.familyGrowthOk():
        var cost: Goods
        moves.addMove(playerIdx, RFamilyGrowth)
        moves.addImprovementCombos(
          state,
          player,
          playerIdx,
          RFamilyGrowth,
          cost,
          false,
          false,
          true
        )
    of RUrgentFamily:
      if player.urgentGrowthOk():
        moves.addMove(playerIdx, RUrgentFamily)
    of RCultivation:
      let fields = player.legalFieldSpaces()
      let sow = player.simpleSowChoices()
      if fields.len > 0:
        let combined = player.simpleSowChoicesWithField(fields[0])
        if combined.len > 0:
          moves.add Move(
            kind: PlacementMove,
            playerIdx: playerIdx,
            action: RCultivation,
            sow: combined,
            plow: fields[0]
          )
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: RCultivation,
          plow: fields[0]
        )
      if sow.len > 0:
        moves.add Move(
          kind: PlacementMove,
          playerIdx: playerIdx,
          action: RCultivation,
          sow: sow,
          plow: NoSpace
        )
    of RRedevelop:
      if player.houseMaterial != HouseStone and
          player.canAfford(player.renovationCost()):
        moves.addMove(playerIdx, RRedevelop)
    of GrainSeeds, DayLaborer, Forest, ClayPit, ReedBank, Fishing, Copse,
      Grove, Hollow, QuarryStall, ResourceMarket, TravelingPlayers, RSheep,
      RWestQuarry, RVegetable, RBoar, REastQuarry, RCattle:
        moves.addMove(playerIdx, space.id)

proc legalMovesSeq*(state: GameState): seq[Move] {.raises: [SolverError].} =
  ## Copies legal moves into a sequence for compatibility callers.
  var moves: MoveBuffer
  state.legalMoves(moves)
  moves.toSeq()

proc moveText*(move: Move): string =
  ## Returns a compact text label for one move.
  if move.kind == FeedingMove:
    return "feed p" & $move.playerIdx
  result = actionName(move.action)
  if move.occupation != NoCard:
    result.add " " & move.occupation.cardName()
  if move.improvement.kind != NoImprovement:
    result.add " " & move.improvement.card.cardName()
  if move.rooms.len > 0:
    result.add " rooms=" & $move.rooms
  if move.stables.len > 0:
    result.add " stables=" & $move.stables
  if move.fields.len > 0:
    result.add " fields=" & $move.fields
  if move.plow != NoSpace:
    result.add " plow=" & $move.plow
  if move.edges.len > 0:
    result.add " fences=" & $move.edges.len
  if move.sow.len > 0:
    result.add " sow=" & $move.sow.len
  if move.bake.len > 0:
    result.add " bake=" & $move.bake.len

proc rootNode*(seed: int, numPlayers: int, perspective = 0): GameNode
    {.raises: [SolverError].} =
  ## Creates a root node for a new started game.
  var state = newGame(seed, numPlayers)
  state.startGame()
  GameNode(
    state: state,
    depth: 0,
    value: state.evaluateState(perspective)
  )

proc expandNode*(node: GameNode, perspective = 0, limit = 32): seq[GameNode]
    {.raises: [SolverError].} =
  ## Expands a node into child nodes sorted by heuristic value.
  var moves: MoveBuffer
  node.state.legalMoves(moves)
  for i in 0 ..< min(moves.len, limit):
    let childState = node.state.applyMove(moves.moves[i])
    result.add GameNode(
      state: childState,
      move: moves.moves[i],
      depth: node.depth + 1,
      value: childState.evaluateState(perspective)
    )
  result.sort do (a, b: GameNode) -> int:
    cmp(b.value, a.value)

when defined(release):
  {.pop.}
