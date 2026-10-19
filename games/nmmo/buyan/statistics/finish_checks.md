Fix only remaining compiler errors in statistics, then actually run Nim
checks and tests. Parent directly supervises you. No subagents, no Python,
no shell scripts, no local games. Use direct nim commands only in terminal.

compare.nim currently fails comparisons.nim807 getCurrentDir unlisted OSError.
Map that boundary error to BuyanError. tests.nim needs strutils import and
its `doAssert "x" in expectError:` template call syntax corrected to
separate local error text or parenthesized explicit block. Compile output
pinpoints166,168,193,195,197,382,391. Do not redesign or weaken assertions.

Run from /Users/me/p/andre_von_auto:
nim check games/nmmo/buyan/statistics/compare.nim
nim check games/nmmo/buyan/statistics/tests.nim
nim r games/nmmo/buyan/statistics/tests.nim
Fix real failures and repeat only as necessary. Existing paired sign-test
rules remain. No network requests/upload/submission. Write checks.md with
actual concise outputs. Keep every code edit Nim in statistics folder.
