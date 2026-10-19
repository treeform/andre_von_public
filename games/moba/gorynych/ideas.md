# MOBA experiments

## Baseline and rules

2026-09-12: gorynych:v1 (6a471409-9b7d-42dc-ba8c-d61ff45110e9)
is champion for Andre von Auto (ply_3d22435e-30a2-4f2a-b037-a5c249583788).
The supplied andre-von-houck XP selector names the other owned player;
use the actual champion owner for evidence filtering.
Rating: 1287.26, sixth. Nearest players: Andrew Brower 1311.79,
PufferLib 1235.71, docxology 1357.84.
Hosted coworld 0.1.3 at f06d28fd9854d3c8cd4dbbe782b6a93fddc7b2cc.
GitHub HEAD matches; current example remains unchanged.
Local commit 20ae58b contains an unverified siege change made after v1.

## Backlog

- Analyze leading player movement, lane concentration and ability use.
- Occupancy-aware steering to avoid walking into creeps and allies.
- Concentrate all five heroes in the strongest lane.
- Siege target selection and wave cover.
- Combat skill usage grounded in replay and exact skill mechanics.
- Reduce wasted travel and retreat time.

## Trials

| Trial | Idea/change | XP ID | Opponents | Trigger proof | Verdict |
|---|---|---|---|---|---|
| Audit | Reconstruct champion, inspect leaders and current rules | Pending | Pending | Pending | Research |
| Baseline b1 | Submitted gorynych:v1, 10 games each, five per side | xreq_a9bef67c-adb0-41bc-8a13-c8ada492611b; xreq_43f0f8bf-48b3-48c7-a020-789ad65ed564; xreq_980e792f-837f-4740-bcc4-2792aeb6712c | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Baseline | Pending |
| Occupancy | Avoid observed occupied movement destinations | xreq_b9017ccc-f840-4823-add5-a73cfadf55cc; xreq_97ee32f5-cd27-472b-830f-f716cc552506; xreq_41342234-baca-42a0-a6c5-14f1cb8a8c8e | Frozen baseline field | Isolation passed, hosted telemetry pending | XP accepted |
| Topstack | All heroes use top lane | Pending | Frozen baseline field | Isolation and telemetry pending | Grok building |
| Soak | Require strictly closer L1 creep cover against towers | Pending | Frozen baseline field | Isolation and telemetry pending | Grok building |
| Haste | Assassin E while pushing | Pending | Frozen baseline field | Isolation and telemetry pending | Grok building |
| Recovery | Regenerate safely near the front | Pending | Frozen baseline field | Isolation and telemetry pending | Grok building |

## Evidence rules

One strategy change per candidate. Commit, push, build/upload then hosted XP.
Upload does not submit. Candidate and champion use identical opponents,
seat allocation, game version, settings and episode counts. Freeze fields.
Score only hosted experience requests, never local simulation.
Log triggers per episode and action changes. At least 10 triggered episodes.
Dashboard significance is required to keep; add multiple-testing control
across five candidates and record planned analysis looks before testing.
Inconclusive results require more episodes or rejection, never promotion.
## Hosted request ledger

b1/a1 are historical nearest-rating cohorts. Only t1 and later top-three cohorts are eligible for promotion.

