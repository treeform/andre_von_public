' Burst the idle hero with every ability and attack.
learn()
nearest(2)
if bestId <> 0 then
  if selfTarget <> bestId then
    accepted = attackTarget(bestId)
  end if
  blast(bestId)
end if
