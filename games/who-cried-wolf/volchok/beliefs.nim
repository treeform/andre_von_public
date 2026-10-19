## Who Cried Wolf beliefs: roles, NewD3 decks, what one seat knows, and the
## exact wolf posterior. The posterior enumerates every deck and dealing
## consistent with the hard facts (own role, team, death reveals, private
## results) and weights each dealing by how likely the public ballots are
## under it: wolves abstain less than town and almost never vote a
## packmate. With `averaged` the abstain rates are not fixed: every town
## and wolf rate pair on AbstainGrid (wolves abstaining less) is averaged
## in, so each game fits its own field. With `aimed` a town ballot is not
## uniform either: it lands on a wolf with weight `aim` against 1 for a
## townsperson, averaged over AimGrid (LLM towns aim above chance, older
## bots at or below it). With `accusations` the social graph counts too:
## every public accusation (who points at whom, once per day) is weighed
## like a ballot, town accusers aiming at wolves and wolves sparing their
## packmate, so whoever accuses a cleared player looks wolfish and whoever
## accuses them looks clearer. An optional kill term also weights who the
## wolves chose to kill each night by that victim's ballot that day
## (wolves hunt voters, most of all those who voted a wolf). Shared by the
## policy and the calibration tools.

import std/math

const
  Seats* = 9

type
  Role* = enum
    Wolf, Alchemist, TrackReader, Seer, Guard, Chef, DairyMaid, Priest,
    Noble, Sheep, Jester

  Ballot* = object
    voter*: int
    target*: int

  VoteDay* = object
    day*: int
    ballots*: seq[Ballot]

  Accusation* = object
    day*: int
    speaker*: int
    target*: int

  VoteModel* = object
    enabled*: bool
    townAbstain*: float
    wolfAbstain*: float
    packWeight*: float
    killWeights*: array[3, float]
    averaged*: bool
    aimed*: bool
    accusations*: bool

  Knowledge* = object
    episode*: string
    slot*: int
    role*: Role
    day*: int
    alive*: array[Seats, bool]
    names*: array[Seats, string]
    fixed*: array[Seats, int]
    wolfSide*: array[Seats, int]
    active*: array[Seats, bool]
    wolfHint*: array[Seats, float]
    deathCause*: array[Seats, string]
    deathDay*: array[Seats, int]
    pack*: seq[int]
    inspected*: array[Seats, bool]
    checked*: array[Seats, int]
    tracked*: array[Seats, bool]
    priestCatch*: int
    priestVictim*: int
    votes*: seq[VoteDay]
    accusations*: seq[Accusation]

const
  RoleIds*: array[Role, string] = [
    "wolf", "alchemist", "track_reader", "seer", "guard", "chef",
    "dairy_maid", "priest", "noble", "sheep", "jester"
  ]
  RoleLabels*: array[Role, string] = [
    "Wolf", "Alchemist", "Track Reader", "Seer", "Guard", "Chef",
    "Dairy Maid", "Priest", "Noble", "Sheep", "Trickster"
  ]
  WolfRoles* = {Wolf, Alchemist, TrackReader}
  VisitRoles* = {
    Wolf, Alchemist, TrackReader, Seer, Guard, Chef, DairyMaid, Priest
  }
  ThreatRoles* = [Seer, Priest, Guard, Chef, DairyMaid, Noble]
  Decks*: array[9, array[Seats, Role]] = [
    [Wolf, Alchemist, Seer, Guard, Sheep, Sheep, Sheep, Sheep, Sheep],
    [Wolf, Alchemist, Chef, Priest, Sheep, Sheep, Sheep, Sheep, Sheep],
    [Wolf, Alchemist, Noble, Noble, Sheep, Sheep, Sheep, Sheep, Sheep],
    [Wolf, TrackReader, Priest, DairyMaid, Sheep, Sheep, Sheep, Sheep,
      Sheep],
    [Wolf, TrackReader, Chef, DairyMaid, Sheep, Sheep, Sheep, Sheep, Sheep],
    [Wolf, TrackReader, Priest, Guard, Sheep, Sheep, Sheep, Sheep, Sheep],
    [Wolf, Wolf, Seer, Sheep, Sheep, Sheep, Sheep, Sheep, Sheep],
    [Wolf, Wolf, Chef, Sheep, Sheep, Sheep, Sheep, Sheep, Sheep],
    [Wolf, Wolf, Noble, Noble, Sheep, Sheep, Sheep, Sheep, Sheep]
  ]
  AbstainGrid* = [0.02, 0.2, 0.4, 0.6, 0.8, 0.95, 0.99]
  AimGrid* = [0.5, 1.0, 2.0, 4.0]
  NoVotes* = VoteModel(enabled: false)
  BallotModel* = VoteModel(
    enabled: true,
    townAbstain: 0.52,
    wolfAbstain: 0.23,
    packWeight: 0.17,
    averaged: true,
    aimed: true,
    accusations: true
  )

