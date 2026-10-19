# nightshift spectator protocol

JSON over the platform WebSocket at `/global`. Common-knowledge stream only: it shows what any player could know — seats & policy names, role set, who-speaks and kill-vote reveals with default markings, the elected speaker's speech as it streams, and the full objective reveal (final layout, deaths, winners, the original deal, and the ordered night log) at each scene's end. It NEVER shows hidden state (deals, night actions) mid-scene and NEVER shows notebooks.

Messages: `scene_start` {scene, role_set, seats}, `who_speaks_reveal`, `speech_delta`, `scene_reveal`. On connect the server first sends `hello` {started, done, seats_connected, seats_total} immediately (even pre-episode), then replays the public event log so far.