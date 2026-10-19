' @gota-structures
' Khors v277 - v270 with tower discipline from v275
' Structure follows the league leader aaron-gota-micro0922: think every six
' ticks, stutter-step after each landed hit, score creeps/heroes/god, retreat
' at a quarter health, respect towers, carry gear and heals, restock at 500
' gold, portal home when the god is threatened, and advance from the lane
' waypoint to the enemy god. Written fresh on our own draft and abilities.
' Tower discipline is v275's: enemy towers are remembered by id, heroes hold
' one tile outside an unsafe tower's reach, and a tower is hit only while
' three of our creeps tank it or, late, a gate or guard has company.

dim owned(22)
dim allyIds(9)
dim allyXs(9)
dim allyYs(9)
dim friendXs(95)
dim friendYs(95)
dim friendHps(95)
dim towerXs(31)
dim towerYs(31)
dim towerMaxHps(31)
dim towerStates(31)
dim towerSeen(31)
dim towerHps(31)
dim towerTargets(31)
dim towerAlive(31)

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

' Tower reach and shot by tier, read from max health: outer 1900 (9 tiles,
' 36), inner 2600 (9.5 tiles, 48), gate and god guards 3900 (10 tiles, 60).
sub towerStats(hitPoints)
  towerRange = 9
  towerShot = 36
  if hitPoints >= 3000 then
    towerRange = 10
    towerShot = 60
  elseif hitPoints >= 2200 then
    towerRange = 9.5
    towerShot = 48
  end if
end sub

' Enemy towers are remembered by id (from v275), because a gate tower's danger
' line (11 tiles) lies beyond hero sight (10 tiles); the ally and own-creep
' tables at exact spots feed judgeTowers.
sub observe()
  bestId = 0
  bestScore = -1000000
  bestDistance = 1000000
  bestKind = 0
  bestHp = 0
  threatDistance = 1000000
  friendPower = self.level + 2
  enemyPower = 0
  allyCount = 0
  friendCount = 0
  ownTowerCount = 0
  startKind = 0
  homeThreat = 0
  homeEnemyHeroes = 0
  homeDefenders = 0
  forwardScore = 1000000
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
      px = objects(index).position.x
      py = objects(index).position.y
      if id = startTarget then
        startKind = kind
      end if
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
          if allyCount < 9 then
            allyIds(allyCount) = id
            allyXs(allyCount) = px
            allyYs(allyCount) = py
            allyCount = allyCount + 1
          end if
        elseif kind = 3 then
          if friendCount < 96 then
            friendXs(friendCount) = px
            friendYs(friendCount) = py
            friendHps(friendCount) = hp
            friendCount = friendCount + 1
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
          ownTowerCount = ownTowerCount + 1
          if towersKnown = 0 and id >= 10 and id <= 31 then
            ' Tower ids are 10 + lane * 6 + team * 3 + tier, guards 28-31.
            ' Lane L of one team mirrors lane 2 - L of the other through
            ' the map center, tier for tier.
            if id >= 28 then
              mirror = id + 2 - 4 * self.team
            else
              laneIndex = (id - 10) \ 6
              rest = (id - 10) mod 6
              mirror = 10 + (2 - laneIndex) * 6 + (1 - (rest \ 3)) * 3 + (rest mod 3)
            end if
            towerXs(mirror) = map.width - 1 - px
            towerYs(mirror) = map.height - 1 - py
            towerMaxHps(mirror) = objects(index).maxHp
            towerStates(mirror) = 1
          end if
        end if
      else
        if kind = 1 then
          enemyX = x
          enemyY = y
          if objects(index).alive then
            ' An exposed god proves both of its guards fell.
            guardBase = 30 - 2 * self.team
            towerStates(guardBase) = 0
            towerStates(guardBase + 1) = 0
          end if
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
        if kind = 4 and id >= 10 and id <= 31 then
          if id >= 28 then
            ' The two guards may sit in either mirrored spot: swap the
            ' remembered spots when this guard turns up in its sibling's.
            sibling = id + 1 - 2 * (id mod 2)
            sx = towerXs(sibling) - px
            sy = towerYs(sibling) - py
            if sx * sx + sy * sy < 2.25 then
              towerXs(sibling) = towerXs(id)
              towerYs(sibling) = towerYs(id)
            end if
          end if
          towerXs(id) = px
          towerYs(id) = py
          towerMaxHps(id) = objects(index).maxHp
          towerStates(id) = 1
          towerSeen(id) = match.tick
          towerHps(id) = hp
          towerTargets(id) = objects(index).targetId
          towerAlive(id) = objects(index).alive
          if towerAlive(id) = 1 and id < 28 then
            ' An exposed lane tower proves every lower tier of its lane
            ' fell, even one we never saw fall (its line sits beyond our
            ' sight, so the spot check in judgeTowers cannot retire it).
            tier = (id - 10) mod 3
            for lower = id - tier to id - 1
              towerStates(lower) = 0
            next lower
          end if
        end if
        ' Towers are scored after judgeTowers, which decides the hit.
        if distance <= 900 and objects(index).alive and kind <> 4 then
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
  if ownTowerCount > 0 then
    towersKnown = 1
  end if
