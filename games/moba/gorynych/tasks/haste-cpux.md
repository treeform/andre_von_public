The user orders IMMEDIATE CPUX after your corrected haste checks pass.
You just finished those checks with a unique cache. Do not repeat them.
Only touch this experiment's files and its requests/evidence.
1. nim r --hints:off games/moba/gorynych/tools/builds.nim haste
2. Commit only experiments/haste candidate.nim, tests.nim, report.md and
Dockerfile. git add exact paths, git commit --only exact paths. Push main.
Other agents share git: retry locks/push races; don't remove locks.
3. docker build --platform linux/amd64
-f games/moba/gorynych/experiments/haste/Dockerfile
-t moba-gorynych-haste:trial1 .
4. Upload NOW with uv --project /Users/me/p/metta run coworld upload-policy
moba-gorynych-haste:trial1 --name gorynych-haste-20260912
--run /bin/policy_player --tag experiment=haste --tag commit=YOURCOMMIT.
Use games/moba/gorynych/tools/captures to save evidence/upload-haste.log.
5. nim r --hints:off games/moba/gorynych/tools/requests.nim
gorynych-haste-20260912:v1 haste b1 10
6. Immediately create all THREE requests/haste/b1/{0,1,2}.json via
uv --project /Users/me/p/metta run coworld xp-request create FILE --json.
Use captures to save raw evidence/xp-haste-b1-I.json. Exactly10 episodes
each, frozen opponent field. All abbreviated paths under games/moba/gorynych.
No more code edits unless build fails. Do not wait for supervisor review.
Do not submit to league. Report policy ref, code commit and all 3 XP IDs.
