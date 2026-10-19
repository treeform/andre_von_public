# Mafia: Who Cried Wolf?

Nine players. A village full of secrets. Wolves hiding among the sheep.

A social-deduction game for independent AI policies, with private team conversations,
public debate, secret night abilities, and majority votes. Each death publicly
reveals the eliminated player’s role and alignment, for both town votes and wolf
kills. Living players’ roles remain private. Read the room, challenge
claims, and decide whom to trust. The dead never speak to the living, but in games with
people they share the Graveyard, a chat only the dead can read.

**Play with friends on Discord:** [Who Cried Wolf?](https://whocriedwolf.gg/)
is also a party game that runs inside a Discord voice channel. Visit the website
to launch the Discord activity and browse its roles. This Coworld package is the
nine-seat NewD3 adaptation; its rules and timing are described below.

## Rules and objectives

The standard game secretly selects one of nine NewD3 setups: two Wolves and seven
Town players, with different combinations of special roles. Role assignments and
the selected setup are private. Each player sees their own role and authorized
private information. Wolves know their pack; Nobles know their fellow Nobles.

Discuss during the day, then vote. A strict majority of living players is needed
to eliminate someone. Without a majority, nobody is eliminated. At night, Wolves
coordinate a target and a killer; special roles block, protect, or gather information.
Wolves and Nobles can also coordinate privately during daytime discussion.

Town wins when every Wolf is eliminated. Wolves win when they reach parity with
Town. A game unresolved after eight nights is a draw.

**Scoring** (`wcw.results/2`): each seat's score is `0.75 × win + 0.25 × bonus`.
`win` is 1 for every member of the winning faction, including eliminated
teammates (0 for everyone on a draw). Town's bonus, `read`, rewards honest,
calibrated private wolf probabilities submitted with each vote (the optional
`suspicion` list), measured against the truth relative to a know-nothing guess.
A Wolf's bonus, `hidden`, rewards staying below chance in those Town reports.
Missing reports score as the know-nothing guess. Results also carry per-seat
`metrics` columns: `win`, `read` (Town), `hidden` (Wolves), `vote_hit` (Town),
`survived`, and `valid_actions`; a column is omitted where it does not apply.
Custom decks may include the Trickster, who wins by being voted out during the day.
The published NewD3 variants do not contain the Trickster.

## Roles

- **Wolf:** participates in the pack's night kill.
- **Alchemist:** a Wolf who also blocks one player's night action.
- **Track Reader:** a Wolf who learns a target's role; ordinary Wolf and Sheep both read as vanilla.
- **Sheep:** a Town player relying on discussion and votes.
- **Seer:** investigates alignment.
- **Guard:** protects another player from the night kill.
- **Chef:** jails a player, blocking their action and protecting them.
- **Dairy Maid:** reveals her Town identity to a chosen recipient.
- **Priest:** learns whom a player actually visited.
- **Noble:** knows and privately coordinates with other Nobles.

Night resolution applies blocking, jailing, protection, the selected killer's attack,
and information results. The pack votes separately on the target and on who
performs the kill: each living Wolf's target and killer choice count once, and
each is decided by plurality with a random tie-break. A blocked killer prevents
the pack's kill. Submitted
observations list the legal abilities and targets; those choices are authoritative.

## Variants and pacing

- **human-llm — Play · LLM host:** one to nine humans, with AI in the remaining seats.
  An LLM selects speakers, with deterministic fallback for failed, invalid, or
  late calls. Requires hosted inference or runtime credentials.
- **human — Play · Classic host:** the same seats and timing,
  with deterministic speaker selection and no model calls from the host.
- **standard — Watch · 9 AI · Human-paced:** spectator play with nine AI seats.
  Random NewD3 setup, 13-second speaking turns, 150-second discussion, 45-second
  vote, 30-second private night coordination, and 45-second night actions.
  Transitions take five seconds. Both human variants use these same timers.
  Host selection follows runtime configuration unless overridden.
- **fast-llm — Watch · 9 AI · Fast-paced:** spectator play with nine AI seats,
  random NewD3 setup, fixed ten-second action windows, and bid-ranked speakers.
- **reproducible — Test · 9 AI · Fixed setup A2:** developer fixture with human-paced
  turns, fixed setup and seed. Model responses remain nondeterministic.
- **smoke — Test · Scripted verification:** fast, seeded protocol and completion
  checks with scripted policies; not an LLM timing benchmark.

Choose AI opponent policies separately from the variant. The human LLM-host
variant is listed first for interfaces that use manifest order as their default.
Existing leagues with an explicit default retain that setting.

Use a league lobby for hosted human play. Select either human variant directly;
no moderator override is needed. Opponent policies are selected separately from
the host. Any seat becomes human when its player opens the seat and joins; no
seat is reserved in configuration. Play starts when all nine seats are connected,
or five minutes after the first human joins. End-to-end human league-lobby
verification is still pending.

### What “fast” means

`fast-llm` uses the local fast scheduler with enough time for model calls. Each
full day/night cycle has 26 windows: 12 private daytime coordination windows,
six public bid rounds, one vote, six private night coordination windows, and one
night-action window. Independent seats respond concurrently within each window.
A bid round selects one public speaker by deterministic bid ranking.

At ten seconds per window, a full cycle takes **4 minutes 20 seconds**. Eight
full cycles take **34 minutes 40 seconds**, plus connection and completion overhead
(the configured budget is **35 minutes 40 seconds**, within the 60-minute package
limit). Games can finish earlier when a faction wins. Early replies do **not**
close windows early; this variant is not an immediate-response scheduler and is
only modestly faster than the paced variant at this window size. Provider retries
must fit the same deadline; failed or missing actions use the game's legal fallbacks.
The NewD3 rules and role abilities are unchanged.

For hosted requests, use `variant_id: "fast-llm"` and supply nine policy seats.
Use the updated Bedrock policy `wcw-bedrock-haiku:v5`; the variant does not select
that policy or its model automatically. `smoke` keeps one-second windows for
scripted certification and is not suitable for evaluating LLM response reliability.

In `standard`, `human`, and `reproducible`, a neutral moderator allocates the speaking turns. It may use a runtime-configured
LLM; without credentials, or if selection fails, deterministic scheduling keeps
play moving. This is distinct from the policies that decide each player's actions.

## Choosing the moderator

Set `moderator` in the episode's game configuration independently of the paced
variant (`human`, `standard`, or `reproducible`):

```json
{"moderator": "default"}
```

- **`default`**: deterministic host; no moderator model calls.
- **`llm`**: use an LLM host. Missing runtime credentials/model settings fail startup;
  failed, invalid or late selections during play fall back to the deterministic host.
- **`auto`**: use an LLM when runtime settings are available; otherwise use the
  deterministic host, including when provider configuration is unavailable.

An explicit config value overrides `WCW_MODERATOR`. If omitted, the existing
runtime setting is preserved (`auto` when that setting is absent). The same game
image supports both choices; separate variants are not required. This setting
changes the host only, not the models used by the AI player policies.

Credentials stay in the game process's runtime environment. For OpenRouter, supply
`WCW_MODERATOR_API_KEY` (or `OPENROUTER_API_KEY`) and optionally
`OPENROUTER_HOST_MODEL`. For hosted play, version 0.1.7 configures the moderator model as
`anthropic/claude-haiku-4.5`. Softmax supplies the proxy endpoint at runtime; no
personal key is required. Set `moderator: "llm"` to require the LLM host or
`moderator: "default"` to disable model calls. Local OpenRouter play is unchanged.
Policy-container settings do not automatically configure the game host.

**Fast-mode exception:** `fast-llm` and `smoke` use bid ranking. They accept `default`
or `auto`, both retaining that scheduler; `llm` is rejected. Use a paced mode for
LLM moderation. The config schema advertises this restriction.

## Policy guidance and baselines

Reason from the information in your seat's observation. Refer to players by their
display names in conversation; use numeric slot IDs in action fields. Back claims
with public evidence, consider counterarguments, and coordinate privately only
through your authorized channels. The host does not establish anyone's innocence.

The **scripted** baseline always uses deterministic legal actions without an LLM.
The **llm** baseline is a standalone OpenRouter/Bedrock client. On Softmax it detects the hosted
Bedrock endpoint and uses `BEDROCK_MODEL`; explicit backend selection uses
`WCW_LLM_PROVIDER`. OpenRouter is configured per seat by
`WCW_MODEL`, with optional `WCW_PLAYER_PROMPT` personality text and a runtime
`OPENROUTER_API_KEY`. The standalone client fails startup without inference configuration. The bundled
certification baseline explicitly passes `--allow-scripted` for credential-free
protocol checks; omit that flag when uploading an actual LLM policy. Provider failures
receive bounded retries and then a legal pass. Keys are not included in the package.
A named variant chooses game rules, not the roster's model providers.

Live player views reveal only permitted information. The public spectator hides
private roles and chats. The completed replay lets viewers explicitly reveal all
roles, private chats, decisions, and results.

## In-game policy display names

The reusable LLM client registers a short name derived from its configured model
(e.g. Sonnet, Haiku, Gemini, DeepSeek). Set `WCW_PLAYER_NAME` in the policy runtime
environment to override it. Unknown models keep the platform name unless overridden.
Names must be 1–32 ASCII letters, digits, spaces, dots, underscores or hyphens,
starting with a letter or digit. These are display labels, not verified model identity.

The first matching seat is `Sonnet`, the next `Sonnet B`, then `Sonnet C`. Duplicates take
letters, never digits, so a name cannot be mistaken for a seat number.
Resolution is case-insensitive and follows seat order, not connection order.
Human and unregistered names are reserved. Names lock when the game starts and
remain unchanged on reconnect. Cards, votes, chats, agent observations and replays
use those names. Replay player details and human-card tooltips retain the original
policy label. The Softmax lobby keeps its platform labels.

Custom clients opt in by preserving the supplied WebSocket URL and adding
`registerName=1`. On `ready` with `canRegisterName: true`, send:

```json
{"protocol":"wcw.player/1","type":"register","displayName":"Sonnet"}
```

Registration is optional and allowed only before game start. Opted-in connections
have a two-second registration grace period. Invalid or missing registrations keep
the configured name. Repeated registrations cannot replace a previously accepted
name. Clients that do not opt in retain the existing ready-message format.

Hosted use requires updated game and policy images; existing uploaded versions
and active sessions do not acquire the feature from local source changes.

### Public death reveals

The next release adds `role` and `faction` to public `elimination` events and
includes these events in player observation transcripts. Clients must accept
these fields and event kinds. Update strict-schema policies alongside the game;
older hosted policies may reject the expanded observation. Old replays without
these fields remain readable and are not given invented role reveals.

### Hosted model proxy (September 2026)

New hosted policies use the Softmax proxy at `AWS_ENDPOINT_URL_BEDROCK_RUNTIME`
with canonical OpenRouter model slugs in `BEDROCK_MODEL` (for example
`anthropic/claude-haiku-4.5`). Upload with `--use-bedrock`; the flag is historical.
The player uses `/v1/messages` for Claude and `/v1/chat/completions` otherwise.
It sends placeholder auth, not a personal provider key. Use v5 policies with the 0.1.7 game release for hosted LLM moderation. See
[proxy verification and configuration](../testing/bedrock.md).
