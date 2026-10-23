import
  std/[json, math, os, strutils],
  curly, jsony,
  common, logs

const
  DefaultModel* = "gpt-6.1-sol"
  DefaultHostedModel* = "openai/gpt-6.1-sol"
  DefaultCacheKey* = "kutuzov-v1"
  MaximumTranscriptMessages* = 64
  MaximumRequestBytes* = 60_000

type
  KutuzovRequestError* = object of KutuzovError

  RequestApi* = enum
    ResponsesApi, ChatApi

  RequestConfig* = object
    api*: RequestApi
    apiKey*: string
    baseUrl*: string
    model*: string
    reasoningEffort*: string
    cacheKey*: string
    timeoutSeconds*: int
    maxOutputTokens*: int

  TokenUsage* = object
    input*: int
    cached*: int
    cacheWrite*: int
    output*: int
    hasInput*: bool
    hasCached*: bool
    hasCacheWrite*: bool
    hasOutput*: bool

  Spend* = object
    available*: bool
    spent*: float
    limit*: float
    hasLimit*: bool

  Completion* = object
    text*: string
    usage*: TokenUsage
    spendUsd*: float
    hasSpend*: bool
    limitUsd*: float
    hasLimit*: bool
    error*: string
    httpStatus*: int

proc integerEnv(name: string, fallback, maximum: int): int
    {.raises: [KutuzovError].} =
  ## Read a positive, bounded integer setting without echoing its value.
  let value = getEnv(name)
  if value.len == 0:
    return fallback
  try:
    result = parseInt(value)
  except ValueError:
    raise newException(KutuzovError, name & " must be an integer.")
  if result < 1 or result > maximum:
    raise newException(KutuzovError,
      name & " must be between 1 and " & $maximum & ".")

proc loadRequestConfig*(): RequestConfig {.raises: [KutuzovError].} =
  ## Load direct OpenAI or hosted COWORLD settings from the environment.
  let
    alias = getEnv("COWORLD_LLM_ENDPOINT").strip()
    endpoint =
      if alias.len > 0:
        alias
      else:
        getEnv("AWS_ENDPOINT_URL_BEDROCK_RUNTIME").strip()
  result = RequestConfig(
    api: ResponsesApi,
    apiKey: getEnv("OPENAI_API_KEY"),
    baseUrl: getEnv("OPENAI_BASE_URL", "https://api.openai.com/v1"),
    model: getEnv("KUTUZOV_MODEL", DefaultModel),
    reasoningEffort: getEnv("KUTUZOV_REASONING", "low"),
    cacheKey: DefaultCacheKey,
    timeoutSeconds: integerEnv("KUTUZOV_TIMEOUT_SECONDS", 45, 120),
    maxOutputTokens: integerEnv("KUTUZOV_MAX_OUTPUT_TOKENS", 4096, 16384)
  )
  if endpoint.len > 0:
    result.api = ChatApi
    result.baseUrl = endpoint
    result.apiKey = "coworld"
    result.model = getEnv(
      "KUTUZOV_MODEL",
      getEnv("COWORLD_LLM_MODEL", getEnv("BEDROCK_MODEL", DefaultHostedModel))
    )
  if result.reasoningEffort notin ["low", "medium", "high", "xhigh", "max"]:
    raise newException(KutuzovError,
      "KUTUZOV_REASONING must be low, medium, high, xhigh, or max.")

proc requestUrl*(config: RequestConfig): string
    {.raises: [KutuzovError].} =
  ## Resolve the configured API base or full completion endpoint.
  result = config.baseUrl.strip().strip(trailing = true, chars = {'/'})
  if not result.startsWith("https://") and
    not result.startsWith("http://"):
      raise newException(KutuzovError,
        "The LLM endpoint must start with http:// or https://.")
  case config.api
  of ResponsesApi:
    if not result.endsWith("/responses"):
      result.add("/responses")
  of ChatApi:
    if not result.endsWith("/chat/completions"):
      if not result.endsWith("/v1"):
        result.add("/v1")
      result.add("/chat/completions")

