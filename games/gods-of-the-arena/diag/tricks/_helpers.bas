' One-trick diagnostic helpers, prepended to every stage script by gota_diag.
' These scripts only exist to pass one diagnostic stage each.

sub learn()
  for pass = 1 to 8
    for k = 0 to 3
      slot = 3 - k
      if canLevelAbility(slot) then
        accepted = levelAbility(slot)
      end if
    next k
  next pass
end sub

sub learnFirst(first)
  ' Ranks one slot as far as the level allows, then everything else.
  for pass = 1 to 4
    if canLevelAbility(first) then
      accepted = levelAbility(first)
    end if
  next pass
  learn()
end sub

sub blast(target)
  for k = 0 to 3
    slot = 3 - k
    if abilityLevel(slot) > 0 then
      accepted = castTarget(slot, target)
    end if
  next k
end sub

sub nearest(kind)
  ' Nearest living enemy (or neutral) of one object kind.
  bestId = 0
  bestD = 1000000
  for i = 0 to objectCount() - 1
    if objectKind(i) = kind and objectTeam(i) <> selfTeam and objectAlive(i) = 1 then
      dx = objectX(i) - selfX
      dy = objectY(i) - selfY
      d = dx * dx + dy * dy
      if d < bestD then
        bestD = d
        bestId = objectId(i)
        bestX = objectX(i)
        bestY = objectY(i)
        bestHp = objectHp(i)
        bestI = i
      end if
    end if
  next i
end sub

sub stepAway(fromX, fromY, tiles)
  goX = selfX + tiles
  if fromX > selfX then
    goX = selfX - tiles
  end if
  goY = selfY + tiles
  if fromY > selfY then
    goY = selfY - tiles
  end if
  accepted = walkTo(goX, goY)
end sub

sub fight(target, targetX, targetY)
  ' Ranged heroes stutter-step: after each landed hit, step away from a
  ' close target for half a second, then attack again.
  if selfAttacksLanded > landedSeen then
    landedSeen = selfAttacksLanded
    kiteUntil = worldTick + 12
  end if
  if selfAttackRange > 150000 and bestD <= 4 and worldTick < kiteUntil then
    stepAway(targetX, targetY, 3)
  else
    if selfTarget <> target then
      accepted = attackTarget(target)
    end if
    blast(target)
  end if
end sub


sub dodge()
  ' Step out of any hostile warning landing within three tiles.
  dodged = 0
  for i = 0 to spellCount() - 1
    if spellCasterId(i) <> selfId then
      dx = selfX - spellX(i)
      dy = selfY - spellY(i)
      if dx * dx + dy * dy <= 9 and spellImpactTick(i) > worldTick then
        goX = selfX + 3
        if dx < 0 then
          goX = selfX - 3
        end if
        goY = selfY - 3
        if dy > 0 then
          goY = selfY + 3
        end if
        accepted = walkTo(goX, goY)
        dodged = 1
        exit for
      end if
    end if
  next i
end sub

if started = 0 then
  started = 1
  homeX = selfX
  homeY = selfY
end if
