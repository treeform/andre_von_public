## Vendored unchanged from ~/p/terra src/terra/policy.nim at commit
## 8869f83 (terra:v268 champion lineage). Only edit: this header.
import
  std/algorithm,
  nodes

const
  LateFenceRound = 10
  LateFenceUnusedSpaces = 5
  RanchRound = 9
  RanchLastRound = 12
  RanchUnusedSpaces = 4
  MidFieldRound = 8
  MidFieldTarget = 3
  FieldCatchupRound = 9
  FieldCatchupTarget = 2
  LateFieldRound = 10
  LateScoreRound = 12
  LateFieldTarget = 4
  LateCoverageFamily = 4
  RenovationTempoStart = 9
  RenovationTempoEnd = 11
  RenovationTempoMinGain = 3
  PointMajorMaxUnusedWithSmallFamily = 7
  RoomSetupRound = 9
  FirstRoomSetupRound = 6
  FirstRoomBuildRound = 11
  FoodPrepWindow = 2
  FourthFamilyRoomRound = 13
  FourthRoomLateMinFields = 2
  FifthFamilyRoomRound = 13
  ZeroFieldPatchRound = 9
  ZeroFieldSafeFoodGap = 2
  UrgentCoverageRound = 12
  UrgentCoverageUnusedSpaces = 8
  RenovationReedRound = 10
  AlternativeBand = 1.35
  DenialCap = 2.2
  UnknownCardPressureCap = 0.6
  UnknownMinorPressureScale = 0.045
  UnknownOccupationPressureScale = 0.05
  LateFoodBuffer = 2
  FirstRoomFenceProgress = 0.5
  BalanceRepairMinScore = 0.65
  AnchorAheadRepairMinScore = 0.45
  FarmProtectionRound = 10
  FarmProtectionUnusedSpaces = 7
  FirstPastureProtectionRound = 10

type
  GameStage = enum
    StageEarly,
    StageMid,
    StageLate

  BasePolicyReason* = enum
    PolicyNone,
    PolicyFood,
    PolicyFence,
    PolicyField,
    PolicyFamily,
    PolicyRoomBuild,
    PolicyRoomSetup,
    PolicyFarmExpansion,
    PolicyScore

  SteeringGoal* = enum
    GoalBalance,
    GoalFood,
    GoalFamily,
    GoalFarm,
    GoalBuildings,
    GoalProfessions

  BalanceNeed* = enum
    NeedNone,
    NeedFood,
    NeedFamily,
    NeedFarm,
    NeedBuildings,
    NeedProfessions

  BasePolicyChoice* = object
    ok*: bool
    move*: Move
    score*: float
    reason*: BasePolicyReason

  ScoredMove = object
    move: Move
    score: float
    reason: BasePolicyReason

when defined(release):
  {.push checks: off.}

proc countKind*(player: PlayerState, kind: FarmKind): int =
  ## Counts farm spaces of one kind.
  for space in player.spaces:
    if space.kind == kind:
      inc result

proc unusedScoringSpaces*(player: PlayerState): int =
  ## Counts farmyard spaces that still lose endgame space points.
  var layout: PastureLayout
  try:
    layout = computePastures(player.spaces, player.fences)
  except CatchableError:
    return player.countKind(Empty)
  for i, space in player.spaces:
    if space.kind == Empty and
        not space.stable and
        not layout.pastureCells.contains(i):
      inc result

proc gameStage(round: int): GameStage =
  ## Returns the broad strategy phase for one round.
  if round <= 4:
    StageEarly
  elif round <= 9:
    StageMid
  else:
    StageLate

proc stageValue(stage: GameStage, early, mid, late: float): float =
  ## Returns one value selected by broad game stage.
  case stage
  of StageEarly:
    early
  of StageMid:
    mid
  of StageLate:
    late

proc goalName*(goal: SteeringGoal): string =
  ## Returns the compact log label for one steering goal.
  case goal
  of GoalBalance:
    "balance"
  of GoalFood:
    "food"
  of GoalFamily:
    "family"
  of GoalFarm:
    "farm"
  of GoalBuildings:
    "buildings"
  of GoalProfessions:
    "professions"

proc balanceNeedName*(need: BalanceNeed): string =
  ## Returns the compact log label for one balance repair need.
  case need
  of NeedNone:
    "none"
  of NeedFood:
    "food"
  of NeedFamily:
    "family"
  of NeedFarm:
    "farm"
  of NeedBuildings:
    "buildings"
  of NeedProfessions:
    "professions"

proc fallbackGoal(seed, perspective: int): SteeringGoal =
  ## Returns a deterministic opening goal when cards give no signal.
  case abs(seed + perspective * 7) mod 5
  of 0:
    GoalFood
  of 1:
    GoalFamily
  of 2:
    GoalFarm
  of 3:
    GoalBuildings
  else:
    GoalProfessions

proc goalCardScore(goal: SteeringGoal, card: CardId): int =
  ## Returns how much one visible card points at a steering goal.
  case goal
  of GoalFood:
    case card
    of MajFireplace2, MajFireplace3, MajHearth4, MajHearth5,
        MajClayOven, MajStoneOven, MinCookingCorner, MinSmokehouse,
        MinStewpot, MinHearthStones, MinDoughTrough,
        MinThreshingBoard, MinGrainLoft, OccButcher, OccCharcutier,
        OccMuttonCook, OccFieldCook, OccBaker, OccMiller,
        OccAngler, OccSeasonalHand:
      3
    else:
      0
  of GoalFamily:
    case card
    of OccCarpenter, OccBricklayer, OccMason, OccThatcher,
        OccMasterBuilder, OccMidwife, OccPatriarch, MinCradle,
        MinGabledHouse:
      3
    else:
      0
  of GoalFarm:
    case card
    of OccHedgeWarden, OccStableBoy, OccFenceHand, OccStablemaster,
        OccShepherdsFriend, OccSwineherd, OccCowherd, OccShepherd,
        OccAnimalBreeder, OccHorticulturist, OccCompostCarter,
        OccPlowwright, OccFurrowMaster, OccGreengrocer, OccVegPeddler,
        MinWoodenPlow, MinHeavyPlow, MinScarecrow, MinAnimalPen,
        MinPigSty, MinCattleShed, MinSheepFold, MinPaddock,
        MinShepherdsCrook, MinPigTrough, MinCattleProd,
        MinShearingShears, MinSeedStock:
      3
    else:
      0
  of GoalBuildings:
    case card
    of OccLumberjack, OccClayDigger, OccReedGatherer, OccQuarryman,
        OccQuarryForeman, OccWoodward, MinWoodCart, MinClayPitClaim,
        MinTimberYard, MinClayWorks, MinStoneYard, MinClayDeposit,
        MinWoodCache, MinStoneCart, MinCarvedChest, MinDovecote,
        MinPewterJug, MinRootCellar, MajJoinery, MajPottery,
        MajBasketmaker, MajWell:
      3
    else:
      0
  of GoalProfessions:
    case card
    of OccPeddler, OccVagrant, OccJourneyman, OccSchoolmaster,
        OccElder:
      3
    else:
      if card.knownOccupation():
        1
      else:
        0
  of GoalBalance:
    0

proc chooseOpeningGoal*(state: GameState, perspective: int): SteeringGoal =
  ## Chooses one persistent visible-information steering goal.
  if perspective < 0 or perspective >= state.players.len:
    return GoalBalance
  let player = state.players[perspective]
  var scores: array[SteeringGoal, int]
  for card in player.handOccupations:
    for goal in GoalFood .. GoalProfessions:
      scores[goal] += goal.goalCardScore(card)
  for card in player.handMinors:
    for goal in GoalFood .. GoalProfessions:
      scores[goal] += goal.goalCardScore(card)
  if player.bestBakePower().perGrain < 3:
    scores[GoalFood] += 1
  if player.family.len < 4:
    scores[GoalFamily] += 1
  if player.countKind(Field) == 0:
    scores[GoalFarm] += 1
  if player.occupations.len == 0:
    scores[GoalProfessions] += 1
  var best = state.seed.fallbackGoal(perspective)
  for goal in GoalFood .. GoalProfessions:
    if scores[goal] > scores[best]:
      best = goal
  best

proc anchorNeed(goal: SteeringGoal): BalanceNeed =
  ## Converts an anchor goal into its matching balance category.
  case goal
  of GoalFood:
    NeedFood
  of GoalFamily:
    NeedFamily
  of GoalFarm:
    NeedFarm
  of GoalBuildings:
    NeedBuildings
  of GoalProfessions:
    NeedProfessions
  of GoalBalance:
    NeedNone

proc cardUtilityScore(card: CardId): int =
  ## Scores whether a card saves actions, food, resources, or raises ceiling.
  for goal in GoalFood .. GoalBuildings:
    result = max(result, goal.goalCardScore(card))
  if result == 0 and card.knownOccupation():
    result = 1

proc isFoodEngineMajor(id: CardId): bool =
  ## Returns true when a major can anchor or strongly supplement feeding.
  case id
  of MajFireplace2, MajFireplace3, MajHearth4, MajHearth5,
      MajClayOven, MajStoneOven:
    true
  else:
    false

proc isEarlyCookingCard(id: CardId): bool =
  ## Returns true when a card needs food targets before it matters.
  id in {
    MajFireplace2, MajFireplace3, MajHearth4, MajHearth5,
    MinCookingCorner, MinSmokehouse, MinStewpot, MinHearthStones,
    OccButcher, OccCharcutier, OccMuttonCook, OccFieldCook,
    OccBaker, OccMiller
  }

proc actionGoods(state: GameState, action: ActionId): Goods =
  ## Returns fixed plus accumulated goods on one action space.
  result = spaceDef(action, state.numPlayers).fixedGoods
  let index = state.findActionIndex(action)
  if index >= 0:
    result.add state.actionSpaces[index].pile

proc cropTotals(player: PlayerState): tuple[grain, vegetable: int] =
  ## Counts stored and planted crops.
  result.grain = player.resources[Grain]
  result.vegetable = player.resources[Vegetable]
  for space in player.spaces:
    case space.crop
    of GrainCrop:
      result.grain += space.cropCount
    of VegetableCrop:
      result.vegetable += space.cropCount
    of NoCrop:
      discard

proc hasCookingTarget(player: PlayerState): bool =
  ## Returns true when a cooking card has food to convert soon.
  let crops = player.cropTotals()
  player.animals.totalAnimals() > 0 or
    crops.grain > 0 or
    crops.vegetable > 0

proc hasAnimalCooking(player: PlayerState): bool =
  ## Returns true when a player can convert at least one animal type.
  for animal in Animal:
    if player.bestCookRate(animal) > 0:
      return true

proc animalCookingKinds(player: PlayerState): int =
  ## Counts animal categories this player can convert into food.
  for animal in Animal:
    if player.bestCookRate(animal) > 0:
      inc result

proc hasMajorCooking(player: PlayerState): bool =
  ## Returns true when a player has broad major-improvement cooking.
  for id in [MajFireplace2, MajFireplace3, MajHearth4, MajHearth5]:
    if player.hasPlayed(id):
      return true

proc hasRoomTempoOccupation(player: PlayerState): bool =
  ## Returns true when played occupations improve room-building tempo.
  for id in [
    OccCarpenter, OccBricklayer, OccMason, OccThatcher,
    OccMasterBuilder
  ]:
    if player.hasPlayed(id):
      return true

proc hasCropPipeline(player: PlayerState, crop: Crop): bool =
  ## Returns true when a crop can be supplied beyond a one-shot grab.
  let totals = player.cropTotals()
  case crop
  of GrainCrop:
    totals.grain >= 2 or
      (totals.grain > 0 and player.countKind(Field) > 0)
  of VegetableCrop:
    totals.vegetable >= 2 or
      (totals.vegetable > 0 and player.countKind(Field) > 0)
  of NoCrop:
    false

proc hasReliableFoodEngine(player: PlayerState): bool =
  ## Returns true when a food plan can support more than one narrow line.
  if player.hasMajorCooking():
    return true
  if player.animalCookingKinds() >= 2 and
      player.bestCookRate(Cattle) > 0:
    return true
  if player.bestVegetableCookRate() > 0 and
      player.hasCropPipeline(VegetableCrop):
    return true
  if player.bestBakePower().perGrain >= 3 and
      player.hasCropPipeline(GrainCrop):
    return true
  false

proc pastureCount(player: PlayerState): int =
  ## Counts enclosed pastures, treating bad fence data as no pastures.
  try:
    computePastures(player.spaces, player.fences).pastureCount
  except CatchableError:
    0

proc missingAnimalKinds(player: PlayerState): int =
  ## Counts animal categories still missing for endgame scoring.
  for animal in Animal:
    if player.animals[animal] == 0:
      inc result

proc animalHousingPotential(player: PlayerState): int {.raises: [SolverError].} =
  ## Estimates animal slots that could matter for future scoring.
  var counts: AnimalCounts
  for animal in Animal:
    counts[animal] = 4
  player.maxRetention(counts).total

proc resourceNeed(player: PlayerState, cost: Goods): int =
  ## Counts missing resources for one cost.
  for resource in Resource:
    result += max(0, cost.resources[resource] - player.resources[resource])

