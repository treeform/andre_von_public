' @gota-structures
' Khors v318 - seat-class screen: v303 with our league-team seat drafting DemonHunter
' Structure follows the league leader aaron-gota-micro0922: think every six
' ticks, stutter-step after each landed hit, score creeps/heroes/god, retreat
' at a quarter health, respect towers, carry gear and heals, restock at 500
' gold, portal home when the god is threatened, and advance from the lane
' waypoint to the enemy god. Written fresh on our own draft and abilities.

dim owned(22)

' The legacy whole-tile index of a tile-center coordinate: floor(p + .5), with
' the Blue observer taking the lower cell on an exact tile edge.
sub mapTile(value)
  tileValue = floor(value + .5)
  if self.team = 1 and tileValue = value + .5 then
    tileValue = tileValue - 1
  end if
end sub

sub chooseHero()
  if draft.turnId <> self.id then
    exit sub
  end if
  ' Draft Warlock while our team has fewer than four: its two spells heal
  ' allies since the October 7 rebalance, and 1 Crossbowman + 4 Warlocks
  ' scored 0.953 vs the top 3 (3 Crossbowmen + 2 Warlocks 0.892).
  warlocks = 0
  mixedTeam = 0
  for player = 0 to draft.playerCount - 1
    if players(player).team = self.team and players(player).id <> self.id and players(player).class = Warlock then
      warlocks = warlocks + 1
    end if
    ' A teammate that already drafted anything but Warlock is another
    ' player's bot: a league team, where our seat plays Crossbowman.
    if players(player).team = self.team and players(player).id <> self.id and players(player).class >= 0 and players(player).class <> Warlock then
      mixedTeam = 1
    end if
  next player
  bestClass = -1
  bestScore = -10000
  for candidate = 0 to 9
    if heroChoices(candidate).available then
      ' Demon Hunter > Lich > Arcanist > Berserker > Druid > Warlock >
      ' Crossbowman > Vanguard > Death Knight > Ranger, 100 apart so the
      ' same-role penalty never reorders them.
      score = 100
      if candidate = DemonHunter then
        score = 1000
      elseif candidate = Lich then
        score = 900
      elseif candidate = Arcanist then
        score = 800
      elseif candidate = Berserker then
        score = 700
      elseif candidate = DruidWarden then
        score = 600
      elseif candidate = Warlock then
        score = 500
        if warlocks < 4 and mixedTeam = 0 then
          score = 5000
        end if
      elseif candidate = Crossbowman then
        ' The October 5 rebalance made Crossbowman the strongest pick; 1200
        ' keeps it first even after four same-role teammates (-100).
        score = 1200
      elseif candidate = 0 then
        score = 300
      elseif candidate = DeathKnight then
        score = 200
      end if
      for player = 0 to draft.playerCount - 1
        if players(player).team = self.team then
          picked = players(player).class
          if picked >= 0 then
            if heroChoices(picked).role = heroChoices(candidate).role then
              score = score - 25
            end if
          end if
        end if
      next player
      if score > bestScore then
        bestScore = score
        bestClass = candidate
      end if
    end if
  next candidate
  ' Seat-class screen: a league team's seat drafts DemonHunter.
  if mixedTeam = 1 then
    bestClass = 4
  end if
  if bestClass >= 0 then
    accepted = draftHero(bestClass)
  end if
end sub

sub learnAbilities()
  for upgrade = 1 to 4
    if self.abilityPoints = 0 then
      exit sub
    end if
    upgradeSlot = -1
    if abilities(0).canLevel then
      upgradeSlot = 0
    end if
    if abilities(2).canLevel then
      upgradeSlot = 2
    end if
    if abilities(1).canLevel then
      upgradeSlot = 1
    end if
    if abilities(3).canLevel then
      upgradeSlot = 3
    end if
    if upgradeSlot < 0 then
      exit sub
    end if
    accepted = levelAbility(upgradeSlot)
  next upgrade
end sub

sub laneWaypoint()
  goalX = map.width \ 2
  goalY = map.height \ 2
  if lane = 0 then
    goalX = map.width \ 10
    goalY = map.height \ 10
  elseif lane = 2 then
    goalX = map.width * 9 \ 10
    goalY = map.height * 9 \ 10
  end if
end sub

