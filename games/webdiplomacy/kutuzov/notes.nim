import
  std/[json, strutils, unicode],
  jsony,
  common

const
  MaxNotes* = 8
  MaxNoteUpdates* = 16
  MaxNoteKeyBytes* = 32
  MaxNoteTextBytes* = 512
  MaxNotePhaseBytes* = 32
  MaxNoteDecisionBytes* = 96
  MaxNoteModelBytes* = 96
  MaxNotesEncodedBytes* = 6144
  MaxNoteUpdateBytes* = 12_288

type
  StrategicNote* = object
    key*, text*: string
    originPhase*, originDecision*, originModel*: string

  NoteUpdateKind* = enum
    Upsert, Delete

  NoteUpdate* = object
    kind*: NoteUpdateKind
    key*, text*: string

proc checkText(value, label: string, limit: int) {.raises: [KutuzovError].} =
  ## Require nonempty bounded UTF-8 without modifying the supplied text.
  if value.len > limit:
    raise newException(KutuzovError, label & " exceeds its byte limit")
  if validateUtf8(value) >= 0:
    raise newException(KutuzovError, label & " is not valid UTF-8")
  if strutils.strip(value).len == 0:
    raise newException(KutuzovError, label & " must not be empty")

proc checkKey(key: string) {.raises: [KutuzovError].} =
  ## Require a stable lowercase ASCII key with no normalization.
  if key.len == 0 or key.len > MaxNoteKeyBytes:
    raise newException(KutuzovError, "Note key length must be 1 to 32 bytes")
  if key[0] notin {'a' .. 'z'}:
    raise newException(
      KutuzovError,
      "Note key must start with a lowercase letter"
    )
  for character in key:
    if character notin {'a' .. 'z', '0' .. '9', '_', '-'}:
      raise newException(KutuzovError, "Note key contains an invalid character")

proc checkFields(
  value: JsonNode,
  expected: openArray[string],
  label: string
) {.raises: [KutuzovError].} =
  ## Reject missing and extra fields instead of interpreting partial records.
  if value.isNil or value.kind != JObject:
    raise newException(KutuzovError, label & " must be an object")
  if value.len != expected.len:
    raise newException(KutuzovError, label & " has missing or unknown fields")
  for field in expected:
    if not value.hasKey(field):
      raise newException(KutuzovError, label & " is missing " & field)

proc stringField(
  value: JsonNode,
  field: string
): string {.raises: [KutuzovError].} =
  ## Read an exact JSON string without coercing numbers, booleans or null.
  let node = value{field}
  if node.isNil or node.kind != JString:
    raise newException(
      KutuzovError,
      "Note field " & field & " must be a string"
    )
  node.getStr()

proc noteJson(note: StrategicNote): JsonNode {.raises: [].} =
  ## Encode one model claim with host-supplied provenance.
  %*{
    "key": note.key,
    "text": note.text,
    "origin_phase": note.originPhase,
    "origin_decision": note.originDecision,
    "origin_model": note.originModel
  }

proc encodedView(notes: openArray[StrategicNote]): JsonNode {.raises: [].} =
  ## Label the notes as model claims rather than verified host facts.
  var items = newJArray()
  for note in notes:
    items.add note.noteJson()
  %*{"source": "model_claims", "notes": items}

proc validateNotes*(notes: openArray[StrategicNote])
    {.raises: [KutuzovError].} =
  ## Validate typed persisted notes and the complete encoded observation size.
  if notes.len > MaxNotes:
    raise newException(KutuzovError, "Strategic notes exceed the record limit")
  for i, note in notes:
    checkKey(note.key)
    checkText(note.text, "Note text", MaxNoteTextBytes)
    checkText(note.originPhase, "Note origin phase", MaxNotePhaseBytes)
    checkText(note.originDecision, "Note origin decision", MaxNoteDecisionBytes)
    checkText(note.originModel, "Note origin model", MaxNoteModelBytes)
    for j in 0 ..< i:
      if note.key == notes[j].key:
        raise newException(
          KutuzovError,
          "Strategic notes contain duplicate keys"
        )
  if ($encodedView(notes)).len > MaxNotesEncodedBytes:
    raise newException(
      KutuzovError,
      "Strategic notes exceed the encoded byte limit"
    )

proc notesView*(notes: openArray[StrategicNote]): JsonNode
    {.raises: [KutuzovError].} =
  ## Expose all claims and their original phases without automatic expiration.
  validateNotes(notes)
  encodedView(notes)

