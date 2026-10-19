## Likho — Contagion policy for Andre von Auto.
## The contagion player container is deliberately thin: it connects, sends
## one frame carrying its operator prompt (or a scripted baseline name),
## and thereafter only listens; the game container runs the LLM and makes
## every weekly decision. This is the Nim rewrite of /bin/contagion-player.
##
## Default is the published `sentinel` baseline, not the LLM prompt.
## decideAll (src/contagion/llm.nim) plays scripted whenever scripted !=
## skNone, even with a non-empty prompt. League leader is daveey-1
## (contagion-outpost-sentinel). Sentinel's lockdown/testing/road cuts
## are the argmax of the x0.25..x4 grid in tests/test_sweep.nim.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (sentinel | laggard).
##                   Defaults to sentinel. Empty string forces the prompt.
## Upload note: default is scripted, so no Bedrock flag is required. LLM
## override still needs --secret-env USE_BEDROCK=true.

import std/[json, os, strutils], coworld_client

const defaultPrompt = """
You are Likho, a cold-eyed governor. Score = accumulated GDP - 2 x deaths.
The real killer is hospital overload: IFR is 0.8% normally and up to 3.2%
when infectious cases exceed 25,000. Keep TRUE infected far below 25,000.

DE-BIAS EVERYTHING. Reported cases = truth x detection. Detection by testing
level: 0->15%, 1->35%, 2->65%, 3->90%. Testing levels are public, so every
week estimate every region's TRUE cases = reported / detection. Do this for
yourself too. Prevalence = true cases / 1,000,000. Log estimates in notes.

DIALS, by own estimated true prevalence:
- Baseline: testing 2 from week 1 (transmission x0.78, 65% detection, 55/wk).
  Raise to testing 3 when prevalence > 1% or when finishing an eradication.
  Drop to testing 1 only after 2+ clean weeks (< 0.05%) everywhere nearby.
- Lockdown: < 0.1% -> L1; 0.1-0.5% -> L2; 0.5-2% -> L3; > 2% or hospital
  strained/overloaded/critical -> L4. L2 + testing 2 gives weekly beta about
  0.5, which shrinks the epidemic; use L3-L4 only to crush surges, then step
  down ONE level per week as the estimate falls. Never sit at L4 with a
  clean region: L4 burns 600/wk of output.
- The variant lands in some week 8-12 (+25% transmission forever). If your
  numbers stop falling on unchanged dials, that is it: add one lockdown
  level and re-derive.

BORDERS (yours cost 10/30 per road, and also tax the far region 5/15; the
effective gate is the tighter end): gate per neighbour's estimated true
prevalence: < 0.2% -> open; 0.2-1.5% -> screened(1); > 1.5% -> closed(2).
A closed road still leaks 12%, so closure buys time, never safety - pair it
with your own dials. Do not close roads against clean neighbours; the spend
spillover makes them poorer and sicker later.

AID (<= 200/wk, <= 3 transfers, unconditional): infections next door become
your infections. When a neighbour's true prevalence is > 3x yours and their
ledger is thin, wire 100-200 and say plainly what it is for: "150 to Ash
Hollow to hold L3+testing2 two more weeks". Repeat only if their published
dials actually tightened; never pay a region that stays at testing 0 twice.

TALK (160 runes, arrives one week late, non-binding): each week state your
dials, your de-biased estimate of the hottest region, and one request. Call
out under-testers by name with the corrected number: "Saltmarch reported 400
at testing 0 - that is ~2,700 real, please screen your roads". Coordination
is worth more than eloquence. Never reveal you would rather free-ride.

ENDGAME: there is no early-out on eradication - clean weeks bank full GDP.
Once your estimate is < 0.05% and neighbours are clean, reopen: lockdown 0-1,
gates open, testing 1 as a tripwire; re-tighten instantly on any uptick.
Weeks 18-20, favour GDP: deaths already seeded will resolve regardless, so
do not buy L4 in week 20 - but keep gates screened against hot regions.

Reply every week with exactly one JSON object: required "lockdown" 0-4 and
"testing" 0-3, plus "borders" naming only your own three roads by region
name, "aid" entries, a short "say", and "notes" carrying your de-biased
table and aid promises made or received.
"""

proc main() =
  let
    scripted = getEnv("PLAYER_SCRIPTED", "sentinel").strip()
    ## Empty the prompt whenever a baseline is named so an LLM path cannot
    ## fire if the scripted field is dropped. Empty PLAYER_SCRIPTED restores
    ## the operator prompt.
    prompt =
      if scripted.len > 0: ""
      else: getEnv("PLAYER_PROMPT", defaultPrompt)
    client = newCoworldClient("likho")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # covers the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  echo "likho: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "likho: seated slot ", message{"slot"}.getInt(),
        " region ", message{"name"}.getStr()
    of "final":
      echo "likho: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
