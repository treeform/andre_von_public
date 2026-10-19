' Everything on the enemy hero, dodging its warnings and kiting when ranged.
learn()
dodge()
if dodged = 0 then
  nearest(2)
  if bestId <> 0 then
    fight(bestId, bestX, bestY)
  end if
end if
