## The Proxy War decision policy.
##
## Every legal action is scored independently and the highest score wins.
## Scoring is pure over (observation, action, memory), so tools/ can replay
## captured decision requests and diff two profiles offline.
##
## The numbers below are anchored on the engine's own economy, read out of
## `app/proxywar/src/core/configuration/DefaultConfig.ts`:
##
## - `maxTroops = 2*(tiles^0.6*1000 + 50000) + cityLevels*250000`
## - `troopIncrease = (10 + troops^0.73/4) * (1 - troops/maxTroops)`
##   which peaks at `troops ≈ 0.42*maxTroops` — so a steady troop ratio near
##   0.42 maximises regeneration, and dumping the pool to near zero wastes it.
## - Gold income is a flat 100/turn; the only scalable source is trade ships,
##   which need a Port and pay 35k with an ally versus 25k with a stranger.
## - Costs double per structure: Port/Factory and City both `2^n * 125_000`
##   capped at 1M, so the first Port and the first City are the two
##   highest-return purchases in the game.

import std/[algorithm, os, strutils, tables]
import observation, opening_actions, openings, opponents

const growthOptimalRatio* = 0.42

type
  Memory* = object
    ## Per-episode state the brain carries between decisions.
    decisions*: int
    allianceAsks*: Table[string, int]
    lastKind*: string
    sameKindRun*: int
    expansions*: int
    builds*: int
    attacks*: int
    lastChoiceID*: string
    lastChoiceKind*: string
    lastTiles*: float
    seenTiles*: bool
    ## Consecutive times an action was taken without the tile count moving.
    stallByID*: Table[string, int]
    neutralStall*: int
    lastAttackTarget*: string
    ## Decisions spent attacking a target, and our tiles when we started.
    targetGrind*: Table[string, int]
    targetStartTiles*: Table[string, float]
    peakTiles*: float
    losingStreak*: int
    ## Every action id we have already committed to, and how often.
    takenIDs*: Table[string, int]
    ## Accepted expansion sequence ids already observed from the game.
    seenAcceptedExpansions*: Table[int, bool]
    acceptedExpansions*: int
    ## Quiet hold or diplomacy decisions already converted into construction.
    quietBuilds*: int
    ## Policy requests consumed by the accepted-cadence position opening.
    mattOpeningAttempts*: int
    ## Stop the position opening permanently after live defensive pressure.
    mattOpeningAborted*: bool

  Weights* = object
    ## Tunable knobs. One profile is one experiment.
    name*: string
    spawnLocalLand*: float
    spawnSafety*: float
    spawnOpportunity*: float

    expandBase*: float
    expandRichBonus*: float
    expandPoorPenalty*: float
    expandPoorRatio*: float
    expandRichRatio*: float
    expandFractionPenalty*: float
    ## Add neutral-expansion pressure only after the 1,500-turn opening assay.
    conversionExpandBonus*: float
    ## Force one neutral-expansion size only during opening conversion.
    conversionExpandFraction*: float
    ## Absolute turn after which conversion expansion controls may apply.
    conversionExpandFloorTurn*: float
    ## Restrict a fixed opening dose to one runtime spawn tile.
    openingExpandSpawnTile*: int
    ## Apply the fixed opening dose to every verified opening-book start.
    openingExpandKnownStarts*: bool
    ## Number of accepted neutral expansions that use the opening dose.
    openingExpandCount*: int
    ## Neutral-expansion troop fraction used by the fixed opening dose.
    openingExpandFraction*: float
    ## Last turn at which the fixed opening dose may apply.
    openingExpandEndTurn*: float
    ## Restrict an absolute neutral-land opening to one runtime spawn.
    forcedLandSpawnTile*: int
    ## Number of game-confirmed neutral-land actions forced at that spawn.
    forcedLandCount*: int
    ## Exact troop fraction required by the forced neutral-land action.
    forcedLandFraction*: float
    ## Last turn at which the forced neutral-land action may apply.
    forcedLandEndTurn*: float
    ## Select where the first five safe decisions use the scripted book.
    openingBookScope*: OpeningScope
    ## Replay the strongest observed Matt opening at exact Pangaea starts.
    mattPositionOpening*: bool
    spendPressure*: float
    threatReserve*: float
    ## Force one neutral-expansion size in a four-player or smaller field.
    smallFieldExpandFraction*: float
    ## Scale per-action expansion stalls while retaining the frontier stall.
    smallFieldExpansionStallScale*: float
    ## Off by default. Measured on mirrored arms the collapse response holds a
    ## seat alive at daveey's rate (54 of 99) while winning **zero** games: it
    ## trades all offence for survival, and surviving with no territory scores
    ## nothing. Profiles that want it opt in.
    collapseDefense*: float
    ## Restrict collapse defence to one runtime spawn tile. Negative is global.
    collapseDefenseSpawnTile*: int
    ## Restrict collapse defence to one verified map. None is unrestricted.
    collapseDefenseScope*: OpeningScope
    ## Require this many simultaneous incoming attacks before digging in.
    collapseDefenseMinIncoming*: int
    grindPenalty*: float
    weakRatioPenalty*: float
    ## Ratio at or above which an attack commits 40% of the pool instead of
    ## 25%. daveey's territory-taking wars in the clean replays are all `:40`;
    ## ours are `:25`, which bleeds troops without taking ground.
    fullCommitRatio*: float
    ## Urgency at which a matchup below `fullCommitRatio` still commits 40%.
    urgentFullCommit*: float
    ## Territory share at which a favorable lead converts at full commitment.
    leadFullCommitShare*: float
    ## Matchup ratio used only after `leadFullCommitShare` is reached.
    leadFullCommitRatio*: float
    ## Territory share below which favorable target ranking gets an extra dose.
    preLeadTargetShare*: float
    ## Extra troop-ratio target score used only before `preLeadTargetShare`.
    preLeadAttackRatioGain*: float
    ## Restrict second-stage hostile-target ranking to one verified map.
    targetRerankScope*: OpeningScope
    ## Extra troop-ratio score after the policy has already chosen to attack.
    targetRerankRatioGain*: float
    ## Keep second-stage target ranking out of active defensive decisions.
    targetRerankPeaceOnly*: bool
    ## Restrict losing pressure-counterattack deflection to one verified map.
    pressureDeflectScope*: OpeningScope
    ## Minimum own-to-target ratio retained during an active invasion.
    pressureDeflectMinRatio*: float
    ## Restrict an early economic conversion window to one runtime spawn.
    spawnBoomTile*: int
    ## Restrict an early economic conversion window to one verified map.
    spawnBoomScope*: OpeningScope
    ## Last turn at which the spawn-specific conversion window may apply.
    spawnBoomEndTurn*: float
    ## Symmetric attack penalty and economic-action bonus in that window.
    spawnBoomDose*: float
    ## Last turn at which quiet construction substitutions may apply.
    quietBuildEndTurn*: float
    ## Maximum score deficit allowed when substituting a legal construction.
    quietBuildMargin*: float
    ## Maximum quiet construction substitutions allowed in one episode.
    quietBuildCount*: int
    ## Maximum target ratio for replacing one safe hostile action with a build.
    quietBuildAttackRatio*: float
    ## Maximum economic builds appended after one compatible ground action.
    economyBatchCount*: int
    ## Append one remaining land action once territory share hits closingShare.
    closingGroundBatch*: bool
    ## Add bounded free-form border chat through the independent comms slot.
    borderChat*: bool
    ## Use structured pacts with an enforced treaty-compliance guard.
    structuredDeals*: bool
    ## Use trusted schema-five front geometry for Defense Post placement.
    spatialLandDefense*: bool
    ## Penalty for attacking a rival we are outright weaker than. Kept separate
    ## from `weakRatioPenalty` so the "don't start losing fights" deterrent does
    ## not weaken when the *threshold* is lowered to let winnable fights through.
    losingFightPenalty*: float
    landGrabTiles*: float

    attackBase*: float
    attackRatioGain*: float
    attackMinRatio*: float
    attackNeutralPenalty*: float
    attackSiegeBonus*: float
    attackWeakTargetBonus*: float
    attackFractionPenalty*: float
    targetStickiness*: float
    ## Scale replay-derived name priors used only to rank hostile targets.
    opponentPriorScale*: float
    ## Scale a replay-derived penalty for opening wars with strong predators.
    opponentAvoidScale*: float
    ## Use 10% probes below this matchup ratio. Zero disables the rule.
    probeAttackRatio*: float
    ## Discourage consecutive hostile decisions without forbidding a push.
    hostileRepeatPenalty*: float
    ## Extra attack pressure when only three or fewer rivals remain.
    smallFieldAttackBonus*: float
    ## Multiplier for the repeat penalty in a four-player or smaller field.
    smallFieldRepeatScale*: float
    ## Let marginal small-field fights probe before urgency forces 40%.
    smallFieldProbeFirst*: bool
    counterAttackBonus*: float
    ## Delay counterattack priority until an absolute observation turn.
    counterAttackFloorTurn*: float
    invadedOffensePenalty*: float
    counterAttackFractionPenalty*: float
    earlyAttackFloorTurn*: float
    earlyAttackPenalty*: float
    ## Apply the opening-war delay only with at least this many live rivals.
    earlyAttackMinRivals*: int
    ## Exempt an overwhelmingly favorable matchup from the opening delay.
    earlyAttackExemptRatio*: float
    ## Restrict the opening-war delay to one verified map. None is unrestricted.
    earlyAttackScope*: OpeningScope
    ## Penalize unprovoked attacks on troop-stronger rivals on water maps.
    waterStrongTargetPenalty*: float
    ## Avoid an unprovoked war with the measured live leader near parity.
    mattAttackPenalty*: float
    ## Use this full-commit threshold only on verified Oceania starts.
    oceaniaFullCommitRatio*: float

    firstPort*: float
    firstCity*: float
    portBase*: float
    cityBase*: float
    factoryBase*: float
    buildDecay*: float
    buildIdleTroopBonus*: float
    ## Small-field penalty for Ports and Factories, but not Cities.
    smallFieldNonCityBuildPenalty*: float
    ## Extra small-field economy penalty once territory is shrinking.
    smallFieldCollapseBuildPenalty*: float
    defensePostBase*: float
    threatDefenseBonus*: float
    ## Small-field penalty for a Defense Post action.
    smallFieldDefensePostPenalty*: float
    ## Extra value for a Port on verified Oceania and Black Sea starts.
    waterPortBonus*: float
    samBase*: float
    siloBase*: float
    warshipBase*: float
    upgradeBase*: float

    allianceBase*: float
    allianceRepeatPenalty*: float
    allianceBorderBonus*: float
    allianceStrongBonus*: float
    allianceLateMalus*: float
    allianceExtend*: float
    ## Suppress alliance actions only on verified Oceania starts.
    oceaniaAlliancePenalty*: float
    breakAllianceBase*: float
    ## Small-field penalty for requesting or extending an alliance.
    smallFieldAlliancePenalty*: float

    boatExpandBase*: float
    boatInvadeBase*: float
    boatDesiredFraction*: float
    ## Small-field boat fraction. Zero keeps `boatDesiredFraction`.
    smallFieldBoatFraction*: float
    ## Small-field penalty for choosing a transport action.
    smallFieldBoatPenalty*: float
    nukeBase*: float
    holdBase*: float
    holdRecoveryBonus*: float
    chatterBase*: float
    ## Territory share at which non-ground actions receive closing pressure.
    closingShare*: float
    ## Penalty applied to non-ground actions above the closing threshold.
    closingPenalty*: float
    ## Earlier share threshold for an optional conversion-pressure tier.
    conversionShare*: float
    ## Penalty applied within the earlier conversion-pressure tier.
    conversionPenalty*: float

  Choice* = object
    id*: string
    kind*: string
    score*: float
    reason*: string
    quietBuild*: bool

  MattOpeningKind = enum
    mattExpand,
    mattAttack,
    mattBoat,
    mattBuild,
    mattHold

  MattOpeningStep = object
    kind: MattOpeningKind
    percent: int
    unit: string

  MattPositionOpening = object
    spawnTile: int
    steps: array[5, MattOpeningStep]

const
  MattOpeningRepeat = 4
  MattPositionOpenings = [
    MattPositionOpening(
      spawnTile: 188728,
      steps: [
        MattOpeningStep(kind: mattExpand, percent: 35),
        MattOpeningStep(kind: mattExpand, percent: 35),
        MattOpeningStep(kind: mattAttack, percent: 40),
        MattOpeningStep(kind: mattBoat, percent: 8),
        MattOpeningStep(kind: mattBoat, percent: 8)
      ]
    ),
    MattPositionOpening(
      spawnTile: 190532,
      steps: [
        MattOpeningStep(kind: mattExpand, percent: 35),
        MattOpeningStep(kind: mattExpand, percent: 35),
        MattOpeningStep(kind: mattBuild, unit: "Defense Post"),
        MattOpeningStep(kind: mattAttack, percent: 40),
        MattOpeningStep(kind: mattAttack, percent: 25)
      ]
    ),
    MattPositionOpening(
      spawnTile: 431138,
      steps: [
        MattOpeningStep(kind: mattExpand, percent: 35),
        MattOpeningStep(kind: mattAttack, percent: 40),
        MattOpeningStep(kind: mattBuild, unit: "City"),
        MattOpeningStep(kind: mattAttack, percent: 40),
        MattOpeningStep(kind: mattAttack, percent: 40)
      ]
    ),
    MattPositionOpening(
      spawnTile: 916672,
      steps: [
        MattOpeningStep(kind: mattExpand, percent: 35),
        MattOpeningStep(kind: mattHold),
        MattOpeningStep(kind: mattBuild, unit: "Defense Post"),
        MattOpeningStep(kind: mattAttack, percent: 25),
        MattOpeningStep(kind: mattAttack, percent: 25)
      ]
    )
  ]

