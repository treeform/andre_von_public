## Offline parse/decide harness for masha.
## Feeds synthetic sugarscape-v3 observations (PROTOCOL.md shapes for
## Solo / Duos / Commonwealth) through targetFromObservation +
## chooseRuleset and prints the ruleset that would be submitted.
##
##   nim c --hints:off -r games/sugarscape/tools/harness.nim

const mashaOfflineHarness = true
include ../masha/masha

const
  FeatureNames = [
    "agent.sugar", "agent.spice", "agent.wealth",
    "agent.sugarMetabolism", "agent.spiceMetabolism",
    "agent.vision", "agent.movement", "agent.age", "agent.ttl", "agent.mrs",
    "cell.sugar", "cell.spice", "cell.pollution", "cell.distance",
    "cell.occupied", "cell.preyWealth", "cell.welfare",
    "world.timestep", "world.population", "world.gini", "world.meanWealth"
  ]
  TraitNames = ["aggression", "trade", "lending", "fertility"]
  NaryOps = ["+", "-", "*", "/", "min", "max", "and", "or"]
  UnaryOps = ["abs", "neg", "not"]
  BinaryOps = ["pow", "<", "<=", ">", ">=", "==", "!="]

proc isFiniteNumber(node: JsonNode): bool =
  if node.isNil: return false
  case node.kind
  of JInt, JFloat: true
  else: false

proc exprOk(node: JsonNode; path: string; issues: var seq[string]) =
  if node.isNil:
    issues.add(path & ": missing expression")
    return
  if isFiniteNumber(node):
    return
  if node.kind != JArray or node.len == 0:
    issues.add(path & ": expression must be a number or a non-empty operator array")
    return
  let opNode = node[0]
  if opNode.kind != JString:
    issues.add(path & "[0]: operator must be a string")
    return
  let op = opNode.getStr()
  let argc = node.len - 1
  if op == "get":
    if argc != 1:
      issues.add(path & ": get expects 1 argument")
      return
    if node[1].kind != JString:
      issues.add(path & "[1]: feature name must be a string")
      return
    let feature = node[1].getStr()
    var known = false
    for name in FeatureNames:
      if name == feature: known = true
    if not known:
      issues.add(path & "[1]: unknown feature " & feature)
    return
  var knownOp = op == "if"
  for name in NaryOps:
    if name == op: knownOp = true
  for name in UnaryOps:
    if name == op: knownOp = true
  for name in BinaryOps:
    if name == op: knownOp = true
  if not knownOp:
    issues.add(path & "[0]: unknown operator " & op)
    return
  if op in NaryOps and argc < 2:
    issues.add(path & ": " & op & " expects at least 2 arguments")
  elif op in UnaryOps and argc != 1:
    issues.add(path & ": " & op & " expects 1 argument")
  elif op in BinaryOps and argc != 2:
    issues.add(path & ": " & op & " expects 2 arguments")
  elif op == "if" and argc != 3:
    issues.add(path & ": if expects 3 arguments")
  for i in 1 ..< node.len:
    exprOk(node[i], path & "[" & $i & "]", issues)

proc grammarIssues(ruleset: JsonNode): seq[string] =
  ## SugarLang v1 object grammar from docs/rules.md / RULES.md.
  if ruleset.isNil or ruleset.kind == JNull:
    return
  if ruleset.kind != JObject:
    return @["$: ruleset must be an object or null"]
  for key in ruleset.keys:
    if key notin ["version", "traits", "movement"]:
      result.add("$." & key & ": unknown ruleset field")
  let hasBehavior = ruleset.hasKey("traits") or ruleset.hasKey("movement")
  if hasBehavior and not ruleset.hasKey("version"):
    result.add("$.version: required when traits or movement is present")
  elif ruleset.hasKey("version"):
    let version = ruleset{"version"}
    if version.isNil or version.kind != JInt or version.getInt() != 1:
      result.add("$.version: only SugarLang version 1 is supported")
  if ruleset.hasKey("traits"):
    let traits = ruleset{"traits"}
    if traits.isNil or traits.kind != JObject:
      result.add("$.traits: traits must be an object")
    else:
      for key in traits.keys:
        var known = false
        for name in TraitNames:
          if name == key: known = true
        if not known:
          result.add("$.traits." & key & ": unknown trait")
        elif not isFiniteNumber(traits{key}):
          result.add("$.traits." & key & ": trait value must be a finite number")
  if ruleset.hasKey("movement"):
    let movement = ruleset{"movement"}
    if movement.isNil or movement.kind != JArray or movement.len == 0:
      result.add("$.movement: movement must be a non-empty array")
    else:
      for i in 0 ..< movement.len:
        let
          rule = movement[i]
          path = "$.movement[" & $i & "]"
        if rule.kind != JObject:
          result.add(path & ": movement rule must be an object")
          continue
        for key in rule.keys:
          if key notin ["if", "score"]:
            result.add(path & "." & key & ": unknown movement-rule field")
        if not rule.hasKey("score"):
          result.add(path & ".score: required")
        else:
          exprOk(rule{"score"}, path & ".score", result)
        if rule.hasKey("if"):
          exprOk(rule{"if"}, path & ".if", result)
      let last = movement[movement.len - 1]
      if last.kind == JObject and last.hasKey("if"):
        result.add("$.movement[-1]: final movement rule must omit if")