proc buildRequest*(
  config: RequestConfig,
  instructions, context: string,
  transcript: JsonNode = nil
): JsonNode {.raises: [KutuzovError].} =
  ## Append current context to validated history without rewriting its text.
  if config.model.len == 0:
    raise newException(KutuzovError, "The LLM model must not be empty.")
  if config.maxOutputTokens < 1 or config.maxOutputTokens > 16384:
    raise newException(KutuzovError,
      "The LLM output limit must be between 1 and 16384 tokens.")
  var
    messages = newJArray()
    firstUser = -1
    previousUser = -1
  if not transcript.isNil:
    if transcript.kind != JArray or transcript.len > MaximumTranscriptMessages:
      raise newException(KutuzovError,
        "The LLM transcript must contain at most 64 messages.")
    for message in transcript:
      if message.isNil or message.kind != JObject or
        message{"role"}.isNil or message{"role"}.kind != JString or
        message{"content"}.isNil or message{"content"}.kind != JString:
          raise newException(KutuzovError,
            "Each LLM transcript message needs a string role and content.")
      let
        role = message{"role"}.getStr()
        content = message{"content"}.getStr()
      if role notin ["user", "assistant"] or content.len == 0:
        raise newException(KutuzovError,
          "LLM transcript roles must be user or assistant with nonempty text.")
      if role == "user":
        if firstUser < 0:
          firstUser = messages.len
      elif messages.len > 0 and
        messages[messages.len - 1]{"role"}.getStr() == "user":
          previousUser = messages.len - 1
      messages.add(%*{"role": role, "content": content})
  if messages.len > 0 and firstUser != 0:
    raise newException(KutuzovError,
      "The LLM transcript must begin with a user observation.")
  if firstUser < 0:
    firstUser = messages.len
  messages.add(%*{"role": "user", "content": context})
  case config.api
  of ResponsesApi:
    var input = %*[{
      "role": "developer",
      "content": [{
        "type": "input_text",
        "text": instructions,
        "prompt_cache_breakpoint": {"mode": "explicit"}
      }]
    }]
    for i in 0 ..< messages.len:
      let
        message = messages[i]
        role = message{"role"}.getStr()
        content = message{"content"}.getStr()
      if role == "user":
        var part = %*{"type": "input_text", "text": content}
        if i == firstUser or i == previousUser or i == messages.len - 1:
          part["prompt_cache_breakpoint"] = %*{"mode": "explicit"}
        input.add(%*{"role": role, "content": [part]})
      else:
        input.add(%*{"role": role, "content": content})
    result = %*{
      "model": config.model,
      "reasoning": {"effort": config.reasoningEffort},
      "max_output_tokens": config.maxOutputTokens,
      "store": false,
      "prompt_cache_key": config.cacheKey,
      "prompt_cache_options": {"mode": "explicit", "ttl": "30m"},
      "text": {"format": {"type": "json_object"}},
      "input": input
    }
  of ChatApi:
    var chat = %*[{"role": "developer", "content": instructions}]
    for message in messages:
      chat.add(message)
    result = %*{
      "model": config.model,
      "reasoning": {"effort": config.reasoningEffort},
      "max_completion_tokens": config.maxOutputTokens,
      "response_format": {"type": "json_object"},
      "messages": chat
    }

proc field(node: JsonNode, name: string): JsonNode {.raises: [].} =
  ## Read an optional object field without accepting other JSON shapes.
  if node != nil and node.kind == JObject:
    return node.getOrDefault(name)

proc stringField(node: JsonNode, name: string): string {.raises: [].} =
  ## Read a string field or return an empty string for absent data.
  let value = field(node, name)
  if value != nil and value.kind == JString:
    return value.getStr()

proc tokenField(node: JsonNode, name: string): int {.raises: [].} =
  ## Read a nonnegative token count from an optional usage object.
  let value = field(node, name)
  if value != nil and value.kind == JInt:
    return max(0, value.getInt())

proc hasTokens(node: JsonNode, name: string): bool {.raises: [].} =
  ## Distinguish missing usage details from reported zero-token counts.
  let value = field(node, name)
  value != nil and value.kind == JInt and value.getInt() >= 0

proc readUsage(node: JsonNode, api: RequestApi): TokenUsage
    {.raises: [].} =
  ## Normalize token accounting across Responses and Chat Completions.
  let usage = field(node, "usage")
  var details: JsonNode
  case api
  of ResponsesApi:
    result.input = tokenField(usage, "input_tokens")
    result.output = tokenField(usage, "output_tokens")
    result.hasInput = hasTokens(usage, "input_tokens")
    result.hasOutput = hasTokens(usage, "output_tokens")
    details = field(usage, "input_tokens_details")
  of ChatApi:
    result.input = tokenField(usage, "prompt_tokens")
    result.output = tokenField(usage, "completion_tokens")
    result.hasInput = hasTokens(usage, "prompt_tokens")
    result.hasOutput = hasTokens(usage, "completion_tokens")
    details = field(usage, "prompt_tokens_details")
  result.cached = min(result.input, tokenField(details, "cached_tokens"))
  result.hasCached = hasTokens(details, "cached_tokens")
  result.hasCacheWrite = hasTokens(details, "cache_write_tokens")
  result.cacheWrite = min(
    result.input - result.cached,
    tokenField(details, "cache_write_tokens")
  )

