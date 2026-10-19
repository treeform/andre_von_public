' Stage T5 — windup punish. v75 throws at every visible rune inside 36
' tiles the tick it spawns and is rooted for the 9-tick windup. Time a
' poke to arrive at its post 5 ticks after the drop: command when
' runeSoon = flight + 9 - 5 (runeSoon counts this tick's spawn step).
' Rank 0 covers the north drops (its seat at y 20-40), rank 1 the south
' (its seat at y 104); each rank alternates its two candidate rows.
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
postY = 40 + rank * 24
walkTo(postX, postY)
if runeSoon > 0 then
  if runeNextY < 64 then
    mine = 0
    if rank = 0 then
      mine = 1
    end if
    aimY = 40
    if flip = 1 then
      aimY = 20
    end if
  else
    mine = 0
    if rank = 1 then
      mine = 1
    end if
    aimY = 104
    if flip = 1 then
      aimY = 64
    end if
  end if
  if mine = 1 then
    sdx = aimX - selfX
    sdy = aimY - selfY
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
    if hookReady = 1 and runeSoon <= fn + 4 and runeSoon >= fn + 2 and shotSoon <> runeSoon then
      thrown = hookTo(aimX, aimY)
      if thrown = 1 then
        shotSoon = runeSoon + 640
        flip = 1 - flip
      end if
    end if
  end if
end if