end sub

' The danger tower is the standing enemy tower with the smallest margin
' (distance minus reach). Our creeps inside its reach decide whether we may
' stand there: macromackie enters with three creeps on a tower that shoots a
' creep and leaves at one, or at two whose health covers under three shots.
sub judgeTowers()
  dangerId = 0
  dangerMargin = 1000
  for slot = 10 to 31
    if towerStates(slot) = 1 then
      tx = towerXs(slot) - spotX
      ty = towerYs(slot) - spotY
      span = tx * tx + ty * ty
      if towerSeen(slot) <> match.tick and span < 400 then
        ' Retire a remembered tower whose spot our team must see (us within
        ' 9.6 tiles, an ally within 9, a creep within 4; sight is 10 and 5)
        ' while it is gone; otherwise a tower that fell unseen would hold us
        ' at its line.
        gone = 0
        if span < 92 then
          gone = 1
        else
          for ally = 0 to allyCount - 1
            ax = allyXs(ally) - towerXs(slot)
            ay = allyYs(ally) - towerYs(slot)
            if ax * ax + ay * ay < 81 then
              gone = 1
            end if
          next ally
          for friend = 0 to friendCount - 1
            fx = friendXs(friend) - towerXs(slot)
            fy = friendYs(friend) - towerYs(slot)
            if fx * fx + fy * fy < 16 then
              gone = 1
            end if
          next friend
        end if
        if gone = 1 then
          towerStates(slot) = 0
        end if
      end if
      if towerStates(slot) = 1 and span < 400 then
        towerStats(towerMaxHps(slot))
        margin = sqrt(span) - towerRange
        if margin < dangerMargin then
          dangerMargin = margin
          dangerId = slot
          dangerX = towerXs(slot)
          dangerY = towerYs(slot)
          dangerSpan = span
          dangerRange = towerRange
          dangerShot = towerShot
          dangerMaxHp = towerMaxHps(slot)
          dangerTarget = 0
          dangerHp = towerMaxHps(slot)
          dangerAlive = 0
          if towerSeen(slot) = match.tick then
            dangerTarget = towerTargets(slot)
            dangerHp = towerHps(slot)
            dangerAlive = towerAlive(slot)
          end if
        end if
      end if
    end if
  next slot
  dangerSafe = 1
  towerAttack = 0
  creepsIn = 0
  creepHpIn = 0
  if dangerId = 0 then
    exit sub
  end if
  reach = dangerRange * dangerRange
  for friend = 0 to friendCount - 1
    fx = friendXs(friend) - dangerX
    fy = friendYs(friend) - dangerY
    if fx * fx + fy * fy <= reach then
      creepsIn = creepsIn + 1
      creepHpIn = creepHpIn + friendHps(friend)
    end if
  next friend
  alliesAtTower = 0
  coveredByAlly = 0
  edgeSpan = (dangerRange - 1.5) * (dangerRange - 1.5)
  for ally = 0 to allyCount - 1
    ax = allyXs(ally) - dangerX
    ay = allyYs(ally) - dangerY
    allySpan = ax * ax + ay * ay
    if allySpan <= 121 then
      alliesAtTower = alliesAtTower + 1
    end if
    ' A tower shooting a teammate who is nearer to it and near its edge.
    if allyIds(ally) = dangerTarget and allySpan < dangerSpan and allySpan >= edgeSpan then
      coveredByAlly = 1
    end if
  next ally
  dangerSafe = 0
  onCreep = 0
  if dangerTarget >= 1000 then
    onCreep = 1
    if creepsIn >= 3 then
      dangerSafe = 1
    elseif creepsIn = 2 and creepHpIn >= dangerShot * 3 then
      dangerSafe = 1
    end if
  elseif coveredByAlly = 1 then
    dangerSafe = 1
  end if
  ' Late game macromackie tanks gate and guard towers and finishes them: at
  ' level 6 or more, or once the tower is under 70% health, with company.
  tank = 0
  if dangerAlive = 1 and dangerMaxHp >= 3000 then
    if self.level >= 6 or dangerHp * 10 < dangerMaxHp * 7 then
      if alliesAtTower >= 1 or creepsIn >= 2 then
        if dangerTarget <> self.id or self.hp > dangerShot * 2 then
          tank = 1
          dangerSafe = 1
        end if
      end if
    end if
  end if
  ' Never hit a lane tower that shoots a hero; start only with three creeps
  ' in its reach and keep hitting while it stays safe.
  if dangerAlive = 1 and dangerSafe = 1 then
    if tank = 1 then
      towerAttack = 1
    elseif onCreep = 1 then
      if creepsIn >= 3 or startTarget = dangerId then
        towerAttack = 1
      end if
    end if
  end if
