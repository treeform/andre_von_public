import std/math

const
  LookSizes* = [10, 30, 100, 300]
  PerLookAlpha* = 0.0025

type
  BuyanMathError* = object of CatchableError

proc signP*(wins, losses: int): float {.raises: [BuyanMathError].} =
  ## Exact two-sided binomial sign test at p = 0.5, omitting ties.
  if wins > 300 or losses > 300:
    raise newException(BuyanMathError, "invalid sign counts")
  if wins < 0 or losses < 0 or wins + losses > 300:
    raise newException(BuyanMathError, "invalid sign counts")
  let
    n = wins + losses
    k = min(wins, losses)
  if n == 0:
    return 1.0
  var
    term = pow(2.0, -n.float)
    tail = term
  for i in 0 ..< k:
    term *= (n - i).float / (i + 1).float
    tail += term
  result = min(1.0, 2.0 * tail)

proc supportStatus*(n, wins, losses: int, meanDiff: float,
    unresolved: int = 0): string {.raises: [BuyanMathError].} =
  ## Sequential-look status from sample size, sign counts, and mean difference.
  if n < 0 or wins < 0 or losses < 0 or unresolved < 0:
    raise newException(BuyanMathError, "invalid counts")
  if wins > n or losses > n - wins:
    raise newException(BuyanMathError, "invalid counts")
  if classify(meanDiff) in {fcNan, fcInf, fcNegInf}:
    raise newException(BuyanMathError, "nonfinite meanDiff")
  if unresolved > 0:
    result = "awaiting_completion"
  elif n < 10:
    result = "insufficient_data"
  elif n notin LookSizes:
    result = "off_schedule"
  elif meanDiff <= 0 or wins <= losses:
    result = "negative"
  elif signP(wins, losses) <= PerLookAlpha:
    result = "supporting_sign_test"
  else:
    result = "inconclusive"
