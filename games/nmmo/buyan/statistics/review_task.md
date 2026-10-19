Your first comparisons.nim/compare.nim are written. Supervisor ran
`nim check statistics/compare.nim`; it failed:

```
comparisons.nim(82,34) node[key] can raise unlisted ref KeyError
comparisons.nim(237,39) node["synthetic"] unlisted KeyError
comparisons.nim(274,31) node[key] unlisted KeyError
comparisons.nim(287,34) node["id"] unlisted KeyError
comparisons.nim(420,11) node["participant_scores"] unlisted KeyError
comparisons.nim(531,38) seenJobs[request.xpId] unlisted KeyError
strutils imported unused.
```

Fix these without broadening public raises beyond BuyanError. Use checked
helpers/getOrDefault or explicit KeyError wrapping, not cast(raises).

Independent review required changes:

1. samePath currently accepts same basename from another directory. This is
   unsafe and violates exact registered input files. Compare normalized
   absolute paths. In compareFiles, resolve plan-relative episodes_file
   against parentDir(planPath), CLI files relative to CWD. The in-memory
   compare API can use exact path strings or normalized absolute paths.
   Add negative test /expected/episodes.json vs /other/episodes.json.

2. readScore missing participant_scores or null currently raises instead
   of exclusion missing_score. Treat absent/null score array as missing
   score; malformed array type remains fatal. Scan whole score array for
   duplicates before returning missing/nonfinite, so malformed duplicate
   scores cannot silently pass due first score null. Add tests.

3. signTestP uses direct2^-n; at n>1074 it silently underflows. Its supported
   exact range is <=300. For compare n>300 output off_schedule and report
   sign_test_p=null instead of claiming exact probability outside bound,
   or implement stable log recurrence beyond300. Exported signTestP rejects
   counts total>300. Tests include large n and no fabricated p0.

4. Count strings empty experiment/coworld/episode id metadata should fail
   closed. Baseline/candidate policy_version_id must differ even if names or
   numeric versions differ, and same policy_version_id must never belong to
   two different identity strings in plan. Add small negative tests.

5. Exported decideGate must validate counts and compute p internally or
   verify given p equals signTestP(wins,losses). A caller may not get support
   by supplying p=0 with 6wins4losses. n >= wins+losses, nonnegative counts,
   finite means. For n>300 off_schedule without fake p.

6. Primary inclusion priority and unresolved handling look correct. Exact
   alpha .0025 and p10wins=.001953125 are independently correct. Dashboard
   remains mandatory. Do not require action success to enter cohort.

Keep your tests and usage complete. A second Grok worker writes separate
signs.nim/signs_tests.nim as independent math cross-check; do not edit those.
Do not run shell commands. Supervisor runs compilation/tests after fixes,
then feeds results for your verification. Only own statistics folder files.

Additional first test review: Nim2 reserves `out`; every test `let out` must
be renamed to report. `nim check tests.nim` fails first at tests.nim(206,7)
with keyword out and many consequent parse errors. Two-request fixture also
sets first activation xp_id to xreq_actual instead of xreq_first; correct
the fixture so intended positive test matches its own declared request.
The n301 gate test must not call signTestP301 after you bound exact n<=300.
Also apply optional source/experiment/xp_id matching to individual episode
objects if present, not only wrappers; explicit contradictory metadata must
fail rather than be ignored. Missing optional fields in real CLI arrays are
fine. Tests need episode source="local" rejection.

Before final response, extend tests.nim to write one clearly labeled
synthetic 10-win CLI fixture set within statistics/synthetic/ (plan.json,
activations.json, episodes.json). Use Nim writeFile/createDir. The
supervisor will exercise actual compare.nim file-loading CLI. Keep plan
synthetic true. This is JSON fixture generation, never a local game.
Usage should include the agreed aggregate activation schema from task.md.
