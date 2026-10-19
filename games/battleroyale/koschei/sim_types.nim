## The slice of the engine's ctf/sim_types.nim (GV45) the bot reads. The
## full module drags in the renderer (pixie, bitworld/server), so the policy
## carries just the contract values, verbatim from
## ~/p/coworld-battle-royale/src/ctf/sim_types.nim.

const
  PlayerHalf* = 6             ## half-extent of the solid player footprint, px.
  BulletHalfWidth* = 8.0      ## bullet corridor half-width, px: a shot hits
                              ## the nearest living player crossing it.
  TargetFps* = 24             ## simulation ticks per second.

  FfaWeaponLow* = 1           ## FFA weapon tiers: fists are tier 0.
  FfaWeaponMid* = 2
  FfaWeaponHeavy* = 3
  FfaLowGunRange* = 700       ## low-tier gun range, px (mid/heavy use the
                              ## full gun range).
  FfaFistAimHalfBrads* = 48   ## unarmed FFA melee aim-cone half-width.
  FfaRingShrinkSec* = 150     ## seconds the safe zone takes to shrink from
                              ## arena-covering to its floor radius.
  FfaRingDamageTicks* = 48    ## ticks of continuous exposure outside the
                              ## ring per hit point lost.

  ReplayFps = 24
  GrenadeRespawnTicks* = 5 * ReplayFps  ## a taken corner refills after 5s.
  GrenadeBlastRadius* = 52    ## blast hits every solid body box it touches.

  SoldierBodyPx = 34          ## cog body target size on the map.
  PlasmaArcSquare = SoldierBodyPx  ## one "square": a cog body length.
  PlasmaArcReach* = 5 * PlasmaArcSquare  ## forward cone reach: 5 squares.
  PlasmaArcMaxWidth* = 5 * PlasmaArcSquare div 2  ## cone width at max reach.
  PlasmaArcBodyRadius* = SoldierBodyPx div 2