proc foodEngineNeed(state: GameState, player: PlayerState): int =
  ## Returns the resource gap to the closest available food engine major.
  if player.hasReliableFoodEngine():
    return 0
  result = high(int)
  for id in state.majorsAvailable:
    if id.isFoodEngineMajor():
      result = min(result, player.resourceNeed(id.cardCost()))
  if result == high(int):
    return 0

proc cardVisible(state: GameState, id: CardId): bool =
  ## Returns true when a card is public or in an observed hand.
  if id == NoCard or id in state.majorsAvailable:
    return true
  for player in state.players:
    if id in player.handOccupations or
        id in player.handMinors or
        id in player.occupations or
        id in player.minors or
        id in player.majors:
      return true

proc unseenMinorPressure(
  state: GameState,
  stage: GameStage
): float =
  ## Returns a capped denial nudge for unknown minor-card pressure.
  let cap =
    case stage
    of StageEarly:
      UnknownCardPressureCap * 0.3
    of StageMid:
      UnknownCardPressureCap * 0.7
    of StageLate:
      UnknownCardPressureCap
  for card in MinorCards:
    if state.cardVisible(card):
      continue
    case card
    of MinGabledHouse:
      result += stage.stageValue(0.0, 0.3, 0.9)
    of MinCradle:
      result += stage.stageValue(0.2, 0.6, 0.5)
    of MinCarvedChest, MinDovecote, MinPewterJug, MinRootCellar:
      result += stage.stageValue(0.1, 0.4, 0.7)
    of MinWoodCart, MinClayPitClaim, MinTimberYard, MinClayWorks,
        MinStoneYard, MinClayDeposit, MinWoodCache, MinSeedStock:
      result += stage.stageValue(0.5, 0.35, 0.1)
    of MinWoodenPlow, MinHeavyPlow, MinScarecrow, MinThreshingBoard,
        MinGrainLoft, MinAnimalPen, MinPigSty, MinCattleShed,
        MinSheepFold, MinPaddock, MinShepherdsCrook, MinPigTrough,
        MinCattleProd, MinShearingShears:
      result += stage.stageValue(0.1, 0.25, 0.35)
    else:
      discard
  result = min(cap, result * UnknownMinorPressureScale)

proc unseenOccupationPressure(
  state: GameState,
  stage: GameStage
): float =
  ## Returns a capped denial nudge for unknown occupation pressure.
  let cap =
    case stage
    of StageEarly:
      UnknownCardPressureCap * 0.3
    of StageMid:
      UnknownCardPressureCap * 0.7
    of StageLate:
      UnknownCardPressureCap
  for card in OccupationCards:
    if state.cardVisible(card):
      continue
    case card
    of OccCarpenter, OccBricklayer, OccMason, OccThatcher,
        OccMasterBuilder:
      result += stage.stageValue(0.6, 0.6, 0.15)
    of OccLumberjack, OccClayDigger, OccReedGatherer, OccQuarryman,
        OccQuarryForeman, OccWoodward:
      result += stage.stageValue(0.55, 0.35, 0.05)
    of OccFieldCook, OccBaker, OccMiller, OccAngler, OccSeasonalHand,
        OccWayfarer, OccGreengrocer, OccVegPeddler:
      result += stage.stageValue(0.4, 0.35, 0.1)
    of OccHedgeWarden, OccStableBoy, OccFenceHand, OccStablemaster,
        OccShepherdsFriend, OccSwineherd, OccCowherd, OccShepherd,
        OccAnimalBreeder, OccHorticulturist, OccCompostCarter,
        OccPlowwright, OccFurrowMaster:
      result += stage.stageValue(0.1, 0.35, 0.35)
    else:
      discard
  result = min(
    cap,
    result * UnknownOccupationPressureScale
  )

proc actionOpen(state: GameState, action: ActionId): bool =
  ## Returns true when an action space is currently open.
  for space in state.actionSpaces:
    if space.id == action and space.occupiedBy == NoPlayer:
      return true

proc roundsUntilAction(state: GameState, action: ActionId): int =
  ## Returns rounds until one round action is usable.
  if state.actionOpen(action):
    return 0
  for i, card in state.roundDeck:
    if card == action:
      return i + 1
  high(int)

proc actionSoon(state: GameState, action: ActionId, rounds: int): bool =
  ## Returns true when one action is open or about to appear.
  state.roundsUntilAction(action) <= rounds

proc minorThreatValue(
  player: PlayerState,
  card: CardId,
  stage: GameStage
): float =
  ## Returns how much an opponent minor is worth denying.
  if not card.knownMinor():
    return
  result += cardVp(card).float * stage.stageValue(0.25, 0.45, 0.7)
  case card
  of MinGabledHouse:
    result += stage.stageValue(0.0, 0.9, 2.2)
  of MinCarvedChest, MinDovecote, MinPewterJug, MinRootCellar:
    result += stage.stageValue(0.3, 0.8, 1.5)
  of MinCradle:
    if player.family.len < MaxFamily:
      result += stage.stageValue(0.7, 1.4, 1.1)
  of MinWoodCart, MinClayPitClaim, MinTimberYard, MinClayWorks,
      MinStoneYard, MinClayDeposit, MinWoodCache, MinSeedStock:
    result += stage.stageValue(1.0, 0.9, 0.25)
  of MinCarpPond, MinReedPond, MinFishWeir, MinRainBarrel:
    result += stage.stageValue(0.7, 0.9, 0.35)
  of MinWoodenPlow, MinHeavyPlow, MinScarecrow, MinThreshingBoard,
      MinGrainLoft:
    if player.countKind(Field) < 3:
      result += stage.stageValue(0.25, 0.9, 1.0)
  of MinAnimalPen, MinPigSty, MinCattleShed, MinSheepFold, MinPaddock,
      MinShepherdsCrook, MinPigTrough, MinCattleProd,
      MinShearingShears:
    result += stage.stageValue(0.25, 0.8, 0.9)
  of MinCookingCorner, MinSmokehouse, MinStewpot, MinHearthStones:
    if not player.hasReliableFoodEngine():
      if player.hasCookingTarget():
        result += stage.stageValue(1.0, 0.9, 0.25)
      else:
        result += stage.stageValue(0.2, 0.25, 0.1)
  else:
    discard
  let targetlessCooking =
    card.isEarlyCookingCard() and not player.hasCookingTarget()
  if player.playerCanPlayCard(card):
    if targetlessCooking:
      result += 0.1
    else:
      result += 0.9
  elif player.occupations.len >= cardPrereqOccs(card) and
      player.cardSpecialPrereqOk(card) and
      player.resourceNeed(cardCost(card)) <= 1:
    if targetlessCooking:
      result += 0.05
    else:
      result += 0.35

proc occupationThreatValue(
  player: PlayerState,
  card: CardId,
  stage: GameStage
): float =
  ## Returns how much an opponent occupation is worth denying.
  if not card.knownOccupation():
    return
  case card
  of OccCarpenter, OccBricklayer, OccMason, OccThatcher,
      OccMasterBuilder:
    if player.family.len < MaxFamily:
      result += stage.stageValue(1.0, 1.1, 0.3)
  of OccLumberjack, OccClayDigger, OccReedGatherer, OccQuarryman,
      OccQuarryForeman, OccWoodward:
    result += stage.stageValue(1.0, 0.8, 0.15)
  of OccFieldCook, OccBaker, OccMiller, OccAngler, OccSeasonalHand,
      OccWayfarer, OccGreengrocer, OccVegPeddler:
    result += stage.stageValue(0.9, 0.9, 0.2)
  of OccHedgeWarden, OccStableBoy, OccFenceHand, OccStablemaster,
      OccShepherdsFriend, OccSwineherd, OccCowherd, OccShepherd,
      OccAnimalBreeder:
    result += stage.stageValue(0.25, 0.8, 0.7)
  of OccHorticulturist, OccCompostCarter, OccPlowwright,
      OccFurrowMaster:
    result += stage.stageValue(0.25, 0.8, 0.6)
  of OccMidwife, OccPatriarch:
    if player.family.len < MaxFamily:
      result += stage.stageValue(0.2, 0.7, 1.0)
  else:
    discard

proc bestMinorThreat(player: PlayerState, stage: GameStage): float =
  ## Returns the strongest known minor threat in one hand.
  for card in player.handMinors:
    result = max(result, player.minorThreatValue(card, stage))

proc bestOccupationThreat(player: PlayerState, stage: GameStage): float =
  ## Returns the strongest known occupation threat in one hand.
  for card in player.handOccupations:
    result = max(result, player.occupationThreatValue(card, stage))

proc startPlayerNeed(
  state: GameState,
  player: PlayerState,
  stage: GameStage
): float {.raises: [SolverError].} =
  ## Returns how useful first player is for a known future state.
  result += min(1.6, player.bestMinorThreat(stage))
  let occThreat = player.bestOccupationThreat(stage)
  if occThreat > 0 and player.resources[Food] > 0:
    result += min(0.8, occThreat)
  let growWait = state.roundsUntilAction(RFamilyGrowth)
  if player.familyGrowthOk() and growWait <= 1:
    result += 2.0
  elif player.family.len < MaxFamily and
      player.roomCount() <= player.family.len and
      player.roomProgress() >= 0.75 and
      growWait <= 2:
    result += 1.1
  let urgentWait = state.roundsUntilAction(RUrgentFamily)
  if player.urgentGrowthOk() and urgentWait <= 1:
    result += 1.4
  let renovateWait = state.roundsUntilAction(RRenovateImprove)
  if renovateWait <= 1 and
      player.houseMaterial != HouseStone and
      player.resourceNeed(player.renovationCost()) <= 1:
    result += stage.stageValue(0.0, 0.7, 1.2)

proc pointMajorNeed(state: GameState, player: PlayerState): int =
  ## Returns the resource gap to a useful point major.
  result = high(int)
  for id in state.majorsAvailable:
    if cardVp(id) < 2:
      continue
    result = min(result, player.resourceNeed(id.cardCost()))
  if result == high(int):
    return 0

proc renovationNeed(player: PlayerState): int =
  ## Returns the resource gap to the next renovation.
  try:
    player.resourceNeed(player.renovationCost())
  except CatchableError:
    0

proc resourceDelta(before, after: PlayerState, resource: Resource): int =
  ## Returns the resource change after one move.
  after.resources[resource] - before.resources[resource]

proc animalDelta(before, after: PlayerState, animal: Animal): int =
  ## Returns the animal change after one move.
  after.animals[animal] - before.animals[animal]

proc firstPatchBonus(
  before,
  after: PlayerState,
  stage: GameStage
): float =
  ## Returns extra value for moving out of cheap negative categories.
  let
    beforeFields = before.countKind(Field)
    afterFields = after.countKind(Field)
    beforePastures = before.pastureCount()
    afterPastures = after.pastureCount()
    beforeCrops = before.cropTotals()
    afterCrops = after.cropTotals()
  let canPatchFields = before.family.len >= 3
  if beforeFields < 2 and afterFields >= 2:
    let value =
      if canPatchFields:
        stage.stageValue(0.1, 1.0, 2.2)
      else:
        stage.stageValue(0.1, 0.9, 2.0)
    result += value
  elif beforeFields == 0 and afterFields == 1:
    let value =
      if canPatchFields:
        stage.stageValue(0.05, 0.55, 1.1)
      else:
        stage.stageValue(0.05, 0.3, 0.7)
    result += value
  if beforePastures == 0 and afterPastures > 0:
    result += stage.stageValue(0.1, 0.8, 1.6)
  if beforeCrops.grain == 0 and afterCrops.grain > 0:
    result += stage.stageValue(0.15, 0.75, 1.8)
  if beforeCrops.vegetable == 0 and afterCrops.vegetable > 0:
    result += stage.stageValue(0.1, 0.7, 1.6)
  for animal in Animal:
    if before.animals[animal] == 0 and after.animals[animal] > 0:
      result += stage.stageValue(0.05, 0.5, 1.25)

proc coveragePressureBonus(
  state: GameState,
  before,
  after: PlayerState,
  stage: GameStage
): float =
  ## Returns extra value for coverage before late farm holes become forced.
  if stage == StageEarly:
    return
  let
    beforeFields = before.countKind(Field)
    afterFields = after.countKind(Field)
    beforePastures = before.pastureCount()
    afterPastures = after.pastureCount()
    beforeUnused = before.unusedScoringSpaces()
    afterUnused = after.unusedScoringSpaces()
    fieldDelta = afterFields - beforeFields
    pastureDelta = afterPastures - beforePastures
    covered = beforeUnused - afterUnused
  if state.round >= 6 and state.round <= 11 and beforeFields < 2:
    let value =
      if before.family.len >= 3:
        stage.stageValue(0.0, 1.2, 1.0)
      else:
        stage.stageValue(0.0, 1.0, 0.8)
    result += fieldDelta.float * value
    if beforeFields == 0 and afterFields > 0:
      if before.family.len >= 3:
        result += 1.1
      else:
        result += 0.8
  if state.round >= 8 and beforeUnused >= 7 and covered > 0:
    result += covered.float * stage.stageValue(0.0, 0.55, 0.85)
  if state.round >= 8 and beforePastures == 0 and pastureDelta > 0:
    result += stage.stageValue(0.0, 1.1, 1.0)

