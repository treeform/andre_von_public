# Mandatory review corrections

Before finalizing read this correction file plus task.md again.

1. `find_target` sets attack animation BEFORE target search, so animation
   doesn't establish target/hit. Use `attack_animation`, never attack_fired,
   and explicitly describe as branch/animation only. For movement the anim
   assignment occurs only after destination checks, so walk/run succeeded
   interpretation is supported on nonterminal, live, play-mode intervals.
2. The deployed nmmo3_sim.wasm is now here. SHA256 is
   299e7759936e3b10c8f8869d2212c1f13157e11e4123ab836b523d30d3d26a30,
   matching current baseline replay header. Source export ABI and runtime
   are exact; final digest check remains required.
3. Clean observation opt-in isn't recorded in action replay. Reconstruction
   default is legacy tile bytes. Self scalars and sim stats are unaffected
   by clean opt-in, and these are the only fields our report uses. Say so
   in usage/output limitations; don't claim full clean observation equality.
4. Please stop rereading full references and write implementation now.
   Use only file read/edit tools, no terminal. Supervisor runs checks.