proc parseCompletion*(
  body: string,
  api = ResponsesApi
): Completion {.raises: [KutuzovError].} =
  ## Preserve billable usage even when a completion is refused or cut short.
  let node =
    try:
      body.fromJson(JsonNode)
    except ValueError:
      raise newException(KutuzovError, "The LLM returned invalid JSON.")
  if node == nil or node.kind != JObject:
    raise newException(KutuzovError,
      "The LLM response must be a JSON object.")
  result.usage = readUsage(node, api)
  let failure = field(node, "error")
  if failure != nil and failure.kind != JNull:
    result.error = "The LLM API rejected the request."
    return
  case api
  of ResponsesApi:
    if stringField(node, "status") != "completed":
      result.error = "The LLM response did not complete."
      return
    let output = field(node, "output")
    if output == nil or output.kind != JArray:
      result.error = "The LLM response has no output messages."
      return
    for item in output:
      if stringField(item, "type") != "message" or
        stringField(item, "role") != "assistant":
          continue
      let content = field(item, "content")
      if content == nil or content.kind != JArray:
        continue
      for part in content:
        case stringField(part, "type")
        of "output_text":
          result.text.add(stringField(part, "text"))
        of "refusal":
          result.error = "The LLM refused to provide an action."
        else:
          discard
  of ChatApi:
    let choices = field(node, "choices")
    if choices == nil or choices.kind != JArray or choices.len == 0:
      result.error = "The LLM response has no completion choices."
      return
    let
      choice = choices[0]
      message = field(choice, "message")
    if stringField(choice, "finish_reason") != "stop":
      result.error = "The LLM response did not complete."
      return
    if stringField(message, "refusal").len > 0:
      result.error = "The LLM refused to provide an action."
      return
    if stringField(message, "role") != "assistant":
      result.error = "The LLM response has no assistant message."
      return
    result.text = stringField(message, "content")
  if result.error.len > 0:
    result.text.setLen(0)
  elif result.text.strip().len == 0:
    result.error = "The LLM returned an empty action."

proc parseResponse*(body: string): string {.raises: [KutuzovError].} =
  ## Extract only complete assistant text from a Responses API response.
  let completion = parseCompletion(body)
  if completion.error.len > 0:
    raise newException(KutuzovError, completion.error)
  completion.text

proc completeResult*(
  config: RequestConfig,
  instructions, context: string,
  transcript: JsonNode = nil
): Completion {.raises: [KutuzovError].} =
  ## Make one bounded request, returning usage and any model output error.
  if config.apiKey.len == 0:
    raise newException(KutuzovError, "OPENAI_API_KEY is required.")
  if config.timeoutSeconds < 1 or config.timeoutSeconds > 120:
    raise newException(KutuzovError,
      "The LLM timeout must be between 1 and 120 seconds.")
  let
    url = requestUrl(config)
    body = $buildRequest(config, instructions, context, transcript)
    route =
      if config.api == ResponsesApi:
        "/responses"
      else:
        "/v1/chat/completions"
  if body.len + 512 > MaximumRequestBytes:
    raise newException(KutuzovError,
      "The LLM request exceeds the 60000-byte context limit.")
  if config.apiKey != "coworld":
    registerSecret(config.apiKey)
  let request = logHttpRequest(
    "model",
    "POST",
    route,
    body,
    config.timeoutSeconds,
    %*{"model": config.model, "reasoning_effort": config.reasoningEffort}
  )
  var headers: HttpHeaders
  headers["Authorization"] = "Bearer " & config.apiKey
  headers["Content-Type"] = "application/json"
  headers["Accept"] = "application/json"
  let response =
    try:
      let client = newCurly(1)
      defer:
        client.close()
      client.post(url, headers, body, config.timeoutSeconds)
    except CatchableError as error:
      logHttpError(request, error)
      raise newException(KutuzovRequestError,
        "The LLM HTTP request failed or exceeded its timeout.")
  var loggedHeaders = %*{
    "content-type": response.headers["Content-Type"],
    "x-request-id": response.headers["X-Request-Id"],
    "retry-after": response.headers["Retry-After"],
    "x-coworld-spend-usd": response.headers["X-Coworld-Spend-Usd"],
    "x-coworld-spend-limit-usd": response.headers["X-Coworld-Spend-Limit-Usd"]
  }
  for name in [
    "X-Softmax-Llm-Call-Id", "X-Softmax-Llm-Error-Category",
    "X-Softmax-Llm-Retryable", "X-Should-Retry", "X-Generation-Id"
  ]:
    let value = response.headers[name]
    if value.len > 0:
      loggedHeaders[name.toLowerAscii()] = %value
  logHttpResponse(request, response.code, response.body, loggedHeaders)
  if response.code >= 200 and response.code < 300:
    try:
      result = parseCompletion(response.body, config.api)
    except KutuzovError as error:
      logError("model_response_parse", error)
      result.error = error.msg
  else:
    result.error = "The LLM request failed with HTTP " &
      $response.code & "."
  result.httpStatus = response.code
  let spend = response.headers["X-Coworld-Spend-Usd"]
  if spend.len > 0:
    try:
      result.spendUsd = parseFloat(spend)
    except ValueError:
      raise newException(KutuzovRequestError,
        "The hosted LLM returned an invalid spend value.")
    if result.spendUsd < 0 or result.spendUsd.classify in {fcNan, fcInf}:
      raise newException(KutuzovRequestError,
        "The hosted LLM returned an invalid spend value.")
    result.hasSpend = true
  let limit = response.headers["X-Coworld-Spend-Limit-Usd"]
  if limit.len > 0:
    try:
      result.limitUsd = parseFloat(limit)
    except ValueError:
      raise newException(KutuzovRequestError,
        "The hosted LLM returned an invalid spend limit.")
    if result.limitUsd < 0 or result.limitUsd.classify in {fcNan, fcInf}:
      raise newException(KutuzovRequestError,
        "The hosted LLM returned an invalid spend limit.")
    result.hasLimit = true
  logEvent("model_return", %*{
    "request_id": request.id,
    "model": config.model,
    "status": result.httpStatus,
    "error": result.error,
    "usage": result.usage,
    "has_spend": result.hasSpend,
    "spend_usd": result.spendUsd,
    "has_limit": result.hasLimit,
    "limit_usd": result.limitUsd,
    "text_bytes": result.text.len
  })