proc cookingMajorAvailable(
  state: GameState,
  player: PlayerState
): bool =
  ## Returns true when one available major would unlock cooking.
  if player.hasReliableFoodEngine():
    return false
  for id in state.majorsAvailable:
    case id
    of MajFireplace2, MajFireplace3, MajHearth4, MajHearth5:
      if player.playerCanPlayCard(id):
        return true
    else:
      discard

proc opponentDenialBonus(
  state: GameState,
  move: Move,
  perspective: int
): float {.raises: [SolverError].} =
  ## Returns a small capped value for useful opponent denial.
  if move.kind != PlacementMove:
    return 0
  let
    stage = state.round.gameStage()
    goods = state.actionGoods(move.action)
    unknownPressure =
      case move.action
      of MeetingPlace:
        state.unseenMinorPressure(stage)
      of Lessons, LessonsB:
        state.unseenOccupationPressure(stage)
      of RImprovement, RRenovateImprove:
        state.unseenMinorPressure(stage) * 0.5
      else:
        0.0
  for i, opponent in state.players:
    if i == perspective:
      continue
    let
      ownScore = state.scorePlayer(state.players[perspective])
      opponentScore = state.scorePlayer(opponent)
      scoreLead = opponentScore - ownScore
      leaderBoost =
        if scoreLead >= 6:
          1.35
        elif scoreLead >= 3:
          1.22
        elif scoreLead >= 1:
          1.12
        else:
          1.0
    var value = 0.0
    case move.action
    of RFamilyGrowth:
      if opponent.familyGrowthOk():
        value += stage.stageValue(0.0, 1.0, 1.2)
    of RUrgentFamily:
      if opponent.urgentGrowthOk():
        value += stage.stageValue(0.0, 0.0, 1.4)
    of FarmExpansion:
      if opponent.family.len < MaxFamily and
          opponent.roomCount() <= opponent.family.len and
          (opponent.canAfford(opponent.roomCost()) or
            opponent.roomProgress() >= 0.75):
        value += stage.stageValue(0.5, 1.1, 0.5)
      if opponent.hasRoomTempoOccupation() and opponent.family.len < MaxFamily:
        value += stage.stageValue(0.35, 0.55, 0.15)
    of RImprovement, RRenovateImprove:
      if state.cookingMajorAvailable(opponent):
        value += stage.stageValue(0.8, 1.0, 0.5)
    of MeetingPlace:
      value += state.startPlayerNeed(opponent, stage)
      if stage == StageLate and state.round in {11, 13}:
        value += 0.4
      if stage != StageEarly and opponent.affordableMinors().len > 0:
        value += 0.3
    of Lessons, LessonsB:
      let threat = opponent.bestOccupationThreat(stage)
      if threat > 0 and opponent.resources[Food] > 0:
        value += min(1.1, threat)
    of Forest, Copse, Grove:
      if goods.resources[Wood] >= 5 and
          (opponent.roomProgress() >= 0.5 or
            opponent.unusedScoringSpaces() >= 5):
        value += stage.stageValue(0.5, 0.9, 0.7)
      if opponent.hasRoomTempoOccupation() and
          opponent.family.len < MaxFamily and
          opponent.roomProgress() >= 0.4:
        value += stage.stageValue(0.35, 0.55, 0.1)
    of ReedBank:
      if goods.resources[Reed] >= 2 and
          opponent.family.len < 4 and
          opponent.roomCount() <= opponent.family.len:
        value += stage.stageValue(0.5, 0.9, 0.3)
      if opponent.hasRoomTempoOccupation() and opponent.family.len < MaxFamily:
        value += stage.stageValue(0.3, 0.45, 0.1)
    of ClayPit, Hollow:
      if goods.resources[Clay] >= 4 and not opponent.hasReliableFoodEngine():
        value += stage.stageValue(0.5, 0.8, 0.3)
    of ResourceMarket:
      if opponent.roomProgress() >= 0.6:
        value += stage.stageValue(0.4, 0.6, 0.2)
    of RWestQuarry, REastQuarry:
      if goods.resources[Stone] >= 2 and stage != StageEarly:
        value += 0.5
    of DayLaborer, Fishing, TravelingPlayers:
      let risk = state.feedingRisk(i)
      if risk.foodGap > 0 or risk.begging > 0:
        value += stage.stageValue(0.3, 0.6, 0.8)
    of RSheep, RBoar, RCattle:
      let risk = state.feedingRisk(i)
      let animal =
        case move.action
        of RSheep:
          Sheep
        of RBoar:
          Boar
        of RCattle:
          Cattle
        else:
          Sheep
      if risk.foodGap > 0 and opponent.bestCookRate(animal) > 0:
        value += stage.stageValue(0.3, 0.7, 0.8)
      if move.action == RSheep and opponent.animals[Sheep] == 0:
        value += stage.stageValue(0.1, 0.4, 0.7)
      elif move.action == RBoar and opponent.animals[Boar] == 0:
        value += stage.stageValue(0.1, 0.4, 0.7)
      elif move.action == RCattle and opponent.animals[Cattle] == 0:
        value += stage.stageValue(0.1, 0.4, 0.7)
    of RVegetable:
      if opponent.cropTotals().vegetable == 0:
        value += stage.stageValue(0.1, 0.4, 0.7)
    of GrainSeeds:
      if opponent.cropTotals().grain == 0:
        value += stage.stageValue(0.1, 0.4, 0.7)
    of Farmland, RCultivation:
      if stage == StageLate and opponent.countKind(Field) < 2:
        value += 0.8
    of RFences:
      if stage == StageLate and
          opponent.unusedScoringSpaces() >= 5 and
          opponent.resources[Wood] >= 4:
        value += 0.9
    else:
      discard
    result += min(1.25, value * leaderBoost)
  let cardPressure =
    if result > 0.0:
      unknownPressure
    else:
      min(0.05, unknownPressure)
  min(DenialCap, result + cardPressure)

proc improvementValue(
  before,
  after: PlayerState,
  card: CardId,
  stage: GameStage
): float =
  ## Returns a policy bonus for playing one improvement.
  if card == NoCard:
    return 0
  result += cardVp(card).float * stage.stageValue(0.65, 1.05, 1.35)
  case card
  of MajFireplace2, MajFireplace3:
    if not before.hasReliableFoodEngine():
      result += stage.stageValue(3.6, 3.2, 1.4)
    else:
      result += 0.6
  of MajHearth4, MajHearth5:
    if not before.hasReliableFoodEngine():
      result += stage.stageValue(3.4, 3.3, 1.6)
    else:
      result += 1.0
  of MajClayOven, MajStoneOven:
    let crops = before.cropTotals()
    if crops.grain > 0 or before.countKind(Field) >= 2:
      result += stage.stageValue(1.6, 3.0, 1.2)
    else:
      result -= 0.8
  of MajJoinery, MajPottery, MajBasketmaker, MajWell:
    result += stage.stageValue(1.7, 3.4, 2.8)
  else:
    if card.cardKind() == MinorImprovement:
      let value =
        if stage == StageLate:
          0.6
      else:
        0.9
      result += value
      if not before.hasReliableFoodEngine() and
          after.hasReliableFoodEngine():
        result += 2.5

