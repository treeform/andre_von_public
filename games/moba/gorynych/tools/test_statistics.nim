{.define: statisticsTest.}
include statistics

echo "Exact permutation distribution"
let probabilities = distribution([0, 0, 2, 2], 2)
doAssert abs(probabilities[0] - 1.0 / 6.0) < 1e-12
doAssert abs(probabilities[2] - 4.0 / 6.0) < 1e-12
doAssert abs(probabilities[4] - 1.0 / 6.0) < 1e-12
doAssert distribution([1, 1, 1, 1], 2)[2] == 1.0

echo "Stratified tail and direction"
var strata = initTable[string, Stratum]()
strata["a"] = Stratum(baseline: @[0, 0], candidate: @[2, 2])
strata["b"] = Stratum(baseline: @[0, 0], candidate: @[2, 2])
let result = compare(strata)
doAssert result.count == 4
doAssert result.baselineMean == 0
doAssert result.candidateMean == 1
doAssert abs(result.probability - 1.0 / 36.0) < 1e-12
strata["b"] = Stratum(baseline: @[2, 2], candidate: @[0, 0])
doAssert compare(strata).probability > 0.5

echo "Unmatched samples fail closed"
strata["b"] = Stratum(baseline: @[2], candidate: @[0, 0])
var rejected = false
try:
  discard compare(strata)
except MobaError:
  rejected = true
doAssert rejected
echo "Statistics checks passed"
