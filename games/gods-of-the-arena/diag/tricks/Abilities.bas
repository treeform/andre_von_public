' Use every ability, and only when it does something: damage on the enemy
' hero, heals when hurt, mana restores when short. The least-used ready
' ability goes next, and we wait for its mana instead of spending it.
learn()
nearest(2)
closing = 0
pick = -1
pickUsed = 100000
for slot = 0 to 3
  useful = 0
  if abilityLevel(slot) > 0 and abilityCooldown(slot) = 0 then
    if abilityDamage(slot) > 0 and bestId <> 0 then
      useful = 1
    elseif abilityHeal(slot) > 0 and selfHp < selfMaxHp then
      useful = 1
    elseif abilityRestore(slot) > 0 and selfMana < selfMaxMana then
      useful = 1
    end if
  end if
  if slot = 0 then
    times = used0
  elseif slot = 1 then
    times = used1
  elseif slot = 2 then
    times = used2
  else
    times = used3
  end if
  if useful and times < pickUsed then
    pick = slot
    pickUsed = times
  end if
next slot
if pick >= 0 and selfMana >= abilityManaCost(pick) then
  target = bestId
  if abilityDamage(pick) = 0 then
    target = selfId
  end if
  accepted = castTarget(pick, target)
  if accepted = 0 and lastActionError() = ActionOutOfRange then
    closing = 1
  end if
  if accepted then
    if pick = 0 then
      used0 = used0 + 1
    elseif pick = 1 then
      used1 = used1 + 1
    elseif pick = 2 then
      used2 = used2 + 1
    else
      used3 = used3 + 1
    end if
  end if
end if
if closing then
  accepted = walkTo(bestX, bestY)
elseif bestId <> 0 and selfTarget <> bestId then
  accepted = attackTarget(bestId)
end if
