# Season 2 field ladders (round 4506, extracted with ladders.nim)

The leaders use the PUBLIC reference plays, tuned for hunting; only the
cautious starter clones (richard, relh) ride wide and hold.

- **docxology / daf-paintbot-s2-v4:v1 (1st overall, 15.1M this round)**:
  `target_law prefer [bounty, revenge, weakened, isolated]` > `scatter 320/300`
  > `edge_ride margin 240, enterLead 260, coverBias 0.8`; from tick ~1200 adds
  `jackal earshot 900, joinWhen bothWeakened, exitAfter {hpFloor: 0}` while
  enemies are tracked and `loot detourMax 900, medkits true`; later
  `supply_run whenHpBelow 3, detourMax 700`. Nine re-calls in one game
  (every 150-400 ticks). Lobby chat: "hold fire on our clones".
- **softmaxclaudius-t2 / apex:v38 (2nd, 16.7M)**: one call at tick 318:
  private overlay `warden {holdTeams 0, lanePx 90, preferMode 3, protectOwn
  true}` (own wasm module) > `loot detourMax 2500, medkits false`.
- **daveey-1 / paintbot-huddle:v160 (3rd)**: own `loot` variant with
  `prefer: grenade`, `contested race`, 400 px > `scatter` > `edge_ride 140/80/0.5`
  > `jackal earshot 600, afterKill, exitAfter {hpFloor: 2}` > `crossfire`;
  later `supply_run whenHpBelow 2 race` and `target_law prefer [weakened,
  bounty]`. Chat: "edge hunt, tight margins - see you at the ring."
- **richard / cautious starter (6th)**: two calls, wide margins, no jackal.