proc soloObservation(): JsonNode =
  ## PROTOCOL.md distribution observation (Solo ladder / wealth target).
  %*{
    "type": "observation",
    "protocol": Protocol,
    "seat": 0,
    "config": {"seats": 1, "timesteps": 1000},
    "target": {
      "id": "wealth.skewed-gini-0.5",
      "kind": "distribution",
      "variable": "wealth",
      "scope": "global",
      "support": [0, 1000],
      "bins": [0, 25, 50],
      "probs": [0.4, 0.6],
      "window": 100,
      "source": "engine"
    },
    "ruleset_schema": {
      "version": 1,
      "limits": {"max_nodes": 256, "max_depth": 16, "max_bytes": 32768}
    }
  }

proc duoObservation(seat: int, targetId, variable: string): JsonNode =
  ## Duo ladder: two seats, distinct global targets, same observation shape.
  %*{
    "type": "observation",
    "protocol": Protocol,
    "seat": seat,
    "config": {"seats": 2, "timesteps": 1000},
    "target": {
      "id": targetId,
      "kind": "distribution",
      "variable": variable,
      "scope": "global"
    }
  }

proc commonwealthObservation(): JsonNode =
  ## PROTOCOL.md maximize observation (Commonwealth).
  %*{
    "type": "observation",
    "protocol": Protocol,
    "seat": 0,
    "config": {"seats": 1, "timesteps": 1000},
    "target": {
      "id": "wellness.max",
      "kind": "maximize",
      "variable": "wellness",
      "description": "Maximize the summed normalized DTL happiness of agents surviving to the final tick."
    }
  }

proc nestedWrapper(inner: JsonNode): JsonNode =
  ## Coworld-style wrapper some seats see: type at the top, payload nested.
  %*{"type": "observation", "observation": inner}

proc drive(label: string, observation: JsonNode) =
  echo "=== ", label, " ==="
  let
    target = targetFromObservation(observation)
    action = actionFromObservation(observation)
    ruleset = action{"ruleset"}
  echo "parsed target id=", target{"id"}.getStr(),
    " kind=", target{"kind"}.getStr(),
    " variable=", target{"variable"}.getStr()
  echo pretty(ruleset)
  let issues = grammarIssues(ruleset)
  if issues.len > 0:
    echo "PIPELINE DIE: SugarLang grammar"
    for issue in issues:
      echo "  ", issue
  else:
    echo "grammar: ok"
  let actionType = action{"type"}.getStr()
  if actionType != "action" or ruleset.isNil:
    echo "PIPELINE DIE: action envelope is not {type:action, ruleset:...}"
  echo ""

when isMainModule:
  drive("solo wealth.skewed-gini-0.5", soloObservation())
  drive("duos seat 0 wealth.egalitarian",
    duoObservation(0, "wealth.egalitarian", "wealth"))
  drive("duos seat 1 tribe.diversity",
    duoObservation(1, "tribe.diversity", "majority_tribe_share"))
  drive("commonwealth wellness.max", commonwealthObservation())
  drive("commonwealth nested observation wrapper",
    nestedWrapper(commonwealthObservation()))
  drive("kind-only maximize (no id)", %*{
    "type": "observation",
    "protocol": Protocol,
    "target": {"kind": "maximize", "variable": "wellness"}
  })
  echo "=== commonwealth two-seat identical hash ==="
  let
    a = actionFromObservation(commonwealthObservation()){"ruleset"}
    b = actionFromObservation(%*{
      "type": "observation",
      "protocol": Protocol,
      "seat": 1,
      "target": {
        "id": "wellness.max",
        "kind": "maximize",
        "variable": "wellness"
      }
    }){"ruleset"}
  if $a == $b:
    echo "rulesets_identical: yes (same constitution both seats)"
  else:
    echo "PIPELINE DIE: commonwealth seats produced different rulesets"
    echo $a
    echo $b
