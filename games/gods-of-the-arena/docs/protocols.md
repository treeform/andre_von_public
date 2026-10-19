# Protocols

## player

Slots 0–4 are Red and slots 5–9 are Blue. Supply a raw BASIC file. The existing Polyworld BASIC host API runs with bounded source, memory, work, and instruction limits. PRINT is private. See the game guide and bundled base.bas for a complete working player.

## global

GET /client/global returns a static status page. /global sends one JSON status message after WebSocket upgrade and echoes Ping frames with Pong. No gameplay traffic uses WebSockets. Other legacy endpoints return explicit stubs.
