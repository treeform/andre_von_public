' Portal at once to our tower nearest the map center, walk out past it,
' and kill the enemy wave before the tower can.
learn()
if ported = 0 then
  towerD = 1000000
  for i = 0 to objectCount() - 1
    if objectKind(i) = 4 and objectTeam(i) = selfTeam then
      dx = objectX(i) - mapWidth \ 2
      dy = objectY(i) - mapHeight \ 2
      if dx * dx + dy * dy < towerD then
        towerD = dx * dx + dy * dy
        towerX = objectX(i)
        towerY = objectY(i)
      end if
    end if
  next i
  for slot = 0 to 5
    if itemId(slot) = 21 and ported = 0 then
      if useItemAt(slot, towerX, towerY) then
        ported = 1
      end if
    end if
  next slot
end if
if selfChannelTicks = 0 and ported = 1 then
  nearest(3)
  if bestId <> 0 then
    if selfTarget <> bestId then
      accepted = attackTarget(bestId)
    end if
    blast(bestId)
  else
    ' Meet the wave in front of the tower.
    accepted = walkTo(towerX + (mapWidth \ 2 - towerX) \ 2, towerY + (mapHeight \ 2 - towerY) \ 2)
  end if
end if
