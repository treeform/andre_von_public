' Hit the tower only while it shoots our creeps; leave when it turns on us.
learn()
nearest(4)
if bestId <> 0 then
  towerTarget = objectTarget(bestI)
  if towerTarget = selfId then
    stepAway(bestX, bestY, 4)
  elseif towerTarget <> 0 then
    if selfTarget <> bestId then
      accepted = attackTarget(bestId)
    end if
  else
    accepted = walkTo(selfX, selfY)
  end if
end if
