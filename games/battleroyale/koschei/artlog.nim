## No-op stand-in for the baseline bot's artifact telemetry module.
##
## The upstream artlog zips tick-stamped decision events and uploads them as
## the per-seat player artifact, pulling in zippy and curly. Telemetry never
## touches gameplay (the upstream contract forbids it raising into the game
## loop), so this policy keeps the call sites and drops the machinery: every
## entry point accepts the same arguments and does nothing. Restore the real
## module from coworld-battle-royale players/baseline/baseline/artlog.nim if
## an experiment needs post-hoc decision logs.

import std/json

export json                 # callers build event fields with `%*`

const SampleEvery* = 12     # ticks between state rows (~0.5 s at 24 tps)

type
  FrameSnap* = object
    ## Everything `decide` learned this frame that telemetry cares about.
    tick*: int
    alive*: bool
    x*, y*: int               # own position, map px
    hp*: int
    aim*: int                 # dead-reckoned aim, brads
    objective*: string        # movement-target branch, e.g. "carry"
    action*: string           # turret/act branch, e.g. "fire"
    phase*: string            # FFA strategic phase, empty for CTF
    bandFraction*: float      # FFA radial band fraction
    bandRadius*: int          # FFA resolved radial band radius
    safeRadius*: int          # FFA current safe-zone radius
    weaponTier*: int          # FFA weapon tier, 0=unarmed
    elapsedGameSec*: int      # FFA elapsed game seconds
    targetX*, targetY*: int   # movement target, map px
    iCarry*, mateCarry*, ownStolen*, sawThief*, pushOut*: bool
    hasShield*, hasPlasma*, carryNade*: bool
    nadeCharge*: int
    jinked*: bool             # stuck-detector burst fired this frame
    nadeDanger*: bool
    enemiesVisible*: int      # streamed into vision this frame
    engageDist*: int          # px to the live engage target, -1 = none
    engageReason*: string     # hold/fire_range/pursue_weak/endgame/ring
    lootTripStarted*: bool    # edge: a bounded FFA arm trip began
    mask*: uint8              # the input mask decide returned
    fired*: bool              # a fresh A press went out this frame

proc artBuildDefines*(): seq[string] =
  ## Define names injected by the build; empty in this telemetry-free build.
  discard

proc artInit*(slot: int, team, role: string, doctrine = "",
    gameTicksPerFrame = 1) =
  ## Would arm the log; telemetry is compiled out.
  discard

proc artSetDoctrine*(doctrine: string) =
  ## Would record the FFA doctrine; telemetry is compiled out.
  discard

proc artEvent*(tick: int, kind: string, fields: JsonNode = nil) =
  ## Would append one event row; telemetry is compiled out.
  discard

proc artFrame*(snap: FrameSnap) =
  ## Would fold one frame snapshot into the log; telemetry is compiled out.
  discard

proc artFlush*() =
  ## Would zip and upload the artifact; telemetry is compiled out.
  discard
