' Spells are kept for kill securing: cast one only on a creep it finishes.
' Otherwise basic-attack the lowest enemy creep in reach.
learn()
secured = 0
for k = 0 to 3
  slot = 3 - k
  if secured = 0 and abilityDamage(slot) > 0 and abilityCooldown(slot) = 0 then
    if selfMana >= abilityManaCost(slot) then
      for i = 0 to objectCount() - 1
        if secured = 0 and objectKind(i) = 3 and objectTeam(i) <> selfTeam and objectAlive(i) = 1 then
          if objectHp(i) <= abilityDamage(slot) then
            if castTarget(slot, objectId(i)) then
              secured = 1
            end if
          end if
        end if
      next i
    end if
  end if
next k
lowId = 0
lowHp = 100000
for i = 0 to objectCount() - 1
  if objectKind(i) = 3 and objectTeam(i) <> selfTeam and objectAlive(i) = 1 then
    if objectHp(i) < lowHp then
      lowHp = objectHp(i)
      lowId = objectId(i)
    end if
  end if
next i
if lowId <> 0 and selfTarget <> lowId then
  accepted = attackTarget(lowId)
end if
