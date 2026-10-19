The user explicitly orders immediate CPUX when your candidate checks pass.
Your soak candidate has passed supervisor nim check, isolated tests with
its OWN nimcache, and Docker build. Do not repeat those checks.
Image moba-gorynych-soak:trial1 is built, digest
ce0a58cb1e114d34280b0eb1a931d043082197f47ac452805554c3005cc76301.
IMMEDIATELY commit ONLY experiments/soak/{candidate.nim,tests.nim,
report.md,Dockerfile}, then push main. Other agents share this repo:
never stage others' files; use git commit --only with your exact paths.
If git has an index lock, retry briefly; don't change or remove lock.
Then upload using existing CLI:
uv --project /Users/me/p/metta run coworld upload-policy
moba-gorynych-soak:trial1 --name gorynych-soak-20260912
--run /bin/policy_player --tag experiment=soak --tag commit=YOURCOMMIT
Use tools/captures to save output evidence/upload-soak.log.
Then nim r --hints:off games/moba/gorynych/tools/requests.nim
gorynych-soak-20260912:v1 soak b1 10
For EACH generated requests/soak/b1/{0,1,2}.json, immediately call
uv --project /Users/me/p/metta run coworld xp-request create FILE --json.
Save raw results via tools/captures into evidence/xp-soak-b1-I.json.
All paths are rooted games/moba/gorynych. There are 3 different opponents,
10 episodes each, identical to champion baseline. Do not change the field.
Do not submit to league. Do not wait for supervisor. Report policy ref,
commit, and three XP IDs when accepted. If an upload/create response is
uncertain, inspect saved evidence and use existing idempotency body,
never blindly upload another version. No other code changes are needed.
