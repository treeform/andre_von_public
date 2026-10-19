# Stop searching and write the adapter

You spent many calls reading guessed paths that do not exist. Stop all
searching and exploratory reads now. You have every schema needed in the
original task. The parser file now EXISTS at
`/Users/me/p/andre_von_auto/games/nmmo/buyan/replays_tools/replays.nim`.
Use native `search_replace` to CREATE activations.nim, activate.nim,
tests/activations.nim, and activation_usage.md inside that directory.
The supervisor runs all Nim commands. Do not attempt any commands.

Implement the clean/hunt/escape adapters as specified now. Add exact armor
text support too, because its final schema is known:

`armor_upgrade event=issued tick=100 agent=0 life=0 action=8 slot=helm oldTier=1 desiredTier=3 freshTier=1 issued=1 confirmed=0 tierGain=0`

Fields are space-delimited key=value. Require event=issued, tick>=0,
agent>=0, action in 8..16, slot helm/chest/legs, oldTier>=1,
desiredTier>oldTier, freshTier=oldTier. The policy invariant proving
divergence: this action unequips currently worn armor; unchanged baseline
equipAction never emits an already-equipped armor key. Do not invent a
baselineAction for armor. Metric explicitly names this source invariant.
Other armor events confirmed/summary do not count. Malformed issued lines
must fail. Match actual replay action at tick/seat/local-agent as always.

Sword is still pending final schema: fail closed for it for now.
Do not look up any other parent/sibling files. Original task already pins
statistics output shape and plan fields. Never change another worker's
replays.nim. Write all code in Nim using native file edits immediately.
