## Offline calibration of Volchok's wolf posterior on cached replays.
##
##   nim r --hints:off games/who-cried-wolf/tools/wcw_reads.nim [replay files]
##
## With no arguments it reads every replay in games/who-cried-wolf/eps/cache.
## For every town seat at every day's vote it rebuilds what that seat knew
## just before the ballots closed (own role, Noble mates, death reveals,
## its private results, earlier ballots) and scores the game's `read`
## bonus for the posterior with the ballot model off and on. This proves
## the model fires and is calibrated; it is not the score.

import
  std/[json, os, strutils],
  ../volchok/beliefs

type
  Trial = object
    name: string
    model: VoteModel
    total: float
    days: int
    games: seq[float]

proc readSkill(
  k: Knowledge,
  beliefs: array[Seats, float],
  living: seq[int],
  wolves: array[Seats, bool]
): float =
  ## Returns the game's read score for one report.
  var
    others: seq[int]
    count = 0
  for slot in living:
    if slot != k.slot:
      others.add slot
      if wolves[slot]:
        inc count
  if others.len == 0:
    return 0
  let chance = count.float / others.len.float
  var ours, base = 0.0
  for slot in others:
    let truth = float(wolves[slot])
    ours += (beliefs[slot] - truth) * (beliefs[slot] - truth)
    base += (chance - truth) * (chance - truth)
  if base <= 0:
    return 0
  max(0.0, 1 - ours / base)

proc score(path: string, trials: var seq[Trial]) =
  ## Adds one replay's town reports to every trial.
  let data = parseFile(path)
  var
    roles: array[Seats, Role]
    wolves: array[Seats, bool]
    seats: array[Seats, Knowledge]
    started = false
  for event in data{"events"}:
    let payload = event{"payload"}
    if payload{"kind"}.getStr() == "roles":
      for row in payload{"roles"}:
        let slot = row{"slot"}.getInt()
        roles[slot] = parseRole(row{"role"}.getStr())
        wolves[slot] = roles[slot] in WolfRoles
      started = true
  if not started:
    return
  for slot in 0 ..< Seats:
    seats[slot] = newKnowledge(slot, roles[slot])
    if roles[slot] == Noble:
      for other in 0 ..< Seats:
        if roles[other] == Noble:
          seats[slot].fix(other, Noble)
  var sums = newSeq[float](trials.len)
  var counts = 0
  for event in data{"events"}:
    let
      payload = event{"payload"}
      day = event{"day"}.getInt()
    case payload{"kind"}.getStr()
    of "ballots":
      var
        living: seq[int]
        round = VoteDay(day: day)
      for ballot in payload{"ballots"}:
        let voter = ballot{"slot"}.getInt()
        living.add voter
        let target =
          if ballot{"target"}.kind == JInt: ballot{"target"}.getInt() else: -1
        round.ballots.add Ballot(voter: voter, target: target)
      for slot in living:
        if wolves[slot]:
          continue
        seats[slot].day = day
        for t, trial in trials.mpairs:
          let skill = seats[slot].readSkill(
            seats[slot].posterior(trial.model),
            living,
            wolves
          )
          trial.total += skill
          inc trial.days
          sums[t] += skill
        inc counts
      for slot in 0 ..< Seats:
        seats[slot].votes.add round
    of "speech":
      let
        speech = payload{"speech"}
        speaker = speech{"slot"}.getInt()
      if speech{"accusation"}.kind == JInt:
        let accusation = Accusation(
          day: day,
          speaker: speaker,
          target: speech{"accusation"}.getInt()
        )
        for seat in seats.mitems:
          if accusation notin seat.accusations:
            seat.accusations.add accusation
    of "elimination":
      let slot = payload{"slot"}.getInt()
      for seat in seats.mitems:
        seat.alive[slot] = false
        seat.deathCause[slot] = payload{"cause"}.getStr()
        seat.deathDay[slot] = day
        if payload{"role"} != nil and payload{"role"}.kind == JString:
          seat.fix(slot, parseRole(payload{"role"}.getStr()))
    of "private_result":
      let
        slot = payload{"slot"}.getInt()
        result = payload{"result"}
        target = result{"target"}.getInt()
      case result{"ability"}.getStr()
      of "inspect":
        if result{"result"}.getStr() == "wolf":
          seats[slot].wolfSide[target] = 1
        elif result{"result"}.getStr() == "not_wolf":
          seats[slot].wolfSide[target] = 0
      of "inform":
        seats[slot].fix(target, DairyMaid)
      of "track":
        let visits = result{"result"}
        if visits.kind == JArray and visits.len > 0:
          seats[slot].active[target] = true
          for visit in visits:
            let v = visit.getInt()
            if seats[slot].deathCause[v] == "wolf" and
              seats[slot].deathDay[v] == result{"day"}.getInt():
                seats[slot].wolfHint[target] = 3.0
      else:
        discard
    else:
      discard
  if counts > 0:
    for t, trial in trials.mpairs:
      trial.games.add sums[t] / counts.float

proc main() =
  ## Scores every trial model over the chosen replays.
  var paths: seq[string]
  for argument in commandLineParams():
    paths.add argument
  if paths.len == 0:
    for path in walkFiles("games/who-cried-wolf/eps/cache/*.replay"):
      paths.add path
  var trials = @[
    Trial(name: "no ballots", model: NoVotes),
    Trial(name: "fixed rates (v3)", model: VoteModel(
      enabled: true,
      townAbstain: 0.52,
      wolfAbstain: 0.23,
      packWeight: 0.17
    )),
    Trial(name: "ballot model", model: BallotModel),
    Trial(name: "ballots + kills", model: VoteModel(
      enabled: true,
      townAbstain: BallotModel.townAbstain,
      wolfAbstain: BallotModel.wolfAbstain,
      packWeight: BallotModel.packWeight,
      killWeights: [1.32, 1.15, 0.81]
    )),
    Trial(name: "averaged rates", model: VoteModel(
      enabled: true,
      packWeight: BallotModel.packWeight,
      averaged: true
    )),
    Trial(name: "averaged + aim", model: VoteModel(
      enabled: true,
      packWeight: BallotModel.packWeight,
      averaged: true,
      aimed: true
    )),
    Trial(name: "aim + accusations", model: VoteModel(
      enabled: true,
      packWeight: BallotModel.packWeight,
      averaged: true,
      aimed: true,
      accusations: true
    ))
  ]
  for townAbstain in [0.4, 0.52, 0.65]:
    for wolfAbstain in [0.15, 0.3]:
      for packWeight in [0.1, 0.3, 0.6]:
        trials.add Trial(
          name: "t" & $townAbstain & " w" & $wolfAbstain & " p" & $packWeight,
          model: VoteModel(
            enabled: true,
            townAbstain: townAbstain,
            wolfAbstain: wolfAbstain,
            packWeight: packWeight
          )
        )
  for path in paths:
    score(path, trials)
  echo paths.len, " replays"
  echo "model                     reports   read  wins vs none"
  for trial in trials:
    var wins = 0
    for i, game in trial.games:
      if game > trials[0].games[i] + 1e-9:
        inc wins
      elif game < trials[0].games[i] - 1e-9:
        dec wins
    echo trial.name.alignLeft(24), " ", ($trial.days).align(8), " ",
      formatFloat(trial.total / max(1, trial.days).float, ffDecimal, 4),
      " ", ($wins).align(5)

main()
