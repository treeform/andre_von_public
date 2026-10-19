The user explicitly orders immediate CPUX when your candidate checks pass.
Your topstack candidate has passed supervisor nim check, isolated tests
with its OWN nimcache, and Docker build. Do not repeat those checks.
Image moba-gorynych-topstack:trial1 is built, digest
587fb46beb3ca4a16f9a19dab64f044a49d7f708de83b04b144706fdee4348d2.
IMMEDIATELY commit ONLY experiments/topstack/{candidate.nim,tests.nim,
report.md,Dockerfile}, then push main. Other agents share this repo:
never stage others' files; use git commit --only with your exact paths.
If git has an index lock, retry briefly; don't change or remove lock.
Then upload using existing CLI:
uv --project /Users/me/p/metta run coworld upload-policy
moba-gorynych-topstack:trial1 --name gorynych-topstack-20260912
--run /bin/policy_player --tag experiment=topstack --tag commit=YOURCOMMIT
Use tools/captures to save output evidence/upload-topstack.log.
Then nim r --hints:off games/moba/gorynych/tools/requests.nim
gorynych-topstack-20260912:v1 topstack b1 10
For EACH generated requests/topstack/b1/{0,1,2}.json, immediately call
uv --project /Users/me/p/metta run coworld xp-request create FILE --json.
Save raw results via tools/captures into evidence/xp-topstack-b1-I.json.
All paths are rooted games/moba/gorynych. There are 3 different opponents,
10 episodes each, identical to champion baseline. Do not change the field.
Do not submit to league. Do not wait for supervisor. Report policy ref,
commit, and three XP IDs when accepted. If an upload/create response is
uncertain, inspect saved evidence and use existing idempotency body,
never blindly upload another version. No other code changes are needed.
