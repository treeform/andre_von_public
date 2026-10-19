Patch existing candidate.nim NOW. Scope only this hunt directory. Nim only.
Do not research, no shell. You have read_file and search_replace tools only.
Baseline is already copied. Previous Grok resumed session stalled 7 minutes.
Supervisor will execute Nim checks, then give you outputs to verify.

Minimal ONE hunt navigation strategy:
- Insert narrow hunt branch after existing tool-grab, before disengage.
- Require hp >= fightStartHealth, not inCombat, no equipAction pending,
  nonfull inventory. Existing UI/heal/adjacent fight/tool grab stay unchanged.
- Collect mind.liveHints(p). Require exactly one hint in entire visible window
  (conservative isolation), deltaCombat==0, entity byte5==0 (neutral melee).
- Require Manhattan distance 2..4. At 2 issue noopAction, max2 consecutive
  stage waits; then use baseline flee. At 3..4 choose a passable single walk
  decreasing Manhattan distance while remaining >=2 (no run).
- Add Mind huntWaits integer; reset to0 in reset and when no hunt eligibility.
- Add optional huntEnabled=true to decide. For accepted hunt action, fresh
  Mind copy with baseline[]=mind[]; baseline.decide(p,false) obtains action
  before huntWaits mutation. Counterfactual must not log/mutate actual state.
- Add optional tick:int=-1 to act, store currentTick in Mind, main passes
  parsed["tick"].getInt(). Log one stdout JSON per hunt issue exactly:
  {"experiment":"hunt","event":"issued","tick":T,"agent":I,
   "generation":G,"action":A,"baselineAction":B,"kind":"walk" or
   "stage","changed":A!=B,"r":R,"c":C}.
- Keep current combat thresholds/equipment/clean observation/priorities intact.
- Gate last main() with when not defined(buyanTest).

Add compact diagnostic counters only if fast: since hunt issue, actual
movement (next scalarAnim move) / fresh combat onset / combatLevel increase /
best inventory tool tier increase, all are confirmations not score filter.
Bound observation attribution to10 decisions. Issued difference is activation,
regardless of success. New proc doc comments required. Nim only.

Write tests.nim include candidate, doAssert: isolatedlive melee walk/stage,
two waits then baseline, corpse/ghost/stronger/ranged/crowd rejects, heal/UI
and adjacentfight/toolgrab priorities, no unsafe walk-adjacent, baseline RNG
unmodified, issue JSON exact action/baseline difference. No scored games.
Write short report.md PENDING HOSTED XP, no invented test claims.
