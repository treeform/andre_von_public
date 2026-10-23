import
  std/[json, math],
  jsony,
  common

const
  MaximumToolCalls* = 8
  MaximumToolReplyBytes* = 60_000
  MaximumToolIdBytes* = 64
  MaximumToolNameBytes* = 64
  MaximumToolDepth = 64
  ToolProtocol* = """
Return only JSON: {"calls":[{"id":"c1","name":"tool_name","arguments":{}}]}.
Use at most 8 calls, unique short ASCII IDs, and object arguments. Use an
explicit finishing tool when done. Calls in one reply execute in listed order.
You cannot see an earlier call's result until the next reply. The host returns
{"results":[{"id":"c1","output":{}}]} with one factual result per call.
A requested action is a model claim, not proof it happened. Trust the actual
host result, report errors honestly, and never fabricate execution or success.
"""

type
  ToolCall* = object
    id*: string
    name*: string
    arguments*: JsonNode

  ToolResult* = object
    id*: string
    output*: JsonNode

proc skipSpace(text: string, position: var int) {.raises: [].} =
  ## Skip only whitespace allowed in JSON.
  while position < text.len and text[position] in {' ', '\t', '\r', '\n'}:
    inc position

proc take(text: string, position: var int, expected: char)
    {.raises: [KutuzovError].} =
  ## Consume a required JSON delimiter without accepting omitted commas.
  skipSpace(text, position)
  if position >= text.len or text[position] != expected:
    raise newException(KutuzovError, "The tool reply has invalid JSON syntax.")
  inc position

proc readString(text: string, position: var int): string
    {.raises: [ValueError, KutuzovError].} =
  ## Decode JSON strings while rejecting unescaped control characters.
  skipSpace(text, position)
  if position >= text.len or text[position] != '"':
    raise newException(KutuzovError, "A tool JSON object key must be a string.")
  let start = position
  parseHook(text, position, result)
  var i = start + 1
  while i < position - 1:
    if ord(text[i]) < 32:
      raise newException(KutuzovError,
        "The tool reply contains an unescaped control character.")
    if text[i] == '\\':
      inc i
      if i >= position - 1 or
        text[i] notin {'"', '\\', '/', 'b', 'f', 'n', 'r', 't', 'u'}:
          raise newException(KutuzovError,
            "The tool reply contains an invalid JSON string escape.")
      if text[i] == 'u':
        for j in 1 .. 4:
          if i + j >= position - 1 or
            text[i + j] notin {'0' .. '9', 'a' .. 'f', 'A' .. 'F'}:
              raise newException(KutuzovError,
                "The tool reply contains an invalid Unicode escape.")
        i += 4
    inc i

proc validNumber(text: string): bool {.raises: [].} =
  ## Accept the JSON number grammar without relaxed numeric spellings.
  var position = 0
  if position < text.len and text[position] == '-':
    inc position
  if position >= text.len:
    return false
  if text[position] == '0':
    inc position
  elif text[position] in {'1' .. '9'}:
    while position < text.len and text[position] in {'0' .. '9'}:
      inc position
  else:
    return false
  if position < text.len and text[position] == '.':
    inc position
    let start = position
    while position < text.len and text[position] in {'0' .. '9'}:
      inc position
    if start == position:
      return false
  if position < text.len and text[position] in {'e', 'E'}:
    inc position
    if position < text.len and text[position] in {'+', '-'}:
      inc position
    let start = position
    while position < text.len and text[position] in {'0' .. '9'}:
      inc position
    if start == position:
      return false
  position == text.len

proc readValue(text: string, position: var int, depth: int): JsonNode
    {.raises: [ValueError, KutuzovError].} =
  ## Parse bounded JSON containers with explicit delimiters and unique keys.
  skipSpace(text, position)
  if position >= text.len or depth > MaximumToolDepth:
    raise newException(KutuzovError,
      "The tool reply is incomplete or exceeds the JSON nesting limit.")
  case text[position]
  of '{':
    result = newJObject()
    inc position
    skipSpace(text, position)
    if position < text.len and text[position] == '}':
      inc position
      return
    while true:
      let key = readString(text, position)
      if result.hasKey(key):
        raise newException(KutuzovError,
          "The tool reply contains a duplicate JSON object key.")
      take(text, position, ':')
      result[key] = readValue(text, position, depth + 1)
      skipSpace(text, position)
      if position < text.len and text[position] == '}':
        inc position
        return
      take(text, position, ',')
  of '[':
    result = newJArray()
    inc position
    skipSpace(text, position)
    if position < text.len and text[position] == ']':
      inc position
      return
    while true:
      result.add(readValue(text, position, depth + 1))
      skipSpace(text, position)
      if position < text.len and text[position] == ']':
        inc position
        return
      take(text, position, ',')
  of '"':
    result = %readString(text, position)
  else:
    let start = position
    parseHook(text, position, result)
    if result.kind in {JInt, JFloat}:
      if not validNumber(text[start ..< position]) or
        (result.kind == JFloat and
        result.getFloat().classify in {fcNan, fcInf, fcNegInf}):
          raise newException(KutuzovError,
            "The tool reply contains an invalid or nonfinite number.")

