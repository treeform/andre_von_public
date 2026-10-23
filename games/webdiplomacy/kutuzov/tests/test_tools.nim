import
  std/[json, strutils],
  ../common, ../tools

proc testCalls() =
  ## Preserve ordered calls and arbitrary object arguments without execution.
  let calls = parseToolCalls("""{"calls":[
    {"id":"c1","name":"inspect_board","arguments":{}},
    {"arguments":{"text":"Hello \\ world \"quoted\" \u263a",
      "nested":[true,false,null,-1,0,1.25e2,{"key":"value"}]},
      "name":"unknown_tool","id":"call-2"}
  ]}""")
  doAssert calls.len == 2
  doAssert calls[0].id == "c1"
  doAssert calls[0].name == "inspect_board"
  doAssert calls[0].arguments.kind == JObject
  doAssert calls[0].arguments.len == 0
  doAssert calls[1].name == "unknown_tool"
  doAssert calls[1].arguments["nested"].len == 7
  doAssert calls[1].arguments["nested"][5].getFloat() == 125
  doAssert calls[1].arguments["text"].getStr().endsWith("☺")
  doAssert parseToolCalls(" \n{\"calls\":[]}\t").len == 0
  doAssert ToolProtocol.contains("listed order")
  doAssert ToolProtocol.contains("never fabricate")

proc testInvalidCalls() =
  ## Reject malformed, ambiguous, incomplete, and legacy action envelopes.
  let invalid = [
    "", "null", "[]", "{}", "not JSON",
    "{\"orders\":[]}",
    "{\"calls\":null}",
    "{\"calls\":{}}",
    "{\"calls\":[],\"comment\":\"done\"}",
    "{\"calls\":[],\"calls\":[]}",
    "{\"calls\":[],}",
    "{\"calls\":[]} trailing",
    "{\"calls\":[null]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\"}]}",
    "{\"calls\":[{\"id\":3,\"name\":\"x\",\"arguments\":{}}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":true,\"arguments\":{}}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":[]}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":null}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":{},\"extra\":0}]}",
    "{\"calls\":[{\"id\":\"a\",\"id\":\"b\",\"name\":\"x\",\"arguments\":{}}]}",
    "{\"calls\":[{\"id\":\"a\" \"name\":\"x\",\"arguments\":{}}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":{}},]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":{\"n\":01}}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":{\"n\":+1}}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":{\"n\":1.}}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":{\"n\":1e999}}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":{\"n\":0,\"n\":1}}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":{\"s\":\"bad\nline\"}}]}",
    "{\"calls\":[{\"id\":\"a\",\"name\":\"x\",\"arguments\":{\"s\":\"\\q\"}}]}"
  ]
  for i, text in invalid:
    var rejected = false
    try:
      discard parseToolCalls(text)
    except KutuzovError:
      rejected = true
    doAssert rejected, "Malformed fixture " & $i & " must be rejected."
  for id in ["", "has space", "has.dot", "☃",
    repeat("i", MaximumToolIdBytes + 1)]:
      let envelope = %*{"calls": [{
        "id": id, "name": "valid_name", "arguments": {}
      }]}
      doAssertRaises KutuzovError:
        discard parseToolCalls($envelope)
  for name in ["", "9starts_wrong", "has space", "has.dot", "a-b", "☃",
    repeat("n", MaximumToolNameBytes + 1)]:
      let envelope = %*{"calls": [{
        "id": "a", "name": name, "arguments": {}
      }]}
      doAssertRaises KutuzovError:
        discard parseToolCalls($envelope)
  doAssertRaises KutuzovError:
    discard parseToolCalls("""{"calls":[
      {"id":"same","name":"x","arguments":{}},
      {"id":"same","name":"y","arguments":{}}
    ]}""")
  let complete = """{"calls":[{"id":"a","name":"x","arguments":{
    "text":"Escaped \u263a and \"quotes\"","value":-1.25e2}}]}"""
  for length in 0 ..< complete.len:
    doAssertRaises KutuzovError:
      discard parseToolCalls(complete[0 ..< length])

proc testBounds() =
  ## Bound call count, raw bytes, identifiers, and nested argument depth.
  let entries = newJArray()
  for i in 0 ..< MaximumToolCalls:
    entries.add(%*{"id": "c" & $i, "name": "x", "arguments": {}})
  let maximum = %*{"calls": entries}
  doAssert parseToolCalls($maximum).len == MaximumToolCalls
  entries.add(%*{"id": "extra", "name": "x", "arguments": {}})
  doAssertRaises KutuzovError:
    discard parseToolCalls($maximum)
  let empty = "{\"calls\":[]}"
  doAssert parseToolCalls(
    empty & repeat(" ", MaximumToolReplyBytes - empty.len)
  ).len == 0
  doAssertRaises KutuzovError:
    discard parseToolCalls(repeat(" ", MaximumToolReplyBytes + 1))
  let identifiers = %*{"calls": [{
    "id": repeat("i", MaximumToolIdBytes),
    "name": repeat("n", MaximumToolNameBytes),
    "arguments": {}
  }]}
  doAssert parseToolCalls($identifiers).len == 1
  let nested = "{\"calls\":[{\"id\":\"a\",\"name\":\"x\"," &
    "\"arguments\":{\"deep\":" & repeat("[", 70) & "0" &
    repeat("]", 70) & "}}]}"
  doAssertRaises KutuzovError:
    discard parseToolCalls(nested)

proc testResults() =
  ## Require factual results for every call without guessing missing outcomes.
  let
    calls = parseToolCalls("""{"calls":[
      {"id":"first","name":"inspect_board","arguments":{}},
      {"id":"second","name":"unknown_tool","arguments":{}}
    ]}""")
    outputs = [
      ToolResult(id: "second", output: %*{"error": "unknown_tool"}),
      ToolResult(id: "first", output: %*{"verified": true, "turn": 1})
    ]
    original = $outputs[0].output
    view = toolResultView(calls, outputs)
  doAssert view.len == 1
  doAssert view["results"].len == 2
  doAssert view["results"][0]["id"].getStr() == "first"
  doAssert view["results"][0]["output"] == outputs[1].output
  doAssert view["results"][1]["id"].getStr() == "second"
  doAssert view["results"][1]["output"] == outputs[0].output
  doAssert $outputs[0].output == original
  doAssert toolResultView([], [])["results"].len == 0
  let invalid = [
    @[],
    @[outputs[0]],
    @[outputs[0], outputs[0]],
    @[outputs[0], ToolResult(id: "orphan", output: %*{})],
    @[outputs[0], ToolResult(id: "first")],
    @[outputs[0], outputs[1], outputs[1]]
  ]
  for results in invalid:
    doAssertRaises KutuzovError:
      discard toolResultView(calls, results)
  doAssertRaises KutuzovError:
    discard toolResultView([], outputs)
  doAssertRaises KutuzovError:
    discard toolResultView(
      [ToolCall(id: "bad id", name: "x", arguments: %*{})],
      [ToolResult(id: "bad id", output: %*{})]
    )
  doAssertRaises KutuzovError:
    discard toolResultView(
      [calls[0]],
      [ToolResult(id: "first", output: %repeat("x", MaximumToolReplyBytes))]
    )
  doAssert toolResultView(
    [calls[0]],
    [ToolResult(id: "first", output: newJNull())]
  )["results"][0]["output"].kind == JNull

testCalls()
testInvalidCalls()
testBounds()
testResults()
echo "Tool envelope checks passed"