' Heal the most injured ally hero in reach, ourselves included, with any
' ready heal spell once it is missing at least half the heal.
sub healAllies()
  for slot = 0 to 3
    if abilities(slot).level > 0 and abilities(slot).cooldownTicks = 0 and abilities(slot).heal > 0 then
      if abilities(slot).charges > 0 and self.mana >= abilities(slot).manaCost then
        healReach = abilities(slot).range - 0.1
        healId = 0
        healMissing = abilities(slot).heal \ 2
        if self.maxHp - self.hp >= healMissing then
          healId = self.id
          healMissing = self.maxHp - self.hp
        end if
        for index = 0 to match.objectCount - 1
          if objects(index).kind = 2 and objects(index).team = self.team and objects(index).id <> self.id and objects(index).hp > 0 then
            mapTile(objects(index).position.x)
            healDx = tileValue - myX
            mapTile(objects(index).position.y)
            healDy = tileValue - myY
            if healDx * healDx + healDy * healDy <= healReach * healReach then
              missing = objects(index).maxHp - objects(index).hp
              if missing >= healMissing then
                healId = objects(index).id
                healMissing = missing
              end if
            end if
          end if
        next index
        if healId > 0 then
          accepted = castTarget(slot, healId)
        end if
      end if
    end if
  next slot
end sub

sub observe()
  bestId = 0
  bestScore = -1000000
  bestDistance = 1000000
  bestKind = 0
  bestHp = 0
  threatDistance = 1000000
  towerDistance = 1000000
  towerTarget = 0
  towerAggro = 0
  friendPower = self.level + 2
  enemyPower = 0
  tanks = 0
  homeThreat = 0
  homeEnemyHeroes = 0
  homeDefenders = 0
  forwardScore = 1000000
  followDistance = 1000000
  hitReach = floor(self.attackRange) + 1
  laneWaypoint()
  for index = 0 to match.objectCount - 1
    hp = objects(index).hp
    if hp > 0 then
      id = objects(index).id
      kind = objects(index).kind
      mapTile(objects(index).position.x)
      x = tileValue
      mapTile(objects(index).position.y)
      y = tileValue
      dx = x - myX
      dy = y - myY
      distance = dx * dx + dy * dy
      if objects(index).team = self.team then
        if kind = 1 then
          homeX = x
          homeY = y
          enemyX = map.width - 1 - x
          enemyY = map.height - 1 - y
        elseif kind = 2 and id <> self.id then
          hx = x - homeX
          hy = y - homeY
          if hx * hx + hy * hy < 400 then
            homeDefenders = homeDefenders + 1
          end if
          if distance <= 100 then
            friendPower = friendPower + objects(index).level + 2
          end if
          if objects(index).class <> Warlock and objects(index).class <> DruidWarden and distance < followDistance then
            followDistance = distance
            followX = x
            followY = y
          end if
        elseif kind = 3 then
          if distance <= 64 then
            tanks = tanks + 1
          end if
        elseif kind = 4 then
          ' Our tower nearest the lane waypoint anchors the forward portal.
          fx = x - goalX
          fy = y - goalY
          score = fx * fx + fy * fy
          if score < forwardScore then
            forwardScore = score
            forwardX = x
            forwardY = y
          end if
        end if
      else
        if kind = 1 then
          enemyX = x
          enemyY = y
        end if
        if kind = 2 or kind = 3 then
          if distance < threatDistance then
            threatDistance = distance
          end if
          if kind = 2 and distance <= 100 then
            enemyPower = enemyPower + objects(index).level + 2
          end if
          hx = x - homeX
          hy = y - homeY
          if kind = 2 and hx * hx + hy * hy < 225 then
            homeEnemyHeroes = homeEnemyHeroes + 1
          end if
          if hx * hx + hy * hy < 144 then
            homeThreat = homeThreat + 1
          end if
        end if
        if kind = 4 then
          if distance < towerDistance then
            towerDistance = distance
            towerX = x
            towerY = y
            towerTarget = objects(index).targetId
          end if
          if objects(index).targetId = self.id then
            towerAggro = 1
          end if
        end if
        if distance <= 900 and objects(index).alive then
          score = 1000 - distance * 3
          if kind = 3 then
            score = score + 200
            if hp <= self.attackDamage and distance <= hitReach * hitReach then
              score = score + 650
            end if
            if objects(index).class = 1 then
              score = score + 25
            end if
          elseif kind = 2 then
            ' Fight heroes that come into reach, never chase them.
            if distance <= (hitReach + 2) * (hitReach + 2) or hp < self.attackDamage * 4 then
              score = score + 1000
            else
              score = score + 80
            end if
            if hp < self.attackDamage * 4 then
              score = score + 300
            end if
          elseif kind = 5 then
            ' Win fast: enemy barracks outrank everything.
            score = score + 2000
          elseif kind = 4 then
            ' Towers outrange a Crossbowman: hit one only while it shoots a
            ' creep (creep ids start at 1000), never while it shoots a hero.
            if objects(index).targetId >= 1000 then
              score = score + 2000
            end if
          elseif kind = 1 then
            score = score + 500
          end if
          if id = startTarget then
            score = score + 70
          end if
          if score > bestScore then
            bestScore = score
            bestId = id
            bestKind = kind
            bestHp = hp
            bestX = x
            bestY = y
            bestDistance = distance
          end if
        end if
      end if
    end if
  next index