const baseWeights* = Weights(
  name: "base",
  spawnLocalLand: 60.0,
  spawnSafety: 22.0,
  spawnOpportunity: 10.0,

  expandBase: 62.0,
  expandRichBonus: 14.0,
  expandPoorPenalty: 26.0,
  expandPoorRatio: 0.20,
  expandRichRatio: 0.48,
  expandFractionPenalty: 40.0,
  conversionExpandBonus: 0.0,
  conversionExpandFraction: 0.0,
  conversionExpandFloorTurn: 0.0,
  openingExpandSpawnTile: -1,
  openingExpandKnownStarts: false,
  openingExpandCount: 0,
  openingExpandFraction: 0.0,
  openingExpandEndTurn: 0.0,
  forcedLandSpawnTile: -1,
  forcedLandCount: 0,
  forcedLandFraction: 0.0,
  forcedLandEndTurn: 0.0,
  openingBookScope: openingNone,
  mattPositionOpening: false,
  spendPressure: 42.0,
  threatReserve: 0.0,
  smallFieldExpandFraction: 0.0,
  smallFieldExpansionStallScale: 1.0,
  collapseDefense: 0.0,
  collapseDefenseSpawnTile: -1,
  collapseDefenseScope: openingNone,
  collapseDefenseMinIncoming: 0,
  grindPenalty: 60.0,
  weakRatioPenalty: 0.0,
  fullCommitRatio: 2.0,
  urgentFullCommit: 0.8,
  leadFullCommitShare: 0.0,
  leadFullCommitRatio: 0.0,
  preLeadTargetShare: 0.0,
  preLeadAttackRatioGain: 0.0,
  targetRerankScope: openingNone,
  targetRerankRatioGain: 0.0,
  targetRerankPeaceOnly: false,
  pressureDeflectScope: openingNone,
  pressureDeflectMinRatio: 0.0,
  spawnBoomTile: -1,
  spawnBoomScope: openingNone,
  spawnBoomEndTurn: 0.0,
  spawnBoomDose: 0.0,
  quietBuildEndTurn: 0.0,
  quietBuildMargin: 0.0,
  quietBuildCount: 0,
  quietBuildAttackRatio: 0.0,
  economyBatchCount: 0,
  closingGroundBatch: false,
  borderChat: false,
  structuredDeals: false,
  spatialLandDefense: false,
  losingFightPenalty: 0.0,
  landGrabTiles: 0.0,

  attackBase: 34.0,
  attackRatioGain: 16.0,
  attackMinRatio: 1.25,
  attackNeutralPenalty: 24.0,
  attackSiegeBonus: 10.0,
  attackWeakTargetBonus: 10.0,
  attackFractionPenalty: 30.0,
  targetStickiness: 14.0,
  opponentPriorScale: 0.0,
  opponentAvoidScale: 0.0,
  probeAttackRatio: 0.0,
  hostileRepeatPenalty: 0.0,
  smallFieldAttackBonus: 0.0,
  smallFieldRepeatScale: 1.0,
  smallFieldProbeFirst: false,
  counterAttackBonus: 0.0,
  counterAttackFloorTurn: 0.0,
  invadedOffensePenalty: 0.0,
  counterAttackFractionPenalty: 0.0,
  earlyAttackFloorTurn: 0.0,
  earlyAttackPenalty: 0.0,
  earlyAttackMinRivals: 0,
  earlyAttackExemptRatio: 0.0,
  earlyAttackScope: openingNone,
  waterStrongTargetPenalty: 0.0,
  mattAttackPenalty: 0.0,
  oceaniaFullCommitRatio: 0.0,

  firstPort: 96.0,
  firstCity: 88.0,
  portBase: 70.0,
  cityBase: 72.0,
  factoryBase: 58.0,
  buildDecay: 9.0,
  buildIdleTroopBonus: 18.0,
  smallFieldNonCityBuildPenalty: 0.0,
  smallFieldCollapseBuildPenalty: 0.0,
  defensePostBase: 26.0,
  threatDefenseBonus: 22.0,
  smallFieldDefensePostPenalty: 0.0,
  waterPortBonus: 0.0,
  samBase: 14.0,
  siloBase: 12.0,
  warshipBase: 14.0,
  upgradeBase: 46.0,

  allianceBase: 74.0,
  allianceRepeatPenalty: 34.0,
  allianceBorderBonus: 8.0,
  allianceStrongBonus: 8.0,
  allianceLateMalus: 40.0,
  allianceExtend: 74.0,
  oceaniaAlliancePenalty: 0.0,
  breakAllianceBase: 50.0,
  smallFieldAlliancePenalty: 0.0,

  boatExpandBase: 52.0,
  boatInvadeBase: 30.0,
  boatDesiredFraction: 0.35,
  smallFieldBoatFraction: 0.0,
  smallFieldBoatPenalty: 0.0,
  nukeBase: 55.0,
  holdBase: 1.0,
  holdRecoveryBonus: 0.0,
  chatterBase: 2.0,
  closingShare: 0.35,
  closingPenalty: 30.0,
  conversionShare: 0.0,
  conversionPenalty: 0.0,
)

proc rushWeights(): Weights =
  ## Territory above all: economy only when troops are too thin to spend.
  result = baseWeights
  result.name = "rush"
  result.expandBase = 74.0
  result.expandPoorPenalty = 34.0
  result.firstPort = 84.0
  result.firstCity = 76.0
  result.portBase = 50.0
  result.cityBase = 52.0
  result.factoryBase = 40.0
  result.allianceBase = 58.0

proc econWeights(): Weights =
  ## Buy the compounding structures early, expand with what is left.
  result = baseWeights
  result.name = "econ"
  result.firstPort = 110.0
  result.firstCity = 104.0
  result.portBase = 84.0
  result.cityBase = 86.0
  result.factoryBase = 70.0
  result.upgradeBase = 60.0
  result.buildDecay = 6.0

proc aggroWeights(): Weights =
  ## What the league replays actually show winning.
  ##
  ## Round 1219, Asia 12P: softmaxwell won with 887 996 tiles on a decision
  ## mix of 37 attacks / 1 build / 2 boats, and Jordan won the other episode
  ## with 928 697 tiles on 35 attacks / 2 builds / 3 boats — 25 of them
  ## hostile. Both games ended early because someone crossed the 80% win
  ## threshold, and six of twelve seats were wiped to zero tiles. Meanwhile
  ## the boat-heavy, alliance-heavy and target_player-heavy seats finished at
  ## the bottom, and djizus' pure neutral-expansion line (23 expansions, zero
  ## hostile attacks) still only reached 35 595 tiles.
  ##
  ## Winner takes 1.0 and everybody else takes their territory share, so the
  ## whole game is about being the seat that snowballs.
  result = baseWeights
  result.name = "aggro"
  result.attackBase = 92.0
  result.attackRatioGain = 18.0
  result.attackMinRatio = 0.9
  result.attackNeutralPenalty = 0.0
  result.attackWeakTargetBonus = 16.0
  result.attackSiegeBonus = 14.0
  result.expandBase = 74.0
  result.firstPort = 62.0
  result.firstCity = 66.0
  result.portBase = 40.0
  result.cityBase = 44.0
  result.factoryBase = 30.0
  result.upgradeBase = 34.0
  result.allianceBase = 8.0
  result.allianceExtend = 20.0
  result.allianceLateMalus = 0.0
  result.boatExpandBase = 30.0
  result.boatInvadeBase = 20.0

proc aggroTwoWeights(): Weights =
  ## `aggro` plus what the 17-replay aggregate adds on top of the two episodes
  ## that inspired it (105 seats, 14 winners, per-decision rates):
  ##
  ##   action            winners  middle   wiped
  ##   hostile attack      0.468   0.141   0.174
  ##   nuke                0.072   0.007   0.016
  ##   boat                0.190   0.255   0.237
  ##   build               0.076   0.101   0.110
  ##   alliance_request    0.018   0.057   0.069
  ##   hold                0.000   0.061   0.123
  ##   target_player       0.000   0.038   0.024
  ##   move_warship        0.002   0.060   0.041
  ##   avg troop %          23.5    21.8    20.6
  ##
  ## Winners nuke ten times as often as the middle of the table, which means
  ## the Missile Silo is worth its 1M gold; and they never hold, never mark
  ## targets, never retreat boats. Games end around turn 9 600–12 000, i.e.
  ## ~100–150 decisions rather than the 500 cap, so slow-compounding economy
  ## has much less time to pay back than the raw constants suggest.
  result = aggroWeights()
  result.name = "aggro2"
  result.nukeBase = 88.0
  result.siloBase = 52.0
  result.samBase = 8.0
  result.warshipBase = 4.0
  result.chatterBase = 0.2
  result.boatExpandBase = 34.0

proc aggroThreeWeights(): Weights =
  ## `aggro2` plus a survival floor. In the first hosted 12P sample our four
  ## seats were eliminated by turns 1 900–4 300 of a 10 100-turn game while
  ## every league bot outlived them, so raw aggression alone is not the whole
  ## answer: eight of twelve seats finish on zero tiles and a dead seat scores
  ## nothing at all. This arm keeps the aggressive action mix but pre-builds
  ## Defense Posts against a bigger neighbour and stops draining the pool
  ## below the regeneration optimum.
  result = aggroTwoWeights()
  result.name = "aggro3"
  result.defensePostBase = 44.0
  result.threatDefenseBonus = 40.0
  result.expandPoorRatio = 0.30
  result.expandPoorPenalty = 30.0

proc aggroFiveWeights(): Weights =
  ## The winner-take-all correction. Nine of the first ten measured episodes
  ## ended with somebody crossing the 80% threshold, and in those the adapter
  ## gives the winner 1.0 and *every other seat 0.0* — a large, safe,
  ## second-place empire scores exactly what being wiped out scores. So the
  ## defensive floor `aggro3` added is not worth its decisions: this arm keeps
  ## the pure snowball line and just adds concentration of force.
  result = aggroTwoWeights()
  result.name = "aggro5"
  result.targetStickiness = 22.0
  result.attackWeakTargetBonus = 20.0

proc phaseWeights(): Weights =
  ## The tempo evidence, over 216 seats and 18 winners in the downloaded
  ## league replays (`tools/replay_tempo.nim`):
  ##
  ##   median tiles at turn   500    1000    1500    2000    3000    6000
  ##   winners                443   14857   40713   80701  116533  244348
  ##   everyone else          431   14975   26319   31720   38632    3183
  ##
  ##   winners: first hostile attack at turn 2600, 27 expansions, 60 attacks
  ##   others:  first hostile attack at turn 1700, 14 expansions, 11 attacks
  ##
  ## Two things fall out. The opening is *not* where games are decided —
  ## through turn 1 000 the eventual winners are indistinguishable from the
  ## field. The split opens between turns 1 000 and 2 000. And winners attack
  ## players **later** than losers do, but roughly six times as much: they
  ## take free land until it runs out, then never stop pushing.
  ##
  ## So this profile does not race to fight. It keeps neutral expansion on top
  ## while it is still gaining tiles, and leans on the stall detector to flip
  ## it into permanent hostile pressure the moment the frontier closes.
  result = baseWeights
  result.name = "phase"
  result.expandBase = 76.0
  result.attackBase = 82.0
  result.attackRatioGain = 18.0
  result.attackMinRatio = 0.9
  result.attackNeutralPenalty = 34.0
  result.attackWeakTargetBonus = 18.0
  result.attackSiegeBonus = 14.0
  result.targetStickiness = 22.0
  result.firstPort = 64.0
  result.firstCity = 68.0
  result.portBase = 44.0
  result.cityBase = 48.0
  result.factoryBase = 32.0
  result.upgradeBase = 34.0
  result.nukeBase = 88.0
  result.siloBase = 52.0
  result.samBase = 8.0
  result.warshipBase = 4.0
  result.allianceBase = 10.0
  result.allianceExtend = 24.0
  result.allianceLateMalus = 0.0
  result.boatExpandBase = 34.0
  result.boatInvadeBase = 20.0
  result.chatterBase = 0.2

proc phaseTwoWeights(): Weights =
  ## `phase` plus the survival lesson from arm D (Pangaea 12P, 15 episodes):
  ##
  ##   proxywar-nim:v1  (alliances on, patient)   alive 15/15, 37 306 tiles
  ##   proxywar-base3   (alliances on, patient)   alive  5/15,  1 372 tiles
  ##   proxywar-aggro   (no alliances, fights early) alive 0/15, **0 tiles**
  ##
  ## The pure aggression line was wiped out in every single episode. Alliances
  ## are what let a seat grow unmolested through the turn 1 000–2 000 window
  ## where the game is actually decided — but they also cap the ceiling, and
  ## only a win scores, so they are dropped once the field has thinned.
  result = phaseWeights()
  result.name = "phase2"
  result.allianceBase = 48.0
  result.allianceExtend = 58.0
  result.allianceRepeatPenalty = 34.0
  result.allianceStrongBonus = 12.0
  result.allianceLateMalus = 55.0

proc phaseFiveWeights(): Weights =
  ## `phase` with an explicit early-fight floor. The tempo data has winners
  ## opening their first hostile attack at a median turn of 2 600 and losers
  ## at 1 700; the stall detector already produces that shape *when the
  ## frontier is genuinely open*, but on a crowded spawn it can close by turn
  ## 1 000 and drag us into a fight we are too small to win. This arm refuses
  ## to start one before turn 1 500 unless somebody has already started it.
  result = phaseWeights()
  result.name = "phase5"
  result.earlyAttackFloorTurn = 1500.0
  result.earlyAttackPenalty = 45.0

proc phaseSixWeights(): Weights =
  ## `phase` that always takes the biggest neutral slice until it has a real
  ## empire. The tempo curves separate between turns 1 000 and 2 000, and the
  ## regeneration optimum that governs the rest of the game is the wrong
  ## objective inside that window.
  result = phaseWeights()
  result.name = "phase6"
  result.landGrabTiles = 40_000.0

proc phaseSevenWeights(): Weights =
  ## `phase2` — the line that actually wins — with the land-grab window on top:
  ## always take the biggest neutral slice until there is a real empire.
  result = phaseTwoWeights()
  result.name = "phase7"
  result.landGrabTiles = 40_000.0

proc phaseEightWeights(): Weights =
  ## The map split says the two winning traits live in different profiles.
  ##
  ##   Asia    (n=88)  `phase2` alliances   30/88 = 0.341 [0.250, 0.445]
  ##   Pangaea (n=90)  `phase5` fight-floor 15/90 = 0.167 [0.104, 0.257]
  ##                   `phase2` not in the top seven
  ##
  ## Pangaea is one connected landmass, so contact comes early and starting a
  ## war before turn 1 500 is fatal; Asia is fragmented, so the early-fight
  ## floor rarely binds and what matters is buying the growth window with
  ## alliances. This profile takes both: ally through the window *and* refuse
  ## to open a war inside it.
  result = phaseTwoWeights()
  result.name = "phase8"
  result.earlyAttackFloorTurn = 1500.0
  result.earlyAttackPenalty = 45.0