proc fetchSpend*(config: RequestConfig): Spend {.raises: [KutuzovError].} =
  ## Read the hosted sidecar's authoritative episode spend without inference.
  if config.api != ChatApi:
    return
  let endpoint = requestUrl(config)
  var base = endpoint[0 ..< endpoint.len - "/chat/completions".len]
  if base.endsWith("/v1"):
    base.setLen(base.len - "/v1".len)
  let request = logHttpRequest(
    "spend", "GET", "/spend", "", min(3, max(1, config.timeoutSeconds))
  )
  let response =
      try:
        let client = newCurly(1)
        defer:
          client.close()
        client.get(
          base & "/spend",
          timeout = min(3, max(1, config.timeoutSeconds))
        )
      except CatchableError as error:
        logHttpError(request, error)
        raise newException(KutuzovError,
          "The hosted LLM spend request failed or exceeded its timeout.")
  logHttpResponse(request, response.code, response.body, deduplicate = true)
  if response.code != 200:
    raise newException(KutuzovError,
      "The hosted LLM spend request failed with HTTP " &
      $response.code & ".")
  let node =
    try:
      response.body.fromJson(JsonNode)
    except ValueError as error:
      logError("spend_response_parse", error)
      raise newException(KutuzovError,
        "The hosted LLM returned invalid spend JSON.")
  let
    spent = field(node, "spend_usd")
    limit = field(node, "spend_limit_usd")
  if spent == nil or spent.kind notin {JFloat, JInt}:
    raise newException(KutuzovError,
      "The hosted LLM spend response is missing spend_usd.")
  result.spent = spent.getFloat()
  if result.spent < 0 or result.spent.classify in {fcNan, fcInf}:
    raise newException(KutuzovError,
      "The hosted LLM returned an invalid spend value.")
  result.available = true
  if limit != nil and limit.kind != JNull:
    if limit.kind notin {JFloat, JInt}:
      raise newException(KutuzovError,
        "The hosted LLM returned an invalid spend limit.")
    result.limit = limit.getFloat()
    if result.limit < 0 or result.limit.classify in {fcNan, fcInf}:
      raise newException(KutuzovError,
        "The hosted LLM returned an invalid spend limit.")
    result.hasLimit = true
  logEvent("spend_return", %*{
    "request_id": request.id,
    "available": result.available,
    "spend_usd": result.spent,
    "has_limit": result.hasLimit,
    "limit_usd": result.limit
  })

proc complete*(
  config: RequestConfig,
  instructions, context: string,
  transcript: JsonNode = nil
): string {.raises: [KutuzovError].} =
  ## Request a complete action without automatic retries or hidden calls.
  let completion = completeResult(config, instructions, context, transcript)
  if completion.error.len > 0:
    raise newException(KutuzovError, completion.error)
  completion.text
