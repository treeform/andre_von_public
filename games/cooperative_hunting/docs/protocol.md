# Protocol

## Player protocol

Base: **bitworld sprite_v1**, unchanged.

Server -> client messages: `0x01` sprite, `0x02` object, `0x03` remove,
`0x04` clear, `0x05` viewport, `0x06` layer, `0x07` identity.

Client -> server: the 2-byte input packet `[0x84, mask]` (`0x00` is also
accepted for the bitscreen_v1 header). Mask bits: 0 up, 1 down, 2 left,
3 right, 4 A, 5 B, 6 select. At most one direction bit should be set; the
server reads them with priority up > down > left > right.

Two additive messages, and only two:

### `0x90` client -> server, registration

Sent once immediately after connect.

```
0x90  <u16 len little-endian>  <len bytes UTF-8 JSON>     len <= 4096
```

Body is either

```json
{"kind": "prompt", "prompt": "<= 1200 runes"}
```

or

```json
{"kind": "scripted", "baseline": "big_game_hunter"}
```

A malformed, oversized or non-UTF-8 body is dropped and the seat is treated as
`{"kind":"scripted","baseline":"big_game_hunter"}`. It is never a disconnect.

### `0x91` server -> client, plan

Sent **only** to seats that registered `kind: "prompt"`, at most once per
planning turn (every 120 ticks).

```
0x91  <u16 len little-endian>  <len bytes UTF-8 JSON>
```

```json
{"turn": 7, "intent": "hunt", "target": "stag@13,17", "side": "S",
 "with": ["Cog-A"], "say": "...", "src": "llm"}
```

`src` is `llm` or `fallback:<cause>`. Scripted seats never receive it, because
the bundled bots' parsers reject unknown message types.

## Global protocol

The same sprite_v1 stream at world scale (384x384 px viewport, no identity
packet), plus the broadcast chrome smuggled as the **label of a reserved 1x1
sprite, id 4090**, re-emitted every tick. The body is UTF-8 JSON of at most
12 KB (12288 bytes) carrying `tick`, `round`, `rounds`, `ticksPerRound`,
`phase`, `variant`, `reason`, `seats[]`, `feed[]`, `beats[]` and `final`.