end sub

' The danger tower competes in the v270 score (+2000, +70 to keep hitting
' it) only while judgeTowers allows the hit; no other tower is a target.
sub targetTower()
  if towerAttack = 0 then
    exit sub
  end if
  mapTile(dangerX)
  x = tileValue
  mapTile(dangerY)
  y = tileValue
  dx = x - myX
  dy = y - myY
  distance = dx * dx + dy * dy
  score = 1000 - distance * 3 + 2000
  if dangerId = startTarget then
    score = score + 70
  end if
  if score > bestScore then
    bestScore = score
    bestId = dangerId
    bestKind = 4
    bestHp = dangerHp
    bestX = x
    bestY = y
    bestDistance = distance
  end if
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

' The v270 casts: heal ourselves, or hit the best target from where we stand
' (a creep only when the spell kills it).
sub castSpells()
  for slot = 0 to 3
    if abilities(slot).level > 0 and abilities(slot).cooldownTicks = 0 then
      if abilities(slot).charges > 0 and startMana >= abilities(slot).manaCost then
        if abilities(slot).heal > 0 then
          if self.maxHp - self.hp >= abilities(slot).heal \ 2 then
            accepted = castTarget(slot, self.id)
          end if
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
end sub

' Drafting.
if draft.active then
  chooseHero()
  end
end if

' Decision-start state: our tile, our exact spot, and the target and mana
' before this decision's commands (self.* refreshes after every command).
mapTile(self.position.x)
myX = tileValue
mapTile(self.position.y)
myY = tileValue
spotX = self.position.x
spotY = self.position.y
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
judgeTowers()
targetTower()
economy()

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

' Tower edge: inside one tile beyond an unsafe tower's reach, walk toward our
' spawn this decision (the next one overrides it), finishing a windup first
' while still outside its reach, and cast from where we stand.
if dangerId <> 0 and dangerSafe = 0 and dangerMargin < 1 then
  hold = 0
  if dangerMargin >= 0 and startTarget <> 0 then
    if self.attackCooldownTicks > 0 and self.attackCooldownTicks < 13 then
      hold = 1
    end if
  end if
  if hold = 0 and self.controls.rootTicks = 0 then
    accepted = walkTo(spawnX, spawnY)
    lastGoalX = -1
  end if
  castSpells()
  end
end if

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
  castSpells()
  end
end if

' Let go of a tower we may not hit (one shooting a hero, or too few creeps).
if startKind = 4 and towerAttack = 0 and self.controls.rootTicks = 0 then
  accepted = walkTo(spawnX, spawnY)
  lastGoalX = -1
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