| Trial | Idea | Policy | XP IDs | Opponents | Verdict |
|---|---|---|---|---|---|
| baseline b1 | Submitted champion | gorynych:v1 | xreq_a9bef67c-adb0-41bc-8a13-c8ada492611b; xreq_43f0f8bf-48b3-48c7-a020-789ad65ed564; xreq_980e792f-837f-4740-bcc4-2792aeb6712c | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Historical, not eligible |
| occupancy b1 | Avoid occupied next cells | gorynych-occupancy-20260912:v1 | xreq_b9017ccc-f840-4823-add5-a73cfadf55cc; xreq_97ee32f5-cd27-472b-830f-f716cc552506; xreq_41342234-baca-42a0-a6c5-14f1cb8a8c8e | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Historical, not eligible |
| topstack b1 | All heroes use top lane | gorynych-topstack-20260912:v1 | xreq_51eb6078-5b80-4819-b81e-5ee40289bb45; xreq_d0a3484f-3481-41b4-b869-153286a79a4a; xreq_0663cbe4-86ad-440d-9650-f9eeceae782b | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Historical, not eligible |
| soak b1 | Strictly closer L1 creep cover | gorynych-soak-20260912:v1 | xreq_e06a96ee-4979-4eb8-b45e-7eacac00f2d8; xreq_d9404583-e050-4213-abbb-cb8ad7fb698f; xreq_2d29a714-6ba6-44a8-b97c-ca715b168509 | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Historical, not eligible |
| recovery b1 | Recover near the front | gorynych-recovery-20260912:v1 | xreq_d5c0081e-f8a4-4ce4-9c6a-9f0761784d01; xreq_7656dfc3-0524-460a-bd54-504767e6ab71; xreq_796ce737-c0e7-4429-94e3-a04392ba8f29 | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Historical, not eligible |
| occupancy a1 | Avoid occupied next cells | gorynych:v2 | xreq_1940dc67-dc4d-4fe0-abd0-15561d4646c9; xreq_bca1c369-8bf1-4720-b460-ff3b60ee77b0; xreq_f6918d60-7d8e-4301-b086-e4fa5caa174c | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Historical, not eligible |
| topstack a1 | All heroes use top lane | gorynych:v3 | xreq_04d17c16-8362-49a4-aaca-0e13dd451af8; xreq_a2b930e1-02b2-43b5-b2f2-85b7b20b97fc; xreq_5ae1688d-490a-4833-be8b-fda03e90235f | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Historical, not eligible |
| haste a1 | Assassin E while moving in push mode | gorynych:v4 | xreq_f06b8da7-7d96-460f-a05e-49887a4db22b; xreq_bec8fdf7-c9db-4c79-bd32-148ec0174131; xreq_8efe7911-cb8c-4db9-b7c7-cb677af1aa28 | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Historical, not eligible |
| soak a1 | Strictly closer L1 creep cover | gorynych:v5 | xreq_5fc01549-d19a-4a7b-a090-413d096684d9; xreq_f9ab2c36-f593-4c7b-932e-fa5c106289a0; xreq_6734a0f6-610e-4fb3-9ce5-a9564c508107 | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Historical, not eligible |
| recovery a1 | Recover near the front | gorynych:v6 | xreq_b9277273-12b9-4d7b-9a4d-16886de6a034; xreq_08121987-3050-4ac1-a7ce-07d90d25b913; xreq_45782931-6872-4b8a-b245-5c003677d955 | moba-example:v1; pufferlib-baseline:v1; docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 | Historical, not eligible |
| baseline t1 | Submitted champion | gorynych:v1 | xreq_798c5043-ed36-4776-8f80-158019ec0d90; xreq_ee5f2931-5acf-40c6-b7b5-78136e7483dd; xreq_a381eda8-e730-49f2-9fa2-f68c8027e80d | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | Champion reference cohort |
| occupancy t1 | Avoid occupied next cells | gorynych:v2 | xreq_ad88392a-9a81-4514-920c-49de06651908; xreq_14bf1ea0-2140-49a7-87a4-2adf25430ed6; xreq_f458582e-1c96-4dd5-b8a6-af2048a5dfc4 | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | p=0.8888888888888888; score gate=false; unsubmitted |
| topstack t1 | All heroes use top lane | gorynych:v3 | xreq_cad4f1d6-5725-408c-88d6-f69ad4f1fd2a; xreq_895fc2ee-e843-4e05-8599-d51c05ee2ed2; xreq_ec930edf-0140-41fd-9f1d-55fe55945377 | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | p=0.7037037037037037; score gate=false; unsubmitted |
| haste t1 | Assassin E while moving in push mode | gorynych:v4 | xreq_21c03da7-8747-4f96-8604-60971eb497cf; xreq_2e86b1e8-8f04-4408-a2f8-cbc8e9bef2c4; xreq_1de1cd20-b380-4fe3-9c9f-68db3c4a4c35 | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | p=0.6944444444444445; score gate=false; unsubmitted |
| soak t1 | Strictly closer L1 creep cover | gorynych:v5 | xreq_b677de3b-4a1d-423e-9832-4da72d62bfd6; xreq_65edb124-9aff-4517-b348-3da58843eff7; xreq_c165eaf1-a5ba-4568-8286-0a5d7a728563 | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | p=0.8888888888888888; score gate=false; unsubmitted |
| recovery t1 | Recover near the front | gorynych:v6 | xreq_dd4842ef-303f-4a64-b193-0b203b6210ac; xreq_e3d29346-2d9d-4c49-a169-fc7c20e38599; xreq_0d6386e5-124d-4a83-8303-93282b30ece8 | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | p=0.32870370370370366; score gate=false; unsubmitted |
| snipe t1 | Ancient snipe from tower-blind cells (brain.nim rewrite) | gorynych:v9 | xreq_f022af57-9019-4172-9a49-02c8a6bf4da7; xreq_b67d17b7-f86a-4f49-abbb-38a0acce49a3; xreq_6f3f3f33-0ed4-407c-ba3d-3d92b455d079 | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | p=2.95e-12; score gate=true; activation proven in 30/30 replays; SUBMITTED |
| creepfight t1 | Target filter 0 whenever a hostile creep is visible | gorynych:v10 | xreq_11ca1d62-240a-401c-b111-676ad503ae2c; xreq_12beff61-dbc6-4507-94fe-e1d20428bf45; xreq_1e56f9ce-a4d7-4d44-82e3-538ba7d32e30 | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | p=0.5 at both looks (t1 29/30 vs 28/30, t1+t2 115/120 vs 114/120); discarded |
| snipe t2 | v9 baseline extension | gorynych:v9 | xreq_7af265f5-35ca-4baf-ba3d-164265320116; xreq_c4ad733c-610e-4b84-99a1-7ace1c3b1082; xreq_cd843d95-1f06-4f1a-a03b-a0550813dc13 | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | Champion reference cohort (30 each) |
| creepfight t2 | second look | gorynych:v10 | xreq_f7587278-73c2-4639-9c6d-4a9f5392bdc1; xreq_c68939f1-56de-4a57-8a51-e243b72a2103; xreq_d34a0f22-a7e0-49dd-9423-ce696aee614d | same | see creepfight t1 |
| corners t1 | No diagonal corner-cutting + clustered nest (stall fix) | gorynych:v11 | xreq_3218c9f8-2f10-4566-b9a7-fedc721438fb; xreq_f6df4df3-aa68-486e-bc84-669a9b2f6bc3; xreq_83bba703-96a2-4c3e-aed7-b310e48e39f6 | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | t1 120/120 vs 114/120 p=0.0101; t1+t2 240/240 vs 229/240 p=2.2e-4; activation lockstep 0 mismatches; KEPT and SUBMITTED |
| snipe t3 | v9 baseline extension | gorynych:v9 | xreq_07d171d6-52b2-4039-8a41-a5f7830aa2e3; xreq_feb9b5ee-f66b-4d12-966d-8a0770193280; xreq_8bd591cb-327b-4c4a-ab77-0a4afe6c37ea | same | Champion reference cohort (40 each) |
| corners t2 | v11 extension | gorynych:v11 | xreq_1d0e5250-7f9c-439f-901d-897da22f63d1; xreq_8703e139-60c5-4780-88bd-38715269fb69; xreq_dbe5aa71-98fc-42cc-ba1f-b050d0ca0c29 | same | see corners t1 |
