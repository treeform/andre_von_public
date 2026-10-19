Implement a faithful Nim port of the published pretrained NMMO MMONet as
one decision-engine replacement. Parent directly supervises Grok; no
subagents. Write code now, bounded to this neural directory. All new code
Nim only; no Python, C, shell scripts or local games. Direct nim commands
are allowed for checks and isolated inference tests. No statistical claims.

Sources: /Users/me/p/andre_von_auto/sims/nmmo/sim/brain_shim.c (architecture
and exact forward), vendor/upstream/puffernet.h functions _conv2d, _linear,
embedding, mingru, _softmax_multidiscrete. candidate.nim is unchanged
submitted buyan:v1 wire/FSM; preserve wire protocol, reset behavior, error
handling. The 17,723,904-byte weights.bin is already in your directory.
Do not read irrelevant whole repositories. No external libraries beyond
current Nim deps. Scalar explicit float32 math first; optimize later only
if measured latency requires. Use seq/arrays, not inheritance.

Write networks.nim providing shared immutable float32 weights, explicit
per-agent recurrent state, reset and forward logits; a categorical sampler
using deterministic Nim RNG; and candidate integration. Keep legacy inputs
for the trained model. Do not enable clean observations.

Exact weights order, no padding beyond existing8float alignment:
conv1 weights128*59*5*5 and bias128; conv2 weights128*128*3*3+bias128;
embedding128*32; affine1817*512+bias512; decoder512*27; then4 matrices
512*1536 for MinGRU. Total4,430,976float32 little-endian. Validate size and
finite weights, explicit offsets ending exactly at count. Output-major
weights for dense layers. Conv weights OIHW. One-hot tile factors
[4,4,17,5,3,5,5,5,7,4], map59x11x15. conv1 kernel5stride3 produces128x3x4,
ReLU, conv2 kernel3stride1 gives128x1x2. NO ReLU after conv2.
Embed47 self bytes at offsets1650..1696 to47*32; concatenate conv256,
embed1504, raw47 scalars, raw10 reward bytes =>1817. Affine512+ReLU.
Four MinGRU layers: project x into hidden,gate,highway (512each).
gate_s=sigmoid(gate); h_tilde=hidden+0.5 if hidden>=0 else sigmoid(hidden);
newState=oldState+gate_s*(h_tilde-oldState);
output=sigmoid(highway)*newState+(1-sigmoid(highway))*x. Persist newState,
NOT highway output. Next layer reads output; avoid overwriting x early.
Decoder gives27 logits; last is value, sample softmax from first26 only.

Reset only hero whose wire reset is true BEFORE forward. Every action must
come from neural sampler. Shadow the old FSM on same observation using a
separate Mind only for diagnostics; do not let it influence neural actions.
Bound JSON telemetry: experiment=neural,event=strategy_action,tick,agent,
action,baselineAction,generation. Record inference latency and reset count.
Only differing actions count as activation; success not required.

tests.nim: plain doAssert, no test framework. Test parameter offsets,
small known dense/conv/MinGRU arithmetic fixtures, finite network logits
on valid synthetic obs, reset reproduces logits and isolates other hero,
sampler reproducibility/bounds (not argmax), actual wire selection path.
Run nim check then nim r -d:buyanTest tests.nim. These are inference checks,
NEVER local game scoring. Benchmark forward latency with std/monotimes and
state exact machine/check configuration. Do not claim pretrained reference
parity until recorded-observation reference comparison is supplied.

Prepare Dockerfile derived from games/nmmo/buyan/Dockerfile.experiment:
copy only this directory's candidate.nim, networks.nim and weights.bin;
compile candidate as policy_player; copy weights to /bin/weights.bin so
the policy loads getAppDir()/weights.bin. No simulator in runtime image.
Build Linux using direct docker command. Write report.md with exact checks,
hashes and remaining reference-parity limitation. Parent will review these
before CPUX of this larger engine replacement; do not stall coding for it.
Do not commit/upload/run XP until all implementation checks are complete.
Then report readiness immediately; parent provides final reference check.
