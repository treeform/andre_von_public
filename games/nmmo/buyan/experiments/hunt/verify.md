VERIFY ONLY, promptly. No implementation exploration. Prior Grok sessions
stalled and parent authorized supervisor Nim fallback. Candidate is now written.
Your task is to verify the final code and observed isolation test outputs.
Read only candidate.nim (focus lines 630..850), reviewer_tests.nim, this file.
Never read other source, docs, artifacts, missing files, or skills.

Expected one strategy: exactly one live hint in entire observed window,
neutral element byte5==0, delta0, health>=95, not inCombat, inventory nonfull,
equipAction<0. Manhattan2..4 only. Walk from3/4 to remain>=2, never run. At2
wait at most2 consecutive times. Preserve all existing combat thresholds,
UI/heal/adjacentattack/toolgrab gates. Copy Mind for baseline counterfactual.
Log wire tick, local agent, action, baselineAction; changed issued drives
activation regardless of success. Telemetry diagnostics have 10-decision bound.

Supervisor executed:
nim check draft.nim
PASS 79360 lines, 0.463s, 144.781MiB.
nim r -d:buyanTest -d:huntDraft reviewer_tests.nim
PASS. Then draft copied byte-identically to candidate.
Output:
Testing approach stages outside NPC first-hit range.
{"experiment":"hunt","event":"issued","tick":-1,"agent":0,"generation":0,"action":2,"baselineAction":25,"kind":"walk","changed":true,"r":5,"c":10}
Testing bounded distance-two wait.
{"experiment":"hunt","event":"issued","tick":-1,"agent":0,"generation":0,"action":4,"baselineAction":25,"kind":"stage","changed":true,"r":5,"c":9}
{"experiment":"hunt","event":"issued","tick":-1,"agent":0,"generation":0,"action":4,"baselineAction":25,"kind":"stage","changed":true,"r":5,"c":9}
Testing dangerous or untrusted targets retain baseline behavior.
Testing original action priorities.
Reviewer isolation checks passed.

Tick=-1 is direct decide test fixture only. Production act receives parsed wire
tick from main. No local games or score claims. Verdict PENDING HOSTED XP.

Respond with concrete verification findings immediately after reading those
two files. You can write grok_verification.md with verdict/test interpretation,
or concise actionable bug report. Do NOT create/modify candidate or tests.
Tools read_file/search_replace only. No shell, Python or other code language.
