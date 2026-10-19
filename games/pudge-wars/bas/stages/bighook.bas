' Stage T7 — big hook reach. Take every drop off the clock (R1); while
' holding Big Hook (selfBuff = 4: +50% range and head) poke deep at
' x = lip + 32 where v75's near seat idles out of normal reach, else
' poke the normal post at lip + 16. Rank 0 works row 20, rank 1 row 104.
if selfTeam = 0 then
  postX = riverWest - 16
  nearX = riverEast + 16
  deepX = riverEast + 32
else
  postX = riverEast + 16
  nearX = riverWest - 16
  deepX = riverWest - 32
end if
rank = 0
ix = 0
while ix < objectCount()
  if objectTeam(ix) = selfTeam and objectAlive(ix) = 1 and objectId(ix) < selfId then
    rank = rank + 1
  end if
  ix = ix + 1
wend
row = 20 + rank * 84
walkTo(postX, row)
thrown = 0
if runeSoon > 0 then
  sdx = runeNextX - selfX
  sdy = runeNextY - selfY
  sd2 = sdx * sdx + sdy * sdy
  sd = 0
  while (sd + 1) * (sd + 1) <= sd2 and sd < 130
    sd = sd + 1
  wend
  fn = 0
  covered = 0
  while covered < sd * 100 and fn < 200
    fn = fn + 1
    if fn <= 40 then
      covered = 60 * fn + (3 * fn * fn) / 2
    else
      covered = 4800 + 180 * (fn - 40)
    end if
  wend
  mine = 0
  if runeNextY < 64 and rank = 0 then
    mine = 1
  end if
  if runeNextY >= 64 and rank = 1 then
    mine = 1
  end if
  if mine = 1 and hookReady = 1 and runeSoon = fn + 9 then
    thrown = hookTo(runeNextX, runeNextY)
  end if
  if mine = 1 and runeSoon <= fn + 60 then
    thrown = 1
  end if
end if
if thrown = 0 and hookReady = 1 and selfX = postX then
  if selfBuff = 4 then
    hookTo(deepX, row)
  else
    hookTo(nearX, row)
  end if
end if