proc phaseNineWeights(): Weights =
  ## `phase8` with the survival lever the P(win|alive) split identified.
  ##
  ##   policy            wins/198   alive   P(win | alive)
  ##   kutuzov:v3          26        36        0.722
  ##   kutuzov:v2          30        56        0.536
  ##   daveey-proxywar     28        98        0.286
  ##   captain-underpants  21        84        0.250
  ##   keystone            21        95        0.221
  ##
  ## Our line converts a surviving position into a win two to three times
  ## better than anything in the field and simply does not survive often
  ## enough. `phase5` at daveey's survival rate would win ~36% of episodes.
  ## So: hold a reserve against a visibly stronger neighbour rather than
  ## waiting for the invasion to register, and pre-build posts harder.
  result = phaseEightWeights()
  result.name = "phase9"
  result.threatReserve = 0.9
  result.threatDefenseBonus = 38.0
  result.defensePostBase = 36.0

proc phaseTenWeights(): Weights =
  ## Same axis as `phase5`, moved to where the evidence actually points.
  ##
  ## Across 41 replays the winners open their first hostile attack at a median
  ## turn of **2 400** and the rest of the field at 1 700. `phase5` set the
  ## floor at 1 500, and it has the best conversion of anything measured
  ## (P(win|alive) = 0.61–0.72 against the field's 0.19–0.30). This moves the
  ## floor to the winners' own median.
  result = phaseTwoWeights()
  result.name = "phase10"
  result.earlyAttackFloorTurn = 2400.0
  result.earlyAttackPenalty = 45.0

proc phaseElevenWeights(): Weights =
  ## Everything that has independently won a map, in one profile.
  ##
  ##   EastAsia / Pangaea  the fight-floor line (`phase5`) — 0.32 and 0.16
  ##   Asia                the alliance + land-grab line (`phase7`) — 0.26
  ##
  ## The two share the alliance and stall-decay machinery and differ in the
  ## fight-floor and the land-grab window, so this takes both: ally through the
  ## growth window, refuse to open a war inside it, and spend that window
  ## taking the biggest neutral slice on offer.
  result = phaseEightWeights()
  result.name = "phase11"
  result.landGrabTiles = 40_000.0

proc phaseTwelveWeights(): Weights =
  ## `phase11` plus the economy cadence the winner actually runs.
  ##
  ## In the clean episode we traced, daveey won with 28 attacks and **9
  ## builds** plus 2 upgrades out of 48 sampled decisions — about 19% economy.
  ## Our seat spent 2 of 26 on builds and never upgraded, built the largest
  ## empire on the board at turn 7 700, and then could not hold it. Each City
  ## is +250 000 max troops; territory without the capacity to garrison it is
  ## territory somebody else collects.
  result = phaseElevenWeights()
  result.name = "phase12"
  result.firstPort = 84.0
  result.firstCity = 88.0
  result.portBase = 66.0
  result.cityBase = 70.0
  result.factoryBase = 52.0
  result.upgradeBase = 56.0
  result.buildDecay = 5.0

proc phaseThirteenWeights(): Weights =
  ## Stop expanding into bankruptcy.
  ##
  ## Across 120 clean seats, ours peak at turn 1 900 and die at 3 300 while the
  ## field peaks at 4 100 and dies at 11 500 — 21 of our 30 deaths come after a
  ## real empire of 40 000+ tiles. We buy land with troops we then need to hold
  ## it, and the engine's regeneration peaks at a ratio of 0.42, so a seat
  ## sitting at 0.1 is both defenceless and slow to recover.
  ##
  ## The existing poor-ratio brake only engages below 0.20, which is already
  ## far past the point of no return. This raises it to 0.35 and makes it bite.
  result = phaseElevenWeights()
  result.name = "phase13"
  result.expandPoorRatio = 0.35
  result.expandPoorPenalty = 55.0
  result.threatReserve = 0.18

proc phaseFourteenWeights(): Weights =
  ## `phase11` plus the grind brake.
  ##
  ## The clean replays show our seat spending ~30 consecutive decisions on one
  ## rival — `attack:X:10`, `:25`, `:40` in rotation — while its own territory
  ## shrinks. Those are three distinct action ids, so the existing stall
  ## detector never saw a repeat. daveey hits a target twice at 40% and returns
  ## to free land.
  result = phaseElevenWeights()
  result.name = "phase14"
  result.grindPenalty = 60.0
  result.targetStickiness = 4.0

proc phaseFifteenWeights(): Weights =
  ## Only fight fights we win.
  ##
  ## `phase11` with the ratio requirement made unconditional and raised: a
  ## rival we are weaker than costs up to 80 points instead of being free once
  ## the neutral land is gone.
  result = phaseElevenWeights()
  result.name = "phase15"
  result.attackMinRatio = 1.3
  result.weakRatioPenalty = 130.0
  result.grindPenalty = 60.0
  result.targetStickiness = 4.0

proc phaseSixteenWeights(): Weights =
  ## Few fights, but fought properly.
  ##
  ## `phase15` fixed survival — 87 of 96 episodes alive — by refusing fights we
  ## are not clearly winning. It also stopped us growing: 54 000 tiles against
  ## daveey's 522 000. The missing half is commitment. Our attacks commit 25%
  ## because the 40% branch needed ratio > 2.0, while every war daveey actually
  ## gains ground with is a 40% order. A quarter of the pool is enough to lose
  ## troops and not enough to take the tiles they were spent on.
  result = phaseFifteenWeights()
  result.name = "phase16"
  result.fullCommitRatio = 1.25
  result.attackFractionPenalty = 46.0

proc phaseSeventeenWeights(): Weights =
  ## The gate, set where it stops losing fights without forbidding all of them.
  ##
  ## `phase15`/`phase16` require ratio >= 1.3 and survive 87-100% of episodes
  ## while winning almost nothing: 54 000 tiles against daveey's 522 000. The
  ## threshold is a one-way trap. We spend troops, so our ratio is low; the gate
  ## then forbids attacking; rivals keep taking ground and grow their own
  ## troops, so the ratio we need drifts further out of reach. A seat that never
  ## attacks never grows, and 1.3 is unreachable from behind.
  ##
  ## 1.05 keeps the property that mattered — the clean replays show us dying
  ## because we attacked rivals *stronger* than us the moment free land ran out
  ## — while letting us take ground from a neighbour we actually outmatch, at
  ## full commitment, which is what daveey does.
  result = phaseSixteenWeights()
  result.name = "phase17"
  result.attackMinRatio = 1.05
  result.fullCommitRatio = 1.05
  result.weakRatioPenalty = 130.0
  result.losingFightPenalty = 140.0

proc phaseEighteenWeights(): Weights =
  ## Counter the invasion instead of opportunistically opening another war.
  ##
  ## Across ten `phase17` replays, only 3 of our 196 hostile orders targeted
  ## an active invader, versus 45 of 299 for the winners. Their commitment
  ## also tracks the matchup: 10% below a 0.9 ratio, 25% near parity, and 40%
  ## above 1.2. This bias applies only during a real incoming attack, so a
  ## merely stronger border neighbour does not turn the policy into a turtle.
  result = phaseSeventeenWeights()
  result.name = "phase18"
  result.counterAttackBonus = 140.0
  result.invadedOffensePenalty = 25.0
  result.counterAttackFractionPenalty = 120.0

proc phaseNineteenWeights(): Weights =
  ## The counterattack experiment on the aggressive, pre-gate champion line.
  ##
  ## `phase18` went 0-83 while the current leaders won 25-33 times. Its own
  ## replays show only 19% hostile decisions against the winners' 21-33%: the
  ## ratio gate keeps it out of the war until an invasion is already terminal.
  ## This removes that confound by putting the same targeted counter response
  ## on `phase11`, the line before the unconditional ratio gate was added.
  result = phaseElevenWeights()
  result.name = "phase19"
  result.counterAttackBonus = 140.0
  result.invadedOffensePenalty = 25.0
  result.counterAttackFractionPenalty = 120.0

proc phaseTwentyWeights(): Weights =
  ## Match daveey's allocation without copying its weakest outcomes.
  ##
  ## Across 235 independent Competition appearances, daveey used hostile moves
  ## on 32.8% of decisions against `kutuzov:v29` at 54.6%, held 17.8% against
  ## 2.1%, and chained hostile-to-hostile decisions 15.2% against 37.7%. Its
  ## hostile commitments were 43% at 10%, versus our 19%; 68% of its builds
  ## were Cities, versus our 23%. These are episode-weighted differences, not
  ## the duplicated unseeded XP sample. This profile changes those mechanisms
  ## directly while preserving `phase11`'s opening and alliance behavior.
  result = phaseElevenWeights()
  result.name = "phase20"
  result.attackBase = 70.0
  result.probeAttackRatio = 1.15
  result.fullCommitRatio = 1.35
  result.hostileRepeatPenalty = 32.0
  result.targetStickiness = 4.0
  result.grindPenalty = 80.0
  result.firstCity = 88.0
  result.cityBase = 72.0
  result.buildDecay = 5.0
  result.upgradeBase = 70.0
  result.defensePostBase = 8.0
  result.threatDefenseBonus = 8.0
  result.siloBase = 4.0
  result.nukeBase = 20.0
  result.boatExpandBase = 46.0
  result.boatInvadeBase = 28.0
  result.boatDesiredFraction = 0.16
  result.holdBase = 3.0
  result.holdRecoveryBonus = 80.0

proc phaseTwentyOneWeights(): Weights =
  ## Correct the allocation imitation for the four-player XP regime.
  ##
  ## In 48 balanced games, daveey attacked on 49.0% of decisions and chained
  ## attacks 36.0% of the time. `phase20` reached only 25.9% and 13.9%, while
  ## spending 18.9% on boats and 10.9% on builds. It tied daveey 12-12 on Asia
  ## but lost all 24 Pangaea games. These modifiers engage only with at most
  ## three live rivals, preserving the measured large-field allocation.
  result = phaseTwentyWeights()
  result.name = "phase21"
  result.smallFieldAttackBonus = 20.0
  result.smallFieldRepeatScale = 0.15
  result.smallFieldProbeFirst = true
  result.fullCommitRatio = 1.55
  result.urgentFullCommit = 1.15
  result.smallFieldBoatFraction = 0.205
  result.smallFieldBoatPenalty = 20.0
  result.smallFieldDefensePostPenalty = 90.0
  result.smallFieldAlliancePenalty = 70.0
  result.earlyAttackPenalty = 25.0
  result.firstCity = 68.0
  result.cityBase = 48.0
  result.buildDecay = 9.0
  result.upgradeBase = 34.0

proc phaseTwentyTwoWeights(): Weights =
  ## Keep taking full neutral slices and remove excess small-field economy.
  ##
  ## Across the balanced `v42` and `v43` games, daveey used 35% for 92-96%
  ## of Pangaea expansions and never used 10%. Our policies used 35% for only
  ## 56-65% because an action-specific stall penalty rotated a blocked 35%
  ## frontier down to 20% and 10%. The global frontier stall already makes
  ## all expansions yield to another move, so the per-size penalty is both
  ## redundant and behaviorally wrong in a small field.
  result = phaseTwentyOneWeights()
  result.name = "phase22"
  result.smallFieldExpandFraction = 0.35
  result.smallFieldExpansionStallScale = 0.0
  result.smallFieldNonCityBuildPenalty = 35.0
  result.smallFieldCollapseBuildPenalty = 60.0
  result.smallFieldBoatPenalty = 30.0

proc phaseTwentyThreeWeights(): Weights =
  ## Rank hostile targets using replay-derived opponent priors.
  ##
  ## This is isolated on the active `phase19` champion line. The adjustment is
  ## centered across all currently attackable rivals, so it changes target
  ## selection without globally rewarding hostile actions. Current behavior
  ## still wins: an active invader and the live troop ratio enter the prior
  ## score, while an unknown name receives the field-average prior.
  result = phaseNineteenWeights()
  result.name = "phase23"
  result.opponentPriorScale = 1.0

proc phaseTwentyFourWeights(): Weights =
  ## Match large-field cadence and avoid opening wars with named predators.
  ##
  ## Phase23's 100 Pangaea games won twice while daveey won fourteen.
  ## Request-only replays show 77% hostile choices and 67% hostile chaining,
  ## versus daveey's 39% and 23%. Phase20 already isolates the lower-chaining
  ## large-field cadence. This centered adjustment prefers low-win,
  ## low-persistence rivals, but strongly answers an active invader.
  result = phaseTwentyWeights()
  result.name = "phase24"
  result.opponentAvoidScale = 5.0

proc phaseTwentyFiveWeights(): Weights =
  ## Delay only unprovoked opening wars to daveey's measured first-attack time.
  ##
  ## Across 199 controlled large-field replays, phase24 used hostile actions
  ## for 52.5% of its decisions before turn 2,000 versus daveey's 26.4%.
  ## Their median first hostile turns were 1,900 and 2,700. This experiment
  ## changes only the opening timing gate; active invaders remain exempt.
  result = phaseTwentyFourWeights()
  result.name = "phase25"
  result.earlyAttackFloorTurn = 2_700.0
  result.earlyAttackPenalty = 45.0

proc phaseTwentySixWeights(): Weights =
  ## Use daveey's full neutral expansion in small fields.
  ##
  ## On the deterministic two-player conversion board, phase24 used 20% for
  ## 68.8% of its neutral expansions and 35% for 31.2%. Daveey favored 35%.
  ## This experiment changes only the desired small-field expansion fraction.
  result = phaseTwentyFourWeights()
  result.name = "phase26"
  result.smallFieldExpandFraction = 0.35

proc phaseTwentySevenWeights(): Weights =
  ## Prefer neutral territory over a marginal war without delaying all attacks.
  ##
  ## Phase24 expands less often than daveey in both the sixteen-player opening
  ## and the deterministic two-player conversion board. This changes only the
  ## base score of an offered neutral expansion.
  result = phaseTwentyFourWeights()
  result.name = "phase27"
  result.expandBase = 78.0

proc phaseTwentyEightWeights(): Weights =
  ## Preserve the proven opening and prefer neutral land during conversion.
  ##
  ## Phase27's global bonus regressed only the favorable opening seat. This
  ## applies the same isolated expansion score after that 1,500-turn assay.
  result = phaseTwentyFourWeights()
  result.name = "phase28"
  result.conversionExpandBonus = 16.0
  result.conversionExpandFloorTurn = 1_500.0

proc phaseTwentyNineWeights(): Weights =
  ## Preserve every observed decision in the 60-step opening assay.
  ##
  ## Spawn setup shifts the final observation turn to 1,800 rather than the
  ## nominal 1,500. The conversion bonus begins only after that audited turn.
  result = phaseTwentyFourWeights()
  result.name = "phase29"
  result.conversionExpandBonus = 16.0
  result.conversionExpandFloorTurn = 1_800.0

proc phaseThirtyWeights(): Weights =
  ## Commit enough troops to post-opening neutral expansion.
  ##
  ## After turn 1,800, phase24 used 20% on five of six expansions while
  ## daveey used 35% on nine of thirteen. Action scores remain unchanged.
  result = phaseTwentyFourWeights()
  result.name = "phase30"
  result.conversionExpandFraction = 0.35
  result.conversionExpandFloorTurn = 1_800.0

