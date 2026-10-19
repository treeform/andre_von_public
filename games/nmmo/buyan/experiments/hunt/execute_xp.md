Execute this reviewed experiment immediately. No research or source edits.
The parent directly supervises you. Do not spawn subagents.
Use only direct CLI commands and read_file. Never Python or shell scripts.

The parent committed and pushed 01d1875, checked Nim isolation tests, and
built Linux image buyan-hunt:20260912. The Andre von Auto player session
has just been refreshed and is valid through 2026-09-13T14:44:04Z.
Always act as player ply_3d22435e-30a2-4f2a-b037-a5c249583788.

Run this now:

    /Users/me/p/andre_von_auto/games/nmmo/buyan/captures /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/hunt/upload.txt uv --project /Users/me/p/metta run coworld upload-policy buyan-hunt:20260912 --name buyan-hunt --run /bin/policy_player --tag experiment=hunt --tag git_commit=01d1875

Read upload.txt. Use only the actual returned label in these commands:

    /Users/me/p/andre_von_auto/games/nmmo/buyan/requests hunt ACTUAL_LABEL 10 a
    /Users/me/p/andre_von_auto/games/nmmo/buyan/requests hunt ACTUAL_LABEL 10 b

Immediately launch both requests without waiting for parent:

    /Users/me/p/andre_von_auto/games/nmmo/buyan/captures /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/hunt/response_a.json uv --project /Users/me/p/metta run coworld xp-request create /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/hunt/request_a.json --json
    /Users/me/p/andre_von_auto/games/nmmo/buyan/captures /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/hunt/response_b.json uv --project /Users/me/p/metta run coworld xp-request create /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/hunt/request_b.json --json

Read both receipts and verify the hunt participant belongs to Andre von Auto.
Report both XP IDs and the player identity. No league submission yet.
If any command fails, report exact failure without retrying upload.
