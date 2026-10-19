## Tsar Gorokh — Nomic policy for Andre von Auto.
## Command player: this is a Nim rewrite of the only bundled example,
## `nomic.players.baseline` ("passes actions, proposes harmless
## enactments, and votes AYE" — deterministic, no network). We keep that
## certified-safe shape: pass every action (and the one repair), cycle
## clear harmless enactments (an adopted proposal pays its proposer 3
## points, so proposing something unvetoable every turn is free income
## under the early unanimity regime of AYE voters), debate briefly with
## an AYE intent, and vote AYE.
##
## Protocol confidence: the manifest protocol page is a summary, not a
## field-level spec. Known for sure: decision requests are
## action_request / action_repair_request / proposal_request /
## debate_request / vote_request; replies echo `rid`; actions are
## natural-language strings; proposal kinds are enact|amend|repeal|
## transmute; debate replies carry text + private vote_intent; vote
## replies carry vote aye|nay + reason. Exact reply field names for
## actions and proposals are reconstructed (see ideas.md); the failure
## mode is benign for actions (malformed => pass, which is what we
## want anyway) but costs the proposal slot if wrong.
## Zero model calls — no secret-envs needed at upload time.

import std/json, coworld_client

const harmlessEnactments = [
  "Enact a new rule: the public record of each turn shall include a " &
    "one-line summary of that turn's events. This rule changes no points " &
    "and no procedures.",
  "Enact a new rule: each turn bears a name, the word 'Turn' followed by " &
    "its number. Naming has no effect on points or procedures.",
  "Enact a new rule: any player may include a short explanatory note with " &
    "a proposal. The note has no mechanical effect.",
  "Enact a new rule: players are encouraged, without obligation or " &
    "mechanical effect, to keep proposals under one hundred words.",
  "Enact a new rule: a player may thank the Judge during debate. Thanks " &
    "have no effect on points or procedures."
]

proc main() =
  let client = newCoworldClient("tsar_gorokh")
  var proposalsMade = 0
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "game_start":
      echo "tsar_gorokh: game start"
    of "action_request", "action_repair_request":
      # Baseline passes every action; malformed also resolves to pass,
      # so we send both plausible field spellings.
      client.send(%*{"rid": message{"rid"}, "action": "pass", "text": "pass"})
    of "proposal_request":
      let text = harmlessEnactments[proposalsMade mod harmlessEnactments.len]
      inc proposalsMade
      client.send(%*{"rid": message{"rid"}, "kind": "enact", "text": text})
    of "debate_request":
      client.send(%*{
        "rid": message{"rid"},
        "text": "The measure is clear, harmless, and executable; adopting " &
          "it keeps the assembly moving. I intend to vote aye.",
        "vote_intent": "aye"
      })
    of "vote_request":
      client.send(%*{
        "rid": message{"rid"},
        "vote": "aye",
        "reason": "Harmless and clear; adoption keeps the game progressing."
      })
    of "game_over":
      echo "tsar_gorokh: game over ", message{"scores"}
    of "final":
      echo "tsar_gorokh: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