end sub

sub economy()
  gearCount = 0
  healSlot = -1
  healCount = 0
  portalSlot = -1
  portalCount = 0
  empty = 0
  hasDagger = 0
  hasArmor = 0
  hasAxe = 0
  hasBow = 0
  for slot = 0 to 5
    item = items(slot).id
    if item = 0 then
      empty = empty + 1
    elseif item = 11 then
      hasDagger = 1
      gearCount = gearCount + 1
    elseif item = 16 then
      hasArmor = 1
      gearCount = gearCount + 1
    elseif item = 18 then
      hasAxe = 1
      gearCount = gearCount + 1
    elseif item = 19 then
      hasBow = 1
      gearCount = gearCount + 1
    elseif item = 1 then
      healSlot = slot
      healCount = items(slot).count
    elseif item = 21 then
      portalSlot = slot
      portalCount = items(slot).count
    end if
  next slot
  if healSlot >= 0 and self.inOwnSpawn = 0 then
    if items(healSlot).cooldownTicks = 0 and self.maxHp - self.hp >= 70 and threatDistance > 64 then
      if match.tick - hurtTick > match.tickRate then
        accepted = useItem(healSlot)
      end if
    end if
  end if
  restock = 0
  if self.canShop then
    budget = self.gold
    if hasDagger = 0 and budget >= 110 and empty > 0 then
      if buyItem(11) then
        budget = budget - 110
        empty = empty - 1
      end if
    end if
    if hasArmor = 0 and budget >= 160 and empty > 0 then
      if buyItem(16) then
        budget = budget - 160
        empty = empty - 1
      end if
    end if
    if hasAxe = 0 and budget >= 180 and empty > 0 then
      if buyItem(18) then
        budget = budget - 180
        empty = empty - 1
      end if
    end if
    if portalCount = 0 and budget >= 100 and empty > 0 then
      if buyItem(21) then
        budget = budget - 100
        empty = empty - 1
      end if
    end if
    if hasBow = 0 and budget >= 180 and empty > 0 then
      if buyItem(19) then
        budget = budget - 180
        empty = empty - 1
      end if
    end if
    if healCount = 0 and budget >= 30 and empty > 0 then
      if buyItem(1) then
        budget = budget - 30
        empty = empty - 1
      end if
    end if
    if healCount > 0 and healCount < 2 and budget >= 30 then
      accepted = buyItem(1)
    end if
  else
    if gearCount < 4 and self.gold >= 500 and threatDistance > 225 then
      restock = 1
    end if
  end if
  if restock = 1 then
    retreat = 1
  end if
end sub

' Drafting.
if draft.active then
  chooseHero()
  end
end if

' Decision-start state: our tile, and the target and mana before this
' decision's commands (self.* refreshes after every command).
mapTile(self.position.x)
myX = tileValue
mapTile(self.position.y)
myY = tileValue
startTarget = self.targetId
startMana = self.mana

' Death: buy back when the wait is long and the gold is spare.
if self.hp <= 0 then
  initialized = 0
  retreat = 0
  resumeTarget = 0
  price = self.buybackPrice
  if price > 0 and self.respawnTicks > match.tickRate * 25 then
    if self.gold >= price + 200 then
      accepted = buyback()
    end if
  end if
  end
end if
if self.channelTicks > 0 or self.controls.stunTicks > 0 then
  end
end if

' Stutter-step: after a landed hit, a quarter-tile walk resets the swing;
' the next think resumes the same target.
if self.controls.rootTicks = 0 then
  if resumeTarget > 0 then
    if retreat = 0 and startTarget = 0 then
      accepted = attackTarget(resumeTarget)
      lastGoalX = -1
    end if
    resumeTarget = 0
  elseif retreat = 0 and startTarget > 0 and self.attacksLanded > previousHits then
    previousHits = self.attacksLanded
    resumeTarget = startTarget
    accepted = walkTo(myX + 0.25, myY + 0.25)
    lastGoalX = -1
    end
  end if