proc phaseThirtyOneWeights(): Weights =
  ## Fight the active invader instead of boating during conversion.
  ##
  ## The baseline log boats while two to four attacks are incoming. This adds
  ## target priority only after the audited opening and keeps commitment logic.
  result = phaseTwentyFourWeights()
  result.name = "phase31"
  result.counterAttackBonus = 45.0
  result.counterAttackFloorTurn = 1_800.0

proc phaseThirtyTwoWeights(): Weights =
  ## Test a stronger point on the conversion counterattack dose curve.
  ##
  ## Phase31 improved the mirrored endpoint but one seat remained in a boat
  ## loop while invaded. This changes only the post-opening bonus from 45 to 90.
  result = phaseTwentyFourWeights()
  result.name = "phase32"
  result.counterAttackBonus = 90.0
  result.counterAttackFloorTurn = 1_800.0

proc phaseThirtyThreeWeights(): Weights =
  ## Spend the large-field opening on free land, not unprovoked wars.
  ##
  ## In the valid v54 16P field, the candidate expanded on 46% and attacked on
  ## 50% of opening decisions, versus daveey at 64% and 26%. The old phase25
  ## timing experiment was rejected on a two-player board. This version keeps
  ## v54 exactly unchanged with three or fewer rivals and delays only
  ## unprovoked large-field attacks.
  result = phaseThirtyTwoWeights()
  result.name = "phase33"
  result.earlyAttackFloorTurn = 2_700.0
  result.earlyAttackPenalty = 45.0
  result.earlyAttackMinRivals = 4

proc phaseThirtyFourWeights(): Weights =
  ## Delay marginal opening wars while taking an overwhelming matchup.
  ##
  ## In the final 199-replay v55 audit, winners aimed 82.9% of hostile orders
  ## at smaller-territory rivals and 66.6% at weaker-troop rivals. Surviving
  ## losses reached only 56.6% and 46.4%. Phase33 penalizes even a 3.2:1
  ## matchup before turn 2,700, so it discards the profitable tail along with
  ## the marginal wars it was built to prevent. This changes only that tail.
  result = phaseThirtyThreeWeights()
  result.name = "phase34"
  result.earlyAttackExemptRatio = 1.8

proc phaseThirtyFiveWeights(): Weights =
  ## Convert a leading position instead of continuing economic development.
  ##
  ## At 10-20% territory, v55 winners spent 81% of decisions on ground and
  ## 14% on economy, versus surviving losses at 69% and 27%. At 20%+, the
  ## split widened to 91%/8% versus 68%/23%. The existing closing suppression
  ## begins only at 35%, after most failed conversion opportunities. This
  ## changes only that state threshold and starts it at 10% territory.
  result = phaseThirtyThreeWeights()
  result.name = "phase35"
  result.conversionShare = 0.10
  result.conversionPenalty = 45.0

proc phaseThirtySixWeights(): Weights =
  ## Apply a smaller dose of the proven conversion mechanism.
  ##
  ## Phase35 moved conversion ground-taking by +8.35 points and economy by
  ## -6.44, but moved territory share by -3.09 points. It nearly eliminated
  ## economy instead of matching the winners' smaller allocation. This keeps
  ## the same 10% state boundary and reduces only the new penalty from 45 to
  ## 15, while preserving v55's 30-point closing pressure above 35%.
  result = phaseThirtyThreeWeights()
  result.name = "phase36"
  result.conversionShare = 0.10
  result.conversionPenalty = 15.0

proc phaseThirtySevenWeights(): Weights =
  ## Reserve the mild conversion pressure for established positions.
  ##
  ## Phase36 produced the intended mild action shift, +3.03 points of ground
  ## and -3.46 points of economy, but territory still moved -2.08 points.
  ## The replay association is much sharper at 20% territory, where winners
  ## use 91% ground versus surviving losses at 68%. This retains the proven
  ## 15-point dose and moves only its state boundary from 10% to 20%.
  result = phaseThirtyThreeWeights()
  result.name = "phase37"
  result.conversionShare = 0.20
  result.conversionPenalty = 15.0

proc phaseThirtyEightWeights(): Weights =
  ## Stop the reproducible Black Sea dogpile counterattack collapse.
  ##
  ## In all five live round-1383 games, spawn tile 87062 peaked near 75,000
  ## tiles and then used hostile attacks for 37 of 39 decisions with two or
  ## more attacks incoming. This preserves phase33 everywhere else and engages
  ## the old self-releasing collapse response only in that exact state.
  result = phaseThirtyThreeWeights()
  result.name = "phase38"
  result.collapseDefense = 220.0
  result.collapseDefenseSpawnTile = 87062
  result.collapseDefenseMinIncoming = 2

proc phaseThirtyNineWeights(): Weights =
  ## Generalize the validated dogpile response across runtime positions.
  ##
  ## Phase38 improved the preregistered Black Sea cell by +23 win-rate points
  ## [7.6, 37.0]. East Asia and Pangaea logs show the same hostile response
  ## under pressure. Keep both causal state gates and remove only the tile gate.
  result = phaseThirtyEightWeights()
  result.name = "phase39"
  result.collapseDefenseSpawnTile = -1

proc openingOneWeights(): Weights =
  ## Test daveey's full-dose opening at the weak Pangaea spawn 188728.
  ##
  ## V55 wins 7 of 70 observations from this cell while daveey wins 28 of 66.
  ## Daveey's dominant sequence starts with three 35% neutral expansions;
  ## v55 starts 20%, 35%, 35%. This changes only the troop fraction of the
  ## first three accepted neutral expansions at that exact runtime spawn.
  result = phaseThirtyThreeWeights()
  result.name = "opening1"
  result.openingExpandSpawnTile = 188728
  result.openingExpandCount = 3
  result.openingExpandFraction = 0.35
  result.openingExpandEndTurn = 2_700.0

proc openingBookOneWeights(): Weights =
  ## Run the measured five-step recipe for every known rotation position.
  result = phaseThirtyThreeWeights()
  result.name = "openingBook1"
  result.openingBookScope = openingAll

proc openingSoftBookOneWeights(): Weights =
  ## Generalize the validated soft three-expansion dose to known starts.
  result = phaseThirtyThreeWeights()
  result.name = "openingSoftBook1"
  result.openingExpandKnownStarts = true
  result.openingExpandCount = 3
  result.openingExpandFraction = 0.35
  result.openingExpandEndTurn = 2_700.0

proc contactBookOneWeights(): Weights =
  ## Add the contact-optimized position book to the current v63 control.
  result = openingSoftBookOneWeights()
  result.name = "contactBook1"
  result.openingBookScope = openingAll

proc contactWinnersOneWeights(): Weights =
  ## Script only the 33 material contact winners over the v63 control.
  result = openingSoftBookOneWeights()
  result.name = "contactWinners1"
  result.openingBookScope = openingOptimized

proc openingSoftOceaniaWeights(): Weights =
  ## Add the verified hard script only on known Oceania starts.
  result = openingSoftBookOneWeights()
  result.name = "openingSoftOceania"
  result.openingBookScope = openingOceania

proc openingSoftBlackSeaWeights(): Weights =
  ## Add the verified hard script only on known Black Sea starts.
  result = openingSoftBookOneWeights()
  result.name = "openingSoftBlackSea"
  result.openingBookScope = openingBlackSea

proc openingSoftWaterWeights(): Weights =
  ## Combine the two isolated water-map scripted opening scopes.
  result = openingSoftBookOneWeights()
  result.name = "openingSoftWater"
  result.openingBookScope = openingWater

proc openingSoftNoAllianceWeights(): Weights =
  ## Preserve v63 while preventing repeated low-value alliance detours.
  result = openingSoftBookOneWeights()
  result.name = "openingSoftNoAlliance"
  result.allianceBase = 8.0
  result.allianceBorderBonus = 0.0
  result.allianceStrongBonus = 0.0
  result.allianceExtend = 16.0

proc openingSoftPreyWeights(): Weights =
  ## Preserve v63 while concentrating attacks on dynamically weaker rivals.
  result = openingSoftBookOneWeights()
  result.name = "openingSoftPrey"
  result.attackRatioGain = 34.0
  result.attackWeakTargetBonus = 28.0
  result.losingFightPenalty = 100.0
  result.fullCommitRatio = 1.20

proc openingSoftMattAvoidWeights(): Weights =
  ## Avoid starting a marginal war with Matt while retaining counterattacks.
  result = openingSoftBookOneWeights()
  result.name = "openingSoftMattAvoid"
  result.mattAttackPenalty = 80.0

proc openingSoftLeadCommitWeights(): Weights =
  ## Commit fully only when an established position attacks a weaker rival.
  result = openingSoftBookOneWeights()
  result.name = "openingSoftLeadCommit"
  result.leadFullCommitShare = 0.10
  result.leadFullCommitRatio = 1.0

proc openingSoftLeadPreyWeights(): Weights =
  ## Prefer favorable targets before the proven lead-conversion state.
  result = openingSoftLeadCommitWeights()
  result.name = "openingSoftLeadPrey"
  result.preLeadTargetShare = 0.10
  result.preLeadAttackRatioGain = 16.0

proc openingSoftLeadDefenseWeights(): Weights =
  ## Add the validated dogpile defense to the lead-commitment branch.
  result = openingSoftLeadCommitWeights()
  result.name = "openingSoftLeadDefense"
  result.collapseDefense = 220.0
  result.collapseDefenseSpawnTile = -1
  result.collapseDefenseMinIncoming = 2

proc openingSoftMapDefenseWeights(): Weights =
  ## Retain the validated dogpile defense only on Black Sea starts.
  result = openingSoftLeadCommitWeights()
  result.name = "openingSoftMapDefense"
  result.collapseDefense = 220.0
  result.collapseDefenseSpawnTile = -1
  result.collapseDefenseScope = openingBlackSea
  result.collapseDefenseMinIncoming = 2

proc openingSoftMapTargetWeights(): Weights =
  ## Rerank an already-selected Pangaea attack toward the weaker rival.
  result = openingSoftMapDefenseWeights()
  result.name = "openingSoftMapTarget"
  result.targetRerankScope = openingPangaea
  result.targetRerankRatioGain = 16.0

proc openingSoftMapTargetStrongWeights(): Weights =
  ## Strongly rerank quiet Pangaea attacks toward the weaker rival.
  result = openingSoftMapDefenseWeights()
  result.name = "openingSoftMapTargetStrong"
  result.targetRerankScope = openingPangaea
  result.targetRerankRatioGain = 200.0
  result.targetRerankPeaceOnly = true

proc openingSoftMapPressureWeights(): Weights =
  ## Deflect only losing Pangaea counterattacks into local defence.
  result = openingSoftMapTargetStrongWeights()
  result.name = "openingSoftMapPressure"
  result.pressureDeflectScope = openingPangaea
  result.pressureDeflectMinRatio = 0.80

proc openingSoftSpawnBoomWeights(): Weights =
  ## Delay war and prefer investment at the defective Pangaea start.
  result = openingSoftLeadCommitWeights()
  result.name = "openingSoftSpawnBoom"
  result.spawnBoomTile = 188728
  result.spawnBoomEndTurn = 5_000.0
  result.spawnBoomDose = 20.0

proc openingSoftSpawnBoomStrongWeights(): Weights =
  ## Test a stronger point on the same isolated conversion dose curve.
  result = openingSoftSpawnBoomWeights()
  result.name = "openingSoftSpawnBoomStrong"
  result.spawnBoomDose = 40.0

proc openingSoftLandBuildWeights(): Weights =
  ## Convert at most two quiet land-map decisions into early construction.
  result = openingSoftSpawnBoomStrongWeights()
  result.name = "openingSoftLandBuild"
  result.quietBuildEndTurn = 6_000.0
  result.quietBuildMargin = 20.0
  result.quietBuildCount = 2

proc openingSoftLandBuildForcedWeights(): Weights =
  ## Force at most two safe idle land-map decisions into construction.
  result = openingSoftSpawnBoomStrongWeights()
  result.name = "openingSoftLandBuildForced"
  result.quietBuildEndTurn = 12_000.0
  result.quietBuildMargin = 1_000_000.0
  result.quietBuildCount = 2

proc openingSoftLandBuildWeakAttackWeights(): Weights =
  ## Convert at most two safe early peer attacks into construction.
  result = openingSoftSpawnBoomStrongWeights()
  result.name = "openingSoftLandBuildWeakAttack"
  result.quietBuildEndTurn = 6_000.0
  result.quietBuildMargin = 1_000_000.0
  result.quietBuildCount = 2
  result.quietBuildAttackRatio = 1.05

proc openingSoftPangaeaPeaceWeights(): Weights =
  ## Strongly delay only marginal, unprovoked Pangaea opening wars.
  result = openingSoftSpawnBoomStrongWeights()
  result.name = "openingSoftPangaeaPeace"
  result.earlyAttackPenalty = 80.0
  result.earlyAttackMinRivals = 3
  result.earlyAttackExemptRatio = 1.8
  result.earlyAttackScope = openingPangaea

proc openingSoftPangaeaPeaceEconomyBatchWeights(): Weights =
  ## Append one safe economic build after a compatible territory action.
  result = openingSoftPangaeaPeaceWeights()
  result.name = "openingSoftPangaeaPeaceEconomyBatch"
  result.economyBatchCount = 1

proc openingSoftPangaeaPeaceEconomyBatchGroundWeights(): Weights =
  ## Keep V98's economy companion, and spend the unused batch slot on land
  ## once the 80% wipeout is in reach. Batches run round-robin by layer, so a
  ## second attack or expansion after the scalar primary is unopposed if the
  ## field is still sending one action. V98 currently returns at closingShare
  ## and fights the winner-take-all chase with a scalar menu.
  result = openingSoftPangaeaPeaceEconomyBatchWeights()
  result.name = "openingSoftPangaeaPeaceEconomyBatchGround"
  result.closingGroundBatch = true

proc openingSoftPangaeaPeaceEconomyBatchTwoWeights(): Weights =
  ## Append a second funded build after the proven economy companion.
  result = openingSoftPangaeaPeaceEconomyBatchWeights()
  result.name = "openingSoftPangaeaPeaceEconomyBatchTwo"
  result.economyBatchCount = 2

proc openingSoftPangaeaPeaceEconomyBatchChatWeights(): Weights =
  ## Add bounded border chat without changing v98's gameplay decisions.
  result = openingSoftPangaeaPeaceEconomyBatchWeights()
  result.name = "openingSoftPangaeaPeaceEconomyBatchChat"
  result.borderChat = true

