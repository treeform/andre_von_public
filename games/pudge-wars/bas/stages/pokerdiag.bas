' Stage T4 — diagonal vs straight pokes against v75's dodge. The poker
' stands at (post, pokerY) and throws every cooldown at (aimX, 40): with
' pokerY = 40 the head flies straight down the target's lane band; with
' pokerY = 64 it arrives at ~23 degrees and stays outside the |dy| <= 10
' band until ~22 tiles out.
if selfTeam = 0 then
  postX = riverWest - 16
  aimX = riverEast + 16
else
  postX = riverEast + 16
  aimX = riverWest - 16
end if
walkTo(postX, pokerY)
if hookReady = 1 and selfX = postX then
  hookTo(aimX, 40)
end if
