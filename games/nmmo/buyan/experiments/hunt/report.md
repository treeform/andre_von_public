# Hunt

- Change: rested isolated live neutral melee pursuit. Walk at distance 3-4,
  stage at distance 2 for at most two waits, then original combat/flee logic.
- Refuse stale/corpse/ranged/stronger/crowded targets, wounded/combat self,
  full inventory, or pending equipment. UI/heal/adjacent fight/tool grab intact.
- Why stage: players act before NPCs. Entering adjacency first gives NPC a hit
  and defeats the unchanged rested combat gate. Letting NPC close avoids that.
- Frozen candidate: candidate.nim. Added navigation and bounded telemetry only.
- Verification: nim check candidate.nim PASS; Nim reviewer_tests PASS.
- Synthetic wire test: issue tick41, action2 versus baseline24; moved42;
  combat43; combatLevel+1 and tool+1 at44. Reset clears pending diagnostics.
- Activation: issued JSON event with changed=true, matched to replay action.
  Never filter score by eventual combat, tool acquisition, success, or death.
- Diagnostic events: moved, combat, combatLevel, tool; amount and issuedTick.
  At most 10 decisions of attribution. These prove observation changes after
  pursuit, not exclusive causal credit for a particular NPC.
- Grok: implementation attempts stalled/researched without patch. Parent
  authorized supervisor Nim fallback; Grok final verification requested.
- XP id/opponents: pending hosted request after parent commit/push.
- Verdict: PENDING HOSTED XP. No score from local games; nothing kept/submitted.
