' Wait out of aggro, pull the camp onto our passing wave, step behind it,
' and help from range so the camp holds the wave until the next arrives.
learn()
nearest(6)
if bestId <> 0 then
  campX0 = bestX
  campY0 = bestY
end if
' Our nearest creep.
allyId = 0
allyD = 1000000
for i = 0 to objectCount() - 1
  if objectKind(i) = 3 and objectTeam(i) = selfTeam and objectAlive(i) = 1 then
    dx = objectX(i) - campX0
    dy = objectY(i) - campY0
    d = dx * dx + dy * dy
    if d < allyD then
      allyD = d
      allyId = objectId(i)
      allyX = objectX(i)
      allyY = objectY(i)
    end if
  end if
next i
if phase = 0 then
  if bestId <> 0 and allyId <> 0 and allyD <= 121 then
    phase = 1
  else
    accepted = walkTo(selfX, selfY)
  end if
end if
if phase = 1 then
  if bestId <> 0 and objectTarget(bestI) = selfId then
    phase = 2
  else
    accepted = walkTo(bestX, bestY)
  end if
end if
if phase = 2 then
  if bestId <> 0 and objectTarget(bestI) <> selfId and objectTarget(bestI) <> 0 then
    phase = 3
  else
    goX = allyX + 3
    if campX0 > allyX then
      goX = allyX - 3
    end if
    goY = allyY + 3
    if campY0 > allyY then
      goY = allyY - 3
    end if
    accepted = walkTo(goX, goY)
  end if
end if
if phase = 3 then
  ' Help from range so the camp stays on our creeps and they survive.
  if bestId <> 0 then
    if bestD < 16 then
      stepAway(bestX, bestY, 3)
    else
      if selfTarget <> bestId then
        accepted = attackTarget(bestId)
      end if
      blast(bestId)
    end if
  end if
end if