proc mixHash(value, extra: uint32): uint32 =
  ## Mixes one value into a tiny deterministic policy hash.
  var x = value xor (extra + 0x9E37_79B9'u32 + (value shl 6) + (value shr 2))
  x = x xor (x shr 16)
  x = x * 0x7FEB_352D'u32
  x xor (x shr 15)

proc policyRoll(state: GameState, perspective: int, moves: seq[ScoredMove]):
    uint32 =
  ## Returns a reproducible coin flip for near-best policy choices.
  result = uint32(state.seed)
  result = result.mixHash(uint32(state.round))
  result = result.mixHash(uint32(perspective + 1))
  result = result.mixHash(uint32(state.currentPlayer + 7))
  result = result.mixHash(uint32(moves.len + 13))
  for space in state.actionSpaces:
    result = result.mixHash(uint32(ord(space.id) * 17 + space.occupiedBy + 19))

proc chooseScoredMove(
  state: GameState,
  perspective: int,
  moves: var seq[ScoredMove]
): BasePolicyChoice =
  ## Chooses the best or a near-best alternative policy move.
  if moves.len == 0:
    return
  moves.sort do (a, b: ScoredMove) -> int:
    result = cmp(b.score, a.score)
    if result == 0:
      result = cmp(a.move.moveText(), b.move.moveText())
  var choice = 0
  if moves.len > 1 and
      moves[1].score >= moves[0].score - AlternativeBand and
      (state.policyRoll(perspective, moves) and 1'u32) == 1'u32:
    choice = 1
  BasePolicyChoice(
    ok: true,
    move: moves[choice].move,
    score: moves[choice].score,
    reason: moves[choice].reason
  )

proc isRoomSetupAction(action: ActionId): bool =
  ## Returns true when an action can help pay for more rooms.
  case action
  of Forest, Copse, Grove, ReedBank, ClayPit, Hollow, QuarryStall,
      ResourceMarket, RWestQuarry, REastQuarry:
    true
  else:
    false

proc strategicBuildRoomMove(
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns a room-building move when one is available.
  for move in rootMoves:
    if move.kind == PlacementMove and
        move.action == FarmExpansion and
        move.rooms.len > 0:
      return (true, move)

proc projectedFeedOutcome(
  state: GameState,
  perspective: int
): tuple[begging, score: int] {.raises: [SolverError].} =
  ## Returns begging and score after immediate auto-feeding.
  var check = state.copy()
  check.phase = Feeding
  check.toFeed = @[perspective]
  let
    before = check.players[perspective].beggingCards
    move = Move(
      kind: FeedingMove,
      playerIdx: perspective,
      feed: check.computeAutoFeed(perspective)
    )
    after = check.applyMove(move)
  result.begging = after.players[perspective].beggingCards - before
  result.score = after.scorePlayer(after.players[perspective])

proc projectedBegging(
  state: GameState,
  perspective: int
): int {.raises: [SolverError].} =
  ## Returns new begging cards after a one-player auto-feed projection.
  state.projectedFeedOutcome(perspective).begging

proc projectedFedScore(
  state: GameState,
  perspective: int
): int {.raises: [SolverError].} =
  ## Returns one player's score after immediate auto-feeding.
  state.projectedFeedOutcome(perspective).score

proc strategicRoomSetupMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns the resource move that best advances room affordability.
  let
    beforePlayer = state.players[perspective]
    before = beforePlayer.roomProgress()
    beforeNeed = beforePlayer.resourceNeed(beforePlayer.roomCost())
  var
    bestMove: Move
    bestNeed = beforeNeed
    bestProgress = before
    bestFood = low(int)
  for move in rootMoves:
    if move.kind != PlacementMove or not move.action.isRoomSetupAction():
      continue
    try:
      let
        after = state.applyMove(move)
        player = after.players[perspective]
        progress = player.roomProgress()
        need = player.resourceNeed(player.roomCost())
        food = player.resources[Food]
      if need < bestNeed or
          (need == bestNeed and
            progress > bestProgress + 0.000_001) or
          (need == bestNeed and
            abs(progress - bestProgress) <= 0.000_001 and
            progress > before and food > bestFood):
        bestNeed = need
        bestProgress = progress
        bestFood = food
        bestMove = move
    except CatchableError:
      discard
  if bestNeed < beforeNeed or bestProgress > before + 0.000_001:
    return (true, bestMove)

proc strategicFamilyGrowthOk(
  state: GameState,
  perspective: int,
  move: Move
): bool {.raises: [SolverError].} =
  ## Returns true when growth is safe enough for direct policy selection.
  if state.round.turnsToHarvest() > 1:
    return true
  let
    player = state.players[perspective]
    after = state.applyMove(move)
    begging = after.projectedBegging(perspective)
  begging <= 0 or
    (begging <= 1 and state.round <= 11 and player.family.len < 4)

proc strategicFamilyMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns the best safe family-growth move when one is legal.
  let player = state.players[perspective]
  if state.round > 13 or player.family.len >= MaxFamily:
    return
  var
    bestMove: Move
    bestFamilyDelta = low(int)
    bestScore = low(int)
    found = false
  for move in rootMoves:
    if move.kind == PlacementMove and
        move.action in {RFamilyGrowth, RUrgentFamily}:
      try:
        if state.strategicFamilyGrowthOk(perspective, move):
          let after = state.applyMove(move)
          if after.feedingRisk(perspective).begging == 0:
            let
              afterPlayer = after.players[perspective]
              familyDelta = afterPlayer.family.len - player.family.len
              score = after.scorePlayer(afterPlayer)
            if not found or
                familyDelta > bestFamilyDelta or
                (familyDelta == bestFamilyDelta and score > bestScore):
              bestMove = move
              bestFamilyDelta = familyDelta
              bestScore = score
              found = true
      except CatchableError:
        discard
  if found:
    return (true, bestMove)

proc strategicFenceMove(
  state: GameState,
  perspective,
  unused: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns the fence move that covers the most empty farm spaces.
  var
    bestMove: Move
    bestValue = low(int)
  for move in rootMoves:
    if move.kind != PlacementMove or move.action != RFences:
      continue
    try:
      let
        after = state.applyMove(move)
        begging =
          if state.round.turnsToHarvest() <= 1:
            after.projectedBegging(perspective)
          else:
            0
        afterUnused = after.players[perspective].unusedScoringSpaces()
        covered = unused - afterUnused
        value = covered * 10 + move.edges.len
      if begging > 0:
        continue
      if value > bestValue:
        bestValue = value
        bestMove = move
    except CatchableError:
      discard
  if bestValue > 0:
    return (true, bestMove)

proc strategicRanchMove(
  state: GameState,
  perspective,
  unused: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns a safe fence move that opens animal capacity before the endgame.
  let
    player = state.players[perspective]
    missing = player.missingAnimalKinds()
  if state.round < RanchRound or state.round > RanchLastRound:
    return
  if missing == 0:
    return
  if player.pastureCount() > 0 and unused < RanchUnusedSpaces:
    return
  var
    beforePotential = 0
    beforeScore = 0
  try:
    beforePotential = player.animalHousingPotential()
    beforeScore = state.scorePlayer(player)
  except CatchableError:
    return
  var
    bestMove: Move
    bestValue = low(int)
  for move in rootMoves:
    if move.kind != PlacementMove or move.action != RFences:
      continue
    try:
      let
        after = state.applyMove(move)
        afterPlayer = after.players[perspective]
        afterRisk = after.feedingRisk(perspective)
        afterPotential = afterPlayer.animalHousingPotential()
        afterUnused = afterPlayer.unusedScoringSpaces()
        potentialGain = afterPotential - beforePotential
        pastureDelta = afterPlayer.pastureCount() - player.pastureCount()
        covered = unused - afterUnused
        scoreGain = after.scorePlayer(afterPlayer) - beforeScore
      if state.round.turnsToHarvest() <= 1 and afterRisk.begging > 0:
        continue
      if potentialGain <= 0 and pastureDelta <= 0:
        continue
      if covered < 2 and pastureDelta <= 0:
        continue
      var value = potentialGain * 12 + pastureDelta * 18
      value += covered * 7 + scoreGain * 20
      value += missing * 4
      if player.pastureCount() == 0 and pastureDelta > 0:
        value += 12
      if state.round.turnsToHarvest() <= 2:
        value -= afterRisk.foodGap * 2
      if value > bestValue:
        bestValue = value
        bestMove = move
    except CatchableError:
      discard
  if bestValue > 0:
    return (true, bestMove)

proc strategicFieldMove(
  state: GameState,
  perspective,
  unused: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns a late plow move when the farm is short on fields.
  let beforeFields = state.players[perspective].countKind(Field)
  var
    bestMove: Move
    bestValue = low(int)
  for move in rootMoves:
    if move.kind != PlacementMove or move.action notin {Farmland, RCultivation}:
      continue
    try:
      let
        after = state.applyMove(move)
        begging =
          if state.round.turnsToHarvest() <= 1:
            after.projectedBegging(perspective)
          else:
            0
        player = after.players[perspective]
        fields = player.countKind(Field)
      if begging > 0 or fields <= beforeFields:
        continue
      let
        covered = unused - player.unusedScoringSpaces()
        value = (fields - beforeFields) * 12 + covered * 4
      if value > bestValue:
        bestValue = value
        bestMove = move
    except CatchableError:
      discard
  if bestValue > 0:
    return (true, bestMove)

proc strategicFoodMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns a root move that avoids or reduces harvest begging.
  proc foodTieValue(player: PlayerState): float =
    ## Returns a cheap future-value tie-breaker for food rescue moves.
    result += player.resources[Wood].float * 0.45
    result += player.resources[Clay].float * 0.35
    result += player.resources[Reed].float * 0.45
    result += player.resources[Stone].float * 0.45
    result += player.resources[Grain].float * 0.55
    result += player.resources[Vegetable].float * 0.8
    result += player.countKind(Field).float * 0.9
    result += player.fencesBuilt.float * 0.08
    result += player.roomCount().float * 0.7
    result += player.animals.totalAnimals().float * 0.35

  let currentBegging = state.projectedBegging(perspective)
  var
    bestMove: Move
    bestBegging = high(int)
    bestFedScore = low(int)
    bestValue = low(float)
    bestFood = low(int)
  for move in rootMoves:
    if move.kind != PlacementMove:
      continue
    try:
      let
        after = state.applyMove(move)
        player = after.players[perspective]
        outcome = after.projectedFeedOutcome(perspective)
        value = player.foodTieValue()
        food = player.resources[Food]
      if outcome.begging < bestBegging or
          (outcome.begging == bestBegging and
            outcome.score > bestFedScore) or
          (outcome.begging == bestBegging and
            outcome.score == bestFedScore and value > bestValue) or
          (outcome.begging == bestBegging and
            outcome.score == bestFedScore and value == bestValue and
            food > bestFood):
        bestBegging = outcome.begging
        bestFedScore = outcome.score
        bestValue = value
        bestFood = food
        bestMove = move
    except CatchableError:
      discard
  if bestBegging == 0 or bestBegging < currentBegging:
    return (true, bestMove)

proc strategicPointImprovementMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns a safe midgame point major before opponents can claim it.
  if state.round < 8:
    return
  let player = state.players[perspective]
  if state.round < 10 and player.family.len < 3:
    return
  if state.round < 12 and
      player.family.len < 4 and
      player.unusedScoringSpaces() > PointMajorMaxUnusedWithSmallFamily:
    return
  var
    beforeScore = 0
    bestMove: Move
    bestValue = low(int)
  try:
    beforeScore = state.scorePlayer(player)
  except CatchableError:
    return
  for move in rootMoves:
    if move.kind != PlacementMove or
        move.action notin {MeetingPlace, RImprovement, RRenovateImprove} or
        move.improvement.kind == NoImprovement:
      continue
    let card = move.improvement.card
    if cardVp(card) < 3 and
        not (state.round >= 11 and cardVp(card) >= 2):
      continue
    try:
      let
        after = state.applyMove(move)
        afterPlayer = after.players[perspective]
        risk = after.feedingRisk(perspective)
        scoreGain = after.scorePlayer(afterPlayer) - beforeScore
      if risk.begging > 0:
        continue
      var value = cardVp(card) * 35 + scoreGain * 20
      if card in [
        MajWell, MajClayOven, MajStoneOven,
        MajJoinery, MajPottery, MajBasketmaker
      ]:
        value += 18
      if not player.hasReliableFoodEngine() and
          afterPlayer.hasReliableFoodEngine():
        value += 24
      if move.action == RRenovateImprove:
        value += 12
      if value > bestValue:
        bestValue = value
        bestMove = move
    except CatchableError:
      discard
  if bestValue > low(int):
    return (true, bestMove)

proc strategicRenovationMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns a safe tempo renovation before the endgame queue jams.
  let player = state.players[perspective]
  if state.round < RenovationTempoStart or
      state.round > RenovationTempoEnd or
      player.houseMaterial == HouseStone or
      player.family.len < 3 or
      player.roomCount() < 3:
    return
  var
    beforeScore = 0
    bestMove: Move
    bestValue = low(int)
  try:
    beforeScore = state.scorePlayer(player)
  except CatchableError:
    return
  for move in rootMoves:
    if move.kind != PlacementMove or move.action != RRenovateImprove:
      continue
    try:
      let
        after = state.applyMove(move)
        afterPlayer = after.players[perspective]
        risk = after.feedingRisk(perspective)
        scoreGain = after.scorePlayer(afterPlayer) - beforeScore
      if risk.begging > 0 or scoreGain < RenovationTempoMinGain:
        continue
      var value = scoreGain * 100
      if move.improvement.kind != NoImprovement:
        value += cardVp(move.improvement.card) * 25
      if afterPlayer.houseMaterial == HouseStone:
        value += 25
      if value > bestValue:
        bestValue = value
        bestMove = move
    except CatchableError:
      discard
  if bestValue > low(int):
    return (true, bestMove)

proc strategicRenovationResourceMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns a resource move that unlocks a near-term renovation.
  let player = state.players[perspective]
  if state.round < RenovationReedRound or
      player.houseMaterial == HouseStone or
      player.roomCount() < 3:
    return
  let beforeRisk = state.feedingRisk(perspective)
  var
    cost: Goods
    beforeNeed = 0
  try:
    cost = player.renovationCost()
    beforeNeed = player.renovationNeed()
  except CatchableError:
    return
  if beforeNeed <= 0 or beforeNeed > 2:
    return
  var missing: array[Resource, int]
  for resource in Resource:
    missing[resource] = max(
      0,
      cost.resources[resource] - player.resources[resource]
    )
  var
    bestMove: Move
    bestValue = low(int)
  for move in rootMoves:
    if move.kind != PlacementMove:
      continue
    let goods = state.actionGoods(move.action)
    var usefulGoods = 0
    for resource in Resource:
      usefulGoods += min(missing[resource], goods.resources[resource])
    if usefulGoods <= 0:
      continue
    try:
      let
        after = state.applyMove(move)
        afterPlayer = after.players[perspective]
        afterRisk = after.feedingRisk(perspective)
        afterNeed = afterPlayer.renovationNeed()
      if afterNeed >= beforeNeed or afterRisk.begging > beforeRisk.begging:
        continue
      var value = (beforeNeed - afterNeed) * 100
      value += usefulGoods * 35
      value += min(missing[Reed], goods.resources[Reed]) * 20
      value += goods.resources[Food] * 8
      if value > bestValue:
        bestValue = value
        bestMove = move
    except CatchableError:
      discard
  if bestValue > low(int):
    return (true, bestMove)

proc strategicFoodEngineMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns a safe early move that establishes a food engine.
  let player = state.players[perspective]
  if player.hasReliableFoodEngine() or state.round > 8:
    return
  var
    bestMove: Move
    bestValue = low(float)
  for move in rootMoves:
    if move.kind != PlacementMove:
      continue
    try:
      let
        after = state.applyMove(move)
        afterPlayer = after.players[perspective]
      if state.round <= 4 and state.round.turnsToHarvest() > 1:
        if move.improvement.card.isEarlyCookingCard() and
            not player.hasCookingTarget():
          continue
        if move.occupation.isEarlyCookingCard() and
            not player.hasCookingTarget():
          continue
      if not afterPlayer.hasReliableFoodEngine():
        continue
      if state.round.turnsToHarvest() <= 1 and
          after.feedingRisk(perspective).begging > 0:
        continue
      var value = after.scorePlayer(afterPlayer).float
      if move.improvement.kind != NoImprovement:
        value += player.improvementValue(
          afterPlayer,
          move.improvement.card,
          state.round.gameStage()
        )
      if value > bestValue:
        bestValue = value
        bestMove = move
    except CatchableError:
      discard
  if bestValue > low(float):
    return (true, bestMove)

proc strategicFoodEngineSetupMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns an early resource move that unlocks a food engine.
  let player = state.players[perspective]
  if player.hasReliableFoodEngine() or state.round > 5:
    return
  let beforeNeed = state.foodEngineNeed(player)
  if beforeNeed <= 0:
    return
  var
    bestMove: Move
    bestNeed = beforeNeed
    bestValue = low(int)
  for move in rootMoves:
    if move.kind != PlacementMove or
        move.action notin {ClayPit, Hollow, ResourceMarket}:
      continue
    try:
      let
        after = state.applyMove(move)
        afterPlayer = after.players[perspective]
        afterNeed = after.foodEngineNeed(afterPlayer)
        goods = state.actionGoods(move.action)
      if afterNeed >= beforeNeed:
        continue
      if state.round.turnsToHarvest() <= 1 and
          after.feedingRisk(perspective).begging > 0:
        continue
      var value = (beforeNeed - afterNeed) * 20
      value += goods.resources[Clay] * 3
      value += goods.resources[Stone] * 2
      value += goods.resources[Food]
      if afterNeed == 0:
        value += 12
      if afterNeed < bestNeed or
          (afterNeed == bestNeed and value > bestValue):
        bestNeed = afterNeed
        bestValue = value
        bestMove = move
    except CatchableError:
      discard
  if bestValue > low(int) and
      (bestNeed == 0 or beforeNeed - bestNeed >= 2):
    return (true, bestMove)

proc strategicLateScoreMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move]
): tuple[ok: bool, move: Move] =
  ## Returns a safe late action that immediately raises final score.
  if state.round < LateScoreRound:
    return
  var beforeScore: int
  try:
    beforeScore =
      if state.round.turnsToHarvest() <= 1:
        state.projectedFedScore(perspective)
      else:
        state.scorePlayer(state.players[perspective])
  except CatchableError:
    return
  let
    player = state.players[perspective]
    beforeUnused = player.unusedScoringSpaces()
    threshold =
      if state.round >= TotalRounds:
        1
      else:
        2
  var
    bestMove: Move
    bestValue = low(int)
  for move in rootMoves:
    if move.kind != PlacementMove:
      continue
    try:
      let
        after = state.applyMove(move)
        afterPlayer = after.players[perspective]
        risk = after.feedingRisk(perspective)
        afterScore =
          if state.round.turnsToHarvest() <= 1:
            after.projectedFedScore(perspective)
          else:
            after.scorePlayer(afterPlayer)
        scoreGain = afterScore - beforeScore
      if risk.begging > 0 or scoreGain < threshold:
        continue
      var value = scoreGain * 100
      value += (beforeUnused - afterPlayer.unusedScoringSpaces()) * 6
      if move.action in {RSheep, RBoar, RCattle}:
        let beforeAnimals = player.animals
        for animal in Animal:
          if beforeAnimals[animal] == 0 and
              afterPlayer.animals[animal] > 0:
            value += 8
      if move.action == FarmExpansion and scoreGain <= 0:
        value -= 60
      if move.action in {DayLaborer, Fishing, TravelingPlayers}:
        value -= 40
      if value > bestValue:
        bestValue = value
        bestMove = move
    except CatchableError:
      discard
  if bestValue > low(int):
    return (true, bestMove)

proc occupationValue(
  player: PlayerState,
  card: CardId,
  stage: GameStage
): float =
  ## Returns a small policy value for occupation tempo.
  if card == NoCard:
    return 0
  case card
  of OccLumberjack, OccClayDigger, OccReedGatherer, OccQuarryman,
      OccQuarryForeman, OccAngler, OccSeasonalHand, OccGreengrocer,
      OccWayfarer, OccFieldCook, OccBaker, OccMiller, OccButcher,
      OccMuttonCook, OccWaterCarrier, OccSeedMerchant, OccVegPeddler:
    result += stage.stageValue(2.5, 1.45, 0.35)
  of OccCarpenter, OccThatcher, OccBricklayer, OccMason:
    if player.family.len < 4:
      result += stage.stageValue(2.1, 1.25, 0.1)
  of OccShepherdsFriend, OccStablemaster, OccSwineherd, OccCowherd,
      OccShepherd, OccHedgeWarden, OccStableBoy, OccFenceHand:
    result += stage.stageValue(1.15, 1.55, 0.65)
  of OccPlowwright, OccFurrowMaster, OccHorticulturist, OccCompostCarter:
    result += stage.stageValue(1.1, 1.45, 0.55)
  of OccPeddler, OccVagrant, OccJourneyman, OccSchoolmaster, OccElder:
    result += stage.stageValue(0.7, 0.75, 0.35)
  else:
    discard

proc policyReason(move: Move): BasePolicyReason =
  ## Returns the broad policy reason represented by one move.
  if move.kind != PlacementMove:
    return PolicyScore
  case move.action
  of DayLaborer, Fishing, TravelingPlayers:
    PolicyFood
  of RSheep, RBoar, RCattle:
    PolicyFood
  of RFences:
    PolicyFence
  of Farmland, RCultivation:
    PolicyField
  of RFamilyGrowth, RUrgentFamily:
    PolicyFamily
  of FarmExpansion:
    if move.rooms.len > 0:
      PolicyRoomBuild
    else:
      PolicyRoomSetup
  of Forest, Copse, Grove, ReedBank, ClayPit, Hollow, ResourceMarket,
      QuarryStall, RWestQuarry, REastQuarry:
    PolicyRoomSetup
  else:
    PolicyScore

proc stageMoveBonus(
  state,
  after: GameState,
  move: Move,
  perspective: int
): float {.raises: [SolverError].} =
  ## Returns stage-aware strategic value for one already-applied move.
  let
    before = state.players[perspective]
    player = after.players[perspective]
    stage = state.round.gameStage()
    roundsLeft = max(0, TotalRounds - state.round)
    harvestWait = state.round.turnsToHarvest()
    growthWait = state.roundsUntilAction(RFamilyGrowth)
    renovationWait = state.roundsUntilAction(RRenovateImprove)
    beforeRisk = state.feedingRisk(perspective)
    afterRisk = after.feedingRisk(perspective)
    beforeScore = state.scorePlayer(before)
    afterScore = after.scorePlayer(player)
    scoreDelta = afterScore - beforeScore
    familyDelta = player.family.len - before.family.len
    roomDelta = player.roomCount() - before.roomCount()
    unusedDelta = before.unusedScoringSpaces() - player.unusedScoringSpaces()
    fieldDelta = player.countKind(Field) - before.countKind(Field)
    pastureDelta = player.pastureCount() - before.pastureCount()
  result += scoreDelta.float * stage.stageValue(0.35, 0.7, 1.35)
  result += before.firstPatchBonus(player, stage)
  result += state.coveragePressureBonus(before, player, stage)
  result -= afterRisk.begging.float * 10.0
  result += max(0, beforeRisk.begging - afterRisk.begging).float * 7.0
  if afterRisk.begging > 0 or harvestWait <= 1:
    let gapWeight =
      if harvestWait <= 1:
        1.7
      elif harvestWait == 2:
        0.8
      else:
        0.25
    result -= afterRisk.animalScoreLoss.float * 0.75
    result -= afterRisk.foodGap.float * gapWeight
  elif harvestWait == 2 and afterRisk.foodGap > 0:
    result -= afterRisk.foodGap.float * 0.55
    result += max(0, beforeRisk.foodGap - afterRisk.foodGap).float * 1.1
  if not before.hasReliableFoodEngine() and player.hasReliableFoodEngine():
    result += stage.stageValue(3.0, 2.7, 0.9)
    if harvestWait <= 1 or beforeRisk.foodGap > 0:
      result += 1.4
    elif before.animals.totalAnimals() == 0 and
        before.cropTotals().grain == 0 and
        before.cropTotals().vegetable == 0:
      result -= stage.stageValue(1.2, 0.8, 0.0)
  if not before.hasReliableFoodEngine() and not player.hasReliableFoodEngine():
    let
      beforeNeed = state.foodEngineNeed(before)
      afterNeed = after.foodEngineNeed(player)
    if beforeNeed > 0 and afterNeed < beforeNeed:
      result += (beforeNeed - afterNeed).float *
        stage.stageValue(1.25, 0.85, 0.15)
      if afterNeed == 0 and state.round <= 6:
        result += 1.0
  if stage != StageEarly and player.hasReliableFoodEngine():
    let
      beforeNeed = state.pointMajorNeed(before)
      afterNeed = after.pointMajorNeed(player)
    if beforeNeed > 0 and afterNeed < beforeNeed:
      result += (beforeNeed - afterNeed).float *
        stage.stageValue(0.0, 0.75, 0.95)
      if afterNeed == 0:
        result += stage.stageValue(0.0, 1.8, 2.2)
  if stage != StageEarly and before.roomCount() >= 3:
    let
      beforeNeed = before.renovationNeed()
      afterNeed = player.renovationNeed()
    if beforeNeed > 0 and afterNeed < beforeNeed:
      result += (beforeNeed - afterNeed).float *
        stage.stageValue(0.0, 0.55, 0.8)
      if afterNeed == 0:
        result += stage.stageValue(0.0, 0.9, 1.3)
  for resource in Resource:
    let delta = before.resourceDelta(player, resource)
    if delta == 0:
      continue
    let weight =
      case resource
      of Wood:
        let needsRoomWood =
          before.family.len < 4 and
          before.roomCount() <= before.family.len and
          growthWait <= 2
        if needsRoomWood:
          stage.stageValue(0.78, 0.65, 0.25)
        else:
          case stage
          of StageEarly:
            0.55
          of StageMid:
            0.48
          of StageLate:
            if before.unusedScoringSpaces() >= 4:
              0.42
            else:
              0.22
      of Reed:
        let needsRoomReed =
          before.family.len < 4 and
          before.roomCount() <= before.family.len and
          before.resources[Reed] < before.roomCost().resources[Reed] and
          growthWait <= 2
        if needsRoomReed:
          case stage
          of StageEarly:
            0.8
          of StageMid:
            0.65
          of StageLate:
            0.18
        elif before.resources[Reed] == 0 and
            before.houseMaterial != HouseStone:
          stage.stageValue(0.35, 0.25, 0.12)
        elif before.resources[Reed] < 2 and
            before.family.len < 4 and
            state.round <= 8:
          0.22
        else:
          stage.stageValue(0.12, 0.08, 0.04)
      of Clay:
        case stage
        of StageEarly:
          if before.hasReliableFoodEngine():
            0.28
          else:
            if harvestWait <= 1 or state.actionSoon(RSheep, 1):
              0.55
            else:
              0.42
        of StageMid:
          if renovationWait <= 2 and before.houseMaterial == HouseWood:
            0.48
          else:
            0.36
        of StageLate:
          0.16
      of Stone:
        var pointMajorAvailable = false
        for id in state.majorsAvailable:
          if cardVp(id) >= 2:
            pointMajorAvailable = true
        case stage
        of StageEarly:
          if pointMajorAvailable:
            0.26
          else:
            0.18
        of StageMid:
          if renovationWait <= 2 and before.houseMaterial != HouseStone:
            0.62
          elif pointMajorAvailable:
            0.56
          else:
            0.42
        of StageLate:
          if pointMajorAvailable:
            0.46
          else:
            0.34
      of Food:
        if harvestWait <= 1 or afterRisk.foodGap > 0:
          0.85
        elif stage == StageEarly:
          0.5
        else:
          0.28
      of Grain:
        case stage
        of StageEarly:
          0.35
        of StageMid:
          0.55
        of StageLate:
          0.75
      of Vegetable:
        case stage
        of StageEarly:
          0.45
        of StageMid:
          0.9
        of StageLate:
          1.15
    result += delta.float * weight
  for animal in Animal:
    let delta = before.animalDelta(player, animal)
    if delta <= 0:
      continue
    let firstBonus =
      if before.animals[animal] == 0:
        1.4
      else:
        0.0
    let canCookAnimal = before.bestCookRate(animal) > 0
    let animalWeight =
      if stage == StageEarly:
        if canCookAnimal:
          0.65
        else:
          0.25
      elif stage == StageMid:
        0.75
      else:
        0.95
    result += delta.float * animalWeight
    result += firstBonus
    if animal == Cattle and before.animals[animal] == 0:
      result += stage.stageValue(0.0, 0.45, 0.9)
  if before.family.len < 4:
    let
      beforeNeed = before.resourceNeed(before.roomCost())
      afterNeed = player.resourceNeed(player.roomCost())
      progress = max(0, beforeNeed - afterNeed)
      roomUrgency =
        if growthWait <= 1:
          stage.stageValue(1.6, 1.35, 0.2)
        elif growthWait <= 2:
          stage.stageValue(1.2, 1.0, 0.1)
        else:
          stage.stageValue(0.7, 0.45, 0.0)
    result += progress.float * roomUrgency
  if familyDelta > 0:
    let familyWeight =
      case stage
      of StageEarly:
        9.0 + roundsLeft.float * 0.25
      of StageMid:
        7.5 + roundsLeft.float * 0.2
      of StageLate:
        5.2
    result += familyDelta.float * familyWeight
    if afterRisk.begging > 0 and harvestWait <= 1:
      result -= 6.0
  if roomDelta > 0:
    let roomWeight =
      case stage
      of StageEarly:
        if growthWait <= 1:
          8.2
        elif state.round >= 4:
          6.8
        else:
          4.5
      of StageMid:
        if growthWait <= 1 and before.family.len < 4:
          6.8
        elif before.family.len < 4:
          5.4
        else:
          2.0
      of StageLate:
        if state.round <= 12 and before.family.len < 4:
          4.0
        elif state.round <= 13 and
            before.family.len < 4 and
            before.countKind(Field) >= FourthRoomLateMinFields:
          4.0
        elif state.round <= 13 and before.family.len < MaxFamily:
          2.5
        else:
          -0.5
    result += roomDelta.float * roomWeight
  if unusedDelta > 0:
    result += unusedDelta.float * stage.stageValue(0.15, 0.45, 1.1)
  if pastureDelta > 0:
    result += pastureDelta.float * stage.stageValue(0.25, 1.0, 1.45)
  if fieldDelta > 0:
    let value =
      if before.family.len >= 3:
        stage.stageValue(0.25, 1.05, 1.45)
      else:
        stage.stageValue(0.25, 0.9, 1.35)
    result += fieldDelta.float * value
  if move.kind != PlacementMove:
    return
  let needsFirstRoom =
    before.family.len < 3 and before.roomCount() <= before.family.len
  case move.action
  of MeetingPlace:
    let startNeed = state.startPlayerNeed(before, stage)
    result += min(3.0, startNeed)
    if move.improvement.kind == NoImprovement:
      if state.round in {11, 13}:
        result += 2.6
      elif state.round == 5 and player.familyGrowthOk():
        result += 1.3
      elif stage == StageEarly and startNeed < 1.6:
        result -= 3.8
    else:
      result += before.improvementValue(
        player,
        move.improvement.card,
        stage
      )
      if state.round in {11, 13}:
        result += 1.2
      if stage == StageEarly and
          move.improvement.card.isEarlyCookingCard() and
          not before.hasCookingTarget() and
          harvestWait > 1:
        result -= 4.0
  of RImprovement, RRenovateImprove:
    result += before.improvementValue(player, move.improvement.card, stage)
    if stage == StageEarly and
        move.improvement.card.isEarlyCookingCard() and
        not before.hasCookingTarget() and
        harvestWait > 1:
      result -= 4.0
  of Lessons, LessonsB:
    let value = before.occupationValue(move.occupation, stage)
    result += value
    if stage == StageEarly and value <= 0.0:
      result -= 3.0
  of FarmExpansion:
    if needsFirstRoom and move.rooms.len == 0 and move.stables.len > 0:
      result -= stage.stageValue(8.0, 9.0, 0.0)
    elif state.round <= 10 and
        before.family.len < 4 and
        before.roomCount() <= before.family.len and
        move.rooms.len == 0 and
        move.stables.len > 0:
      result -= stage.stageValue(5.0, 6.0, 0.0)
    if stage == StageLate:
      if move.rooms.len > 0 and scoreDelta <= 0:
        result -= 3.0
      if move.stables.len > 0 and scoreDelta <= 0:
        result -= 2.0
  of RSowBake:
    if move.sow.len > 0:
      result += move.sow.len.float * stage.stageValue(0.8, 1.3, 1.6)
    if move.bake.len > 0:
      let bakeValue =
        if harvestWait <= 1 or beforeRisk.foodGap > 0:
          1.1
        else:
          0.25
      result += bakeValue
  of RCultivation:
    if state.round >= 12:
      result += 1.0
  of RFences:
    if state.round >= 12:
      result += 1.2
    if needsFirstRoom and state.round <= FirstRoomBuildRound:
      result -= 3.8 + move.edges.len.float * 0.75
      if before.canAfford(before.roomCost()) or
          before.roomProgress() >= FirstRoomFenceProgress:
        result -= 4.5 + move.edges.len.float * 0.55
    elif state.round < 8 and before.family.len < 3 and move.edges.len > 4:
      result -= (move.edges.len - 4).float * 0.55
    if before.hasAnimalCooking() and before.pastureCount() == 0:
      result += stage.stageValue(0.0, 0.9, 1.1)
  of DayLaborer, Fishing, TravelingPlayers:
    if stage == StageLate and
        beforeRisk.foodGap == 0 and
        afterRisk.begging == 0 and
        player.resources[Food] >= after.foodNeeded(player) + LateFoodBuffer:
      result -= 1.2
  of RSheep, RBoar, RCattle:
    var retained = 0
    case move.action
    of RSheep:
      retained = before.animalDelta(player, Sheep)
    of RBoar:
      retained = before.animalDelta(player, Boar)
    of RCattle:
      retained = before.animalDelta(player, Cattle)
    else:
      discard
    if stage == StageLate and
        retained <= 0 and
        beforeRisk.foodGap == 0 and
        afterRisk.begging == 0:
      result -= 1.0
  else:
    discard

proc balanceMoveBonus(
  state,
  after: GameState,
  move: Move,
  perspective: int
): float {.raises: [SolverError].} =
  ## Returns a small nudge toward a rounded farm.
  let
    before = state.players[perspective]
    player = after.players[perspective]
    stage = state.round.gameStage()
    beforeRisk = state.feedingRisk(perspective)
    afterRisk = after.feedingRisk(perspective)
    familyDelta = player.family.len - before.family.len
    roomDelta = player.roomCount() - before.roomCount()
    fieldDelta = player.countKind(Field) - before.countKind(Field)
    unusedDelta = before.unusedScoringSpaces() - player.unusedScoringSpaces()
    pastureDelta = player.pastureCount() - before.pastureCount()
    foodSurplus = player.resources[Food] - after.foodNeeded(player)
  result += max(0, beforeRisk.begging - afterRisk.begging).float * 1.5
  result += max(0, beforeRisk.foodGap - afterRisk.foodGap).float * 0.45
  if afterRisk.begging == 0 and foodSurplus > LateFoodBuffer + 4:
    case move.action
    of DayLaborer, Fishing, TravelingPlayers:
      result -= 0.45
    else:
      discard
  if before.family.len < 4 and state.round <= 12:
    result += familyDelta.float * stage.stageValue(0.0, 0.7, 0.45)
    result += roomDelta.float * stage.stageValue(0.0, 0.45, 0.25)
    if player.roomProgress() > before.roomProgress():
      result += stage.stageValue(0.15, 0.25, 0.05)
  if stage != StageEarly:
    if before.countKind(Field) < 2 and fieldDelta > 0:
      result += fieldDelta.float * stage.stageValue(0.0, 0.55, 0.75)
    if before.unusedScoringSpaces() >= 8 and unusedDelta > 0:
      result += unusedDelta.float * stage.stageValue(0.0, 0.35, 0.65)
    if before.pastureCount() == 0 and pastureDelta > 0:
      result += stage.stageValue(0.0, 0.55, 0.8)
  if state.round >= 10 and before.houseMaterial == HouseWood:
    if move.kind == PlacementMove and
        move.action in {RRenovateImprove, RRedevelop}:
      result += 0.5
  if state.round >= 5 and before.occupations.len == 0:
    if move.kind == PlacementMove and move.action in {Lessons, LessonsB}:
      result += stage.stageValue(0.25, 0.45, 0.1)

proc goalMoveBonus(
  state,
  after: GameState,
  move: Move,
  perspective: int,
  goal: SteeringGoal
): float {.raises: [SolverError].} =
  ## Returns a persistent steering-goal bonus for one move.
  if goal == GoalBalance or move.kind != PlacementMove:
    return
  let
    before = state.players[perspective]
    player = after.players[perspective]
    stage = state.round.gameStage()
    beforeRisk = state.feedingRisk(perspective)
    afterRisk = after.feedingRisk(perspective)
    familyDelta = player.family.len - before.family.len
    roomDelta = player.roomCount() - before.roomCount()
    fieldDelta = player.countKind(Field) - before.countKind(Field)
    pastureDelta = player.pastureCount() - before.pastureCount()
    unusedDelta = before.unusedScoringSpaces() - player.unusedScoringSpaces()
    foodSurplus = player.resources[Food] - after.foodNeeded(player)
  case goal
  of GoalFood:
    result += max(0, beforeRisk.foodGap - afterRisk.foodGap).float * 0.85
    if not before.hasReliableFoodEngine() and player.hasReliableFoodEngine():
      result += stage.stageValue(2.6, 1.8, 0.35)
    case move.action
    of RImprovement, RRenovateImprove, RSowBake:
      result += stage.stageValue(1.0, 0.75, 0.25)
    of DayLaborer, Fishing, TravelingPlayers, RSheep, RBoar, RCattle:
      if beforeRisk.foodGap > 0 or not before.hasReliableFoodEngine():
        result += stage.stageValue(0.65, 0.45, 0.15)
    else:
      discard
    if afterRisk.begging == 0 and foodSurplus > LateFoodBuffer + 2:
      result -= min(2.0, (foodSurplus - LateFoodBuffer - 2).float * 0.35)
  of GoalFamily:
    if before.family.len < 4:
      let safeGrowth =
        afterRisk.begging == 0 and
          (before.hasReliableFoodEngine() or beforeRisk.foodGap <= 0)
      if safeGrowth:
        result += familyDelta.float * 2.5
      else:
        result -= familyDelta.float * 2.0
      result += roomDelta.float * stage.stageValue(1.6, 1.2, 0.5)
      if player.roomProgress() > before.roomProgress():
        result += stage.stageValue(0.7, 0.55, 0.1)
    elif before.family.len >= 4 and familyDelta > 0:
      result += 0.4
    if before.family.len >= 4 and roomDelta > 0:
      result -= 0.8
  of GoalFarm:
    result += fieldDelta.float * stage.stageValue(0.8, 1.25, 1.5)
    result += pastureDelta.float * stage.stageValue(0.4, 1.1, 1.4)
    result += unusedDelta.float * stage.stageValue(0.15, 0.4, 0.75)
    case move.action
    of GrainSeeds, RVegetable, RSowBake, RCultivation, Farmland, RFences,
        RSheep, RBoar, RCattle:
      result += stage.stageValue(0.55, 0.8, 0.75)
    else:
      discard
    if before.countKind(Field) >= 4 and before.unusedScoringSpaces() <= 2:
      result -= 0.9
  of GoalBuildings:
    result += roomDelta.float * stage.stageValue(1.0, 0.8, 0.25)
    case move.action
    of FarmExpansion:
      result += stage.stageValue(0.7, 0.55, 0.0)
    of RImprovement, MeetingPlace:
      if move.improvement.kind != NoImprovement:
        result += stage.stageValue(0.7, 1.0, 1.1)
    of RRenovateImprove, RRedevelop:
      result += stage.stageValue(0.0, 1.3, 1.8)
    of Forest, Copse, Grove, ReedBank, ClayPit, Hollow, ResourceMarket,
        RWestQuarry, REastQuarry:
      result += stage.stageValue(0.55, 0.45, 0.2)
    else:
      discard
    if before.houseMaterial == HouseStone and before.roomCount() > 3:
      result -= 0.7
  of GoalProfessions:
    case move.action
    of Lessons, LessonsB:
      let utility = move.occupation.cardUtilityScore()
      if utility >= 3:
        result += stage.stageValue(1.8, 1.1, 0.25)
      elif before.occupations.len == 0:
        result += stage.stageValue(0.6, 0.4, 0.0)
      else:
        result -= 0.45
      if before.occupations.len == 0:
        result += 0.45
    of MeetingPlace:
      if move.improvement.kind != NoImprovement:
        let utility = move.improvement.card.cardUtilityScore()
        if utility >= 3:
          result += stage.stageValue(0.45, 0.65, 0.55)
        else:
          result -= 0.25
    else:
      discard
    if before.occupations.len >= 3:
      result -= 0.8
  of GoalBalance:
    discard

proc balanceDeficitScore(
  state: GameState,
  perspective: int,
  need: BalanceNeed
): float {.raises: [SolverError].} =
  ## Scores how much one category needs repair right now.
  if perspective < 0 or perspective >= state.players.len:
    return
  let
    player = state.players[perspective]
    round = state.round
    risk = state.feedingRisk(perspective)
    harvestWait = round.turnsToHarvest()
    stage = round.gameStage()
    fields = player.countKind(Field)
    unused = player.unusedScoringSpaces()
  case need
  of NeedFood:
    result += risk.begging.float * 4.0
    if harvestWait <= FoodPrepWindow:
      result += risk.foodGap.float * 1.35
    elif risk.foodGap > 0:
      result += risk.foodGap.float * 0.35
    if round <= 8 and not player.hasReliableFoodEngine():
      result += 1.2
  of NeedFamily:
    if round <= FourthFamilyRoomRound and player.family.len < 4:
      result += (4 - player.family.len).float * stage.stageValue(1.6, 1.2, 0.45)
      if player.roomCount() <= player.family.len:
        result += 1.2
      elif player.roomProgress() < 0.75 and state.actionSoon(RFamilyGrowth, 2):
        result += 0.8
    if round >= 11 and player.family.len < 3:
      result += 2.2
  of NeedFarm:
    if round >= MidFieldRound:
      if fields == 0:
        result += 3.0
      elif fields < FieldCatchupTarget:
        result += 1.35
    if round >= FarmProtectionRound:
      result += max(0, unused - 5).float * 0.32
      if player.pastureCount() == 0:
        result += 1.25
    if round >= UrgentCoverageRound:
      result += max(0, unused - 5).float * 0.35
    elif round >= 9 and unused >= 8:
      result += 0.7
  of NeedBuildings:
    if round >= RenovationTempoStart and player.houseMaterial == HouseWood:
      result += stage.stageValue(0.0, 1.1, 1.8)
    if round <= 10 and player.family.len < 4 and
        player.roomCount() <= player.family.len:
      result += 0.8
    if round >= 11 and player.majors.len == 0:
      result += 0.6
  of NeedProfessions:
    if round >= 5 and player.occupations.len == 0:
      result += stage.stageValue(0.55, 1.0, 0.25)
    if round <= 8 and player.handOccupations.len > 0 and
        player.occupations.len < 2:
      result += 0.35
  of NeedNone:
    discard

proc weakestBalanceNeed*(
  state: GameState,
  perspective: int
): BalanceNeed {.raises: [SolverError].} =
  ## Returns the balance category with the largest current deficit.
  var bestScore = 0.0
  for need in NeedFood .. NeedProfessions:
    let score = state.balanceDeficitScore(perspective, need)
    if score > bestScore:
      bestScore = score
      result = need
  if bestScore < 0.65:
    result = NeedNone

proc anchorGoalAhead*(
  state: GameState,
  perspective: int,
  goal: SteeringGoal
): bool {.raises: [SolverError].} =
  ## Returns true when the anchor category is healthy enough to stop pushing.
  if goal == GoalBalance or perspective < 0 or perspective >= state.players.len:
    return false
  let
    player = state.players[perspective]
    risk = state.feedingRisk(perspective)
    round = state.round
    need = goal.anchorNeed()
  if state.balanceDeficitScore(perspective, need) >= 0.9:
    return false
  case goal
  of GoalFood:
    risk.begging == 0 and risk.foodGap == 0 and
      (player.hasReliableFoodEngine() or
        player.resources[Food] >= state.foodNeeded(player) + LateFoodBuffer)
  of GoalFamily:
    player.family.len >= 4 or
      (round >= 12 and player.family.len >= 3)
  of GoalFarm:
    player.countKind(Field) >= 3 and
      player.unusedScoringSpaces() <= 5 and
      (player.pastureCount() > 0 or round < 12)
  of GoalBuildings:
    player.houseMaterial != HouseWood or
      (player.roomCount() >= 4 and player.majors.len > 0)
  of GoalProfessions:
    player.occupations.len >= 2 or
      (round >= 10 and player.occupations.len >= 1)
  of GoalBalance:
    false

proc activeBalanceNeed*(
  state: GameState,
  perspective: int
): BalanceNeed {.raises: [SolverError].} =
  ## Returns the weakest current category for strategy logging.
  state.weakestBalanceNeed(perspective)

proc criticalBalanceNeed(
  state: GameState,
  perspective: int
): BalanceNeed {.raises: [SolverError].} =
  ## Returns a survival or timing deficit that must override the anchor.
  if perspective < 0 or perspective >= state.players.len:
    return NeedNone
  let
    player = state.players[perspective]
    round = state.round
    risk = state.feedingRisk(perspective)
    harvestWait = round.turnsToHarvest()
  if risk.begging > 0 or
      (risk.foodGap > 0 and harvestWait <= FoodPrepWindow):
    return NeedFood
  if round <= 10 and player.family.len < 4 and
      state.actionSoon(RFamilyGrowth, 1):
    if player.roomCount() <= player.family.len or
        risk.foodGap > 0:
      return NeedFamily
  if round >= FarmProtectionRound:
    if player.countKind(Field) == 0:
      return NeedFarm
    if player.unusedScoringSpaces() >= FarmProtectionUnusedSpaces and
        player.family.len >= 3:
      return NeedFarm
    if round >= FirstPastureProtectionRound and
        player.pastureCount() == 0 and
        (player.animals.totalAnimals() > 0 or player.hasAnimalCooking()):
      return NeedFarm
  NeedNone

proc moveSafetyPenalty(
  state,
  after: GameState,
  move: Move,
  perspective: int
): float {.raises: [SolverError].} =
  ## Penalizes actions that create crises or obvious late scoring holes.
  if move.kind != PlacementMove:
    return
  let
    before = state.players[perspective]
    player = after.players[perspective]
    round = state.round
    beforeRisk = state.feedingRisk(perspective)
    afterRisk = after.feedingRisk(perspective)
    harvestWait = round.turnsToHarvest()
    familyDelta = player.family.len - before.family.len
    roomDelta = player.roomCount() - before.roomCount()
    fieldDelta = player.countKind(Field) - before.countKind(Field)
    pastureDelta = player.pastureCount() - before.pastureCount()
    unusedDelta = before.unusedScoringSpaces() - player.unusedScoringSpaces()
  if afterRisk.begging > beforeRisk.begging:
    result -= (afterRisk.begging - beforeRisk.begging).float * 12.0
  if harvestWait <= FoodPrepWindow and
      afterRisk.foodGap > beforeRisk.foodGap:
    result -= (afterRisk.foodGap - beforeRisk.foodGap).float * 1.4
  if beforeRisk.begging == 0 and afterRisk.begging > 0:
    result -= 6.0
  if round <= 10 and before.family.len < 4 and
      state.actionSoon(RFamilyGrowth, 1):
    if familyDelta == 0 and roomDelta == 0 and
        player.roomProgress() <= before.roomProgress() and
        before.roomCount() <= before.family.len:
      result -= 1.5
  if round >= FarmProtectionRound and
      before.unusedScoringSpaces() >= FarmProtectionUnusedSpaces:
    if unusedDelta <= 0:
      result -= 2.0
  if round >= FarmProtectionRound and
      before.countKind(Field) == 0 and fieldDelta == 0:
    result -= 1.8
  if round >= FirstPastureProtectionRound and
      before.pastureCount() == 0 and
      pastureDelta <= 0 and
      (before.animals.totalAnimals() > 0 or before.hasAnimalCooking()):
    result -= 1.25

proc protectionMoveBonus(
  state,
  after: GameState,
  move: Move,
  perspective: int
): float {.raises: [SolverError].} =
  ## Rewards moves that preserve scoring assets and reduce exposed holes.
  if move.kind != PlacementMove:
    return
  let
    before = state.players[perspective]
    player = after.players[perspective]
    round = state.round
    stage = round.gameStage()
    harvestWait = round.turnsToHarvest()
    beforeRisk = state.feedingRisk(perspective)
    afterRisk = after.feedingRisk(perspective)
    fieldDelta = player.countKind(Field) - before.countKind(Field)
    pastureDelta = player.pastureCount() - before.pastureCount()
    unusedDelta = before.unusedScoringSpaces() - player.unusedScoringSpaces()
  if harvestWait <= 2:
    result += max(
      0,
      beforeRisk.animalScoreLoss - afterRisk.animalScoreLoss
    ).float * 1.55
    result -= afterRisk.animalScoreLoss.float * 0.5
    if afterRisk.begging == 0:
      result -= afterRisk.totalAnimalsCooked.float * 0.18
  if round >= 8 and before.countKind(Field) == 0 and fieldDelta > 0:
    result += stage.stageValue(0.0, 1.35, 2.0)
  if round >= 10 and before.countKind(Field) < 2 and fieldDelta > 0:
    result += fieldDelta.float * stage.stageValue(0.0, 0.95, 1.25)
  if round >= 9 and before.pastureCount() == 0 and pastureDelta > 0:
    result += stage.stageValue(0.0, 1.2, 1.65)
  if round >= 11 and before.unusedScoringSpaces() >= 7 and unusedDelta > 0:
    result += unusedDelta.float * 0.58
  case move.action
  of RSheep, RBoar, RCattle:
    var retained = 0
    case move.action
    of RSheep:
      retained = before.animalDelta(player, Sheep)
    of RBoar:
      retained = before.animalDelta(player, Boar)
    of RCattle:
      retained = before.animalDelta(player, Cattle)
    else:
      discard
    if retained <= 0 and afterRisk.begging == 0:
      result -= stage.stageValue(0.3, 0.95, 1.45)
  else:
    discard

proc balanceRepairScore(
  state,
  after: GameState,
  move: Move,
  perspective: int,
  need: BalanceNeed
): float {.raises: [SolverError].} =
  ## Scores how well one move repairs the current imbalance.
  if need == NeedNone or move.kind != PlacementMove:
    return
  let
    before = state.players[perspective]
    player = after.players[perspective]
    beforeRisk = state.feedingRisk(perspective)
    afterRisk = after.feedingRisk(perspective)
    familyDelta = player.family.len - before.family.len
    roomDelta = player.roomCount() - before.roomCount()
    fieldDelta = player.countKind(Field) - before.countKind(Field)
    pastureDelta = player.pastureCount() - before.pastureCount()
    unusedDelta = before.unusedScoringSpaces() - player.unusedScoringSpaces()
  case need
  of NeedFood:
    result += max(0, beforeRisk.begging - afterRisk.begging).float * 4.0
    result += max(0, beforeRisk.foodGap - afterRisk.foodGap).float * 1.15
    if beforeRisk.foodGap > 0 and afterRisk.foodGap == 0:
      result += 0.8
    if not before.hasReliableFoodEngine() and player.hasReliableFoodEngine():
      result += 1.5
    case move.action
    of DayLaborer, Fishing, TravelingPlayers, RSheep, RBoar, RCattle,
        RImprovement, RRenovateImprove, RSowBake:
      result += 0.3
    else:
      discard
  of NeedFamily:
    result += familyDelta.float * 3.2
    result += roomDelta.float * 1.45
    result += max(0.0, player.roomProgress() - before.roomProgress()) * 1.4
    case move.action
    of RFamilyGrowth, RUrgentFamily:
      result += 1.1
    of FarmExpansion:
      if move.rooms.len > 0:
        result += 0.75
    else:
      discard
  of NeedFarm:
    result += fieldDelta.float * 1.25
    result += pastureDelta.float * 1.1
    result += unusedDelta.float * 0.75
    case move.action
    of Farmland, GrainSeeds, RVegetable, RSowBake, RCultivation,
        RFences, RSheep, RBoar, RCattle:
      result += 0.45
    else:
      discard
  of NeedBuildings:
    result += roomDelta.float * 1.0
    if before.houseMaterial == HouseWood and player.houseMaterial != HouseWood:
      result += 2.4
    case move.action
    of RRenovateImprove, RRedevelop:
      result += 1.1
    of RImprovement, MeetingPlace:
      if move.improvement.kind != NoImprovement:
        result += 0.65
    of Forest, Copse, Grove, ReedBank, ClayPit, Hollow, ResourceMarket,
        RWestQuarry, REastQuarry:
      result += 0.35
    else:
      discard
  of NeedProfessions:
    result += (player.occupations.len - before.occupations.len).float * 2.0
    result += (player.minors.len - before.minors.len).float * 0.65
    case move.action
    of Lessons, LessonsB:
      result += 1.2
    of MeetingPlace:
      if move.improvement.kind != NoImprovement:
        result += 0.4
    else:
      discard
  of NeedNone:
    discard

proc balanceRepairMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move],
  need: BalanceNeed,
  minScore: float = BalanceRepairMinScore
): BasePolicyChoice =
  ## Returns the best direct repair move for the current imbalance.
  if need == NeedNone:
    return
  var
    bestMove: Move
    bestScore = low(float)
    bestReason = PolicyNone
  for move in rootMoves:
    try:
      let
        after = state.applyMove(move)
        repair = state.balanceRepairScore(after, move, perspective, need)
      if repair > bestScore:
        bestMove = move
        bestScore = repair
        bestReason = move.policyReason()
    except CatchableError:
      discard
  if bestScore < minScore:
    return
  BasePolicyChoice(
    ok: true,
    move: bestMove,
    score: bestScore,
    reason: bestReason
  )

proc basePolicyScoreMove*(
  state: GameState,
  move: Move,
  perspective: int,
  goal: SteeringGoal = GoalBalance
): float {.raises: [SolverError].} =
  ## Scores one move for the standalone base policy.
  let before = state.players[perspective]
  let after = state.applyMove(move)
  result = after.evaluateState(perspective)
  result += state.stageMoveBonus(after, move, perspective)
  result += state.balanceMoveBonus(after, move, perspective)
  result += state.moveSafetyPenalty(after, move, perspective)
  result += state.protectionMoveBonus(after, move, perspective)
  result += state.goalMoveBonus(after, move, perspective, goal)
  result += state.opponentDenialBonus(move, perspective)
  if move.kind != PlacementMove:
    return
  if state.round <= 4 and not before.hasCookingTarget():
    if move.improvement.card.isEarlyCookingCard():
      result -= 1.4
    if move.occupation.isEarlyCookingCard():
      result -= 1.4
  case move.action
  of RFamilyGrowth, RUrgentFamily:
    result += 2.0
  of FarmExpansion:
    if move.rooms.len > 0:
      if state.round <= 10:
        result += 1.5
      else:
        result -= 1.0
    if move.stables.len > 0 and
        state.players[perspective].hasAnimalCooking():
      result += 0.8
  of RFences:
    result += move.edges.len.float * 0.08
  of Farmland, RCultivation:
    let value =
      if before.family.len >= 3:
        0.75
      else:
        0.6
    result += move.fields.len.float * value
    if move.plow != NoSpace:
      result += value
  of RSowBake:
    result += move.sow.len.float * 0.5
    result += move.bake.len.float * 0.3
  of RImprovement, MeetingPlace, RRenovateImprove:
    if move.improvement.kind != NoImprovement:
      result += 0.6
  else:
    discard

proc bestScoredMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move],
  goal: SteeringGoal
): BasePolicyChoice =
  ## Returns a high-scoring policy move, sometimes exploring an alternative.
  var scored: seq[ScoredMove]
  for move in rootMoves:
    try:
      let score = state.basePolicyScoreMove(move, perspective, goal)
      scored.add ScoredMove(
        move: move,
        score: score,
        reason: move.policyReason()
      )
    except CatchableError:
      discard
  state.chooseScoredMove(perspective, scored)

