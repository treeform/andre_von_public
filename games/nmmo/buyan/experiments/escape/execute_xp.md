# Execute authorized hosted experiment immediately

NEW explicit user authorization supersedes earlier worker restrictions:
you must upload this already-reviewed candidate and start BOTH paired hosted
XP requests now. Parent has already committed/pushed 465eb93, built Linux,
and checked all Nim tests. Docker image buyan-escape:20260912 is ready.
No research, planning, source reading, git, source edits, configuration,
league submission, Python, shell scripts, or snippets. Only these direct
CLI invocations through run_terminal_command and receipt reads through
read_file. Do not wait for parent confirmation. Execute the upload now:

    /Users/me/p/andre_von_auto/games/nmmo/buyan/captures /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/escape/upload_receipt.txt uv --project /Users/me/p/metta run coworld upload-policy buyan-escape:20260912 --name buyan-escape --run /bin/policy_player --tag experiment=escape --tag git_commit=465eb93

Read upload_receipt.txt with read_file to obtain the actual policy label.
Run these two commands, substituting only that observed actual label:

    /Users/me/p/andre_von_auto/games/nmmo/buyan/requests escape ACTUAL_LABEL 10 a
    /Users/me/p/andre_von_auto/games/nmmo/buyan/requests escape ACTUAL_LABEL 10 b

Then immediately run both exact capture commands:

    /Users/me/p/andre_von_auto/games/nmmo/buyan/captures /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/escape/response_a.json uv --project /Users/me/p/metta run coworld xp-request create /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/escape/request_a.json --json
    /Users/me/p/andre_von_auto/games/nmmo/buyan/captures /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/escape/response_b.json uv --project /Users/me/p/metta run coworld xp-request create /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/escape/request_b.json --json

Report the uploaded policy label and both request IDs from tool output.
If any command fails, report exact failure and stop without retrying uploads.
Do not substitute policy labels from memory. Start now with the upload.
