' @gota-structures
' Khors v275 - macromackie replica from replays: tower-edge dance, creep-gated tower hits, edge-gated hero focus, castPoint E and R, R dodge, five-heal restock, instant buyback, forward portals
' Rewritten on the v272 lane base from 20 replays of v270 against macromackie.
' Four heroes take one edge lane and one holds the other until three minutes;
' after that every trip heads for the enemy god, by portal to our tower
' nearest it when the scroll is ready. Heroes hold one tile outside enemy
' tower range and step in only while three of our creeps tank the tower,
' focus the lowest enemy hero only when they outnumber its helpers, clear
' waves with W and E, sidestep enemy R, drink only at a full potion of
' missing health, go home only without heals below a quarter health, and buy
' back at once. Nobody jungles on purpose or walks back to defend.

dim allyIds(9)
dim allyXs(9)
dim allyYs(9)
dim enemyIds(9)
dim enemyXs(9)
dim enemyYs(9)
dim enemyHps(9)
dim enemyTargets(9)
dim creepIds(95)
dim creepXs(95)
dim creepYs(95)
dim creepHps(95)
dim friendXs(95)
dim friendYs(95)
dim friendHps(95)
dim ownTowerIds(15)
dim ownTowerXs(15)
dim ownTowerYs(15)
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

' Priority R > W > E > Q gives macromackie's exact order: W, E, W, E, W, R,
' W, E, E, Q, Q, R.
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

' Lane corners measured in the replays: lane 0 at (12, 11) and lane 2 at its
' point mirror (103, 104); mid has the map center.
sub laneWaypoint()
  goalX = map.width \ 2
  goalY = map.height \ 2
  if lane = 0 then
    goalX = (map.width \ 10) + 1
    goalY = (map.height \ 10)
  elseif lane = 2 then
    goalX = map.width - 2 - (map.width \ 10)
    goalY = map.height - 1 - (map.height \ 10)
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