proc hardStrategicMove(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move]
): BasePolicyChoice =
  ## Returns safety-critical direct choices that should not be randomized.
  let
    player = state.players[perspective]
    round = state.round
    risk = state.feedingRisk(perspective)
    harvestWait = round.turnsToHarvest()
    foodPressure = risk.foodGap > 0 and harvestWait <= FoodPrepWindow
    needsFirstRoom =
      player.family.len < 3 and player.roomCount() <= player.family.len
    normalGrowthSoon = state.actionSoon(RFamilyGrowth, 2)
    fifthRoomUseful =
      player.family.len == 4 and
        player.roomCount() <= player.family.len and
        (normalGrowthSoon or round <= FifthFamilyRoomRound) and
        (player.hasReliableFoodEngine() or risk.foodGap <= 0)
  if round <= FirstRoomBuildRound and needsFirstRoom:
    let build = rootMoves.strategicBuildRoomMove()
    if build.ok and (round >= 4 or normalGrowthSoon):
      try:
        let after = state.applyMove(build.move)
        if harvestWait > 1 or after.feedingRisk(perspective).begging == 0:
          return BasePolicyChoice(
            ok: true,
            move: build.move,
            score: state.basePolicyScoreMove(build.move, perspective),
            reason: PolicyRoomBuild
          )
      except CatchableError:
        discard
    if not foodPressure and (round <= FirstRoomSetupRound or normalGrowthSoon):
      let setup = state.strategicRoomSetupMove(perspective, rootMoves)
      if setup.ok:
        return BasePolicyChoice(
          ok: true,
          move: setup.move,
          score: state.basePolicyScoreMove(setup.move, perspective),
          reason: PolicyRoomSetup
        )
  let family = state.strategicFamilyMove(perspective, rootMoves)
  if family.ok:
    return BasePolicyChoice(
      ok: true,
      move: family.move,
      score: state.basePolicyScoreMove(family.move, perspective),
      reason: PolicyFamily
    )
  if round <= 8 and not player.hasReliableFoodEngine():
    let engine = state.strategicFoodEngineMove(perspective, rootMoves)
    if engine.ok:
      return BasePolicyChoice(
        ok: true,
        move: engine.move,
        score: state.basePolicyScoreMove(engine.move, perspective),
        reason: engine.move.policyReason()
      )
    let setup = state.strategicFoodEngineSetupMove(perspective, rootMoves)
    if setup.ok:
      return BasePolicyChoice(
        ok: true,
        move: setup.move,
        score: state.basePolicyScoreMove(setup.move, perspective),
        reason: PolicyFood
      )
  if round >= ZeroFieldPatchRound and
      round <= 12 and
      player.family.len >= 3 and
      player.countKind(Field) == 0 and
      risk.begging == 0 and
      (harvestWait > 1 or risk.foodGap <= ZeroFieldSafeFoodGap):
    let field = state.strategicFieldMove(
      perspective,
      player.unusedScoringSpaces(),
      rootMoves
    )
    if field.ok:
      return BasePolicyChoice(
        ok: true,
        move: field.move,
        score: state.basePolicyScoreMove(field.move, perspective),
        reason: PolicyField
      )
  if foodPressure:
    let food = state.strategicFoodMove(perspective, rootMoves)
    if food.ok:
      return BasePolicyChoice(
        ok: true,
        move: food.move,
        reason: PolicyFood
      )
  if round <= FirstRoomBuildRound and needsFirstRoom:
    let build = rootMoves.strategicBuildRoomMove()
    if build.ok and (round >= 4 or normalGrowthSoon):
      return BasePolicyChoice(
        ok: true,
        move: build.move,
        score: state.basePolicyScoreMove(build.move, perspective),
        reason: PolicyRoomBuild
      )
    if round <= FirstRoomSetupRound:
      let setup = state.strategicRoomSetupMove(perspective, rootMoves)
      if setup.ok:
        return BasePolicyChoice(
          ok: true,
          move: setup.move,
          score: state.basePolicyScoreMove(setup.move, perspective),
          reason: PolicyRoomSetup
        )
  let laterFamily = state.strategicFamilyMove(perspective, rootMoves)
  if laterFamily.ok:
    return BasePolicyChoice(
      ok: true,
      move: laterFamily.move,
      score: state.basePolicyScoreMove(laterFamily.move, perspective),
      reason: PolicyFamily
    )
  if round >= FieldCatchupRound and
      round <= 12 and
      player.family.len >= 3 and
      player.countKind(Field) < FieldCatchupTarget:
    let field = state.strategicFieldMove(
      perspective,
      player.unusedScoringSpaces(),
      rootMoves
    )
    if field.ok:
      return BasePolicyChoice(
        ok: true,
        move: field.move,
        score: state.basePolicyScoreMove(field.move, perspective),
        reason: PolicyField
      )
  let fourthRoomWindow =
    round <= 12 or player.countKind(Field) >= FourthRoomLateMinFields
  if round <= FourthFamilyRoomRound and
      fourthRoomWindow and
      player.family.len >= 3 and
      player.family.len < 4 and
      player.roomCount() <= player.family.len:
    let build = rootMoves.strategicBuildRoomMove()
    if build.ok:
      return BasePolicyChoice(
        ok: true,
        move: build.move,
        score: state.basePolicyScoreMove(build.move, perspective),
        reason: PolicyRoomBuild
      )
    let setup = state.strategicRoomSetupMove(perspective, rootMoves)
    if setup.ok and player.roomProgress() < 1.0:
      return BasePolicyChoice(
        ok: true,
        move: setup.move,
        score: state.basePolicyScoreMove(setup.move, perspective),
        reason: PolicyRoomSetup
      )
  if round <= FifthFamilyRoomRound and fifthRoomUseful:
    let build = rootMoves.strategicBuildRoomMove()
    if build.ok:
      return BasePolicyChoice(
        ok: true,
        move: build.move,
        score: state.basePolicyScoreMove(build.move, perspective),
        reason: PolicyRoomBuild
      )
    let setup = state.strategicRoomSetupMove(perspective, rootMoves)
    if setup.ok and player.roomProgress() < 1.0:
      return BasePolicyChoice(
        ok: true,
        move: setup.move,
        score: state.basePolicyScoreMove(setup.move, perspective),
        reason: PolicyRoomSetup
      )
  if round >= 9 and
      round <= 10 and
      player.family.len >= 3 and
      player.countKind(Field) < MidFieldTarget:
    let field = state.strategicFieldMove(
      perspective,
      player.unusedScoringSpaces(),
      rootMoves
    )
    if field.ok:
      return BasePolicyChoice(
        ok: true,
        move: field.move,
        score: state.basePolicyScoreMove(field.move, perspective),
        reason: PolicyField
      )
  if round >= ZeroFieldPatchRound and
      player.countKind(Field) == 0:
    let field = state.strategicFieldMove(
      perspective,
      player.unusedScoringSpaces(),
      rootMoves
    )
    if field.ok:
      return BasePolicyChoice(
        ok: true,
        move: field.move,
        score: state.basePolicyScoreMove(field.move, perspective),
        reason: PolicyField
      )
  if round >= UrgentCoverageRound and
      player.unusedScoringSpaces() >= UrgentCoverageUnusedSpaces:
    if player.countKind(Field) < 2:
      let field = state.strategicFieldMove(
        perspective,
        player.unusedScoringSpaces(),
        rootMoves
      )
      if field.ok:
        return BasePolicyChoice(
          ok: true,
          move: field.move,
          score: state.basePolicyScoreMove(field.move, perspective),
          reason: PolicyField
        )
    let fence = state.strategicFenceMove(
      perspective,
      player.unusedScoringSpaces(),
      rootMoves
    )
    if fence.ok:
      return BasePolicyChoice(
        ok: true,
        move: fence.move,
        score: state.basePolicyScoreMove(fence.move, perspective),
        reason: PolicyFence
      )
    let field = state.strategicFieldMove(
      perspective,
      player.unusedScoringSpaces(),
      rootMoves
    )
    if field.ok:
      return BasePolicyChoice(
        ok: true,
        move: field.move,
        score: state.basePolicyScoreMove(field.move, perspective),
        reason: PolicyField
      )
  let renovation = state.strategicRenovationMove(
    perspective,
    rootMoves
  )
  if renovation.ok:
    return BasePolicyChoice(
      ok: true,
      move: renovation.move,
      score: state.basePolicyScoreMove(renovation.move, perspective),
      reason: PolicyScore
    )
  let renovationResource = state.strategicRenovationResourceMove(
    perspective,
    rootMoves
  )
  if renovationResource.ok:
    return BasePolicyChoice(
      ok: true,
      move: renovationResource.move,
      score: state.basePolicyScoreMove(renovationResource.move, perspective),
      reason: PolicyScore
    )
  let pointMajor = state.strategicPointImprovementMove(
    perspective,
    rootMoves
  )
  if pointMajor.ok:
    return BasePolicyChoice(
      ok: true,
      move: pointMajor.move,
      score: state.basePolicyScoreMove(pointMajor.move, perspective),
      reason: PolicyScore
    )
  if round <= 8 and
      player.family.len < 4 and
      player.roomCount() <= player.family.len and
      state.actionSoon(RFamilyGrowth, 1):
    let build = rootMoves.strategicBuildRoomMove()
    if build.ok:
      return BasePolicyChoice(
        ok: true,
        move: build.move,
        score: state.basePolicyScoreMove(build.move, perspective),
        reason: PolicyRoomBuild
      )
  let scoreMove = state.strategicLateScoreMove(perspective, rootMoves)
  if scoreMove.ok:
    return BasePolicyChoice(
      ok: true,
      move: scoreMove.move,
      score: state.basePolicyScoreMove(scoreMove.move, perspective),
      reason: scoreMove.move.policyReason()
    )
  if round >= MidFieldRound and
      round <= 12 and
      player.countKind(Field) < MidFieldTarget:
    let field = state.strategicFieldMove(
      perspective,
      player.unusedScoringSpaces(),
      rootMoves
    )
    if field.ok:
      return BasePolicyChoice(
        ok: true,
        move: field.move,
        score: state.basePolicyScoreMove(field.move, perspective),
        reason: PolicyField
      )
  if round >= RanchRound and round <= RanchLastRound:
    let ranch = state.strategicRanchMove(
      perspective,
      player.unusedScoringSpaces(),
      rootMoves
    )
    if ranch.ok:
      return BasePolicyChoice(
        ok: true,
        move: ranch.move,
        score: state.basePolicyScoreMove(ranch.move, perspective),
        reason: PolicyFence
      )
  if round >= LateFenceRound and
      player.unusedScoringSpaces() >= LateFenceUnusedSpaces:
    let fence = state.strategicFenceMove(
      perspective,
      player.unusedScoringSpaces(),
      rootMoves
    )
    if fence.ok and round >= 13:
      return BasePolicyChoice(
        ok: true,
        move: fence.move,
        score: state.basePolicyScoreMove(fence.move, perspective),
        reason: PolicyFence
      )
  if round >= LateFieldRound and
      player.family.len >= LateCoverageFamily and
      player.countKind(Field) < LateFieldTarget:
    let field = state.strategicFieldMove(
      perspective,
      player.unusedScoringSpaces(),
      rootMoves
    )
    if field.ok and round >= 13:
      return BasePolicyChoice(
        ok: true,
        move: field.move,
        score: state.basePolicyScoreMove(field.move, perspective),
        reason: PolicyField
      )
  if round == 4 and
      player.family.len < 4 and
      player.roomCount() <= player.family.len:
    let build = rootMoves.strategicBuildRoomMove()
    if build.ok:
      return BasePolicyChoice(
        ok: true,
        move: build.move,
        score: state.basePolicyScoreMove(build.move, perspective),
        reason: PolicyRoomBuild
      )
  if round <= RoomSetupRound and
      player.family.len < 4 and
      player.roomCount() <= player.family.len and
      player.roomProgress() < 0.75:
    let setup = state.strategicRoomSetupMove(perspective, rootMoves)
    if setup.ok and round <= 3:
      return BasePolicyChoice(
        ok: true,
        move: setup.move,
        score: state.basePolicyScoreMove(setup.move, perspective),
        reason: PolicyRoomSetup
      )
  if round >= 4 and
      round <= 8 and
      player.family.len < 4 and
      player.roomCount() <= player.family.len:
    for move in rootMoves:
      if move.kind == PlacementMove and
          move.action == FarmExpansion and
          move.rooms.len > 0:
        return BasePolicyChoice(
          ok: true,
          move: move,
          score: state.basePolicyScoreMove(move, perspective),
          reason: PolicyFarmExpansion
        )

