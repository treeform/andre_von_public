' Stage T1 — throw detection. Stand at a fixed post and cycle blind pokes
' through a fan of aim y values; after each throw watch our own head:
' if it strays > 6 tiles off the launch line before 50 tiles of travel it
' bounced. Verdicts are encoded in the action log via attackTarget:
'   attackTarget(900 + aimIndex)      at the throw tick
'   attackTarget(950 + aimIndex)      when that throw's head is seen bouncing
' The checker compares these with treedump's line of sight for the seed.
if selfTeam = 0 then
  postX = riverWest - 16
  aimX = riverEast + 16
else
  postX = riverEast + 16
  aimX = riverWest - 16
end if
postY = 40
if selfId mod 2 = 0 then
  postY = 88
end if
walkTo(postX, postY)
' fan: aim y = 12 + 8 * aimIndex, aimIndex 0..12 (12..108)
ownX = -1
h = 0
while h < hookCount()
  if hookOwner(h) = selfId and hookVictim(h) = 0 and hookFlying(h) = 1 then
    ownX = hookX(h)
    ownY = hookY(h)
  end if
  h = h + 1
wend
if launched = 1 and ownX >= 0 then
  tdx = lastAimX - lastFromX
  tdy = lastAimY - lastFromY
  tl2 = tdx * tdx + tdy * tdy
  tl = 0
  while (tl + 1) * (tl + 1) <= tl2 and tl < 130
    tl = tl + 1
  wend
  hdx = ownX - lastFromX
  hdy = ownY - lastFromY
  halong = hdx * tdx + hdy * tdy
  hcross = hdx * tdy - hdy * tdx
  if tl > 0 and flagged = 0 then
    if halong < 50 * tl and hcross * hcross > 36 * tl2 then
      attackTarget(950 + lastIndex)
      flagged = 1
    end if
  end if
end if
if hookReady = 1 and launched = 1 and ownX < 0 and worldTick > lastThrowTick + 12 then
  launched = 0
end if
if hookReady = 1 and launched = 0 and selfX = postX then
  aimY = 12 + 8 * aimIndex
  thrown = hookTo(aimX, aimY)
  if thrown = 1 then
    attackTarget(900 + aimIndex)
    lastAimX = aimX
    lastAimY = aimY
    lastFromX = selfX
    lastFromY = selfY
    lastIndex = aimIndex
    lastThrowTick = worldTick
    launched = 1
    flagged = 0
    aimIndex = (aimIndex + 1) mod 13
  end if
end if
