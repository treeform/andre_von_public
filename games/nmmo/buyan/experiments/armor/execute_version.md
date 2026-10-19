Run this tiny authorized job now. No planning, research, source edits or subagents. Only direct CLI commands/read_file; no Python or shell scripts.
LATEST USER RULE: always policy name buyan, only numbered versions, always Andre von Auto. Older prompts using buyan-armor or buyan-auto-armor are superseded.
Auto player ply_3d22435e-30a2-4f2a-b037-a5c249583788 session is freshly valid through September13. Exact image buyan-armor:20260912 is Linux-tested and source checked/committed/pushed in01d1875.
1. Execute:
/Users/me/p/andre_von_auto/games/nmmo/buyan/captures /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/armor/upload_version.txt uv --project /Users/me/p/metta run coworld upload-policy buyan-armor:20260912 --name buyan --run /bin/policy_player --tag experiment=armor --tag git_commit=01d1875
2. Read upload_version.txt. Use the actual returned buyan:vN; never guess N, five uploads run concurrently.
3. Run, replacing ACTUAL_LABEL only:
/Users/me/p/andre_von_auto/games/nmmo/buyan/requests armor ACTUAL_LABEL 15 version_a
/Users/me/p/andre_von_auto/games/nmmo/buyan/requests armor ACTUAL_LABEL 15 version_b
4. Immediately run both:
/Users/me/p/andre_von_auto/games/nmmo/buyan/captures /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/armor/response_version_a.json uv --project /Users/me/p/metta run coworld xp-request create /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/armor/request_version_a.json --json
/Users/me/p/andre_von_auto/games/nmmo/buyan/captures /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/armor/response_version_b.json uv --project /Users/me/p/metta run coworld xp-request create /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/armor/request_version_b.json --json
5. Read receipts; verify candidate player_id is ply_3d22435e-30a2-4f2a-b037-a5c249583788 and requested candidate exact returned numbered version. Report label, UUID, owner, both request IDs.
Preregistered fresh cohort30episodes, first decision at30triggered episodes then100/300. Earlier differently named uploads retained audit only. Baseline stays buyan:v1, opponents fixed FieldA in request tool. No league submission. On command failure report exact error and stop. Do not wait for parent between steps.
