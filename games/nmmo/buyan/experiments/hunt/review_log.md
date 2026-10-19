# Hunt review log

- Idea: approach isolated rested melee enemies to start combat and acquire a tool.
- Baseline: ../../buyan.nim, current submitted policy copy.
- Worker: Grok CLI, task.md, implementation and Nim isolation verification.
- Initial Grok invocation interrupted before candidate writes after source review
  found player-before-NPC ordering. Revised worker started 2026-09-12 14:19 UTC.
- Navigation correction: walk to distance 2, then wait for NPC to close. Never
  walk adjacent and take a first hit that defeats the baseline rested gate.
- Source: nmmo3.h entity byte 5 is element; neutral NPCs are melee. Enemies
  spawn on grass and level >=15 is ranged/nonzero element. Players act before
  NPCs, and melee attacks only from Manhattan distance 1.
- Baseline `nim check games/nmmo/buyan/buyan.nim`: PASS.
- XP id: pending parent hosted request.
- Opponents: parent will fix the same field for baseline and candidate.
- Verdict: PENDING HOSTED XP. Isolation tests cannot establish score improvement.
