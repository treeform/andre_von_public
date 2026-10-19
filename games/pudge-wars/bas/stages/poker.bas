' Stage T2 helper — a fixed poker: stands at its post and throws every
' cooldown at a constant aim (the opposing stand's post), regardless of fog.
if selfTeam = 0 then
  postX = riverWest - 16
  aimX = riverEast + 16
else
  postX = riverEast + 16
  aimX = riverWest - 16
end if
postY = coverY
if postY = 0 then
  postY = 40
end if
walkTo(postX, postY)
if hookReady = 1 and selfX = postX then
  hookTo(aimX, postY)
end if