proc parseNoteUpdates*(value: JsonNode): seq[NoteUpdate]
    {.raises: [KutuzovError].} =
  ## Parse explicit upserts and deletes; an absent argument leaves notes intact.
  if value.isNil:
    return
  if value.kind != JArray:
    raise newException(KutuzovError, "Note updates must be an array")
  if value.len > MaxNoteUpdates:
    raise newException(KutuzovError, "Note updates exceed the batch limit")
  for item in value:
    if item.isNil or item.kind != JObject:
      raise newException(KutuzovError, "Each note update must be an object")
    let operation = stringField(item, "op")
    var update: NoteUpdate
    case operation
    of "upsert":
      checkFields(item, ["op", "key", "text"], "Note upsert")
      update.kind = Upsert
      update.text = stringField(item, "text")
      checkText(update.text, "Note text", MaxNoteTextBytes)
    of "delete":
      checkFields(item, ["op", "key"], "Note delete")
      update.kind = Delete
    else:
      raise newException(
        KutuzovError,
        "Note operation must be upsert or delete"
      )
    update.key = stringField(item, "key")
    checkKey(update.key)
    for previous in result:
      if previous.key == update.key:
        raise newException(KutuzovError, "Note update batch repeats a key")
    result.add update
  if ($value).len > MaxNoteUpdateBytes:
    raise newException(KutuzovError, "Note updates exceed the batch byte limit")

proc decodeNotes(value: string, limit: int): JsonNode
    {.raises: [KutuzovError].} =
  ## Map malformed JSON and oversized encoded inputs to the bot exception.
  if value.len > limit:
    raise newException(
      KutuzovError,
      "Encoded notes input exceeds its byte limit"
    )
  try:
    result = value.fromJson(JsonNode)
  except ValueError:
    raise newException(KutuzovError, "Notes input is not valid JSON")

proc parseNoteUpdates*(value: string): seq[NoteUpdate]
    {.raises: [KutuzovError].} =
  ## Decode a bounded model update batch with strict string field types.
  parseNoteUpdates(decodeNotes(value, MaxNoteUpdateBytes))

proc parseNotes*(value: JsonNode): seq[StrategicNote]
    {.raises: [KutuzovError].} =
  ## Read the claim view or jsony record array; absent legacy notes are empty.
  if value.isNil or value.kind == JNull:
    return
  var
    items = value
    snakeFields = false
  if value.kind == JObject:
    checkFields(value, ["source", "notes"], "Strategic notes view")
    if stringField(value, "source") != "model_claims":
      raise newException(KutuzovError, "Strategic notes must be model claims")
    items = value{"notes"}
    snakeFields = true
  if items.isNil or items.kind != JArray:
    raise newException(
      KutuzovError,
      "Persisted strategic notes must be an array"
    )
  if items.len > MaxNotes:
    raise newException(KutuzovError, "Strategic notes exceed the record limit")
  let
    phaseField =
      if snakeFields:
        "origin_phase"
      else:
        "originPhase"
    decisionField =
      if snakeFields:
        "origin_decision"
      else:
        "originDecision"
    modelField =
      if snakeFields:
        "origin_model"
      else:
        "originModel"
  for item in items:
    checkFields(
      item,
      ["key", "text", phaseField, decisionField, modelField],
      "Persisted strategic note"
    )
    result.add StrategicNote(
      key: stringField(item, "key"),
      text: stringField(item, "text"),
      originPhase: stringField(item, phaseField),
      originDecision: stringField(item, decisionField),
      originModel: stringField(item, modelField)
    )
  validateNotes(result)

proc parseNotes*(value: string): seq[StrategicNote]
    {.raises: [KutuzovError].} =
  ## Decode bounded persisted claims with explicit origin metadata.
  parseNotes(decodeNotes(value, MaxNotesEncodedBytes))

proc applyNoteUpdates*(
  notes: var seq[StrategicNote],
  updates: openArray[NoteUpdate],
  phase, decision, model: string
) {.raises: [KutuzovError].} =
  ## Apply the whole explicit model batch atomically or leave all notes intact.
  validateNotes(notes)
  if updates.len == 0:
    return
  if updates.len > MaxNoteUpdates:
    raise newException(KutuzovError, "Note updates exceed the batch limit")
  checkText(phase, "Note origin phase", MaxNotePhaseBytes)
  checkText(decision, "Note origin decision", MaxNoteDecisionBytes)
  checkText(model, "Note origin model", MaxNoteModelBytes)
  var candidate = newSeqOfCap[StrategicNote](notes.len + updates.len)
  for note in notes:
    candidate.add note
  for i, update in updates:
    checkKey(update.key)
    for j in 0 ..< i:
      if updates[j].key == update.key:
        raise newException(KutuzovError, "Note update batch repeats a key")
    var index = -1
    for j, note in candidate:
      if note.key == update.key:
        index = j
        break
    case update.kind
    of Upsert:
      checkText(update.text, "Note text", MaxNoteTextBytes)
      let replacement = StrategicNote(
        key: update.key,
        text: update.text,
        originPhase: phase,
        originDecision: decision,
        originModel: model
      )
      if index < 0:
        candidate.add replacement
      else:
        candidate[index] = replacement
    of Delete:
      if update.text.len != 0:
        raise newException(KutuzovError, "Note delete must not include text")
      if index >= 0:
        for j in index ..< candidate.len - 1:
          candidate[j] = candidate[j + 1]
        candidate.setLen(candidate.len - 1)
  validateNotes(candidate)
  notes = candidate