proc validId(value: string): bool {.raises: [].} =
  ## Accept bounded ASCII call identifiers for unambiguous result matching.
  if value.len == 0 or value.len > MaximumToolIdBytes:
    return false
  for character in value:
    if character notin {'a' .. 'z', 'A' .. 'Z', '0' .. '9', '_', '-'}:
      return false
  true

proc validName(value: string): bool {.raises: [].} =
  ## Accept bounded tool names without deciding which tools are available.
  if value.len == 0 or value.len > MaximumToolNameBytes or
    value[0] notin {'a' .. 'z', 'A' .. 'Z'}:
      return false
  for character in value:
    if character notin {'a' .. 'z', 'A' .. 'Z', '0' .. '9', '_'}:
      return false
  true

proc validateCalls(calls: openArray[ToolCall]) {.raises: [KutuzovError].} =
  ## Check manually constructed calls with the same rules as parsed calls.
  if calls.len > MaximumToolCalls:
    raise newException(KutuzovError, "A tool reply may contain at most 8 calls.")
  for i, call in calls:
    if not validId(call.id) or not validName(call.name):
      raise newException(KutuzovError,
        "Tool IDs and names must be bounded ASCII identifiers.")
    if call.arguments.isNil or call.arguments.kind != JObject:
      raise newException(KutuzovError, "Tool arguments must be a JSON object.")
    for j in 0 ..< i:
      if calls[j].id == call.id:
        raise newException(KutuzovError, "Tool call IDs must be unique.")

proc parseToolCalls*(text: string): seq[ToolCall]
    {.raises: [KutuzovError].} =
  ## Decode only the bounded action envelope without executing its calls.
  if text.len == 0 or text.len > MaximumToolReplyBytes:
    raise newException(KutuzovError,
      "The tool reply must contain between 1 and 60000 bytes.")
  var position = 0
  let envelope =
    try:
      readValue(text, position, 0)
    except ValueError:
      raise newException(KutuzovError, "The tool reply is not valid JSON.")
  skipSpace(text, position)
  if position != text.len or envelope.kind != JObject or
    envelope.len != 1 or not envelope.hasKey("calls") or
    envelope{"calls"}.kind != JArray:
      raise newException(KutuzovError,
        "A tool reply must contain only a calls array.")
  let calls = envelope{"calls"}
  if calls.len > MaximumToolCalls:
    raise newException(KutuzovError, "A tool reply may contain at most 8 calls.")
  for call in calls:
    if call.kind != JObject or call.len != 3 or
      call{"id"}.isNil or call{"id"}.kind != JString or
      call{"name"}.isNil or call{"name"}.kind != JString or
      call{"arguments"}.isNil or call{"arguments"}.kind != JObject:
        raise newException(KutuzovError,
          "Each tool call needs only id, name, and object arguments.")
    result.add(ToolCall(
      id: call{"id"}.getStr(),
      name: call{"name"}.getStr(),
      arguments: call{"arguments"}
    ))
  validateCalls(result)

proc toolResultView*(
  calls: openArray[ToolCall],
  results: openArray[ToolResult]
): JsonNode {.raises: [KutuzovError].} =
  ## Match factual host outputs exactly once and preserve original call order.
  validateCalls(calls)
  if results.len != calls.len:
    raise newException(KutuzovError,
      "Each tool call requires exactly one host result.")
  let outputs = newJArray()
  var matched = newSeq[bool](results.len)
  for call in calls:
    var index = -1
    for i, item in results:
      if item.id == call.id:
        if index >= 0:
          raise newException(KutuzovError, "Tool result IDs must be unique.")
        index = i
    if index < 0 or results[index].output.isNil:
      raise newException(KutuzovError,
        "A tool result is missing or refers to an unknown call ID.")
    matched[index] = true
    outputs.add(%*{
      "id": call.id,
      "output": results[index].output
    })
  for present in matched:
    if not present:
      raise newException(KutuzovError, "A tool result has an orphan call ID.")
  result = %*{"results": outputs}
  if ($result).len > MaximumToolReplyBytes:
    raise newException(KutuzovError,
      "The tool results exceed the 60000-byte reply limit.")
