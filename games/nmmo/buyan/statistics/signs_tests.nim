import std/math
import signs

echo "synthetic math fixtures, never hosted score"
echo "signP(10, 0) = 0.001953125"
doAssert signP(10, 0) == 0.001953125
echo "signP(9, 1) = 0.021484375"
doAssert signP(9, 1) == 0.021484375
echo "signP(0, 0) = 1"
doAssert signP(0, 0) == 1.0
echo "signP(5, 5) = 1"
doAssert signP(5, 5) == 1.0
echo "signP(300, 0) = 2^(-299)"
doAssert signP(300, 0) == pow(2.0, -299.0)

echo "supportStatus synthetic all-wins looks 10/30/100/300"
doAssert supportStatus(10, 10, 0, 1.0) == "supporting_sign_test"
doAssert supportStatus(30, 30, 0, 1.0) == "supporting_sign_test"
doAssert supportStatus(100, 100, 0, 1.0) == "supporting_sign_test"
doAssert supportStatus(300, 300, 0, 1.0) == "supporting_sign_test"

echo "supportStatus synthetic off-schedule n=11 and n=301"
doAssert supportStatus(11, 11, 0, 1.0) == "off_schedule"
doAssert supportStatus(301, 301, 0, 1.0) == "off_schedule"

echo "supportStatus synthetic n=9 insufficient_data"
doAssert supportStatus(9, 9, 0, 1.0) == "insufficient_data"

echo "supportStatus synthetic all ties"
doAssert supportStatus(10, 0, 0, 1.0) == "negative"

echo "supportStatus synthetic negative mean"
doAssert supportStatus(10, 10, 0, -1.0) == "negative"

echo "supportStatus synthetic unresolved"
doAssert supportStatus(10, 10, 0, 1.0, 1) == "awaiting_completion"

echo "synthetic error fixture signP(high(int), high(int))"
block:
  var
    raised = false
    overflowed = false
  try:
    discard signP(high(int), high(int))
  except BuyanMathError:
    raised = true
  except OverflowDefect:
    overflowed = true
  doAssert raised
  doAssert not overflowed

echo "synthetic error fixture supportStatus(high(int), high(int), high(int), 1.0)"
block:
  var
    raised = false
    overflowed = false
  try:
    discard supportStatus(high(int), high(int), high(int), 1.0)
  except BuyanMathError:
    raised = true
  except OverflowDefect:
    overflowed = true
  doAssert raised
  doAssert not overflowed
