' Stage T2 helper — stands still at (post, coverY) and does nothing else.
if selfTeam = 0 then
  postX = riverWest - 20
else
  postX = riverEast + 20
end if
postY = coverY
if postY = 0 then
  postY = 40
end if
walkTo(postX, postY)
