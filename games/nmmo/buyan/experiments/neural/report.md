# neural — MMONet Nim port (inference checks only)

No pretrained reference-logit parity is claimed. No recorded-observation
comparison was supplied. No game scoring.

## Layout

- `networks.nim`: immutable float32 weights, per-agent MinGRU state,
  reset, forward logits, `std/random` categorical sampler (first 26 of 27
  decoder logits; last is value).
- `candidate.nim`: buyan:v1 wire/FSM preserved. Wire actions come only
  from the neural sampler. A separate `Mind` is advanced on the same obs
  for `baselineAction` diagnostics and does not select the wire action.
  Legacy observations only (no `obs=clean`).
- Reset: `resets[j]==true` zeroes that hero's MinGRU (and shadow FSM)
  before that tick's forward.
- Telemetry (stdout JSON, only when neural action differs from shadow
  FSM): `experiment=neural`, `event=strategy_action`, `tick`, `agent`,
  `action`, `baselineAction`, `generation`, plus `inferenceNs` and
  `resetCount`.

## Weights

- Path: this directory `weights.bin`; runtime `getAppDir()/weights.bin`.
- Size: 17,723,904 bytes = 4,430,976 float32 LE.
- SHA-256: `2bb4a521d2f744e23525baa16a074eb4bc88f1b26b5ad54d7fd571df89887da5`
- Offsets (exclusive end == 4,430,976): conv1 188800+128, conv2
  147456+128, embed 4096, affine 930304+512, decoder 13824, MinGRU
  4×786432. Decoder and MinGRU have no bias (puffernet `make_linear`).
  No 8-float padding consumed.

## Checks (exit 0)

```
nim check -d:buyanTest tests.nim
nim r -d:buyanTest tests.nim
nim check candidate.nim
nim check networks.nim
```

`nim r -d:buyanTest tests.nim` printed `ok neural inference checks`.

Covered: parameter offsets; dense/conv/MinGRU fixtures; finite logits on
synthetic 1707-byte obs; reset matches a fresh agent and leaves the other
hero's state; sampler reproducibility and bounds (not argmax); wire
`processTick` selection; malformed obs → noop.

## Latency (debug, not a score)

- Machine: macosx/arm64
- Nim: 2.2.6
- Build: debug (`opt: none`)
- `forwardLogits` mean over 8 calls after 1 warmup: 495,235,723 ns
- Debug wire `inferenceNs` on synthetic ticks was ~4.9e8 ns
- Release latency was not measured. Scalar float32 loops were left as-is.

## Docker

```
docker build -t buyan-neural:latest -f games/nmmo/buyan/experiments/neural/Dockerfile .
```

- Image id: `sha256:e2be15aa287f294a414cc81fda1341539c17ec3fa487cfdfb696d035c9dbc1cf`
- Runtime: `/bin/policy_player` (674,256 B), `/bin/weights.bin` (17,723,904 B)
- Nim in image: 2.2.4 `-d:release --opt:speed`
- No simulator in the runtime image.

## Source SHA-256

| file | sha256 |
|---|---|
| candidate.nim | cd95f3dd7cfa51318900787fa28e9fd1770af7adf281a555049a8584a70d122a |
| networks.nim | 735a011e432f30cc31b16f90407f229cd1db7b4135f01b989abb0d9cc3b0ba9c |
| tests.nim | 521f8180afb49885b3fb7a194ca3873bfd93bf674732552ce59de88fb8647399 |
| Dockerfile | 8e85b47a85876d9bc5c2517d035c15fd2fe6eec53e4511bff7ee93dc89af8f05 |

## Remaining limitation

Bit-exact match to the published C/wasm MMONet on recorded observations
has not been run. Sampler uses Nim `std/random`, not libc `rand()`, so
sampled actions would differ from musl even with identical logits.

Ready for parent reference-observation review. No commit, upload, or XP.