proc parseRole*(text: string): Role =
  ## Maps a protocol role id to a Role, defaulting to Sheep.
  for role in Role:
    if RoleIds[role] == text:
      return role
  Sheep

proc newKnowledge*(slot: int, role: Role): Knowledge =
  ## Returns a seat's knowledge before anything has happened.
  result.slot = slot
  result.role = role
  result.priestCatch = -1
  result.priestVictim = -1
  for i in 0 ..< Seats:
    result.alive[i] = true
    result.fixed[i] = -1
    result.wolfSide[i] = -1
    result.checked[i] = -1
    result.deathDay[i] = -1
    result.wolfHint[i] = 1.0
    result.names[i] = "Player " & $(i + 1)
  result.fixed[slot] = role.ord
  result.wolfSide[slot] = ord(role in WolfRoles)

proc fix*(k: var Knowledge, slot: int, role: Role) =
  ## Records a seat's role as certain.
  k.fixed[slot] = role.ord
  k.wolfSide[slot] = ord(role in WolfRoles)

proc factorial(n: int): float =
  ## Returns n! as a float.
  result = 1.0
  for i in 2 .. n:
    result *= i.float

proc ballotLikelihood(
  k: Knowledge,
  model: VoteModel,
  wolves: array[Seats, bool]
): float =
  ## Probability of every public ballot except ours under one wolf set.
  result = 1.0
  if not model.enabled:
    return
  if model.killWeights[0] > 0:
    for victim in 0 ..< Seats:
      if k.deathCause[victim] != "wolf":
        continue
      for round in k.votes:
        if round.day != k.deathDay[victim]:
          continue
        var
          total = 0.0
          chosen = 0.0
        for ballot in round.ballots:
          let u = ballot.voter
          if wolves[u] or
            (k.deathCause[u] == "vote" and k.deathDay[u] == round.day):
              continue
          let category =
            if ballot.target < 0: 2
            elif wolves[ballot.target]: 0
            else: 1
          total += model.killWeights[category]
          if u == victim:
            chosen = model.killWeights[category]
        if total > 0 and chosen > 0:
          result *= chosen / total
  var
    wolfAbstains, wolfVotes, townAbstains, townVotes = 0
    aims: seq[(bool, int, int)]
  for round in k.votes:
    let others = round.ballots.len - 1
    if others < 1:
      continue
    for ballot in round.ballots:
      if ballot.voter == k.slot:
        continue
      if wolves[ballot.voter]:
        if ballot.target < 0:
          inc wolfAbstains
          continue
        inc wolfVotes
        var total = 0.0
        for other in round.ballots:
          if other.voter != ballot.voter:
            total += (if wolves[other.voter]: model.packWeight else: 1.0)
        let weight =
          if wolves[ballot.target]: model.packWeight else: 1.0
        result *= weight / total
      else:
        if ballot.target < 0:
          inc townAbstains
        else:
          inc townVotes
          if model.aimed:
            var wolfOthers = 0
            for other in round.ballots:
              if other.voter != ballot.voter and wolves[other.voter]:
                inc wolfOthers
            aims.add (wolves[ballot.target], wolfOthers, others - wolfOthers)
          else:
            result /= others.float
  proc rates(town, wolf: float): float =
    ## Probability of the abstain and vote counts under one rate pair.
    pow(wolf, wolfAbstains.float) * pow(1 - wolf, wolfVotes.float) *
      pow(town, townAbstains.float) * pow(1 - town, townVotes.float)
  if model.accusations and k.accusations.len > 0:
    var aimSum = 0.0
    for aim in AimGrid:
      var factor = 1.0
      for accusation in k.accusations:
        if accusation.speaker == k.slot:
          continue
        var wolfOthers, townOthers = 0
        for u in 0 ..< Seats:
          if u != accusation.speaker and
            (k.deathDay[u] < 0 or k.deathDay[u] >= accusation.day):
              if wolves[u]:
                inc wolfOthers
              else:
                inc townOthers
        if wolves[accusation.speaker]:
          let weight =
            if wolves[accusation.target]: model.packWeight else: 1.0
          factor *= weight /
            (wolfOthers.float * model.packWeight + townOthers.float)
        else:
          let weight = if wolves[accusation.target]: aim else: 1.0
          factor *= weight / (wolfOthers.float * aim + townOthers.float)
      aimSum += factor
    result *= aimSum / AimGrid.len.float
  if model.aimed:
    var aimSum = 0.0
    for aim in AimGrid:
      var factor = 1.0
      for (hit, wolfOthers, townOthers) in aims:
        factor *= (if hit: aim else: 1.0) /
          (wolfOthers.float * aim + townOthers.float)
      aimSum += factor
    result *= aimSum / AimGrid.len.float
  if not model.averaged:
    result *= rates(model.townAbstain, model.wolfAbstain)
    return
  var
    sum = 0.0
    pairs = 0
  for town in AbstainGrid:
    for wolf in AbstainGrid:
      if wolf < town:
        sum += rates(town, wolf)
        inc pairs
  result *= sum / pairs.float

