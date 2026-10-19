# Finish runnable action extraction now

The user needs the hosted action histogram immediately. replays.nim now
exists, but no CLI exists and Nim check errors are saved in
`/Users/me/p/andre_von_auto/games/nmmo/buyan/replays_tools/parser_check.log`.
Read that one file, fix the reported effects, then create a minimal
`extract.nim` importing std/os and replays and printing
`reportJson(loadReplay(path),path)` for each commandLineParams path.
Add std/json import if needed for `$JsonNode`. No when isMainModule.
Wrap the top-level loop in a documented `proc main()` and call main().

Do these two steps NOW, before writing tests, reports or reading anything
else. Tools are read/search_replace only. The supervisor runs nim check.

Parser review also found multiplication overflow risk: before computing
players.len*heroes and tickCount*numAgents, guard division-based size
bounds so malformed huge integers raise NmmoReplayError (no Defect).
Malformed replay players must be objects with nonempty string name.
Retain ordinary valid hosted header behavior.

Once the CLI exists, return immediately to supervisor for compilation.
Tests and detailed report can be added on the next task. Keep changes
only replays.nim and extract.nim. No commands or non-Nim programs.
