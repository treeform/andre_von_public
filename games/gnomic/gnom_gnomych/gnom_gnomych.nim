## Gnom Gnomych — Gnomic policy for Andre von Auto.
## Command player, the tsar_gorokh (nomic) shape adapted to the Gnome
## Moot: pass every action (and the one repair), cycle clear harmless
## enactments (an adopted proposal pays its proposer 3 points and a
## rejected one costs 1), debate briefly with a private AYE intent, and
## vote by ledger: AYE on our own measure, NAY on everybody else's.
## Under the opening unanimity regime a NAY rejects the rival measure
## outright (-1 to its proposer) while AYE-voting baselines still adopt
## ours (+3 to us); once two AYEs suffice our NAY costs nothing. We know
## a measure is ours without parsing any unspecified field: the seat that
## received this turn's proposal_request is this turn's proposer.
##
## Env:
##   GNOM_FRIENDLY=1  vote AYE on everything (the baseline-identical
##                    shape, for fields that punish visible NAYs)
## Protocol confidence: same caveats as nomic/tsar_gorokh — the manifest
## protocol page is a summary, not a field-level spec. Confident: rid
## echo, vote {vote:"aye"|"nay", reason}, debate {text, vote_intent},
## proposal kinds enact|amend|repeal|transmute, malformed action => pass,
## malformed vote => NAY (so our NAY default is also the failure mode).
## Zero model calls — no secret-envs needed at upload time.

import std/[json, os], coworld_client

const harmlessEnactments = [
  "Enact a new rule: the public record of each turn of the Moot shall " &
    "include a one-line summary of that turn's events. This rule changes " &
    "no points and no procedures.",
  "Enact a new rule: each turn of the Moot bears a name, the word 'Turn' " &
    "followed by its number. Naming has no effect on points or procedures.",
  "Enact a new rule: any gnome may include a short explanatory note with " &
    "a proposal. The note has no mechanical effect.",
  "Enact a new rule: gnomes are encouraged, without obligation or " &
    "mechanical effect, to keep proposals under one hundred words.",
  "Enact a new rule: a gnome may thank the Elder during debate. Thanks " &
    "have no effect on points or procedures."
]

proc main() =
  let
    client = newCoworldClient("gnom_gnomych")
    friendly = getEnv("GNOM_FRIENDLY", "") != ""
  var
    proposalsMade = 0
    ownProposalPending = false
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "game_start":
      echo "gnom_gnomych: game start"
    of "turn_start":
      ownProposalPending = false
    of "action_request", "action_repair_request":
      # Pass every action; malformed also resolves to pass, so we send
      # both plausible field spellings.
      client.send(%*{"rid": message{"rid"}, "action": "pass", "text": "pass"})
    of "proposal_request":
      let text = harmlessEnactments[proposalsMade mod harmlessEnactments.len]
      inc proposalsMade
      ownProposalPending = true
      client.send(%*{"rid": message{"rid"}, "kind": "enact", "text": text})
    of "debate_request":
      # vote_intent is private (never revealed to the other gnomes), so
      # a mild supportive statement gives nothing away either way.
      client.send(%*{
        "rid": message{"rid"},
        "text": "The measure is clear and executable; the Moot should " &
          "weigh it on its merits and keep the circuit moving.",
        "vote_intent": if ownProposalPending or friendly: "aye" else: "nay"
      })
    of "vote_request":
      let aye = ownProposalPending or friendly
      client.send(%*{
        "rid": message{"rid"},
        "vote": if aye: "aye" else: "nay",
        "reason": if aye:
          "Harmless and clear; adoption keeps the Moot progressing."
        else:
          "The Moot should adopt measures sparingly; this one is not needed."
      })
      ownProposalPending = false
    of "game_over":
      echo "gnom_gnomych: game over ", message{"scores"}
    of "final":
      echo "gnom_gnomych: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
