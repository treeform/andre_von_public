' micro-test: take every scheduled drop one tick after it spawns, from a post 20 tiles off the lip
if selfTeam = 0 then
  postX = riverWest - 20
else
  postX = riverEast + 20
end if
rank = 0
ix = 0
while ix < objectCount()
  if objectTeam(ix) = selfTeam and objectAlive(ix) = 1 and objectId(ix) < selfId then
    rank = rank + 1
  end if
  ix = ix + 1
wend
walkTo(postX, 40 + rank * 48)
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
  if hookReady = 1 and runeSoon = fn + 9 then
    hookTo(runeNextX, runeNextY)
  end if
end if
