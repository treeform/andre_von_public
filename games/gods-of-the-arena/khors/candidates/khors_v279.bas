' @gota-structures
' Khors v279 - v270 with economy and R dodge from v275
' Structure follows the league leader aaron-gota-micro0922: think every six
' ticks, stutter-step after each landed hit, score creeps/heroes/god, respect
' towers, and advance from the lane waypoint to the enemy god. Written fresh
' on our own draft and abilities. From v275 (the macromackie replica) come the
' items, potions, go-home and spawn-leaving rules, instant buyback, forward
' and home portals, and the Clockwork Charge sidestep.

dim owned(22)
dim allyXs(9)
dim allyYs(9)
dim ownTowerIds(15)
dim ownTowerXs(15)
dim ownTowerYs(15)

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
  allyCount = 0
  ownTowerCount = 0
  hitReach = floor(self.attackRange) + 1
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
          ' Exact ally spots break the forward portal's tie between lanes.
          if allyCount < 9 then
            allyXs(allyCount) = objects(index).position.x
            allyYs(allyCount) = objects(index).position.y
            allyCount = allyCount + 1
          end if
        elseif kind = 3 then
          if distance <= 64 then
            tanks = tanks + 1
          end if
        elseif kind = 4 then
          ' Our standing towers are the forward portal's candidates.
          if ownTowerCount < 16 then
            ownTowerIds(ownTowerCount) = id
            ownTowerXs(ownTowerCount) = objects(index).position.x
            ownTowerYs(ownTowerCount) = objects(index).position.y
            ownTowerCount = ownTowerCount + 1
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
economy()

' Go home only with no heals left and under a quarter health.
if retreat = 0 and self.canShop = 0 then
  if healCount + elixirCount = 0 and self.hp * 4 < self.maxHp then
    retreat = 1
  end if
end if

' Spawn: shop, wait for full health and mana, then portal to the forward
' tower when the scroll is ready. Nobody waits for allies.
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