proc chooseBasePolicyMove*(
  state: GameState,
  perspective: int,
  rootMoves: openArray[Move],
  goal: SteeringGoal = GoalBalance
): BasePolicyChoice =
  ## Chooses one standalone base-policy move from legal root moves.
  if perspective < 0 or perspective >= state.players.len:
    return
  if rootMoves.len == 0:
    return
  if goal != GoalBalance:
    let critical = state.criticalBalanceNeed(perspective)
    if critical != NeedNone:
      let repair = state.balanceRepairMove(perspective, rootMoves, critical)
      if repair.ok:
        return repair
      let direct = state.hardStrategicMove(perspective, rootMoves)
      if direct.ok:
        return direct
    let direct = state.hardStrategicMove(perspective, rootMoves)
    if direct.ok:
      return direct
    if state.anchorGoalAhead(perspective, goal):
      let weak = state.weakestBalanceNeed(perspective)
      let repair = state.balanceRepairMove(
        perspective,
        rootMoves,
        weak,
        AnchorAheadRepairMinScore
      )
      if repair.ok:
        return repair
      return state.bestScoredMove(perspective, rootMoves, GoalBalance)
    return state.bestScoredMove(perspective, rootMoves, goal)
  let direct = state.hardStrategicMove(perspective, rootMoves)
  if direct.ok:
    return direct
  state.bestScoredMove(perspective, rootMoves, goal)

when defined(release):
  {.pop.}
