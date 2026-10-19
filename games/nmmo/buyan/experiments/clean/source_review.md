# Clean observation support review

Status: source review only. No hosted activation or score evidence yet.

- `sims/nmmo/docs/PROTOCOL.md:16` documents per-seat `obs=clean`.
- `sims/nmmo/server/cogame_nmmo/server.py:377` accepts the request.
- `sims/nmmo/server/cogame_nmmo/sim.py:123` looks up the WASM export.
  Missing export prints `obs=clean request ignored` and returns. A server
  connection log containing `[obs=clean]` alone does not prove support.
- `sims/nmmo/sim/patches/0003-obs-clean-optin.patch:48` zeros empty
  cells' bytes 4 through 9 in clean mode.
- Legacy `sims/nmmo/vendor/upstream/nmmo3.h:959` only writes those bytes
  when the cell contains an entity. Live types are 1 (player) and 2
  (enemy), assigned at lines 1786 and 1811. No normal live entity has
  type zero, and legacy empty cells do not clear prior nonzero types.

Consequently, observing one same-window nonzero entity type become six
zero entity bytes between observations within one life is positive clean
support evidence. First observations and reset boundaries must not count.
The candidate must retain legacy trust until this witness occurs.

Hosted acceptance requires both confirmed support and positive changed
decisions. Count only episodes with activation evidence in player logs.
Missing support or zero decisions changed makes a score delta irrelevant
to this strategy. Compare to the submitted policy using the same hosted
opponent field, at least ten activated episodes, and the dashboard's
significance gate. A trust-only shadow over clean input is diagnostic,
not a reconstruction of the old policy's stale observation stream.