proc openingSoftPangaeaPeaceEconomyBatchDealsWeights(): Weights =
  ## Add structured border pacts without enabling free-form chat.
  result = openingSoftPangaeaPeaceEconomyBatchWeights()
  result.name = "openingSoftPangaeaPeaceEconomyBatchDeals"
  result.structuredDeals = true

proc openingSoftPangaeaPeaceEconomyBatchSpatialWeights(): Weights =
  ## Distinguish active land fronts from non-front incoming pressure.
  result = openingSoftPangaeaPeaceEconomyBatchWeights()
  result.name = "openingSoftPangaeaPeaceEconomyBatchSpatial"
  result.spatialLandDefense = true

proc openingSoftMattPositionsWeights(): Weights =
  ## Add exact, accepted-cadence openings only at replicated Pangaea starts.
  result = openingSoftPangaeaPeaceWeights()
  result.name = "openingSoftMattPositions"
  result.mattPositionOpening = true

proc openingSoftPangaeaBoomWeights(): Weights =
  ## Generalize the replicated mild conversion dose to Pangaea starts.
  result = openingSoftLeadCommitWeights()
  result.name = "openingSoftPangaeaBoom"
  result.spawnBoomScope = openingPangaea
  result.spawnBoomEndTurn = 5_000.0
  result.spawnBoomDose = 20.0

proc openingSoftPangaeaFiveLandWeights(): Weights =
  ## Reproduce Matt's five-land opening at the validated Pangaea start.
  result = openingSoftPangaeaBoomWeights()
  result.name = "openingSoftPangaeaFiveLand"
  result.forcedLandSpawnTile = 376534
  result.forcedLandCount = 5
  result.forcedLandFraction = 0.35
  result.forcedLandEndTurn = 2_700.0

proc openingSoftPangaeaAcceptedFiveLandWeights(): Weights =
  ## Count game-confirmed expansions rather than attempted decision responses.
  result = openingSoftPangaeaFiveLandWeights()
  result.name = "openingSoftPangaeaAcceptedFiveLand"
  result.forcedLandEndTurn = 6_700.0

proc openingSoftConversionWeights(): Weights =
  ## Combine the isolated alliance and prey-selection conversion mechanisms.
  result = openingSoftPreyWeights()
  result.name = "openingSoftConversion"
  result.allianceBase = 8.0
  result.allianceBorderBonus = 0.0
  result.allianceStrongBonus = 0.0
  result.allianceExtend = 16.0

proc waterPortsWeights(): Weights =
  ## Test Matt's Port-heavy allocation only on verified water-map starts.
  result = openingSoftBookOneWeights()
  result.name = "waterPorts"
  result.waterPortBonus = 60.0

proc waterTargetsWeights(): Weights =
  ## Test Matt's stronger-target avoidance only on verified water-map starts.
  result = openingSoftBookOneWeights()
  result.name = "waterTargets"
  result.waterStrongTargetPenalty = 45.0

proc waterConversionWeights(): Weights =
  ## Combine the two isolated water-map conversion mechanisms.
  result = waterPortsWeights()
  result.name = "waterConversion"
  result.waterStrongTargetPenalty = 45.0

proc oceaniaNoAllianceWeights(): Weights =
  ## Test the shared winner pattern only on verified Oceania starts.
  result = openingSoftBookOneWeights()
  result.name = "oceaniaNoAlliance"
  result.oceaniaAlliancePenalty = 80.0

proc oceaniaCommitWeights(): Weights =
  ## Test Matt's full-commit allocation only on verified Oceania starts.
  result = openingSoftBookOneWeights()
  result.name = "oceaniaCommit"
  result.oceaniaFullCommitRatio = 1.0

proc oceaniaConversionWeights(): Weights =
  ## Combine the two independently positive Oceania mechanisms.
  result = oceaniaCommitWeights()
  result.name = "oceaniaConversion"
  result.oceaniaAlliancePenalty = 80.0

proc diploWeights(): Weights =
  ## Alliances are free protection and +40% trade gold in a 12-player FFA.
  result = baseWeights
  result.name = "diplo"
  result.allianceBase = 92.0
  result.allianceRepeatPenalty = 28.0
  result.allianceExtend = 80.0
  result.allianceLateMalus = 25.0
  result.attackNeutralPenalty = 30.0

proc profileWeights*(name: string): Weights =
  case name.toLowerAscii()
  of "rush": rushWeights()
  of "econ": econWeights()
  of "diplo": diploWeights()
  of "aggro": aggroWeights()
  of "aggro2": aggroTwoWeights()
  of "aggro3": aggroThreeWeights()
  of "aggro5": aggroFiveWeights()
  of "phase": phaseWeights()
  of "phase2": phaseTwoWeights()
  of "phase5": phaseFiveWeights()
  of "phase6": phaseSixWeights()
  of "phase7": phaseSevenWeights()
  of "phase8": phaseEightWeights()
  of "phase10": phaseTenWeights()
  of "phase11": phaseElevenWeights()
  of "phase12": phaseTwelveWeights()
  of "phase13": phaseThirteenWeights()
  of "phase14": phaseFourteenWeights()
  of "phase15": phaseFifteenWeights()
  of "phase16": phaseSixteenWeights()
  of "phase17": phaseSeventeenWeights()
  of "phase18": phaseEighteenWeights()
  of "phase19": phaseNineteenWeights()
  of "phase20": phaseTwentyWeights()
  of "phase21": phaseTwentyOneWeights()
  of "phase22": phaseTwentyTwoWeights()
  of "phase23": phaseTwentyThreeWeights()
  of "phase24": phaseTwentyFourWeights()
  of "phase25": phaseTwentyFiveWeights()
  of "phase26": phaseTwentySixWeights()
  of "phase27": phaseTwentySevenWeights()
  of "phase28": phaseTwentyEightWeights()
  of "phase29": phaseTwentyNineWeights()
  of "phase30": phaseThirtyWeights()
  of "phase31": phaseThirtyOneWeights()
  of "phase32": phaseThirtyTwoWeights()
  of "phase33": phaseThirtyThreeWeights()
  of "phase34": phaseThirtyFourWeights()
  of "phase35": phaseThirtyFiveWeights()
  of "phase36": phaseThirtySixWeights()
  of "phase37": phaseThirtySevenWeights()
  of "phase38": phaseThirtyEightWeights()
  of "phase39": phaseThirtyNineWeights()
  of "opening1": openingOneWeights()
  of "openingbook1": openingBookOneWeights()
  of "openingsoftbook1": openingSoftBookOneWeights()
  of "contactbook1": contactBookOneWeights()
  of "contactwinners1": contactWinnersOneWeights()
  of "openingsoftoceania": openingSoftOceaniaWeights()
  of "openingsoftblacksea": openingSoftBlackSeaWeights()
  of "openingsoftwater": openingSoftWaterWeights()
  of "openingsoftnoalliance": openingSoftNoAllianceWeights()
  of "openingsoftprey": openingSoftPreyWeights()
  of "openingsoftmattavoid": openingSoftMattAvoidWeights()
  of "openingsoftleadcommit": openingSoftLeadCommitWeights()
  of "openingsoftleadprey": openingSoftLeadPreyWeights()
  of "openingsoftleaddefense": openingSoftLeadDefenseWeights()
  of "openingsoftmapdefense": openingSoftMapDefenseWeights()
  of "openingsoftmaptarget": openingSoftMapTargetWeights()
  of "openingsoftmaptargetstrong": openingSoftMapTargetStrongWeights()
  of "openingsoftmappressure": openingSoftMapPressureWeights()
  of "openingsoftspawnboom": openingSoftSpawnBoomWeights()
  of "openingsoftspawnboomstrong": openingSoftSpawnBoomStrongWeights()
  of "openingsoftlandbuild": openingSoftLandBuildWeights()
  of "openingsoftlandbuildforced": openingSoftLandBuildForcedWeights()
  of "openingsoftlandbuildweakattack":
    openingSoftLandBuildWeakAttackWeights()
  of "openingsoftpangaeapeace": openingSoftPangaeaPeaceWeights()
  of "openingsoftpangaeapeaceeconomybatch":
    openingSoftPangaeaPeaceEconomyBatchWeights()
  of "openingsoftpangaeapeaceeconomybatchground":
    openingSoftPangaeaPeaceEconomyBatchGroundWeights()
  of "openingsoftpangaeapeaceeconomybatchtwo":
    openingSoftPangaeaPeaceEconomyBatchTwoWeights()
  of "openingsoftpangaeapeaceeconomybatchchat":
    openingSoftPangaeaPeaceEconomyBatchChatWeights()
  of "openingsoftpangaeapeaceeconomybatchdeals":
    openingSoftPangaeaPeaceEconomyBatchDealsWeights()
  of "openingsoftpangaeapeaceeconomybatchspatial":
    openingSoftPangaeaPeaceEconomyBatchSpatialWeights()
  of "openingsoftmattpositions": openingSoftMattPositionsWeights()
  of "openingsoftpangaeaboom": openingSoftPangaeaBoomWeights()
  of "openingsoftpangaeafiveland": openingSoftPangaeaFiveLandWeights()
  of "openingsoftpangaeaacceptedfiveland":
    openingSoftPangaeaAcceptedFiveLandWeights()
  of "openingsoftconversion": openingSoftConversionWeights()
  of "waterports": waterPortsWeights()
  of "watertargets": waterTargetsWeights()
  of "waterconversion": waterConversionWeights()
  of "oceanianoalliance": oceaniaNoAllianceWeights()
  of "oceaniacommit": oceaniaCommitWeights()
  of "oceaniaconversion": oceaniaConversionWeights()
  of "phase9": phaseNineWeights()
  else: baseWeights

proc weightsFromEnvironment*(): Weights =
  ## `--profile=<name>` on argv wins over PROXYWAR_PROFILE so one uploaded
  ## image can host every A/B arm through upload-policy's `--run` argv.
  for index in 1 .. paramCount():
    let argument = paramStr(index)
    if argument.startsWith("--profile="):
      return profileWeights(argument[10 .. ^1])
  profileWeights(getEnv("PROXYWAR_PROFILE", "base"))

proc metaFloat(action: Action, key: string, fallback = 0.0): float =
  getFloat(action.meta, key, fallback)

proc metaStr(action: Action, key: string, fallback = ""): string =
  getStr(action.meta, key, fallback)

proc metaBool(action: Action, key: string, fallback = false): bool =
  getBool(action.meta, key, fallback)

proc grinding*(memory: Memory, world: Observation, targetID: string): bool =
  ## Six or more orders against one rival with no net territory to show for it.
  if targetID.len == 0: return false
  let spent = memory.targetGrind.getOrDefault(targetID)
  if spent < 6: return false
  let started = memory.targetStartTiles.getOrDefault(targetID, 0.0)
  world.ownTiles <= started * 1.05

proc collapsing*(memory: Memory, world: Observation): bool =
  ## Two consecutive losing decisions, and nothing else.
  ##
  ## The old second clause — one loss while 10% off the peak — fired in nearly
  ## every game, because a seat is below its own peak for most of the match.
  ## Combined with a streak that only a gain could clear, it was a one-way
  ## latch into turtling.
  memory.losingStreak >= 2

proc collapseDefenseValue(weights: Weights, world: Observation,
    memory: Memory): float =
  ## Return the collapse response dose when every configured gate is active.
  if weights.collapseDefense <= 0.0 or not collapsing(memory, world):
    return 0.0
  if weights.collapseDefenseSpawnTile >= 0 and
      world.spawnTile != weights.collapseDefenseSpawnTile:
    return 0.0
  if weights.collapseDefenseScope != openingNone and
      not openingApplies(weights.collapseDefenseScope, world.spawnTile):
    return 0.0
  if world.incomingAttacks < weights.collapseDefenseMinIncoming:
    return 0.0
  weights.collapseDefense

proc collapseDefenseActive*(weights: Weights, world: Observation,
    memory: Memory): bool =
  ## Return whether the configured collapse response is active now.
  collapseDefenseValue(weights, world, memory) > 0.0

proc spawnBoomActive*(weights: Weights, world: Observation): bool =
  ## Return whether the isolated quiet economic window is active now.
  let spawnMatches =
    (weights.spawnBoomTile >= 0 and
      world.spawnTile == weights.spawnBoomTile) or
    (weights.spawnBoomScope != openingNone and
      openingApplies(weights.spawnBoomScope, world.spawnTile))
  weights.spawnBoomDose > 0.0 and spawnMatches and
    world.turnNumber.float <= weights.spawnBoomEndTurn and
    world.incomingAttacks == 0 and
    world.strategicPriority != "build_defense"

proc spendUrgency*(world: Observation, reserveAgainstThreat = 0.0,
    underCollapse = false): float =
  ## How badly idle troops need to be converted into territory.
  ##
  ## Regeneration is `(10 + troops^0.73/4) * (1 - troops/maxTroops)`: it stops
  ## dead at the cap and peaks near 0.42 of it. Sitting at ratio 1.0 — which
  ## the first self-play corpus did for a dozen decisions — throws away the
  ## entire troop economy, so anything that spends troops gets a bonus that
  ## grows with the overflow.
  result = clamp((world.troopRatio - growthOptimalRatio) / 0.35, 0.0, 1.6)
  ## Troops left at home are the only real defence in this engine, so a seat
  ## that is actually being invaded stops dumping its pool abroad.
  if underCollapse:
    ## Every troop sent abroad is a troop not defending the border that is
    ## actively being pushed in.
    result *= 0.05
  elif world.homeDanger == "high" or world.incomingAttacks > 0:
    result *= 0.35
  elif reserveAgainstThreat > 0.0:
    ## Waiting for the invasion is waiting too late. Our policies convert
    ## survival into wins far better than the field — 0.72 for `phase5` and
    ## 0.54 for `phase2` against 0.19–0.29 for every field bot — while
    ## surviving only 18–28% of episodes against their 41–49%. Survival is
    ## therefore worth more than any further aggression, so an empty pool
    ## next to a visibly stronger neighbour is the thing to avoid.
    let threat = strongestBorderThreat(world)
    if threat > 1.3:
      result *= clamp(1.0 - reserveAgainstThreat * (threat - 1.3), 0.25, 1.0)

proc smallField(world: Observation): bool =
  ## Four-player XP and late endgames need a more direct allocation.
  world.aliveRivals <= 3

proc priorTargetValue(world: Observation, rival: Rival): float =
  ## Score one rival from its field-specific history and current behavior.
  let
    ratio = max(rival.relativeTroopRatio, 0.01)
    countering = rival.incomingAttack and world.incomingAttacks > 0
    prior = opponentPrior(rival.name, world.alivePlayerCount)
  targetPriorScore(prior, ratio, countering)

