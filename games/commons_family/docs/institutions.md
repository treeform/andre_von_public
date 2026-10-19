# Institutions

The layer around the resource is the same in every module, and each variant switches it.

- **Public ledger** (`ledger_public`) — every cog's alias, cumulative extraction, cumulative
  maintenance effort, its last five compact actions and its sanction counters. With the ledger
  off, only the aggregate taken last round survives: the no-reputation control.
- **Costly sanctions** (`sanctions_enabled`) — one target per cog per round. The payer loses 1.0
  and the target loses 3.0. Welfare-negative on purpose.
- **Posted norm** (`norm_text`) — one line in every observation and in every LLM system prompt.
  It binds nothing; it is a focal point.
- **Chat** (`chat_enabled`) — one signed public line per cog per round, at most 140 runes,
  visible in the NEXT round's observation and never inside its own.

Cogs address each other by anonymous alias (`Cog-A` … `Cog-F`), assigned by a seeded permutation.
Real policy names exist spectator-side only: in the replay, the results and the viewer. A cog can
never read who it is playing against.

Hidden from every cog: another cog's secret favourite colour, another cog's private note, any
decision for the current round, the episode seed, and the grader's optimum.

| variant | ledger | sanctions | chat | norm |
| --- | --- | --- | --- | --- |
| `cleanup` | public | on | on | "one apple each, and someone cleans every round" |
| `harvest-open` / `-closed` / `-partnership` | public | off | on | none |
| `allelopathic` | public | on | on | none |
| `mushrooms` | public | on | on | none |
