## Kolobok — Collab Cooking policy for Andre von Auto.
## NOT a thin prompt seat: the player container must send one action every
## tick. Default is the published `runner` baseline, not the LLM prompt:
## league leaders are co-gas-collab-cooking-runner-relhalpha (wr 0.46) and
## co-gas-collab-cooking-runner-richard (wr 0.32). Runner is every seat
## all-rounder (nearest useful job; no slot roles). Score is team dishes
## plus 0.01 * own deliveries, so a slot-pinned brigade prep/cook never
## collects the epsilon and cannot cover a bad partner. Scripted seats
## get no `plan` turns, so an LLM cannot walk us off a ready pot.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (<= 1200 runes)
##   PLAYER_SCRIPTED play a scripted baseline (brigade | runner | passer |
##                   courier). Defaults to runner. Empty string forces
##                   the prompt.
## Upload note: default is scripted, so no Bedrock flag is required. LLM
## override needs --secret-env USE_BEDROCK=true.

import std/[json, os, strutils, unicode], coworld_client, kolobok_brain

const
  PromptRunes = 1200
  TalkRunes = 140

const defaultPrompt = """
You are Kolobok, kitchen shift-lead. Team dishes are the only score.
Give ONE clear job per turn.
Priorities: 1) A ready or burned pot or fryer outranks everything - go
plate it (station pot/fryer). 2) Serve only recipes with live tickets; a
dish with no ticket waits on a counter, not at the pass. 3) Keep the
chain fed: veg -> chop -> pot or fryer; dirty plates are future dishes -
if plates run short, someone sinks. 4) Cook what the board queues: soup =
chopped veg + meat in the pot, fries = chopped veg in the fryer, salad =
plate onto chopped veg at the board; soup burns 14 ticks after ready,
fries 3 - plate before starting more.
Split kitchens (forced, crowded, circuit, asymmetric): do not crowd the
choke. Left cogs fetch, chop, stage on the divider counters (zone left,
handoff on); right cogs cook, plate, serve (zone right). In ring and
figure-eight set yield_to when meeting an ally head-on; the empty-handed
cog gives way.
Keep each cog on its lane for several turns - churn wastes walks.
Holding a dish? station pass. Idle? prep the next ticket's recipe.
say: one line splitting lanes by alias ("A chops, D serves").
note: the kitchen name, your lane, who covers what.
"""

proc runeCap(text: string, limit: int): string =
  if text.runeLen <= limit:
    return text
  text.runeSubStr(0, limit)

proc main() =
  let
    scripted = getEnv("PLAYER_SCRIPTED", "runner").strip().toLowerAscii()
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    client = newCoworldClient("kolobok")
  var
    brain: KitchenBrain
    configured = false
    alias = "Kolobok"
  proc registerFrame(): JsonNode =
    if scripted in BaselineNames:
      %*{"type": "register", "kind": "scripted", "baseline": scripted}
    else:
      %*{"type": "register", "kind": "prompt",
         "prompt": runeCap(prompt, PromptRunes)}
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "player_config":
      let slot = message{"slot"}.getInt()
      alias = message{"alias"}.getStr("Cog-" & $slot)
      let baseline =
        if scripted in BaselineNames: scripted else: DefaultBaseline
      brain = initKitchenBrain(message, slot, baseline)
      configured = true
      client.send(registerFrame())
      echo "kolobok: slot ", slot, " (", alias, ") registered on ",
        message{"layout"}.getStr(),
        " kind=", (if scripted in BaselineNames: "scripted" else: "prompt"),
        " baseline=", (if scripted in BaselineNames: scripted else: "none")
    of "observation":
      if not configured:
        return
      let step = message{"step"}.getInt()
      let (actionName, task) = brain.stepBrain(message{"observation"})
      client.send(%*{
        "type": "action",
        "action_name": actionName,
        "policy_infos": {"policy_name": alias,
                         "task": runeCap(task, TalkRunes)},
        "request_id": "step-" & $step
      })
    of "plan":
      if configured:
        brain.applyPlan(message)
    of "final":
      echo "kolobok: final, reason ", message{"reason"}.getStr(),
        " dishes ", message{"dishes"}
      quit(0)
    else:
      discard

main()