proc relativePriorTargetValue(world: Observation, target: Rival): float =
  ## Center a target prior across legal rivals to preserve action allocation.
  var
    total = 0.0
    count = 0
  for rival in world.rivals:
    if rival.isAlive and rival.canAttack and not rival.isAllied and
        not rival.isTeammate:
      total += priorTargetValue(world, rival)
      inc count
  if count <= 1:
    return 0.0
  priorTargetValue(world, target) - total / count.float

proc avoidTargetValue(world: Observation, rival: Rival): float =
  ## Score a named rival as a farm target or urgent active invader.
  let
    ratio = max(rival.relativeTroopRatio, 0.01)
    countering = rival.incomingAttack and world.incomingAttacks > 0
    prior = opponentPrior(rival.name, world.alivePlayerCount)
  targetAvoidScore(prior, ratio, countering)

proc relativeAvoidTargetValue(world: Observation, target: Rival): float =
  ## Center risk-aware target value across currently legal rivals.
  var
    total = 0.0
    count = 0
  for rival in world.rivals:
    if rival.isAlive and rival.canAttack and not rival.isAllied and
        not rival.isTeammate:
      total += avoidTargetValue(world, rival)
      inc count
  if count <= 1:
    return 0.0
  avoidTargetValue(world, target) - total / count.float

proc isExpansion*(action: Action): bool =
  action.kind == "attack" and (metaBool(action, "expansion") or
    action.id.startsWith("expand:"))

proc scoreSpawn(weights: Weights, action: Action): float =
  weights.spawnLocalLand * metaFloat(action, "localLandScore") +
    weights.spawnSafety * metaFloat(action, "safetyScore") +
    weights.spawnOpportunity * metaFloat(action, "opportunityScore")

proc openingExpansionActive(weights: Weights, world: Observation,
    memory: Memory): bool =
  ## Whether this decision is inside the configured soft opening dose.
  let spawnMatches =
    (weights.openingExpandSpawnTile >= 0 and
      world.spawnTile == weights.openingExpandSpawnTile) or
    (weights.openingExpandKnownStarts and
      openingFor(world.spawnTile).spawnTile >= 0)
  spawnMatches and
    weights.openingExpandCount > 0 and
    memory.expansions < weights.openingExpandCount and
    weights.openingExpandFraction > 0.0 and
    world.turnNumber.float <= weights.openingExpandEndTurn

proc scoreExpansion(weights: Weights, world: Observation, memory: Memory,
    action: Action): float =
  ## Neutral land is uncontested territory: the cheapest score in the game.
  ## Always take the largest offered slice unless the pool is already so thin
  ## that spending it would push regeneration off its peak.
  let fraction = metaFloat(action, "troopPercentage", 0.2)
  let ratio = world.troopRatio
  var desired = 0.35
  ## Inside the land-grab window the regeneration optimum is the wrong
  ## objective: the winners' and losers' curves are identical at turn 1 000
  ## and separate by turn 2 000, so tiles bought early compound into both the
  ## troop cap and the score, and holding troops back to protect regen is
  ## paying for a resource we will have plenty of later.
  if openingExpansionActive(weights, world, memory):
    desired = weights.openingExpandFraction
  elif weights.conversionExpandFraction > 0.0 and
      world.turnNumber.float > weights.conversionExpandFloorTurn:
    desired = weights.conversionExpandFraction
  elif smallField(world) and weights.smallFieldExpandFraction > 0.0:
    desired = weights.smallFieldExpandFraction
  elif weights.landGrabTiles > 0 and world.ownTiles < weights.landGrabTiles:
    desired = 0.35
  elif ratio < weights.expandPoorRatio:
    desired = 0.10
  elif ratio < growthOptimalRatio * 0.7:
    desired = 0.20
  result = weights.expandBase -
    weights.expandFractionPenalty * abs(fraction - desired) +
    weights.spendPressure * spendUrgency(world, weights.threatReserve,
      collapsing(memory, world))
  if weights.conversionExpandBonus > 0.0 and
      world.turnNumber.float > weights.conversionExpandFloorTurn:
    result += weights.conversionExpandBonus
  if ratio > weights.expandRichRatio:
    result += weights.expandRichBonus
  if ratio < weights.expandPoorRatio:
    result -= weights.expandPoorPenalty
  if world.behindExpectedTempo or world.openingWindow:
    result += 10.0
  ## Opening land grab: the very first orders out of the spawn are worth more
  ## than anything else, since every later option scales with the tiles they
  ## win. Gated on the board state, not on our own decision count, so it
  ## cannot fire again after a mid-game lull.
  if world.ownTiles < 800:
    result += 18.0

proc scoreHostileAttack(weights: Weights, world: Observation, memory: Memory,
    action: Action): float =
  let targetID = metaStr(action, "targetID")
  let target = world.rival(targetID)
  if target.isAllied or target.isTeammate:
    return 0.0
  var ratio = metaFloat(action, "relativeTroopRatio", target.relativeTroopRatio)
  if ratio <= 0: ratio = 1.0
  let urgency = spendUrgency(world, weights.threatReserve,
    collapsing(memory, world))
  ## With free neutral land still on the board an unfavourable attack is a
  ## waste; with the pool overflowing and nowhere to expand it is the only
  ## thing troops are good for, so the old hard ratio gate is now a soft one.
  ## The ratio requirement must not evaporate when the frontier closes.
  ##
  ## The old gate carried `and world.canExpandIntoNeutral`, so it applied only
  ## while there was still free land to prefer instead. At the moment the
  ## neutral land runs out — turn ~2 000, exactly where the clean replays show
  ## our territory peaking and then collapsing — the gate switched off and we
  ## began attacking rivals stronger than us at `attackBase` 82, which outranks
  ## every other option on the menu. daveey's wars gain ground because it picks
  ## targets it beats; ours bled because past turn 2 000 we picked anyone.
  let weak = ratio < weights.attackMinRatio and not target.underSiege
  if weak and urgency < 0.35 and world.canExpandIntoNeutral:
    return 4.0
  let fraction = metaFloat(action, "troopPercentage", 0.25)
  let countering = target.incomingAttack and world.incomingAttacks > 0
  let commitRatio =
    if weights.oceaniaFullCommitRatio > 0.0 and
        openingApplies(openingOceania, world.spawnTile):
      weights.oceaniaFullCommitRatio
    elif weights.leadFullCommitRatio > 0.0 and
        world.ownTileShare >= weights.leadFullCommitShare:
      weights.leadFullCommitRatio
    else:
      weights.fullCommitRatio
  let counterBonus =
    if countering and weights.counterAttackBonus > 0.0 and
        (weights.counterAttackFloorTurn <= 0.0 or
          world.turnNumber.float > weights.counterAttackFloorTurn):
      weights.counterAttackBonus
    else:
      0.0
  let desired =
    if countering and weights.counterAttackFractionPenalty > 0.0:
      if ratio < 0.9: 0.10
      elif ratio < 1.2: 0.25
      else: 0.40
    elif weights.smallFieldProbeFirst and smallField(world) and
        weights.probeAttackRatio > 0.0 and ratio < weights.probeAttackRatio:
      0.10
    elif ratio >= commitRatio or
        urgency > weights.urgentFullCommit:
      0.40
    elif weights.probeAttackRatio > 0.0 and
        ratio < weights.probeAttackRatio:
      0.10
    else:
      0.25
  let fractionPenalty =
    if countering and weights.counterAttackFractionPenalty > 0.0:
      weights.counterAttackFractionPenalty
    else:
      weights.attackFractionPenalty
  result = weights.attackBase +
    weights.attackRatioGain * clamp(ratio - 1.0, -1.0, 3.0) -
    fractionPenalty * abs(fraction - desired) +
    weights.spendPressure * urgency
  if spawnBoomActive(weights, world):
    result -= weights.spawnBoomDose
  if weights.preLeadAttackRatioGain > 0.0 and
      world.ownTileShare < weights.preLeadTargetShare:
    result += weights.preLeadAttackRatioGain *
      clamp(ratio - 1.0, -1.0, 3.0)
  if weights.opponentPriorScale > 0.0:
    result += weights.opponentPriorScale *
      relativePriorTargetValue(world, target)
  if weights.opponentAvoidScale > 0.0:
    result += weights.opponentAvoidScale *
      relativeAvoidTargetValue(world, target)
  if smallField(world):
    result += weights.smallFieldAttackBonus
  if countering:
    result += counterBonus
  elif world.incomingAttacks > 0:
    result -= weights.invadedOffensePenalty
  if weights.mattAttackPenalty > 0.0 and not countering and
      opponentKind(target.name) == MattOpponent:
    result -= weights.mattAttackPenalty *
      clamp(1.5 - ratio, 0.0, 1.0)
  if weak:
    ## Still allowed — a besieged or collapsing rival is worth taking on — but
    ## it has to beat the alternatives on merit rather than by default.
    result -= weights.weakRatioPenalty *
      clamp(weights.attackMinRatio - ratio, 0.0, 1.5)
  if ratio < 1.0 and not target.underSiege:
    result -= weights.losingFightPenalty * clamp(1.0 - ratio, 0.0, 1.0)
    if weights.waterStrongTargetPenalty > 0.0 and not countering and
        openingApplies(openingWater, world.spawnTile):
      result -= weights.waterStrongTargetPenalty
  if target.underSiege:
    result += weights.attackSiegeBonus
  ## Eating a small neighbour is cheap territory; the leader will fight back.
  if target.tileShare < world.ownTileShare * 0.6:
    result += weights.attackWeakTargetBonus
  ## Finishing a collapsing seat removes a rival from the score denominator
  ## and hands us its gold.
  if target.tileShare < 0.02:
    result += weights.attackWeakTargetBonus * 1.5
  if targetID.len > 0 and targetID == world.leaderID and
      world.ownTileShare < world.leaderTileShare * 0.8:
    result -= 12.0
  ## Concentration of force. The winning seat in the traced episode ground
  ## through one rival at a time — `attack:X:10`, `:25`, `:40`, again and
  ## again — before rotating to the next. Re-deciding the target every step
  ## spreads the pool across fronts and takes nothing.
  if memory.lastAttackTarget.len > 0 and targetID == memory.lastAttackTarget:
    result += weights.targetStickiness
  if memory.lastChoiceID.startsWith("attack:"):
    let repeatScale =
      if smallField(world): weights.smallFieldRepeatScale
      else: 1.0
    result -= weights.hostileRepeatPenalty * repeatScale
  if world.canExpandIntoNeutral and ratio < 2.5:
    result -= weights.attackNeutralPenalty
  if world.homeDanger == "high" and world.incomingAttacks > 0 and urgency < 0.5:
    result -= 10.0
  if world.troopRatio < 0.15:
    result -= 20.0
  if grinding(memory, world, targetID):
    ## Six orders in and no ground gained: this war is a troop sink. Walk away
    ## and spend the pool on something that yields.
    result -= weights.grindPenalty
  let collapseDefense = collapseDefenseValue(weights, world, memory)
  if collapseDefense > 0.0:
    ## Counter-attacking the invader is fine; opening a second front while
    ## shedding 25 000 tiles a decision is not.
    if targetID.len > 0 and targetID == memory.lastAttackTarget:
      result -= collapseDefense * 0.4
    else:
      result -= collapseDefense
  if weights.earlyAttackFloorTurn > 0 and
      world.turnNumber.float < weights.earlyAttackFloorTurn and
      (weights.earlyAttackMinRivals <= 0 or
        world.aliveRivals >= weights.earlyAttackMinRivals) and
      (weights.earlyAttackScope == openingNone or
        openingApplies(weights.earlyAttackScope, world.spawnTile)) and
      world.incomingAttacks == 0 and
      (weights.earlyAttackExemptRatio <= 0.0 or
        ratio < weights.earlyAttackExemptRatio):
    result -= weights.earlyAttackPenalty

proc scoreBuild(weights: Weights, world: Observation, memory: Memory,
    action: Action): float =
  let unit = metaStr(action, "unit")
  let owned = world.unitCount(unit)
  var base =
    case unit
    of "Port": (if world.portCount == 0 and owned == 0: weights.firstPort
                else: weights.portBase)
    of "City": (if world.cityCount == 0 and owned == 0: weights.firstCity
                else: weights.cityBase)
    of "Factory": weights.factoryBase
    of "Defense Post": weights.defensePostBase
    of "SAM Launcher": weights.samBase
    of "Missile Silo": weights.siloBase
    of "Warship": weights.warshipBase
    else: 10.0
  if unit == "Port" and weights.waterPortBonus > 0.0 and
      openingApplies(openingWater, world.spawnTile):
    base += weights.waterPortBonus
  ## Costs double per structure (`2^n * 125_000`) while the payoff per unit
  ## stays flat, so value per gold halves each time — a linear score decay is
  ## already generous.
  base -= weights.buildDecay * owned.float
  if smallField(world) and unit in ["Port", "Factory"]:
    base -= weights.smallFieldNonCityBuildPenalty
  ## A City raises `maxTroops`, and raising the cap only helps in proportion
  ## to how close we already are to it: differentiating
  ## `(10 + N^0.73/4)*(1 - N/K)` in K gives a relative gain of
  ## `(ΔK/K) * ratio/(1-ratio)`. At ratio 0.27 that is 0.37; at 0.80 it is 4.0.
  ## Buying a city on a 52-tile opening — which the base profile did in the
  ## first local smoke test — buys almost nothing, and costs the land grab
  ## that decides whether we survive at all.
  if unit == "City":
    let leverage = clamp(world.troopRatio /
      max(1.0 - world.troopRatio, 0.05), 0.05, 4.0)
    base *= clamp(leverage / 0.72, 0.15, 1.3)
  ## Trade income scales with territory, and every structure is a decision not
  ## spent grabbing land — but only while there is still land to grab. A seat
  ## boxed in at a thousand tiles on Pangaea has nothing better to buy, and
  ## penalising economy there just leaves it choosing between a dead frontier
  ## and a hold.
  if world.ownTiles < 1500 and unit in ["Port", "City", "Factory"] and
      world.canExpandIntoNeutral and memory.neutralStall == 0:
    base -= 45.0
  ## A decision spent building costs no troops, so it is nearly free while the
  ## pool is too thin to buy meaningful territory.
  if world.troopRatio < 0.25 and unit in ["Port", "City", "Factory"]:
    base += weights.buildIdleTroopBonus
  let hostileDistance = metaFloat(action, "hostileBorderDistance", 999.0)
  if unit in ["City", "Port", "Factory"] and hostileDistance < 6.0:
    base -= 14.0
  let
    losingGround = collapsing(memory, world)
    collapseDefense = collapseDefenseValue(weights, world, memory)
  let besieged = (world.homeDanger == "high" and world.incomingAttacks > 0) or
    losingGround
  if unit == "Defense Post":
    if world.homeDanger == "high": base += 16.0
    if besieged: base += 34.0
    if hostileDistance < 8.0: base += 8.0
    ## Waiting for the invasion to start is waiting too late: in the hosted
    ## 12P episodes eight of twelve seats finish on zero tiles, and ours were
    ## dead by turn 2 000–4 300. A post costs 50k–250k and multiplies local
    ## defence, so it is worth pre-building against a bigger neighbour.
    base += weights.threatDefenseBonus *
      clamp(strongestBorderThreat(world) - 1.0, 0.0, 1.5)
    if collapseDefense > 0.0:
      base += collapseDefense
    if smallField(world):
      base -= weights.smallFieldDefensePostPenalty
    if weights.spatialLandDefense and world.spatialTrusted and
        world.incomingAttacks > 0:
      if world.landFrontAttacks == 0:
        ## A land post cannot stop a naval or otherwise disconnected threat.
        base -= 50.0
      else:
        var uncoveredRatio = 0.0
        for rival in world.rivals:
          if not rival.borderUnderAttack:
            continue
          let total = rival.borderCovered + rival.borderUncovered
          if total > 0:
            uncoveredRatio = max(
              uncoveredRatio,
              rival.borderUncovered.float / total.float
            )
        base += 12.0 * clamp(uncoveredRatio, 0.0, 1.0)
  elif besieged and unit in ["Port", "City", "Factory"]:
    ## A city on an empire that is being taken apart never pays back.
    base -= 40.0
    if smallField(world) and losingGround:
      base -= weights.smallFieldCollapseBuildPenalty
  base += 5.0 * metaFloat(action, "economicValue")
  if world.economyRecommended:
    base += 6.0
  if spawnBoomActive(weights, world) and
      unit in ["City", "Port", "Factory"]:
    base += weights.spawnBoomDose
  result = base

