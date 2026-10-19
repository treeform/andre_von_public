## Replay-derived priors for named Proxy War opponents.

import std/strutils

type
  OpponentKind* = enum
    UnknownOpponent
    DaveeyOpponent
    JordanOpponent
    MickeyOpponent
    ZeroOpponent
    SianOpponent
    MattOpponent

  OpponentPrior* = object
    kind*: OpponentKind
    winRate*: float
    aggression*: float
    persistence*: float
    weakerTargetRate*: float

const
  SmallDefault = OpponentPrior(
    kind: UnknownOpponent,
    winRate: 0.2824,
    aggression: 0.3145,
    persistence: 0.2077,
    weakerTargetRate: 0.3845
  )
  SmallDaveey = OpponentPrior(
    kind: DaveeyOpponent,
    winRate: 0.5069,
    aggression: 0.4581,
    persistence: 0.3384,
    weakerTargetRate: 0.3400
  )
  SmallJordan = OpponentPrior(
    kind: JordanOpponent,
    winRate: 0.1852,
    aggression: 0.1754,
    persistence: 0.0617,
    weakerTargetRate: 0.4091
  )
  SmallMickey = OpponentPrior(
    kind: MickeyOpponent,
    winRate: 0.1551,
    aggression: 0.3100,
    persistence: 0.2230,
    weakerTargetRate: 0.4045
  )
  SmallZero = OpponentPrior(
    kind: ZeroOpponent,
    winRate: SmallDefault.winRate,
    aggression: SmallDefault.aggression,
    persistence: SmallDefault.persistence,
    weakerTargetRate: SmallDefault.weakerTargetRate
  )
  SmallSian = OpponentPrior(
    kind: SianOpponent,
    winRate: SmallDefault.winRate,
    aggression: SmallDefault.aggression,
    persistence: SmallDefault.persistence,
    weakerTargetRate: SmallDefault.weakerTargetRate
  )
  LargeDefault = OpponentPrior(
    kind: UnknownOpponent,
    winRate: 0.0937,
    aggression: 0.2285,
    persistence: 0.1140,
    weakerTargetRate: 0.5581
  )
  LargeDaveey = OpponentPrior(
    kind: DaveeyOpponent,
    winRate: 0.1111,
    aggression: 0.2183,
    persistence: 0.1363,
    weakerTargetRate: 0.4655
  )
  LargeJordan = OpponentPrior(
    kind: JordanOpponent,
    winRate: 0.1143,
    aggression: 0.2285,
    persistence: 0.0941,
    weakerTargetRate: 0.5874
  )
  LargeMickey = OpponentPrior(
    kind: MickeyOpponent,
    winRate: 0.0556,
    aggression: 0.2387,
    persistence: 0.1115,
    weakerTargetRate: 0.6214
  )
  LargeZero = OpponentPrior(
    kind: ZeroOpponent,
    winRate: 0.05,
    aggression: 0.22,
    persistence: 0.10,
    weakerTargetRate: 0.68
  )
  LargeSian = OpponentPrior(
    kind: SianOpponent,
    winRate: 0.00,
    aggression: 0.24,
    persistence: 0.08,
    weakerTargetRate: 0.68
  )

proc opponentKind*(name: string): OpponentKind =
  ## Map the in-game name to a measured opponent identity.
  let key = name.strip().toLowerAscii()
  if key == "daveey" or key.startsWith("daveey ("):
    return DaveeyOpponent
  if key == "jordan" or key.startsWith("jordan ("):
    return JordanOpponent
  if key == "k1z mickey mouse" or key.startsWith("k1z mickey mouse ("):
    return MickeyOpponent
  if key == "0d1novizzz" or key.startsWith("0d1novizzz ("):
    return ZeroOpponent
  if key == "sian voidcrown" or key.startsWith("sian voidcrown ("):
    return SianOpponent
  if key == "matt van" or key.startsWith("matt van ("):
    return MattOpponent
  UnknownOpponent

proc opponentPrior*(name: string, alivePlayerCount: int): OpponentPrior =
  ## Select the name prior for the current field size.
  let kind = opponentKind(name)
  if alivePlayerCount <= 4:
    case kind
    of DaveeyOpponent: SmallDaveey
    of JordanOpponent: SmallJordan
    of MickeyOpponent: SmallMickey
    of ZeroOpponent: SmallZero
    of SianOpponent: SmallSian
    of MattOpponent: SmallDefault
    of UnknownOpponent: SmallDefault
  else:
    case kind
    of DaveeyOpponent: LargeDaveey
    of JordanOpponent: LargeJordan
    of MickeyOpponent: LargeMickey
    of ZeroOpponent: LargeZero
    of SianOpponent: LargeSian
    of MattOpponent: LargeDefault
    of UnknownOpponent: LargeDefault

proc targetPriorScore*(prior: OpponentPrior, troopRatio: float,
    countering: bool): float =
  ## Score target value, retaliation risk, and counterattack urgency.
  result = 20.0 * prior.winRate + 12.0 * (1.0 - prior.persistence)
  if troopRatio < 1.0:
    result -= 25.0 * prior.aggression
    result -= 15.0 * prior.persistence
    result -= 10.0 * prior.weakerTargetRate
  if countering:
    result += 20.0 * prior.aggression
    result += 12.0 * prior.persistence

proc targetAvoidScore*(prior: OpponentPrior, troopRatio: float,
    countering: bool): float =
  ## Prefer farmable rivals while still answering the active invader.
  result = 20.0 * (1.0 - prior.winRate) +
    14.0 * (1.0 - prior.persistence) +
    6.0 * (1.0 - prior.aggression)
  if troopRatio < 1.0:
    result -= 30.0 * prior.winRate
    result -= 20.0 * prior.aggression
    result -= 20.0 * prior.persistence
  if countering:
    result += 20.0 * prior.winRate
    result += 35.0 * prior.aggression
    result += 30.0 * prior.persistence
