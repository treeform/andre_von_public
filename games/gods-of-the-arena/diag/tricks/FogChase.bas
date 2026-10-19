' Chase the fleeing hero; when it vanishes, run to where its path leads.
learn()
nearest(2)
if bestId <> 0 then
  velX = objectVelX(bestI)
  velY = objectVelY(bestI)
  lastX = bestX
  lastY = bestY
  lastTick = worldTick
  if selfTarget <> bestId then
    accepted = attackTarget(bestId)
  end if
  blast(bestId)
elseif lastTick > 0 then
  ' Lead the last seen position by its velocity (world units per tick).
  ahead = worldTick - lastTick + 24
  guessX = lastX + (velX \ 1000) * ahead \ 60
  guessY = lastY + (velY \ 1000) * ahead \ 60
  accepted = walkTo(guessX, guessY)
end if