proc scoreAlliance(weights: Weights, world: Observation, memory: Memory,
    action: Action): float =
  ## Allies cannot attack us and trade with us for 35k instead of 25k.
  let targetID = metaStr(action, "recipientID", metaStr(action, "targetID"))
  let target = world.rival(targetID)
  if target.isAllied:
    return 0.0
  let asks = memory.allianceAsks.getOrDefault(targetID, 0)
  result = weights.allianceBase - weights.allianceRepeatPenalty * asks.float
  if target.sharesBorder:
    result += weights.allianceBorderBonus
  if target.tileShare > world.ownTileShare:
    result += weights.allianceStrongBonus
  if world.homeDanger == "high" or world.incomingAttacks > 0:
    result += 12.0
  if smallField(world):
    result -= weights.smallFieldAlliancePenalty
  if weights.oceaniaAlliancePenalty > 0.0 and
      openingApplies(openingOceania, world.spawnTile):
    result -= weights.oceaniaAlliancePenalty
  ## Late, with the field thinned out, an alliance only caps our own ceiling.
  if world.aliveRivals <= 2:
    result -= weights.allianceLateMalus

proc scoreBreakAlliance(weights: Weights, world: Observation, action: Action): float =
  if not world.backstabRecommended:
    return 0.0
  let targetID = metaStr(action, "targetID")
  if world.backstabTargetID.len > 0 and world.backstabTargetID != targetID:
    return 0.0
  weights.breakAllianceBase

proc scoreBoat(weights: Weights, world: Observation, memory: Memory,
    action: Action): float =
  ## Transports are slow and lossy: worth it only when there is nothing to
  ## walk into. The first corpus spent twelve decisions on boats for 30 tiles.
  if metaBool(action, "expansion"):
    result = weights.boatExpandBase
    if not world.canExpandIntoNeutral:
      result += 18.0
  else:
    var ratio = metaFloat(action, "relativeTroopRatio", 1.0)
    if ratio <= 0: ratio = 1.0
    result = weights.boatInvadeBase + 8.0 * min(ratio - 1.0, 2.0)
    if ratio < 1.2:
      result -= 25.0
  result += 0.4 * weights.spendPressure * spendUrgency(world, weights.threatReserve,
      collapsing(memory, world))
  let desiredFraction =
    if smallField(world) and weights.smallFieldBoatFraction > 0.0:
      weights.smallFieldBoatFraction
    else:
      weights.boatDesiredFraction
  result -= 20.0 * abs(
    metaFloat(action, "troopPercentage", 0.25) - desiredFraction
  )
  if smallField(world):
    result -= weights.smallFieldBoatPenalty
  if world.homeDanger == "high":
    result -= 15.0
  let collapseDefense = collapseDefenseValue(weights, world, memory)
  if collapseDefense > 0.0:
    result -= collapseDefense
  if world.troopRatio < 0.2:
    result -= 15.0

proc scoreAction*(weights: Weights, world: Observation, memory: Memory,
    action: Action): float =
  case action.kind
  of "spawn": scoreSpawn(weights, action)
  of "attack":
    if isExpansion(action): scoreExpansion(weights, world, memory, action)
    else: scoreHostileAttack(weights, world, memory, action)
  of "build": scoreBuild(weights, world, memory, action)
  of "nuke":
    ## The menu only offers a warhead we can already pay for, and winners fire
    ## them ten times as often as the middle of the table.
    if world.bestStrikeActionID == action.id: weights.nukeBase + 8.0
    elif world.strikeRecommended: weights.nukeBase
    else: weights.nukeBase * 0.55
  of "upgrade_structure":
    let unit = metaStr(action, "unit")
    if unit in ["City", "Port", "Factory"]:
      ## A city level is +250k max troops, which is exactly what a capped
      ## pool needs.
      weights.upgradeBase - 6.0 * metaFloat(action, "level") +
        (if world.troopRatio < 0.25: weights.buildIdleTroopBonus else: 0.0) +
        (if unit == "City" and world.troopRatio > 0.85: 22.0 else: 0.0) +
        (if spawnBoomActive(weights, world): weights.spawnBoomDose else: 0.0)
    else: 12.0
  of "alliance_request": scoreAlliance(weights, world, memory, action)
  of "alliance_extend":
    weights.allianceExtend -
      (if smallField(world): weights.smallFieldAlliancePenalty else: 0.0) -
      (if openingApplies(openingOceania, world.spawnTile):
        weights.oceaniaAlliancePenalty
      else:
        0.0)
  of "alliance_reject": 0.0
  of "break_alliance": scoreBreakAlliance(weights, world, action)
  of "boat": scoreBoat(weights, world, memory, action)
  of "boat_retreat":
    ## Pulling transports home shows up at 0.092 per decision among wiped
    ## seats and 0.000 among seats that never collapsed.
    0.5
  of "retreat":
    if world.homeDanger == "high" and world.incomingAttacks > 1: 12.0 else: 1.5
  of "move_warship": min(6.0, weights.warshipBase * 0.4)
  of "target_player": weights.chatterBase
  of "quick_chat", "emoji": weights.chatterBase * 0.5
  of "embargo", "embargo_stop", "embargo_all": 1.0
  of "donate_gold", "donate_troops": 0.0
  of "delete_unit": 0.0
  of "hold":
    weights.holdBase + weights.holdRecoveryBonus *
      clamp((growthOptimalRatio - world.troopRatio) / 0.35, 0.0, 1.0) +
      collapseDefenseValue(weights, world, memory) * 0.7 +
      (if spawnBoomActive(weights, world):
        weights.spawnBoomDose * 0.25
      else:
        0.0)
  else: 0.5

proc observeProgress*(memory: var Memory, world: Observation) =
  ## Did the last order actually move the border?
  ##
  ## In the first hosted 12P episode our seat issued `expand:terra-nullius:35`
  ## on twenty consecutive decisions — turns 1 200 to 3 100 — while its tile
  ## count stayed at exactly 25 089 and its pool saturated at the cap. The
  ## engine kept reporting `canExpandIntoNeutral = true`, so nothing in the
  ## observation said "this move does nothing"; only the tile count did. Those
  ## twenty wasted decisions are a fifth of a game, and the seat was conquered
  ## shortly after.
  if memory.seenTiles and memory.lastChoiceID.len > 0:
    let grew = world.ownTiles > memory.lastTiles + 0.5
    if grew:
      ## Growth clears the counter for the order that produced it and *decays*
      ## the frontier counter by one — it does not wipe the table.
      ##
      ## Wiping it (which `kutuzov:v1` did) means every successful conquest
      ## fully re-arms the dead expansion family, so the seat cycles
      ## attack, expand, expand, attack, … and burns two thirds of its
      ## decisions on a frontier it already proved is closed. That version
      ## survived 1 of 38 hosted episodes. Decaying instead reproduces
      ## daveey's actual behaviour: it re-tries the frontier every few
      ## successful attacks, which is what picks up land a conquest opened.
      memory.stallByID[memory.lastChoiceID] = 0
      if memory.neutralStall > 0: dec memory.neutralStall
    elif memory.lastChoiceKind in ["attack", "boat"]:
      memory.stallByID[memory.lastChoiceID] =
        memory.stallByID.getOrDefault(memory.lastChoiceID, 0) + 1
      if memory.lastChoiceID.startsWith("expand:"):
        inc memory.neutralStall
  ## Losing ground, as opposed to failing to gain it.
  ##
  ## In a clean hosted episode our seat reached 208 290 tiles at turn 7 700 —
  ## the largest empire on the board — and then shed 15 000 to 27 000 tiles
  ## *per decision* while still committing 40% of its troops to outward
  ## attacks and buying a Missile Silo. It finished on zero. The policy had no
  ## notion of losing territory: the tile count was only ever read to detect a
  ## stalled frontier, never a collapsing one. Troops kept at home defend
  ## automatically in this engine, so the response to a collapse is to stop
  ## sending them away.
  if memory.seenTiles:
    if world.ownTiles < memory.lastTiles - 0.5:
      inc memory.losingStreak
    elif world.ownTiles > memory.lastTiles + 0.5:
      memory.losingStreak = 0
    else:
      ## Flat has to release the latch. Under the defensive response we stop
      ## expanding, so tiles go flat by construction — and if only a *gain*
      ## cleared the streak, the first two bad decisions would pin the bot into
      ## permanent defence. Measured: `kutuzov:v30` survived 60 of 159 episodes
      ## (against v27's 23 of 217) and won 1, because it never came back out.
      if memory.losingStreak > 0: dec memory.losingStreak
  ## Grinding the same rival forever.
  ##
  ## `stallByID` is keyed on the action id, but `attack:X:10`, `attack:X:25`
  ## and `attack:X:40` are three different ids against one target — so a war
  ## that yields nothing never trips it. The clean replays show our seat
  ## issuing ~30 consecutive orders against a single rival while its territory
  ## shrinks; daveey hits a target twice and goes back to taking free land.
  if memory.lastAttackTarget.len > 0:
    let target = memory.lastAttackTarget
    if target notin memory.targetStartTiles:
      memory.targetStartTiles[target] = world.ownTiles
    memory.targetGrind[target] = memory.targetGrind.getOrDefault(target) + 1
  if world.ownTiles > memory.peakTiles: memory.peakTiles = world.ownTiles
  memory.lastTiles = world.ownTiles
  memory.seenTiles = true

proc repeatPenalty(memory: Memory, action: Action): float =
  ## Guard of the same class as the dead-expansion bug, for the kinds whose
  ## effect the tile count cannot see.
  ##
  ## A build order names a specific tile, an extend names a specific ally, an
  ## embargo names a specific rival — none of them should ever be worth
  ## issuing twice, and if one silently fails to apply nothing in the
  ## observation says so. Attacks and boats are excluded: repeating those is
  ## correct play, and they already have the tile-growth detector.
  if action.kind in ["attack", "boat", "spawn", "hold"]: return 0.0
  let taken = memory.takenIDs.getOrDefault(action.id, 0)
  if taken == 0: return 0.0
  25.0 * min(taken, 3).float

proc stallPenalty(weights: Weights, memory: Memory, world: Observation,
    action: Action): float =
  ## Repeats that are not working, plus the engine's own repeat flag.
  ## A hostile push that gains nothing for one step is normal grinding; a
  ## neutral expansion that gains nothing is simply dead.
  let perRepeat = if action.kind == "attack" and not isExpansion(action):
      12.0 else: 24.0
  let repeatScale =
    if isExpansion(action) and smallField(world):
      weights.smallFieldExpansionStallScale
    else:
      1.0
  result = perRepeat *
    min(memory.stallByID.getOrDefault(action.id, 0), 4).float * repeatScale
  if isExpansion(action):
    ## `expand:…:10/20/35` are three ids for one move, so a stalled frontier
    ## has to discount the whole family, not just the id we happened to pick.
    result += 26.0 * min(memory.neutralStall, 4).float
  for avoided in world.avoidActionIDs:
    if avoided == action.id:
      result += 8.0
      break

proc closingSuppression(weights: Weights, world: Observation,
    action: Action): float =
  ## Once we are big enough to be chasing the 80% win threshold, the only
  ## thing worth a decision is taking more ground. Winner takes 1.0 and every
  ## other seat takes 0.0, so an economy pick at 40% of the map is spending a
  ## decision on a payoff the game will end before collecting.
  if action.kind in ["attack", "nuke", "boat", "hold"]:
    return 0.0
  if world.ownTileShare >= weights.closingShare:
    result = weights.closingPenalty
  if weights.conversionShare > 0.0 and
      world.ownTileShare >= weights.conversionShare:
    result = max(result, weights.conversionPenalty)

proc adjustedActionScore(weights: Weights, world: Observation, memory: Memory,
    action: Action): float =
  ## Return the complete score used by the deterministic action argmax.
  scoreAction(weights, world, memory, action) -
    stallPenalty(weights, memory, world, action) -
    repeatPenalty(memory, action) -
    closingSuppression(weights, world, action)

proc observeAcceptedExpansions(memory: var Memory, world: Observation) =
  ## Accumulate accepted expansion ids from the game's sliding memory window.
  for sequence in world.recentAcceptedExpansionSequences:
    if not memory.seenAcceptedExpansions.hasKey(sequence):
      memory.seenAcceptedExpansions[sequence] = true
      inc memory.acceptedExpansions

proc mattOpeningIndex(spawnTile: int): int =
  ## Find an exact live spawn in the narrow replay-derived opening book.
  for index, opening in MattPositionOpenings:
    if opening.spawnTile == spawnTile:
      return index
  -1

