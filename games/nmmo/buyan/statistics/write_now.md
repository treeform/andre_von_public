Resume implementation now. Prior allowlist accidentally removed native
editing; it is corrected to read_file and search_replace. Use search_replace
to create/write files, with empty old_string to create new files. Shell is
disabled. Do not spend more time rereading specs. Write comparisons.nim now.
Then compare.nim, tests.nim, usage.md. Supervisor runs Nim diagnostics.

Previous task.md and resume.md remain authoritative. One small provenance
addition: plan.requests each require episode_count positive integer. Require
each registered episodes file contains that exact count of episode entries,
so partial pagination cannot become false significance. The plan example
should show episode_count:10. Gate all registered episodes resolved before
support. Do not implement complex provenance or network access.
