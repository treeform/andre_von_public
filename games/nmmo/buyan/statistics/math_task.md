Use read_file/search_replace to WRITE two short Nim files immediately.
You may change only statistics/signs.nim and statistics/signs_tests.nim
under /Users/me/p/andre_von_auto/games/nmmo/buyan. No shell, no other files,
no research or subagents. Supervisor will run nim check/tests.

signs.nim should export:
- BuyanMathError object of CatchableError.
- const LookSizes=[10,30,100,300], PerLookAlpha=0.0025.
- proc signP(wins,losses:int):float. Reject negative counts or total>300.
  Exact two-sided binomial sign test with p=.5, omitting ties. Return1 if
  no non-ties. P=min(1, 2*sum_{i=0}^{min(w,l)} choose(w+l,i)/2^(w+l)).
  Compute start term2^(-n), recurrence term *= (n-i)/(i+1) to accumulate
  tail. n<=300 is safely within float64 exponent range.
- proc supportStatus(n,wins,losses:int,meanDiff:float,
  unresolved:int=0):string. Require n>=wins+losses; nonnegative all counts.
  Nonfinite meanDiff rejected. First status awaiting_completion if unresolved
  positive; then insufficient_data n<10; off_schedule n notin LookSizes;
  negative if meanDiff<=0 or wins<=losses; then supporting_sign_test if
  signP<=.0025; otherwise inconclusive. Never say KEEP. n>300 must return
  off_schedule before signP call.

signs_tests.nim imports signs and std/math; plain doAssert tests only.
Known probabilities: signP(10,0)=.001953125; signP(9,1)=.021484375;
signP(0,0)=1; signP(5,5)=1; signP(300,0)=2^(-299).
Test support at10/30/100/300 all wins, off schedule11/301, n9, all ties,
negative mean, and unresolved. Tests clearly print synthetic math fixtures,
never hosted score. Every proc concise doc comment, const PascalCase,
2 spaces indentation, adjacent let/var grouped. No when isMainModule.
