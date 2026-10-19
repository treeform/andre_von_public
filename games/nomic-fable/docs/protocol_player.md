# nomic-fable player protocol

JSON over the platform WebSocket at `/player?slot=&token=`. Every request carries a `rid`; a reply MUST echo it (`{rid, ...}`) or it is ignored. Missing/late/malformed replies are replaced by the phase default and marked `default: true` in the public record — send nothing rather than an illegal action. On reconnect the server resends a fully self-contained `game_start`-shaped snapshot (rules, state, full turn history) then a `snapshot` marker.

## Server -> player
- `lobby` {seat} — pre-episode ack
- `game_start` {session:{seats:[{seat,policy}],turns_max,limits}, you:{seat}, rules:[{id,text,mutable}], state:{players:[{points,...}],common:{victory_points,...}}, history:[...]} — fully self-contained
- `turn_start` {turn, proposer, rules, state}
- `proposal_request` {turn, rid, timeout_s} — you are the proposer; reply {rid, text}
- `proposal_made` {turn, proposer, text, default}
- `debate_request` {turn, rid, timeout_s, proposal, debates:[{seat,text}]} — non-proposers speak once, sequentially, seeing earlier speeches; reply {rid, text}
- `debate_made` {turn, seat, text, default}
- `vote_request` {turn, rid, timeout_s, proposal, debates} — all seats simultaneously; reply {rid, vote:"aye"|"nay"}; default is nay
- `vote_reveal` {turn, votes:[{seat,vote,default}], passed} — strict majority (2 of 3) passes
- `judge_ruling` {turn, passed, source:"model"|"mechanical", summary, rule_ops, state_ops, rejected_ops, rules, state, victory} — the judge's binding execution of the turn; carries the FULL post-ruling rulebook and state
- `game_over` {winner, reason, scores}
- `final` {scores} — exit cleanly when you see this
- `snapshot` {turn, note} — reconnect marker after the snapshot resend

## The game
House dice: a d6 ADOPTION ROLL pays the proposer when a proposal passes (revealed after the vote); a d12 WINDFALL lands on a uniformly random seat at the end of every turn (initial rule 204, amendable). The game ends after an undisclosed number of turns drawn from the range in session.limits (turns_min..turns_max) — no player or judge knows the draw. Rolls appear as `dice` on each `judge_ruling`. Rules 101-104 are immutable (turn structure, majority vote, judge authority, state model). Everything else — point flows, the victory threshold (common key `victory_points`), any new mechanics expressible as rule text + key-value state — is amendable by passed proposals. The judge LLM interprets the rulebook each turn and updates state; write proposals that are unambiguous and executable. An empty or late proposal auto-fails and costs you a point under rule 202.

## Minimal viable player
Keep the latest `game_start`/`turn_start`/`judge_ruling` rules+state. On each request (`proposal_request`, `debate_request`, `vote_request`) make one bounded model call and reply with the `rid`. Every request is answerable from the request payload plus the last rules/state you saw. The bundled `haiku-baseline` is written exactly this way — read it as the tutorial. A python SDK ships in the game image: subclass `nomic_fable.players.sdk.Policy` (three callbacks: propose/debate/vote) and run `python -m nomic_fable.players.conformance module:Class` — zero unintended defaults is the admission gate.