proc matchesMattStep(action: Action, step: MattOpeningStep): bool =
  ## Report whether one legal action implements the requested opening step.
  let fraction = metaFloat(action, "troopPercentage", -1.0)
  case step.kind
  of mattExpand:
    action.kind == "attack" and isExpansion(action) and
      abs(fraction * 100.0 - step.percent.float) < 0.1
  of mattAttack:
    action.kind == "attack" and not isExpansion(action) and
      abs(fraction * 100.0 - step.percent.float) < 0.1
  of mattBoat:
    action.kind == "boat" and
      abs(fraction * 100.0 - step.percent.float) < 0.1
  of mattBuild:
    action.kind == "build" and metaStr(action, "unit") == step.unit
  of mattHold:
    action.kind == "hold"

proc mattPositionChoice(weights: Weights, world: Observation,
    memory: var Memory, actions: seq[Action]): Choice =
  ## Repeat each observed move for four requests so one engine action lands.
  result = Choice(score: -1.0e9)
  if not weights.mattPositionOpening or memory.mattOpeningAborted or
      not world.hasSpawned:
    return
  let openingIndex = mattOpeningIndex(world.spawnTile)
  if openingIndex < 0:
    return
  if world.incomingAttacks > 0 or world.homeDanger == "high":
    memory.mattOpeningAborted = true
    return
  let stepIndex = memory.mattOpeningAttempts div MattOpeningRepeat
  if stepIndex >= MattPositionOpenings[openingIndex].steps.len:
    return
  let step = MattPositionOpenings[openingIndex].steps[stepIndex]
  inc memory.mattOpeningAttempts
  var bestScore = -1.0e9
  for action in actions:
    if not matchesMattStep(action, step):
      continue
    let score = adjustedActionScore(weights, world, memory, action)
    if score > bestScore:
      bestScore = score
      result = Choice(
        id: action.id,
        kind: action.kind,
        score: 1_000.0,
        reason: "Matt position opening"
      )

proc forcedLandChoice(weights: Weights, world: Observation, memory: Memory,
    actions: seq[Action]): Choice =
  ## Select one exact safe land expansion in the measured opening cell.
  result = Choice(score: -1.0e9)
  if weights.forcedLandSpawnTile < 0 or
      world.spawnTile != weights.forcedLandSpawnTile or
      weights.forcedLandCount <= 0 or
      memory.acceptedExpansions >= weights.forcedLandCount or
      world.turnNumber.float > weights.forcedLandEndTurn or
      not world.hasSpawned or world.incomingAttacks > 0 or
      world.homeDanger == "high":
    return
  var bestScore = -1.0e9
  for action in actions:
    if not isExpansion(action):
      continue
    let fraction = metaFloat(action, "troopPercentage", -1.0)
    if abs(fraction - weights.forcedLandFraction) > 0.001:
      continue
    let score = adjustedActionScore(weights, world, memory, action)
    if score > bestScore:
      bestScore = score
      result = Choice(
        id: action.id,
        kind: action.kind,
        score: 1_000.0,
        reason: "measured five-land opening"
      )

proc targetRerankValue(world: Observation, action: Action): float =
  ## Score how favorable one hostile target is by current relative troops.
  let target = world.rival(metaStr(action, "targetID"))
  var ratio = metaFloat(
    action,
    "relativeTroopRatio",
    target.relativeTroopRatio
  )
  if ratio <= 0.0:
    ratio = 1.0
  clamp(ratio - 1.0, -1.0, 3.0)

proc rerankHostileTarget(weights: Weights, world: Observation, memory: Memory,
    actions: seq[Action], base: Choice): Choice =
  ## Change only the target of an already-selected hostile attack.
  result = base
  if weights.targetRerankRatioGain <= 0.0 or
      not openingApplies(weights.targetRerankScope, world.spawnTile):
    return
  if weights.targetRerankPeaceOnly and
      (world.incomingAttacks > 0 or
        world.strategicPriority == "build_defense"):
    return
  var
    chosenFraction = -1.0
    foundBase = false
  for action in actions:
    if action.id == base.id and action.kind == "attack" and
        not isExpansion(action):
      chosenFraction = metaFloat(action, "troopPercentage", 0.25)
      foundBase = true
      break
  if not foundBase:
    return
  var bestScore = -1.0e9
  for action in actions:
    if action.kind != "attack" or isExpansion(action):
      continue
    let fraction = metaFloat(action, "troopPercentage", 0.25)
    if abs(fraction - chosenFraction) > 0.001:
      continue
    let score = adjustedActionScore(weights, world, memory, action) +
      weights.targetRerankRatioGain * targetRerankValue(world, action)
    if score > bestScore:
      bestScore = score
      result = Choice(
        id: action.id,
        kind: action.kind,
        score: score,
        reason: action.label & " (target rerank)"
      )

proc pressureDefenseAction(action: Action): bool =
  ## Return whether one legal action banks troops or strengthens local defence.
  action.kind == "hold" or
    (action.kind in ["build", "upgrade_structure"] and
      metaStr(action, "unit") == "Defense Post")

proc deflectLosingPressureAttack(weights: Weights, world: Observation,
    memory: Memory, actions: seq[Action], base: Choice): Choice =
  ## Replace only an outmatched active counterattack with local defence.
  result = base
  if weights.pressureDeflectMinRatio <= 0.0 or
      not openingApplies(weights.pressureDeflectScope, world.spawnTile) or
      (world.incomingAttacks == 0 and
        world.strategicPriority != "build_defense"):
    return
  var selectedRatio = 0.0
  for action in actions:
    if action.id != base.id or action.kind != "attack" or isExpansion(action):
      continue
    let target = world.rival(metaStr(action, "targetID"))
    selectedRatio = metaFloat(
      action,
      "relativeTroopRatio",
      target.relativeTroopRatio
    )
    break
  if selectedRatio <= 0.0 or
      selectedRatio >= weights.pressureDeflectMinRatio:
    return
  var bestScore = -1.0e9
  for action in actions:
    if not pressureDefenseAction(action):
      continue
    let score = adjustedActionScore(weights, world, memory, action)
    if score > bestScore:
      bestScore = score
      result = Choice(
        id: action.id,
        kind: action.kind,
        score: score,
        reason: action.label & " (losing pressure deflection)"
      )

proc quietBuildActive(weights: Weights, world: Observation,
    memory: Memory): bool =
  ## Return whether the narrow safe construction window is active now.
  let opening = openingFor(world.spawnTile)
  weights.quietBuildCount > 0 and
    memory.quietBuilds < weights.quietBuildCount and
    opening.mapName in ["Asia", "Pangaea"] and
    world.turnNumber.float <= weights.quietBuildEndTurn and
    world.incomingAttacks == 0 and
    world.homeDanger != "high" and
    (world.strategicPriority != "build_defense" or
      weights.quietBuildAttackRatio > 0.0)

proc replaceableQuietAttack(weights: Weights, world: Observation,
    actions: seq[Action], base: Choice): bool =
  ## Return whether the selected hostile action is a safe weak-target attack.
  if weights.quietBuildAttackRatio <= 0.0 or base.kind != "attack":
    return false
  for action in actions:
    if action.id != base.id or isExpansion(action):
      continue
    let target = world.rival(metaStr(action, "targetID"))
    let ratio = metaFloat(
      action,
      "relativeTroopRatio",
      target.relativeTroopRatio
    )
    return ratio > 0.0 and
      ratio <= weights.quietBuildAttackRatio and
      not target.incomingAttack and
      not target.underSiege

proc substituteQuietBuild(weights: Weights, world: Observation,
    memory: Memory, actions: seq[Action], base: Choice): Choice =
  ## Replace only configured idle or safe weak-attack choices with construction.
  result = base
  let eligible =
    base.kind in ["hold", "alliance_request", "alliance_extend"] or
    replaceableQuietAttack(weights, world, actions, base)
  if not eligible or not quietBuildActive(weights, world, memory):
    return
  var bestScore = -1.0e9
  for action in actions:
    if action.kind != "build" or
        metaStr(action, "unit") notin ["City", "Port", "Defense Post"]:
      continue
    let score = adjustedActionScore(weights, world, memory, action)
    if score + weights.quietBuildMargin < base.score or score <= bestScore:
      continue
    bestScore = score
    result = Choice(
      id: action.id,
      kind: action.kind,
      score: score,
      reason: action.label & " (quiet build substitution)",
      quietBuild: true
    )

proc decide*(weights: Weights, world: Observation, memory: var Memory,
    actions: seq[Action]): Choice =
  ## Argmax over legal actions; ties break on the earlier offered action so
  ## replays stay deterministic.
  observeAcceptedExpansions(memory, world)
  observeProgress(memory, world)
  if weights.collapseDefense > 0.0 and memory.losingStreak > 3:
    ## A long invasion must not create an equally long recovery latch. Three
    ## flat decisions are enough to prove the border has stabilized.
    memory.losingStreak = 3
  let scriptedID =
    if openingApplies(weights.openingBookScope, world.spawnTile):
      openingAction(world, actions, memory.neutralStall > 0)
    else:
      ""
  var best = mattPositionChoice(weights, world, memory, actions)
  if best.id.len == 0:
    best = forcedLandChoice(weights, world, memory, actions)
  if best.id.len == 0 and scriptedID.len > 0:
    for action in actions:
      if action.id == scriptedID:
        best = Choice(
          id: action.id,
          kind: action.kind,
          score: 1_000.0,
          reason: "measured position opening"
        )
        break
  if best.id.len == 0:
    for action in actions:
      let score = adjustedActionScore(weights, world, memory, action)
      if score > best.score:
        best = Choice(id: action.id, kind: action.kind, score: score,
          reason: action.label)
    best = rerankHostileTarget(weights, world, memory, actions, best)
    best = deflectLosingPressureAttack(
      weights,
      world,
      memory,
      actions,
      best
    )
    best = substituteQuietBuild(weights, world, memory, actions, best)
  if best.id.len == 0 and actions.len > 0:
    best = Choice(id: actions[0].id, kind: actions[0].kind, score: 0.0,
      reason: "fallback")

  inc memory.decisions
  if best.kind == memory.lastKind: inc memory.sameKindRun
  else: memory.sameKindRun = 0
  memory.lastKind = best.kind
  memory.lastChoiceID = best.id
  memory.lastChoiceKind = best.kind
  memory.takenIDs[best.id] = memory.takenIDs.getOrDefault(best.id, 0) + 1
  if best.quietBuild:
    inc memory.quietBuilds
  for action in actions:
    if action.id == best.id:
      if action.kind == "attack":
        if isExpansion(action):
          inc memory.expansions
        else:
          inc memory.attacks
          memory.lastAttackTarget = metaStr(action, "targetID")
      elif action.kind == "build":
        inc memory.builds
      elif action.kind == "alliance_request":
        let targetID = metaStr(action, "recipientID", metaStr(action, "targetID"))
        memory.allianceAsks[targetID] =
          memory.allianceAsks.getOrDefault(targetID, 0) + 1
      break
  best

proc closingGroundCompanion(weights: Weights, world: Observation,
    memory: Memory, actions: seq[Action], chosen: seq[Choice]): Choice =
  ## One remaining expansion or hostile attack for the closing layer-2 slot.
  result = Choice(score: -1.0e9)
  var hasExpansion = false
  for choice in chosen:
    if choice.id.startsWith("expand:"):
      hasExpansion = true
      break
  for action in actions:
    if action.kind != "attack" or action.riskLevel == "high":
      continue
    var taken = false
    for choice in chosen:
      if choice.id == action.id:
        taken = true
        break
    if taken:
      continue
    if hasExpansion and isExpansion(action):
      continue
    let score = adjustedActionScore(weights, world, memory, action)
    if score > 0.0 and score > result.score:
      result = Choice(
        id: action.id,
        kind: action.kind,
        score: score,
        reason: action.label & " (closing ground companion)"
      )

proc batchedChoices*(weights: Weights, world: Observation, memory: Memory,
    actions: seq[Action], primary: Choice, maxActions: int): seq[Choice] =
  ## Append independently funded economy actions after the scalar choice.
  result = @[primary]
  if maxActions < 2 or world.phase == "spawn" or
      primary.kind notin ["attack", "boat"] or
      world.incomingAttacks > 0 or world.homeDanger == "high":
    return
  if world.ownTileShare >= weights.closingShare:
    if weights.closingGroundBatch:
      let ground = closingGroundCompanion(
        weights, world, memory, actions, result)
      if ground.id.len > 0:
        result.add(ground)
    return
  if weights.economyBatchCount <= 0:
    return
  var best = Choice(score: -1.0e9)
  for action in actions:
    if action.id == primary.id or action.kind != "build" or
        action.riskLevel == "high" or
        metaStr(action, "unit") notin ["City", "Port", "Factory"]:
      continue
    let score = adjustedActionScore(weights, world, memory, action)
    if score > 0.0 and score > best.score:
      best = Choice(
        id: action.id,
        kind: action.kind,
        score: score,
        reason: action.label & " (economy batch companion)"
      )
  if best.id.len > 0 and
      result.len < min(maxActions, weights.economyBatchCount + 1):
    result.add(best)
  if weights.economyBatchCount < 2 or maxActions < 3 or result.len < 2:
    return
  var
    firstUnit = ""
    firstCost = 0.0
  for action in actions:
    if action.id == best.id:
      firstUnit = metaStr(action, "unit")
      firstCost = metaFloat(action, "cost")
      break
  if firstUnit.len == 0 or firstCost <= 0.0 or firstCost > world.gold:
    return
  var second = Choice(score: -1.0e9)
  for action in actions:
    if action.id == primary.id or action.id == best.id or
        action.kind != "build" or action.riskLevel == "high":
      continue
    let
      unit = metaStr(action, "unit")
      cost = metaFloat(action, "cost")
    if unit notin ["City", "Port", "Factory"] or unit == firstUnit or
        cost <= 0.0 or firstCost + cost > world.gold:
      continue
    let score = adjustedActionScore(weights, world, memory, action)
    if score > 0.0 and score > second.score:
      second = Choice(
        id: action.id,
        kind: action.kind,
        score: score,
        reason: action.label & " (second economy batch companion)"
      )
  if second.id.len > 0 and
      result.len < min(maxActions, weights.economyBatchCount + 1):
    result.add(second)

proc rankedActions*(weights: Weights, world: Observation, memory: Memory,
    actions: seq[Action], top = 8): seq[(string, string, float)] =
  ## Debug helper for the offline tools: the top scoring actions in order.
  var scored: seq[(string, string, float)]
  for action in actions:
    scored.add((action.id, action.kind,
      adjustedActionScore(weights, world, memory, action)))
  scored.sort(proc (a, b: (string, string, float)): int = cmp(b[2], a[2]))
  if scored.len > top: scored.setLen(top)
  scored
