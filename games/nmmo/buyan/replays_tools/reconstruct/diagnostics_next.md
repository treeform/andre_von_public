# Extra diagnostic metrics after initial reconstruction compiles

Work only this reconstruct directory. Nim code/file tools only.
Parent action-only replay summary showed own policy about90% runs and
70deaths per agent, top opponents20-26%runs with2-5deaths. Need identify
failure mode using hosted recorded actions only. Do not make strategy
changes or run alternative actions. Final digest/stats gate preserved.

After basic tool passes add diagnostics as justified by source:
- Idle (=action4) preHP<80 and postHP rise, counts and net recovery.
- Alive run issued by preHP bucket0..19,20..39,40..59,60..79,80..99;
  per bucket run animation matches, no-animation, terminal tick count,
  netHP loss ticks/amount. Do not conflate failed runs and lethal steps.
- True nearby enemy data can come from deployed read-only debug_nearby
  +debug_buf_ptr exports if present, as exact shim.c documents. Radius4
  sufficient for attack threat. Call per alive agent snapshot; parse rows
  int32 dr,dc,comb,ranged,hp. Record before death nearest enemy distance,
  count within1/2/4, strongest nearby level, plus last20 window presence.
  This is omniscient replay analysis, NOT actual policy obs. Cannot assert
  which enemy attacked or was chasing from proximity alone. Label exactly.
  Default flag clean not recorded, so only self scalars/stats/debug count
  used, no stale entity-byte liveness.
- Run failed because first vs second destination terrain blocked can use
  pre obs terrain bytes, no entities. But teleportitis before move means
  pre obs could be old terrain for ~0.1%ticks; don't make ground-truth
  failure attribution without exact r/c. Better skip for bounded first pass.

Also create aggregate.nim CLI <baseline-index.json> <report-dir> <out.json>:
index uses episode_request_id, local_path, policy_version_ids. Read each
report-dir/<episode_request_id>.json; require verified gates. Group agents
by policy version using pid div heroes. Summary counts of episodes,
agentEpisodes, live ticks, run attempted/noanimation, deaths by cause,
netHP loss, within20 death windows with run failure and nearby enemies,
idle recovery, tool presence. Do not emit scores or significance.
Episode groups and agent counts must be explicit to avoid independence
assumptions. No final KEEP or strategy recommendation based on means.
