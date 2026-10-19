' Hit the exposed god with attacks and every ability.
learn()
nearest(1)
if bestId <> 0 then
  if selfTarget <> bestId then
    accepted = attackTarget(bestId)
  end if
  blast(bestId)
end if
