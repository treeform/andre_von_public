Garble spectator protocol - the /global websocket

Spectators connect to /global and receive the full table snapshot after every
event, as one JSON text frame:

  {"type":"state","game":"garble","started":bool,"done":bool,"connected":int,
   "policyNames":[5 policy display names],
   "seats":[{"name":"<alias>","portfolio":int,"hold":int,"score":float,"cash":int,
             "units":[4 ints],"surplus":int,"demand":int,"airtime":int,
             "silent":bool,"deals":int,"misheard":int,"channel":int,
             "notes":str} x5],
   "turn":int,"turns":int,"turnsPlayed":int,
   "interference":float,"burst":bool,"band":"CLEAR|HAZY|ROUGH|STORM",
   "curve":[float per turn],"prices":[4 ints],"prevPrices":[4 ints],
   "commodities":["ORE","OAT","TIN","TAR"],
   "wire":[{"seat":int,"channel":int,"said":str,"silent":bool,"clipped":bool,
            "ticket":int,
            "heard":[{"to":int,"words":[{"said":str,"heard":str,
                                         "flag":"ok|drop|swap|static"}]}]}],
   "tickets":[{"id":int,"offerer":int,"channel":int,"turn":int,"expiry":int,
               "side":"SELL|BUY","qty":int,"commodity":int,"price":int,
               "kQty":int,"kCom":int,"kPrice":int,"settled":bool}],
   "tape":[{"ticket":int,"turn":int,"seller":int,"buyer":int,"commodity":int,
            "qty":int,"fill":int,"price":int,"saidQty":int,"saidCommodity":int,
            "saidPrice":int,"partial":bool,"misheard":bool}],
   "phase":"open|wire|settle|between|done","gameDone":bool,"reason":str,
   "events":[the complete append-only transcript]}

COMMODITY INDEXING is fixed: 0 ORE, 1 OAT, 2 TIN, 3 TAR. `units`, `prices`,
`prevPrices` and every `commodity` field are indexed that way.

channel: -1 MEANS THE RADIO (all four other seats hear it). Any other value is the
seat index of the addressed cog on a private line; a line is a cleaner channel
(noise x 0.6) that reaches one ear.

THE `events` ARRAY IS THE COMPLETE TRANSCRIPT, append-only, including every seat's
notes and every SAID text. Seven kinds: start, turn, say, confirm, deal, void, end.
`say` and `confirm` are the decisions; turn, deal, void and end are derived facts
that are recorded anyway so a replay can re-derive them and fail loudly on a
mismatch.

HEARD TEXT IS DERIVED, NEVER TRANSPORTED. The replay bytes carry only what was
said. Each listener's garbled version is recomputed from (seed, turn, from, to) by
the same Nim module the server ran, so the bytes carry the truth and the viewer
computes the lie - and anyone can audit every mishearing in the episode.

Replays ship as a STATIC WASM BUNDLE, not a live pod: the viewer renders a hosted
replay at index.html?replay=<url> and contacts nothing but the replay's own URL.
