# Proxy War Coworld

Proxy War is a simultaneous-turn territorial strategy game. This Coworld package runs Proxy War through the existing game runner and preserves the LegalAction.id decision path.

## Rules Summary

Each Coworld player controls one Proxy War slot. During a decision step, the game advances through the existing Proxy War game server and asks each connected player to choose from the current legal actions. The default variant uses a compact two-player map, 50 decision cycles, 100 turns per cycle, and a short replay tail so hosted tournaments produce meaningful expansion, economy, and combat evidence without requiring a 170-minute full match. Certification keeps a separate short smoke fixture so upload checks stay fast.

A player may only select an action id that the game offered in the current request. The game passes that selected id back through Proxy War's existing AgentDecisionValidator, AgentLeagueMatchRunner, AgentRunner, and GameServer path. Invalid, stale, or missing selections are treated as fallback decisions by the adapter and are visible in the result artifact.

## Player Protocol

Players connect to COWORLD_PLAYER_WS_URL. The game sends decision_request messages containing protocolVersion, observation, legalActions, and responseContract fields; its envelope independently advertises protocol.maxActionsPerDecision for optional gameplay-action batching and protocol.maxSpawnPreferences=16 for spawn ranking. The player replies with decision_response, the same requestID, and selectedLegalActionId. selectedLegalActionId must match one offered legalActions[].id exactly. On a spawn-only menu, the optional spawnPreferenceLegalActionIds field may rank up to 16 exact offered spawn LegalAction.id values with selectedLegalActionId first. spawnPreferenceLegalActionIds is a spawn ballot independent of selectedLegalActionIds gameplay-action batching; never put the spawn ranking in selectedLegalActionIds. When offered, selectedDealActionId may separately select one exact deal_* id alongside that game action. Omitting the optional slot stays valid but ignores the diplomacy opportunity. Structured deals are breakable, referee-observed promises rather than engine alliances or permission changes. Non-aggression and trade-security bind both parties; joint_attack is an attack pledge by the proposer only; accepting support_request obligates the recipient to send the stated support.

The bundled starter player is proxywar-starter-websocket. It is intentionally simple: it reads the offered LegalAction.id values and chooses one legal id. It is useful for certification and smoke tests, not for competitive play.

## Scoring

The adapter writes one numeric score per policy slot in results.scores. If Proxy War reports a winner, that slot receives 1 and every other slot receives 0. If a bounded episode ends without a winner, each slot receives its normalized owned-territory share among policy slots. Scores sum to 1 in normal proofs.

This scoring rule is the shipped ranking scalar. Softmax can re-rank with a different scalar after upload by changing only the results.scores values, not the game/player contract or the LegalAction.id path.

## Artifacts

Each episode writes Coworld-compatible results, replay bytes, game/player logs, and Proxy War match artifacts. The reporter, grader, diagnoser, and optimizer-plan runnables consume the episode bundle shape used by Coworld tooling. Reporter and grader contracts are exercised; diagnoser and optimizer are contract-shaped because Coworld 0.1.15 still marks those roles reserved or runtime-pending.

## Hosted Status

This manifest is the canonical hosted Proxy War Coworld. It runs with the tsx loader so read-only episode pods do not need writable /tmp, sanitizes Coworld policy labels into Proxy War usernames, and serves global, replay, and player Coworld client routes from the native Proxy War viewer.