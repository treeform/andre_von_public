Resume the paused statistics task. Your first run spent several minutes
reading/reasoning without writing any code. Start writing comparisons.nim
now, then CLI and tests. The complete specification is already in your
context and statistics/task.md. Do not read unrelated files or research.

Your available tools are filesystem read/write/edit only. You must not use
any shell or MCP tools. All code is Nim. Supervisor will run nim check and
tests and send exact diagnostics for your verification/fixes. This replaces
the original request for you to execute verification directly. All files
stay in the statistics folder. Do not spawn anything or change shared files.

Add one important gate to the specification: if any registered episode is
pending/running/submitted or other unresolved nonterminal status, support
cannot pass even when completed subset n happens to equal a planned look.
Emit unresolved_requests (or count) and status awaiting_completion ahead of
other significance statuses. Failed/cancelled statuses are terminal excluded
episodes. This prevents selection of only fast-completing episodes. Include
a structural test. Raw sums/differences must remain finite; reject overflow.

Keep implementation reasonably short and explicit, not a framework. You
need no further schema research. Plain JSON data and exported proc compare
are enough. Write code first, then usage. Supervisor will independently
review mathematics and every changed file.
