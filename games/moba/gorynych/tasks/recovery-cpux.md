The user orders immediate CPUX when your corrected recovery tests pass.
Do this now without waiting for supervisor. Only this experiment's files.
1. nim check candidate.nim, then run tests with a UNIQUE nimcache:
nim r --hints:off -d:policyTest
--nimcache:games/moba/gorynych/experiments/recovery/nimcache/cpux
games/moba/gorynych/experiments/recovery/tests.nim
2. nim r --hints:off games/moba/gorynych/tools/builds.nim recovery
3. Commit only experiments/recovery candidate.nim, tests.nim, report.md
and Dockerfile. Use git add exact paths and git commit --only exact paths.
Short commit message. Push main. Other agents share git: retry index locks
and push races briefly; never remove locks or stage others' files.
4. docker build --platform linux/amd64
-f games/moba/gorynych/experiments/recovery/Dockerfile
-t moba-gorynych-recovery:trial1 .
5. Upload IMMEDIATELY with uv --project /Users/me/p/metta run coworld
upload-policy moba-gorynych-recovery:trial1 --name gorynych-recovery-20260912
--run /bin/policy_player --tag experiment=recovery --tag commit=YOURCOMMIT.
Capture using games/moba/gorynych/tools/captures to
games/moba/gorynych/evidence/upload-recovery.log.
6. nim r --hints:off games/moba/gorynych/tools/requests.nim
gorynych-recovery-20260912:v1 recovery b1 10
7. Create all THREE XP requests from requests/recovery/b1/0.json,1.json,2.json
via uv --project /Users/me/p/metta run coworld xp-request create FILE --json.
Use captures to save evidence/xp-recovery-b1-I.json raw results.
All abbreviated paths under games/moba/gorynych. Each10 episodes, frozen
opponents same as champion. No more code changes unless checks fail.
Do not submit to league. Report policy ref, commit and accepted XP IDs.
No wait for supervisor; this instruction authorizes all steps above.