end if

' Think every six ticks.
if match.tick < nextThink then
  end
end if
nextThink = match.tick + 6

if initialized = 0 then
  initialized = 1
  spawnX = myX
  spawnY = myY
  homeX = myX
  homeY = myY
  enemyX = map.width - 1 - myX
  enemyY = map.height - 1 - myY
  crossed = 1
  previousHp = self.hp
  previousHits = self.attacksLanded
  ordinal = 0
  for player = 0 to draft.playerCount - 1
    if players(player).team = self.team then
      if players(player).id < self.id then
        ordinal = ordinal + 1
      end if
    end if
  next player
  allyWarlocks = 0
  for player = 0 to draft.playerCount - 1
    if players(player).team = self.team and players(player).id <> self.id and players(player).class = Warlock then
      allyWarlocks = allyWarlocks + 1
    end if
  next player
  lane = ordinal mod 3
  ' Least-shared lane (Ari): count allies away from spawn by their nearest
  ' lane waypoint and take the emptiest lane; ties keep our usual lane.
  laneCount0 = 0
  laneCount1 = 0
  laneCount2 = 0
  for index = 0 to match.objectCount - 1
    if objects(index).team = self.team and objects(index).kind = 2 and objects(index).id <> self.id and objects(index).hp > 0 then
      mapTile(objects(index).position.x)
      x = tileValue
      mapTile(objects(index).position.y)
      y = tileValue
      dx = x - myX
      dy = y - myY
      if dx * dx + dy * dy > 225 then
        dx = x - map.width \ 10
        dy = y - map.height \ 10
        near0 = dx * dx + dy * dy
        dx = x - map.width \ 2
        dy = y - map.height \ 2
        near1 = dx * dx + dy * dy
        dx = x - map.width * 9 \ 10
        dy = y - map.height * 9 \ 10
        near2 = dx * dx + dy * dy
        if near0 <= near1 and near0 <= near2 then
          laneCount0 = laneCount0 + 1
        elseif near1 <= near2 then
          laneCount1 = laneCount1 + 1
        else
          laneCount2 = laneCount2 + 1
        end if
      end if
    end if
  next index
  laneBest = laneCount0
  if lane = 1 then
    laneBest = laneCount1
  elseif lane = 2 then
    laneBest = laneCount2
  end if
  if laneCount0 < laneBest then
    lane = 0
    laneBest = laneCount0
  end if
  if laneCount1 < laneBest then
    lane = 1
    laneBest = laneCount1
  end if
  if laneCount2 < laneBest then
    lane = 2
  end if
end if
justHit = 0
if self.attacksLanded > previousHits then
  justHit = 1
end if
previousHits = self.attacksLanded
if self.hp < previousHp then
  hurtTick = match.tick
end if
previousHp = self.hp

learnAbilities()
observe()
economy()
' A healer with a carry within 30 tiles fights only what is already in its
' reach, so it walks beside the carry instead of into fights alone. A team
' with three other Warlocks (our five-copy stack) pushes together instead.
if self.class = Warlock or self.class = DruidWarden then
  if followDistance <= 900 and bestId <> 0 and allyWarlocks < 3 then
    if bestDistance > hitReach * hitReach then
      bestId = 0
      bestKind = 0
    end if
  end if
end if

' Portal home when the god is threatened and nobody is home (first two seats).
if retreat = 0 and portalSlot >= 0 and self.controls.rootTicks = 0 then
  if ordinal <= 1 and homeEnemyHeroes > 0 and homeDefenders < 2 then
    dx = myX - homeX
    dy = myY - homeY
    if dx * dx + dy * dy > 625 and self.hp * 100 >= self.maxHp * 60 then
      if self.portalCooldownTicks = 0 and threatDistance > 225 and match.tick - hurtTick > match.tickRate * 2 then
        if useItemAt(portalSlot, homeX, homeY) then
          end
        end if
      end if
    end if
  end if
end if

' Recover: retreat below a quarter health; in spawn, wait until nearly full.
if self.hp * 100 < self.maxHp * 15 then
  retreat = 1
end if
if self.inOwnSpawn then
  if self.hp * 10 >= self.maxHp * 9 and startMana * 10 >= self.maxMana * 8 then
    retreat = 0
  else
    if match.tick >= moveTick then
      accepted = walkTo(spawnX, spawnY)
      lastGoalX = -1
      moveTick = match.tick + 24
    end if
    end
  end if
