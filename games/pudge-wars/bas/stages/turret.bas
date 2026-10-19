' turret.bas — local mimic of co-gas-pudge-blind-hook-richard/relhalpha v2
' (league 3v3, 0.3.13 tapes): three seats parked 20 tiles behind their own
' lip on the spawn rows, throwing every cooldown at the far lip with a fan
' of -12..+8 tiles around their own row, rot on when an enemy is within 8,
' no dodging. They move ~20% of ticks (rune walks, blinks); skipped here.
if selfTeam = 0 then
  postX = riverWest - 20
  aimX = riverEast
else
  postX = riverEast + 20
  aimX = riverWest
end if
rank = 0
ix = 0
while ix < objectCount()
  if objectTeam(ix) = selfTeam and objectAlive(ix) = 1 and objectId(ix) < selfId then
    rank = rank + 1
  end if
  ix = ix + 1
wend
row = 33
if rank = 1 then
  row = 96
end if
if rank = 2 then
  row = 54
end if
walkTo(postX, row)
near = 0
ix = 0
while ix < objectCount()
  if objectTeam(ix) <> selfTeam and objectKind(ix) = 1 and objectAlive(ix) = 1 then
    ndx = objectX(ix) - selfX
    ndy = objectY(ix) - selfY
    if ndx * ndx + ndy * ndy <= 64 then
      near = 1
    end if
  end if
  ix = ix + 1
wend
if near = 1 and selfRot = 0 then
  rotToggle()
end if
if near = 0 and selfRot = 1 then
  rotToggle()
end if
if hookReady = 1 then
  fan = fan + 1
  off = (fan mod 6) * 4 - 12
  hookTo(aimX, row + off)
end if