proc posterior*(
  k: Knowledge,
  model: VoteModel = BallotModel
): array[Seats, float] =
  ## Exact wolf probability per slot over every NewD3 deck and dealing.
  var
    total = 0.0
    mass: array[Seats, float]
    unknown: seq[int]
    cache: array[512, float]
  for mask in 0 ..< 512:
    cache[mask] = -1
  for i in 0 ..< Seats:
    if k.fixed[i] < 0:
      unknown.add i
  for deck in Decks:
    var counts: array[Role, int]
    for role in deck:
      inc counts[role]
    var weight = 1.0
    for role in Role:
      weight *= factorial(counts[role])
    var possible = true
    for i in 0 ..< Seats:
      if k.fixed[i] >= 0:
        let role = Role(k.fixed[i])
        dec counts[role]
        if counts[role] < 0:
          possible = false
    if not possible:
      continue
    var assigned: array[Seats, Role]
    for i in 0 ..< Seats:
      if k.fixed[i] >= 0:
        assigned[i] = Role(k.fixed[i])
    proc visit(at: int, w: float) =
      ## Deals the remaining roles to unknown slots, depth first.
      if at == unknown.len:
        var
          wolves: array[Seats, bool]
          mask = 0
        for i in 0 ..< Seats:
          if assigned[i] in WolfRoles:
            wolves[i] = true
            mask = mask or (1 shl i)
        if cache[mask] < 0:
          cache[mask] = k.ballotLikelihood(model, wolves)
        let leaf = w * cache[mask]
        total += leaf
        for i in 0 ..< Seats:
          if wolves[i]:
            mass[i] += leaf
        return
      let i = unknown[at]
      for role in Role:
        if counts[role] == 0:
          continue
        let wolfish = role in WolfRoles
        if k.wolfSide[i] >= 0 and k.wolfSide[i] != ord(wolfish):
          continue
        if k.active[i] and role notin VisitRoles:
          continue
        dec counts[role]
        assigned[i] = role
        visit(at + 1, if wolfish: w * k.wolfHint[i] else: w)
        inc counts[role]
    visit(0, weight)
  if total > 0:
    for i in 0 ..< Seats:
      result[i] = mass[i] / total
    return
  var
    wolves = 2
    open: seq[int]
  for i in 0 ..< Seats:
    if k.wolfSide[i] == 1:
      result[i] = 1.0
      dec wolves
    elif k.wolfSide[i] < 0 and k.alive[i]:
      open.add i
  for i in open:
    result[i] = max(0, wolves).float / open.len.float
