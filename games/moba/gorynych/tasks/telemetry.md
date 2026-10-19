Write a compact Nim hosted evidence verifier at
games/moba/gorynych/tools/telemetry.nim and its tests. All code Nim.
Read our experiments/*/candidate.nim telemetry names and the downloaded
hosted evidence under games/moba/gorynych/evidence/xreq_*/. Every episode
has .replay and .log. The log is coworld CLI output and can be a Python
bytes repr with literal backslash-n, not real line breaks. Extract bounded
MOBA_TRIAL JSON objects from that text. For each candidate XP current.json
passed as argument, verify two real distinct policy participants, expected
focal policy label, completed status, no errors and exactly one focal seat.
Read every focal .log and .replay via research/replays.nim if helpful. Verify
expected idea marker, monotonic counters, final or latest triggers and
changedActions. Report per episode counts and aggregate triggered games,
changed actions, total calls, noops/dead-agent fields from replay header.
Return an explicit trigger gate only when ALL episodes have evidence
of strategy activation and changed issued action, and at least ten games
qualify. Do not read scores for strategy selection. Never call this proof
of improvement. No uploads/submissions, no edits outside tools/telemetry.nim
and tools/test_telemetry.nim. Use unique nimcache tools/nimcache/telemetry.
The research report direction-based stack inference cannot prove positions;
leave it clearly described as inference if you mention it. Tests should
cover bytes repr logs, missing logs, zero triggers and mismatched idea.
