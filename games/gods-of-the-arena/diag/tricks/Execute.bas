' Chase the fleeing hero and burst it; melee heroes hold their spells
' until the target is inside two tiles so no cooldown is wasted. Molten
' Fist (slot 1) is ranked first: its three charges finish a 35% runner.
learnFirst(1)
nearest(2)
if bestId <> 0 then
  lastX = bestX
  lastY = bestY
  if selfTarget <> bestId then
    accepted = attackTarget(bestId)
  end if
  if selfAttackRange > 150000 or bestD <= 4 then
    blast(bestId)
  end if
elseif lastX <> 0 then
  accepted = walkTo(lastX, lastY)
end if