' One pass over the visible objects fills the hero, creep and tower tables.
' Enemy towers are remembered by id, because a gate tower's danger line (11
' tiles) lies beyond hero sight (10 tiles).
sub observe()
  allyCount = 0
  enemyCount = 0
  creepCount = 0
  friendCount = 0
  ownTowerCount = 0
  heroThreat = 1000000
  campId = 0
  godId = 0
  barracksId = 0
  barracksDistance = 1000000
  startKind = 0
  lastIndex = match.objectCount - 1
  if lastIndex > 399 then
    lastIndex = 399
  end if
  for index = 0 to lastIndex
    hp = objects(index).hp
    if hp > 0 then
      id = objects(index).id
      kind = objects(index).kind
      team = objects(index).team
      px = objects(index).position.x
      py = objects(index).position.y
      dx = px - spotX
      dy = py - spotY
      distance = dx * dx + dy * dy
      if id = startTarget then
        startKind = kind
      end if
      if team = self.team then
        if kind = 1 then
          mapTile(px)
          homeX = tileValue
          mapTile(py)
          homeY = tileValue
          enemyX = map.width - 1 - homeX
          enemyY = map.height - 1 - homeY
        elseif kind = 2 then
          if id <> self.id and allyCount < 9 then
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
          if ownTowerCount < 16 then
            ownTowerIds(ownTowerCount) = id
            ownTowerXs(ownTowerCount) = px
            ownTowerYs(ownTowerCount) = py
            ownTowerCount = ownTowerCount + 1
          end if
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
      elseif team <> 2 then
        if kind = 1 then
          mapTile(px)
          enemyX = tileValue
          mapTile(py)
          enemyY = tileValue
          if objects(index).alive then
            godId = id
            godX = px
            godY = py
            godDistance = distance
            ' An exposed god proves both of its guards fell.
            guardBase = 30 - 2 * self.team
            towerStates(guardBase) = 0
            towerStates(guardBase + 1) = 0
          end if
        elseif kind = 2 then
          if distance < heroThreat then
            heroThreat = distance
          end if
          if enemyCount < 9 then
            enemyIds(enemyCount) = id
            enemyXs(enemyCount) = px
            enemyYs(enemyCount) = py
            enemyHps(enemyCount) = hp
            enemyTargets(enemyCount) = objects(index).targetId
            enemyCount = enemyCount + 1
          end if
        elseif kind = 3 then
          if creepCount < 96 then
            creepIds(creepCount) = id
            creepXs(creepCount) = px
            creepYs(creepCount) = py
            creepHps(creepCount) = hp
            creepCount = creepCount + 1
          end if
        elseif kind = 4 then
          if id >= 10 and id <= 31 then
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
              ' sight, so the spot check below cannot retire it).
              tier = (id - 10) mod 3
              for lower = id - tier to id - 1
                towerStates(lower) = 0
              next lower
            end if
          end if
        elseif kind = 5 then
          if objects(index).alive and distance < barracksDistance then
            barracksId = id
            barracksX = px
            barracksY = py
            barracksDistance = distance
          end if
        end if
      elseif kind = 6 then
        ' Neutral camps count only while one of them is hitting us.
        if objects(index).targetId = self.id and distance <= 64 then
          campId = id
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

sub scanItems()
  healSlot = -1
  healCount = 0
  elixirSlot = -1
  elixirCount = 0
  manaSlot = -1
  portalSlot = -1
  portalCount = 0
  empty = 0
  hasDagger = 0
  hasArmor = 0
  hasBow = 0
  hasBoots = 0
  for itemSlot = 0 to 5
    item = items(itemSlot).id
    if item = 0 then
      empty = empty + 1
    elseif item = 11 then
      hasDagger = 1
    elseif item = 16 then
      hasArmor = 1
    elseif item = 19 then
      hasBow = 1
    elseif item = 8 then
      hasBoots = 1
    elseif item = 1 then
      healSlot = itemSlot
      healCount = items(itemSlot).count
    elseif item = 2 then
      elixirSlot = itemSlot
      elixirCount = items(itemSlot).count
    elseif item = 22 then
      manaSlot = itemSlot
    elseif item = 21 then
      portalSlot = itemSlot
      portalCount = items(itemSlot).count
    end if
  next itemSlot
end sub

' Potions in the field only, never short of a full restore: a heal at 120
' missing health (at once below half health, otherwise after a second without
' damage, since damage cancels the heal), an elixir at 90, a mana potion at
' 90 missing mana below half mana. At home: the next gear item of dagger,
' armor, Rune Crossbow, boots whenever affordable, then heals up to five, then
' one portal; a free slot after the gear takes a mana potion, or elixirs once
' rich after minute 9.4.
sub economy()
  scanItems()
  if self.canShop = 0 then
    drank = 0
    if healSlot >= 0 and self.maxHp - self.hp >= 120 then
      if items(healSlot).cooldownTicks = 0 then
        if self.hp * 2 < self.maxHp or match.tick - hurtTick > 24 then
          accepted = useItem(healSlot)
          drank = 1
        end if
      end if
    end if
    if drank = 0 and elixirSlot >= 0 and self.maxHp - self.hp >= 90 then
      if items(elixirSlot).cooldownTicks = 0 then
        accepted = useItem(elixirSlot)
      end if
    end if
    if manaSlot >= 0 and self.maxMana - self.mana >= 90 and self.mana * 2 < self.maxMana then
      if items(manaSlot).cooldownTicks = 0 then
        if self.mana * 10 < self.maxMana * 3 or match.tick - hurtTick > 24 then
          accepted = useItem(manaSlot)
        end if
      end if
    end if
    exit sub
  end if
  budget = self.gold
  if hasDagger = 0 and budget >= 110 and empty > 0 then
    if buyItem(11) then
      budget = budget - 110
      empty = empty - 1
      hasDagger = 1
    end if
  end if
  if hasDagger = 1 and hasArmor = 0 and budget >= 160 and empty > 0 then
    if buyItem(16) then
      budget = budget - 160
      empty = empty - 1
      hasArmor = 1
    end if
  end if
  if hasArmor = 1 and hasBow = 0 and budget >= 180 and empty > 0 then
    if buyItem(19) then
      budget = budget - 180
      empty = empty - 1
      hasBow = 1
    end if
  end if
  if hasBow = 1 and hasBoots = 0 and budget >= 100 and empty > 0 then
    if buyItem(8) then
      budget = budget - 100
      empty = empty - 1
      hasBoots = 1
    end if
  end if
  for purchase = 1 to 5
    if healCount < 5 and budget >= 30 then
      if healCount > 0 or empty > 0 then
        if buyItem(1) then
          if healCount = 0 then
            empty = empty - 1
          end if
          healCount = healCount + 1
          budget = budget - 30
        end if
      end if
    end if
  next purchase
  if portalCount = 0 and budget >= 100 and empty > 0 then
    if buyItem(21) then
      budget = budget - 100
      empty = empty - 1
    end if
  end if
  if hasBoots = 1 and empty > 0 then
    if match.battleTick >= 13536 and budget >= 587 then
      for purchase = 1 to 2
        if budget >= 75 then
          if buyItem(2) then
            budget = budget - 75
          end if
        end if
      next purchase
    elseif manaSlot < 0 and budget >= 45 then
      if buyItem(22) then
        budget = budget - 45
      end if
    end if
  end if
  scanItems()
end sub

' The portal target is our standing tower nearest the enemy god; allies in
' the field within 30 tiles of a tower break the tie between the edge lanes.
sub pickForward()
  forwardId = 0
  forwardScore = 1000000
  forwardLane = -1
  for tower = 0 to ownTowerCount - 1
    tx = ownTowerXs(tower) - enemyX
    ty = ownTowerYs(tower) - enemyY
    score = tx * tx + ty * ty
    for ally = 0 to allyCount - 1
      hx = allyXs(ally) - homeX
      hy = allyYs(ally) - homeY
      if hx * hx + hy * hy > 400 then
        ax = allyXs(ally) - ownTowerXs(tower)
        ay = allyYs(ally) - ownTowerYs(tower)
        if ax * ax + ay * ay <= 900 then
          score = score - 300
        end if
      end if
    next ally
    if score < forwardScore then
      forwardScore = score
      forwardId = ownTowerIds(tower)
      forwardX = ownTowerXs(tower)
      forwardY = ownTowerYs(tower)
      forwardLane = -1
      if forwardId >= 10 and forwardId < 28 then
        forwardLane = (forwardId - 10) \ 6
      end if
    end if
  next tower
end sub

' Hero focus: the lowest-health enemy hero within 10 tiles (14 for the one we
' already hit) when our heroes within 8 tiles of us outnumber its heroes
' within 8 tiles of it; +2 to take one standing in its tower's reach. A hero
' hitting us inside our reach is always fair game. Creeps: the lowest within
' 7.5 tiles, ordered only near a kill.
sub chooseTargets()
  near = 1
  for ally = 0 to allyCount - 1
    ax = allyXs(ally) - spotX
    ay = allyYs(ally) - spotY
    if ax * ax + ay * ay <= 64 then
      near = near + 1
    end if
  next ally
  heroTargetId = 0
  heroTargetHp = 1000000
  heroTargetDistance = 1000000
  reachSquared = (self.attackRange + 1) * (self.attackRange + 1)
  for enemy = 0 to enemyCount - 1
    ex = enemyXs(enemy) - spotX
    ey = enemyYs(enemy) - spotY
    span = ex * ex + ey * ey
    limit = 100
    if enemyIds(enemy) = startTarget then
      limit = 196
    end if
    eligible = 0
    if span <= limit then
      guard = 0
      for other = 0 to enemyCount - 1
        ox = enemyXs(other) - enemyXs(enemy)
        oy = enemyYs(other) - enemyYs(enemy)
        if ox * ox + oy * oy <= 64 then
          guard = guard + 1
        end if
      next other
      edge = near - guard
      if edge >= 1 then
        eligible = 1
        if edge < 2 and dangerId <> 0 then
          tx = enemyXs(enemy) - dangerX
          ty = enemyYs(enemy) - dangerY
          if tx * tx + ty * ty <= dangerRange * dangerRange then
            eligible = 0
          end if
        end if
      end if
    end if
    if enemyTargets(enemy) = self.id and span <= reachSquared then
      eligible = 1
    end if
    if eligible = 1 and enemyHps(enemy) < heroTargetHp then
      heroTargetId = enemyIds(enemy)
      heroTargetHp = enemyHps(enemy)
      heroTargetX = enemyXs(enemy)
      heroTargetY = enemyYs(enemy)
      heroTargetDistance = span
    end if
  next enemy
  creepTargetId = 0
  creepTargetHp = 1000000
  for creep = 0 to creepCount - 1
    cx = creepXs(creep) - spotX
    cy = creepYs(creep) - spotY
    if cx * cx + cy * cy <= 56.25 and creepHps(creep) < creepTargetHp then
      creepTargetId = creepIds(creep)
      creepTargetHp = creepHps(creep)
    end if
  next creep
  bestId = 0
  bestKind = 0
  buildingId = 0
  if heroTargetId <> 0 then
    bestId = heroTargetId
    bestKind = 2
  elseif godId <> 0 and godDistance <= 100 then
    bestId = godId
    bestKind = 1
    buildingId = godId
    buildingX = godX
    buildingY = godY
    buildingDistance = godDistance
  elseif creepTargetId <> 0 and creepTargetHp <= self.attackDamage then
    bestId = creepTargetId
    bestKind = 3
  elseif towerAttack = 1 then
    bestId = dangerId
    bestKind = 4
    buildingId = dangerId
    buildingX = dangerX
    buildingY = dangerY
    buildingDistance = dangerSpan
  elseif barracksId <> 0 and barracksDistance <= 64 then
    bestId = barracksId
    bestKind = 5
    buildingId = barracksId
    buildingX = barracksX
    buildingY = barracksY
    buildingDistance = barracksDistance
  elseif creepTargetId <> 0 and creepTargetHp <= self.attackDamage * 2 then
    bestId = creepTargetId
    bestKind = 3
  elseif campId <> 0 then
    bestId = campId
    bestKind = 6
  end if
end sub

' Spells, checked against live mana so a second cast never fails short. W
' opens on the focused hero, else takes a creep kill the swing cannot. E and R
' are point casts at the target's spot: E at a hero within 5.9 tiles, else
' into three creeps it would kill; R at a hero within 7.4 tiles, else at the
' building we hit. Q hits the hero, else a creep it kills.
sub castSpells()
  if self.controls.silenceTicks > 0 then
    exit sub
  end if
  if abilities(1).level > 0 and abilities(1).cooldownTicks = 0 and abilities(1).charges > 0 then
    if self.mana >= abilities(1).manaCost then
      castId = 0
      spellReach = abilities(1).range - 0.1
      spellReach = spellReach * spellReach
      if heroTargetId <> 0 and heroTargetDistance <= spellReach then
        castId = heroTargetId
      else
        spellDamage = abilities(1).damage
        castHp = 1000000
        for creep = 0 to creepCount - 1
          if creepIds(creep) <> bestId and creepHps(creep) <= spellDamage and creepHps(creep) < castHp then
            cx = creepXs(creep) - spotX
            cy = creepYs(creep) - spotY
            if cx * cx + cy * cy <= spellReach then
              castId = creepIds(creep)
              castHp = creepHps(creep)
            end if
          end if
        next creep
      end if
      if castId <> 0 then
        accepted = castTarget(1, castId)
      end if
    end if
  end if
  if abilities(2).level > 0 and abilities(2).cooldownTicks = 0 and abilities(2).charges > 0 then
    if self.mana >= abilities(2).manaCost then
      if heroTargetId <> 0 and heroTargetDistance <= 34.8 then
        accepted = castPoint(2, heroTargetX, heroTargetY)
      else
        spellDamage = abilities(2).damage
        sumX = 0
        sumY = 0
        killable = 0
        for creep = 0 to creepCount - 1
          if creepHps(creep) <= spellDamage then
            cx = creepXs(creep) - spotX
            cy = creepYs(creep) - spotY
            if cx * cx + cy * cy <= 30.25 then
              sumX = sumX + cx
              sumY = sumY + cy
              killable = killable + 1
            end if
          end if
        next creep
        if killable >= 3 then
          aimX = sumX / killable
          aimY = sumY / killable
          aimSpan = aimX * aimX + aimY * aimY
          if aimSpan >= 0.25 then
            ' Count the killable creeps inside the 90 degree cone.
            inCone = 0
            for creep = 0 to creepCount - 1
              if creepHps(creep) <= spellDamage then
                cx = creepXs(creep) - spotX
                cy = creepYs(creep) - spotY
                span = cx * cx + cy * cy
                if span <= 36 then
                  dot = cx * aimX + cy * aimY
                  if dot > 0 and dot * dot * 2 >= span * aimSpan then
                    inCone = inCone + 1
                  end if
                end if
              end if
            next creep
            if inCone >= 3 then
              accepted = castPoint(2, spotX + aimX, spotY + aimY)
            end if
          end if
        end if
      end if
    end if
  end if
  if abilities(3).level > 0 and abilities(3).cooldownTicks = 0 and abilities(3).charges > 0 then
    if self.mana >= abilities(3).manaCost then
      if heroTargetId <> 0 and heroTargetDistance <= 54.7 then
        accepted = castPoint(3, heroTargetX, heroTargetY)
      elseif buildingId <> 0 and buildingDistance <= 49 then
        accepted = castPoint(3, buildingX, buildingY)
      end if
    end if
  end if
  if abilities(0).level > 0 and abilities(0).cooldownTicks = 0 and abilities(0).charges > 0 then
    if self.mana >= abilities(0).manaCost then
      castId = 0
      spellReach = abilities(0).range - 0.1
      spellReach = spellReach * spellReach
      if heroTargetId <> 0 and heroTargetDistance <= spellReach then
        castId = heroTargetId
      else
        spellDamage = abilities(0).damage
        castHp = 1000000
        for creep = 0 to creepCount - 1
          if creepIds(creep) <> bestId and creepHps(creep) <= spellDamage and creepHps(creep) < castHp then
            cx = creepXs(creep) - spotX
            cy = creepYs(creep) - spotY
            if cx * cx + cy * cy <= spellReach then
              castId = creepIds(creep)
              castHp = creepHps(creep)
            end if
          end if
        next creep
      end if
      if castId <> 0 then
        accepted = castTarget(0, castId)
      end if
    end if
  end if
end sub

' Clockwork Charge (ability 27) lands 24 ticks after the cast in a capsule
' 7.5 tiles long and 0.75 tiles half-wide from the caster along its facing.
' From the tick after the cast, a hero in that footprint (with body margin)
' walks 1.5 tiles sideways to the side it already stands on.
sub dodgeSpells()
  dodging = 0
  lastSpell = match.spellCount - 1
  if lastSpell > 31 then
    lastSpell = 31
  end if
  for warning = 0 to lastSpell
    if spells(warning).hostile = 1 and spells(warning).abilityId = 27 then
      impact = spells(warning).impactTick
      if impact > match.tick and impact - match.tick <= 23 then
        caster = spells(warning).casterId
        if caster > 0 then
          found = 0
          lastSeek = match.objectCount - 1
          if lastSeek > 399 then
            lastSeek = 399
          end if
          for seek = 0 to lastSeek
            if objects(seek).id = caster then
              axisX = objects(seek).facing.x
              axisY = objects(seek).facing.y
              found = 1
              exit for
            end if
          next seek
          if found = 1 and axisX * axisX + axisY * axisY < 0.5 then
            found = 0
          end if
          if found = 1 then
            relX = spotX - spells(warning).position.x
            relY = spotY - spells(warning).position.y
            along = relX * axisX + relY * axisY
            across = relY * axisX - relX * axisY
            if along >= -0.5 and along <= 8 and across <= 1.25 and across >= -1.25 then
              sideSign = 1
              if across < 0 then
                sideSign = -1
              end if
              dodgeX = spotX - axisY * 1.5 * sideSign
              dodgeY = spotY + axisX * 1.5 * sideSign
              if dodgeX < 1 then
                dodgeX = 1
              elseif dodgeX > map.width - 2 then
                dodgeX = map.width - 2
              end if
              if dodgeY < 1 then
                dodgeY = 1
              elseif dodgeY > map.height - 2 then
                dodgeY = map.height - 2
              end if
              dodgeUntil = impact + 1
              dodging = 1
              exit for
            end if
          end if
        end if
      end if
    end if
  next warning
end sub

' Drafting.
if draft.active then
  chooseHero()
  end
end if

' Decision-start state: our tile, our exact spot, and the target before this
' decision's commands (self.* refreshes after every command).
mapTile(self.position.x)
myX = tileValue
mapTile(self.position.y)
myY = tileValue
spotX = self.position.x
spotY = self.position.y
startTarget = self.targetId

' Death: buy back on the first tick it is affordable, with no reserve.
if self.hp <= 0 then
  initialized = 0
  retreat = 0
  resumeTarget = 0
  dodgeUntil = 0
  price = self.buybackPrice
  if price > 0 and self.gold >= price then
    accepted = buyback()
  end if
  end
end if
if self.channelTicks > 0 or self.controls.stunTicks > 0 then
  end
end if

' Dodge: sidestep an enemy Clockwork Charge and give no other order until it
' lands.
if match.tick < dodgeUntil then
  end
end if
if self.controls.rootTicks = 0 and match.spellCount > 0 then
  dodgeSpells()
  if dodging = 1 then
    accepted = walkTo(dodgeX, dodgeY)
    if accepted = 0 then
      ' A wall on that side: step out the other way.
      accepted = walkTo(spotX + spotX - dodgeX, spotY + spotY - dodgeY)
    end if
    if accepted = 1 then
      lastGoalX = -1
      resumeTarget = 0
      end
    end if
    ' Both sides refused: keep fighting instead of freezing until impact.
    dodgeUntil = 0
  end if
end if

' Stutter-step: after a landed hit, a quarter-tile walk resets the swing;
' the next tick resumes the same target.
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
  if spawnKnown = 0 then
    spawnKnown = 1
    spawnX = myX
    spawnY = myY
  end if
  homeX = myX
  homeY = myY
  enemyX = map.width - 1 - myX
  enemyY = map.height - 1 - myY
  previousHp = self.hp
  previousHits = self.attacksLanded
  lastGoalX = -1
  ordinal = 0
  for player = 0 to draft.playerCount - 1
    if players(player).team = self.team then
      if players(player).id < self.id then
        ordinal = ordinal + 1
      end if
    end if
  next player
  ' Macro lanes (macromackie, every 2026.10.8 game): four heroes walk one
  ' edge lane to its far corner and push on along it to the enemy god, the
  ' point mirror of each other (lane 2 for Red, lane 0 for Blue); one hero
  ' holds the other edge (Red ordinal 4, Blue ordinal 1). Nobody takes mid.
  isSolo = 0
  if self.team = 0 then
    lane = 2
    if ordinal = 4 then
      lane = 0
      isSolo = 1
    end if
  else
    lane = 0
    if ordinal = 1 then
      lane = 2
      isSolo = 1
    end if
  end if
  ' Lanes last three minutes; every later life heads straight for the god.
  crossed = 0
  if match.battleTick >= 4320 then
    crossed = 1
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
economy()

' Go home only with no heals left and under a quarter health.
if retreat = 0 and self.canShop = 0 then
  if healCount + elixirCount = 0 and self.hp * 4 < self.maxHp then
    retreat = 1
  end if
end if
' The edge solo walks home once at about 3:25, with no enemy hero within 15
' tiles, to shop before it joins the push.
if isSolo = 1 and soloRecalled = 0 and match.battleTick >= 4920 then
  dx = myX - homeX
  dy = myY - homeY
  if match.battleTick >= 5760 or dx * dx + dy * dy < 900 then
    soloRecalled = 1
  elseif heroThreat > 225 then
    soloRecalled = 1
    retreat = 1
  end if
end if

' Spawn: shop, wait for full health and mana (the edge solo also waits 13 s
' at the start), then portal to the forward tower when the scroll is ready.
' Nobody waits for allies.
if self.inOwnSpawn then
  if spawnTick = 0 then
    spawnTick = match.tick
  end if
  ready = 0
  if self.hp * 100 >= self.maxHp * 99 and self.mana * 100 >= self.maxMana * 99 then
    ready = 1
  end if
  if match.tick - spawnTick >= 240 then
    ready = 1
  end if
  ' The edge solo leaves about 13 s after the pack (battle tick 312). Our
  ' first creep wave spawns on the first battle tick, so waiting for it
  ' would not hold the solo at all.
  if isSolo = 1 and match.battleTick < 312 then
    ready = 0
  end if
  if ready = 0 then
    if match.tick >= moveTick then
      accepted = walkTo(spawnX, spawnY)
      lastGoalX = -1
      moveTick = match.tick + 24
    end if
    end
  end if
  retreat = 0
  if portalSlot >= 0 and self.portalCooldownTicks = 0 and self.controls.rootTicks = 0 then
    pickForward()
    if forwardId <> 0 then
      dx = forwardX - spotX
      dy = forwardY - spotY
      if dx * dx + dy * dy > 400 then
        if useItemAt(portalSlot, forwardX, forwardY) then
          if crossed = 0 and forwardLane >= 0 then
            lane = forwardLane
          end if
          lastGoalX = -1
          end
        end if
      end if
    end if
  end if
else
  spawnTick = 0
end if

' Trip home: a ready portal always (from the field or the keep entrance,
' often bought that same tick), otherwise one walk to the spawn tile.
if retreat = 1 then
  if portalSlot >= 0 and self.portalCooldownTicks = 0 and self.controls.rootTicks = 0 then
    dx = myX - spawnX
    dy = myY - spawnY
    if dx * dx + dy * dy > 100 then
      if useItemAt(portalSlot, spawnX, spawnY) then
        lastGoalX = -1
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

chooseTargets()

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

' Combat: attack the chosen target and cast what is ready.
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
castSpells()

' Let go of a tower we may not hit (one shooting a hero, or too few creeps).
if startKind = 4 and towerAttack = 0 and self.controls.rootTicks = 0 then
  accepted = walkTo(spawnX, spawnY)
  lastGoalX = -1
  end
end if

' Advance: the lane corner, then attack-move to the enemy god's center; the
' tower edge above stops us at each tower until our creeps arrive.
laneWaypoint()
if match.battleTick >= 4320 then
  crossed = 1
end if
dx = myX - goalX
dy = myY - goalY
if dx * dx + dy * dy <= 64 then
  crossed = 1
end if
if crossed = 1 then
  goalX = enemyX
  goalY = enemyY
end if
' Re-issue the attack-move when its goal changes, after any other order once
' the hero has no target, every five seconds without a target, or after one
' second standing idle (an attack-move chase replaces the path, so a hero
' whose chased target died stops where it died); never over a fight.
if self.controls.rootTicks = 0 then
  issue = 0
  if goalX <> lastGoalX or goalY <> lastGoalY then
    if startTarget = 0 or lastGoalX <> -1 then
      issue = 1
    end if
  elseif startTarget = 0 and match.tick - lastGoalTick >= 120 then
    issue = 1
  elseif startTarget = 0 and self.hasMoveTarget = 0 and match.tick - lastGoalTick >= 24 then
    issue = 1
  end if
  if issue = 1 then
    accepted = attackMove(goalX, goalY)
    lastGoalX = goalX
    lastGoalY = goalY
    lastGoalTick = match.tick
  end if
end if
