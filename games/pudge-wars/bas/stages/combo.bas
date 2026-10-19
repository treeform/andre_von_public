' Stage T6 — committed-dodge combo. v75 picks its dodge side from the
' first threat head (away from the head's y) and keeps it while any
' threat persists. Poker A (rank 0) aims ROW - SGN*4 so v75 walks
' SGN*y; poker B (rank 1) fires DELAY ticks after A's chain appears,
' aimed ROW + SGN*OFF, where the dodging body will be.
if selfTeam = 0 then
  postX = riverWest - 16
  aimX = riverEast + 16
else
  postX = riverEast + 16
  aimX = riverWest - 16
end if
rank = 0
ix = 0
while ix < objectCount()
  if objectTeam(ix) = selfTeam and objectAlive(ix) = 1 and objectId(ix) < selfId then
    rank = rank + 1
  end if
  ix = ix + 1
wend
standY = ROW - 6 + rank * 12
if standY < 16 then
  standY = 16
end if
if standY > 108 then
  standY = 108
end if
walkTo(postX, standY)
if rank = 0 then
  if hookReady = 1 and selfX = postX then
    hookTo(aimX, ROW - SGN * 4)
  end if
else
  partnerOut = 0
  h = 0
  while h < hookCount()
    if hookTeam(h) = selfTeam and hookOwner(h) <> selfId then
      partnerOut = 1
    end if
    h = h + 1
  wend
  if partnerOut = 1 then
    if seenAt = 0 then
      seenAt = worldTick
    end if
    if hookReady = 1 and worldTick >= seenAt + DELAY then
      hookTo(aimX, ROW + SGN * OFF)
    end if
  else
    seenAt = 0
  end if
end if