end if
if retreat = 1 then
  dx = myX - spawnX
  dy = myY - spawnY
  if portalSlot >= 0 and self.portalCooldownTicks = 0 then
    if dx * dx + dy * dy > 400 and threatDistance > 144 then
      if useItemAt(portalSlot, spawnX, spawnY) then
        end
      end if
    end if
  end if
  if self.controls.rootTicks = 0 and match.tick >= moveTick then
    accepted = walkTo(spawnX, spawnY)
    lastGoalX = -1
    moveTick = match.tick + 24
  end if
  end
end if

' Tower safety: step away from a tower that is on us, or one with no creeps.
unsafe = 0
if towerAggro = 1 and self.hp * 100 < self.maxHp * 65 then
  unsafe = 1
end if
if bestKind = 4 and bestId <> 0 and tanks = 0 then
  if towerDistance < 64 and towerTarget = 0 then
    unsafe = 1
  end if
end if
if unsafe = 1 and self.controls.rootTicks = 0 then
  dx = myX - towerX
  dy = myY - towerY
  if dx = 0 and dy = 0 then
    dx = homeX - myX
    dy = homeY - myY
  end if
  stepX = 3
  stepY = 3
  if dx < 0 then
    stepX = -3
  end if
  if dy < 0 then
    stepY = -3
  end if
  if match.tick >= moveTick then
    accepted = walkTo(myX + stepX, myY + stepY)
    lastGoalX = -1
    moveTick = match.tick + 24
  end if
  end
end if

healAllies()

' A Crossbowman closes on creeps it cannot reach when the fight is even.
if self.class = Crossbowman and bestKind = 3 and bestId > 0 then
  if bestDistance > 25 and bestDistance <= 64 and enemyPower <= friendPower then
    if self.controls.rootTicks = 0 then
      accepted = walkTo((myX + bestX) / 2, (myY + bestY) / 2)
      lastGoalX = -1
      moveTick = match.tick + 6
    end if
    end
  end if
end if

' Combat: attack the best target and cast what is ready.
if bestId <> 0 then
  if justHit = 1 and self.controls.rootTicks = 0 then
    accepted = walkTo(myX + 0.25, myY + 0.25)
    lastGoalX = -1
  end if
  if startTarget <> bestId or justHit = 1 then
    accepted = attackTarget(bestId)
    lastGoalX = -1
  end if
  for slot = 0 to 3
    if abilities(slot).level > 0 and abilities(slot).cooldownTicks = 0 then
      if abilities(slot).charges > 0 and startMana >= abilities(slot).manaCost then
        if abilities(slot).heal > 0 then
          ' Heal spells belong to healAllies.
        elseif abilities(slot).damage > 0 then
          castReach = abilities(slot).range - 0.1
          if castReach > 0 and bestDistance <= castReach * castReach then
            if bestKind <> 3 or bestHp <= abilities(slot).damage then
              accepted = castTarget(slot, bestId)
            end if
          end if
        end if
      end if
    end if
  next slot
  end
end if

' Advance: the lane waypoint, then the enemy god; guard home when threatened.
laneWaypoint()
dx = myX - goalX
dy = myY - goalY
if dx * dx + dy * dy <= 64 then
  crossed = 1
end if
if crossed = 1 then
  goalX = enemyX
  goalY = enemyY
end if
dx = myX - homeX
dy = myY - homeY
if homeThreat > 0 and dx * dx + dy * dy < 400 then
  goalX = homeX
  goalY = homeY
end if
' A healer walks with the nearest allied carry within 30 tiles instead of
' its own route, so its heals reach someone (in league teams our seat is the
' Warlock beside other players' bots).
if self.class = Warlock or self.class = DruidWarden then
  if followDistance <= 900 then
    goalX = followX
    goalY = followY
  end if
end if
if self.canShop and portalSlot >= 0 and self.portalCooldownTicks = 0 then
  if threatDistance > 144 and forwardScore < 1000000 then
    dx = myX - forwardX
    dy = myY - forwardY
    if dx * dx + dy * dy > 400 then
      if useItemAt(portalSlot, forwardX, forwardY) then
        end
      end if
    end if
  end if
end if
' Re-issue the standing attack-move only when its goal changes or every
' five seconds: an identical order every 24 ticks is spam.
if self.controls.rootTicks = 0 and match.tick >= moveTick then
  if goalX <> lastGoalX or goalY <> lastGoalY or match.tick - lastGoalTick >= 120 then
    accepted = attackMove(goalX, goalY)
    lastGoalX = goalX
    lastGoalY = goalY
    lastGoalTick = match.tick
  end if
  moveTick = match.tick + 24
end if
