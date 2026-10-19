Read-only spectator feed: the @cogweb/core ServerMessage stream the live console
and replay viewer render (snapshot / event / status / lobby / reset frames). Each
turn places one worker; harvests trigger feeding. The saved replay is
{ protocol:"cogweb.replay.v1", frames: ServerMessage[] }. Spectators send nothing.