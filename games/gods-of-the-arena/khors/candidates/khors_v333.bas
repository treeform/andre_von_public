' @gota-structures
' Khors v333 - macromackie-style league Crossbowman: v331 stack + v330 kiting + tower edge + hero spacing
' Structure follows the league leader aaron-gota-micro0922: think every six
' ticks, stutter-step after each landed hit, score creeps/heroes/god, retreat
' at a quarter health, respect towers, carry gear and heals, restock at 500
' gold, portal home when the god is threatened, and advance from the lane
' waypoint to the enemy god. Written fresh on our own draft and abilities.
'
' League Crossbowman priority (self.class = Crossbowman and mixedTeam = 1),
' highest first. A rule that acts ends the decision, so no lower rule moves us:
'   1. Retreat: below 15% health walk (or portal) home at once. While
'      retreating, only an enemy hero already in reach is executed (an
'      instant kill, no step), and the walk home is re-issued in the same
'      tick.
'   2. Execute: every tick, finish the weakest enemy hero in reach (else an
'      exposed tower, barracks or god) with exactly enough Poison Potions. It
'      ignores rules 3 and 4, and while a dose waits on a step toward its
'      target, the think does nothing else.
'   3. Tower edge: an enemy tower is safe while it shoots one of our creeps
'      (targetId >= 1000) with at least 2 of our creeps inside its range (9 /
'      9.5 / 10 tiles by max HP). Never step into an unsafe tower's range + 1;
'      inside its range, walk straight out to range + 1, and keep walking until
'      range + 0.9 (hysteresis). Siege mode tanks exposed guards (v328), so
'      they are never unsafe.
'   4. Hero spacing: keep every visible enemy hero (the nearest included) at
'      its attack range + 1.5 or more, except (a) the hero we attack while it
'      is in our 6-tile reach and we outrange it, and (b) a hero our poison
'      stack can kill. A hero that targets us with us inside its range: step
'      2 tiles away instead of attacking (only a poison kill outranks this,
'      and rule 2 already threw it).
'   5. Kiting stutter (v330): after each landed hit step behind a screen from
'      the nearest enemy hero, never into an unsafe tower's range + 1.
'   6. Siege and targeting (v328 + v331 scores): a target is dropped when the
'      spot we would shoot it from breaks rule 3 or 4.
'   7. Advance: attack-move along the lane; when the way runs into a rule 3
'      or 4 zone within 2.5 tiles, hold at its edge instead.

dim owned(22)
' Rules 3 and 4 zones, rebuilt every think by scanDangers(): the unsafe enemy
' towers and the spaced enemy heroes.
dim edgeXs(11)
dim edgeYs(11)
dim edgeRanges(11)
dim edgeOnCreeps(11)
dim edgeCreeps(11)
dim foeXs(9)
dim foeYs(9)
dim foeRanges(9)
dim foeIds(9)
dim foeTargets(9)

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

' The basic-attack range in tiles of a hero class (content.nim): melee heroes
' reach about 1.3 tiles.
sub classRange(heroClass)
  heroRange = 1.3
  if heroClass = Ranger or heroClass = Crossbowman then
    heroRange = 6
  elseif heroClass = Lich then
    heroRange = 5.5
  elseif heroClass = Arcanist then
    heroRange = 5
  elseif heroClass = Warlock then
    heroRange = 4.5
  elseif heroClass = DruidWarden then
    heroRange = 4
  end if
end sub

' Rules 3 and 4 zones for the league Crossbowman, within 32 tiles: every
' unsafe enemy tower (edgeCount) and every enemy hero to keep spaced
' (foeCount). A tower is safe while it shoots one of our creeps and at least
' two of ours stand inside its range; exposed guards in siege mode never count.
sub scanDangers()
  edgeCount = 0
  foeCount = 0
  ownX = self.position.x
  ownY = self.position.y
  for scan = 0 to match.objectCount - 1
    if objects(scan).hp > 0 and objects(scan).team <> self.team then
      sx = objects(scan).position.x - ownX
      sy = objects(scan).position.y - ownY
      if sx > -32 and sx < 32 and sy > -32 and sy < 32 then
        if objects(scan).kind = 4 and edgeCount < 12 then
          towerGuard = 0
          if siegeOpen = 1 and objects(scan).alive then
            gx = objects(scan).position.x - enemyX
            gy = objects(scan).position.y - enemyY
            if gx > -9 and gx < 9 and gy > -9 and gy < 9 then
              if gx * gx + gy * gy <= 64 then
                towerGuard = 1
              end if
            end if
          end if
          if towerGuard = 0 then
            edgeXs(edgeCount) = objects(scan).position.x
            edgeYs(edgeCount) = objects(scan).position.y
            ' Outer, inner and gate/guard towers reach 9, 9.5 and 10 tiles.
            edgeRanges(edgeCount) = 10
            if objects(scan).maxHp <= 2000 then
              edgeRanges(edgeCount) = 9
            elseif objects(scan).maxHp <= 3000 then
              edgeRanges(edgeCount) = 9.5
            end if
            edgeOnCreeps(edgeCount) = 0
            if objects(scan).targetId >= 1000 then
              edgeOnCreeps(edgeCount) = 1
            end if
            edgeCreeps(edgeCount) = 0
            edgeCount = edgeCount + 1
          end if
        elseif objects(scan).kind = 2 and foeCount < 10 then
          ' (b) A hero our Poison Potion stack can kill is never spaced.
          if objects(scan).hp > poisons * 35 then
            classRange(objects(scan).class)
            foeXs(foeCount) = objects(scan).position.x
            foeYs(foeCount) = objects(scan).position.y
            foeRanges(foeCount) = heroRange
            foeIds(foeCount) = objects(scan).id
            foeTargets(foeCount) = objects(scan).targetId
            foeCount = foeCount + 1
          end if
        end if
      end if
    end if
  next scan
  if edgeCount = 0 then
    exit sub
  end if
  ' Count our creeps inside each tower's range.
  for scan = 0 to match.objectCount - 1
    if objects(scan).kind = 3 and objects(scan).team = self.team and objects(scan).hp > 0 then
      for edge = 0 to edgeCount - 1
        cx = objects(scan).position.x - edgeXs(edge)
        cy = objects(scan).position.y - edgeYs(edge)
        if cx > -10 and cx < 10 and cy > -10 and cy < 10 then
          if cx * cx + cy * cy <= edgeRanges(edge) * edgeRanges(edge) then
            edgeCreeps(edge) = edgeCreeps(edge) + 1
          end if
        end if
      next edge
    end if
  next scan
  ' Keep only the unsafe towers.
  kept = 0
  for edge = 0 to edgeCount - 1
    if edgeOnCreeps(edge) = 0 or edgeCreeps(edge) < 2 then
      edgeXs(kept) = edgeXs(edge)
      edgeYs(kept) = edgeYs(edge)
      edgeRanges(kept) = edgeRanges(edge)
      kept = kept + 1
    end if
  next edge
  edgeCount = kept
end sub

' Rule 3 for one spot: towerOk = 0 when (px, py) lies within an unsafe enemy
' tower's range + slack.
sub checkTowers(px, py, slack)
  towerOk = 1
  for edge = 0 to edgeCount - 1
    edgeDx = px - edgeXs(edge)
    edgeDy = py - edgeYs(edge)
    edgeLimit = edgeRanges(edge) + slack
    if edgeDx > 0 - edgeLimit and edgeDx < edgeLimit and edgeDy > 0 - edgeLimit and edgeDy < edgeLimit then
      if edgeDx * edgeDx + edgeDy * edgeDy < edgeLimit * edgeLimit then
        towerOk = 0
        exit for
      end if
    end if
  next edge
end sub

' Rule 4 for one spot: foeOk = 0 when (px, py) lies within a spaced enemy
' hero's attack range + 1.5 + slack. The hero spareId is skipped.
sub checkFoes(px, py, slack, spareId)
  foeOk = 1
  for foe = 0 to foeCount - 1
    if foeIds(foe) <> spareId then
      foeDx = px - foeXs(foe)
      foeDy = py - foeYs(foe)
      foeLimit = foeRanges(foe) + 1.5 + slack
      if foeDx > 0 - foeLimit and foeDx < foeLimit and foeDy > 0 - foeLimit and foeDy < foeLimit then
        if foeDx * foeDx + foeDy * foeDy < foeLimit * foeLimit then
          foeOk = 0
          exit for
        end if
      end if
    end if
  next foe
end sub

' The spot we would shoot objects(standIndex) from: where a straight walk
' first brings it within 5.8 of our 6-tile reach (towers and barracks a tile
' sooner from their footprint, the god within 4.05 of its 4.25), or our own
' spot when it is in reach already (standMoves = 0). A hero, creep or
' neutral within the full 6 tiles is in reach: the attack does not step.
sub standPoint(standIndex)
  standX = self.position.x
  standY = self.position.y
  standMoves = 0
  standReach = self.attackRange - 0.2
  standLimit = self.attackRange
  if objects(standIndex).kind = 4 or objects(standIndex).kind = 5 then
    standReach = standReach + 1
    standLimit = standReach
  elseif objects(standIndex).kind = 1 then
    standReach = 4.05
    standLimit = standReach
  end if
  standDx = objects(standIndex).position.x - standX
  standDy = objects(standIndex).position.y - standY
  if standDx > -32 and standDx < 32 and standDy > -32 and standDy < 32 then
    standSpan = standDx * standDx + standDy * standDy
    if standSpan > standLimit * standLimit then
      standSpan = sqrt(standSpan)
      standX = objects(standIndex).position.x - standDx * standReach / standSpan
      standY = objects(standIndex).position.y - standDy * standReach / standSpan
      standMoves = 1
    end if
  end if
end sub

' Rules 3 and 4 for one target objects(zoneIndex): zoneOk = 0 when the spot
' we would shoot it from lies inside an unsafe tower's range + 1 or a spaced
' hero's range + 2 and we must walk there, or inside the tower's range or the
' hero's range + 1.5 when we already reach it (hysteresis). Siege targets
' (zoneSiege = 1: exposed guards in siege mode, the god) skip the + 1 margin
' but not the range itself (+ 0.3 to walk), or rule 3 walks us back out.
sub zoneTarget(zoneIndex, zoneSiege)
  zoneOk = 1
  if edgeCount = 0 and foeCount = 0 then
    exit sub
  end if
  standPoint(zoneIndex)
  towerSlack = 0
  foeSlack = 0
  if standMoves = 1 then
    towerSlack = 1
    foeSlack = 0.5
    if zoneSiege = 1 then
      towerSlack = 0.3
    end if
  end if
  checkTowers(standX, standY, towerSlack)
  if towerOk = 0 then
    zoneOk = 0
    exit sub
  end if
  ' (a) An enemy hero already in our reach that we outrange is fought, not
  ' spaced.
  spareHero = 0
  if objects(zoneIndex).kind = 2 and standMoves = 0 then
    classRange(objects(zoneIndex).class)
    if self.attackRange > heroRange then
      spareHero = objects(zoneIndex).id
    end if
  end if
  checkFoes(standX, standY, foeSlack, spareHero)
  if foeOk = 0 then
    zoneOk = 0
  end if
end sub

' Rule 7 for one zone of the given radius around (zoneX, zoneY): when it lies
' ahead on the way to the goal (unit wayX, wayY over wayLength), crosses that
' line, and its edge is within 2.5 tiles of us, hold 0.2 outside its edge on
' our side. The nearest such edge wins (holdFound, holdX, holdY).
sub holdCheck(zoneX, zoneY, radius)
  zoneDx = zoneX - self.position.x
  zoneDy = zoneY - self.position.y
  outer = radius + 2.5
  if zoneDx > 0 - outer and zoneDx < outer and zoneDy > 0 - outer and zoneDy < outer then
    zoneSpan = sqrt(zoneDx * zoneDx + zoneDy * zoneDy)
    along = zoneDx * wayX + zoneDy * wayY
    across = zoneDx * wayY - zoneDy * wayX
    if across < 0 then
      across = 0 - across
    end if
    if zoneSpan < outer and zoneSpan > 0.05 and along > 0 and along < wayLength + radius and across < radius then
      if holdFound = 0 or zoneSpan - radius < holdGap then
        holdFound = 1
        holdGap = zoneSpan - radius
        holdX = zoneX - zoneDx * (radius + 0.2) / zoneSpan
        holdY = zoneY - zoneDy * (radius + 0.2) / zoneSpan
      end if
    end if
  end if
end sub

' League Crossbowman screen spot (v330). With an enemy hero within 12 tiles
' it sets spotOk = 1 and spotX/spotY to the far side of a screen from that
' hero: 1.4 behind and 1.3 beside the nearest ally non-healer hero within 6
' tiles, else 3 behind our creep nearest the enemy within 8 tiles, else 2
' straight back. A spot inside an unsafe tower's range + 1 is refused.
sub screenSpot(spotTarget)
  spotOk = 0
  ownX = self.position.x
  ownY = self.position.y
  aimFound = 0
  foeFound = 0
  foeDistance = 144
  for scan = 0 to match.objectCount - 1
    if objects(scan).hp > 0 then
      sx = objects(scan).position.x - ownX
      sy = objects(scan).position.y - ownY
      if sx > -12 and sx < 12 and sy > -12 and sy < 12 then
        ' Only hero, creep and neutral targets: building ranges count from
        ' their footprint, so the 5.8-tile pull below does not fit them.
        if objects(scan).id = spotTarget then
          if objects(scan).kind = 2 or objects(scan).kind = 3 or objects(scan).kind = 6 then
            aimFound = 1
            aimX = objects(scan).position.x
            aimY = objects(scan).position.y
          end if
        end if
        if objects(scan).kind = 2 and objects(scan).team <> self.team then
          if sx * sx + sy * sy < foeDistance then
            foeFound = 1
            foeDistance = sx * sx + sy * sy
            foeX = objects(scan).position.x
            foeY = objects(scan).position.y
          end if
        end if
      end if
    end if
  next scan
  if aimFound = 0 or foeFound = 0 or foeDistance < 0.04 then
    exit sub
  end if
  ' The screen: macromackie's screened samples stand 1.4 tiles behind and
  ' 1.3 beside an ally hero, or 3.3 behind the front creep.
  screenKind = 0
  mateDistance = 36
  creepDistance = 1000
  for scan = 0 to match.objectCount - 1
    if objects(scan).team = self.team and objects(scan).hp > 0 and objects(scan).id <> self.id then
      sx = objects(scan).position.x - ownX
      sy = objects(scan).position.y - ownY
      if sx > -8 and sx < 8 and sy > -8 and sy < 8 then
        if objects(scan).kind = 2 and objects(scan).class <> Warlock and objects(scan).class <> DruidWarden then
          if sx * sx + sy * sy < mateDistance then
            mateDistance = sx * sx + sy * sy
            mateX = objects(scan).position.x
            mateY = objects(scan).position.y
            screenKind = 1
          end if
        elseif objects(scan).kind = 3 and sx * sx + sy * sy <= 64 then
          cx = objects(scan).position.x - foeX
          cy = objects(scan).position.y - foeY
          if cx * cx + cy * cy < creepDistance then
            creepDistance = cx * cx + cy * cy
            creepX = objects(scan).position.x
            creepY = objects(scan).position.y
          end if
        end if
      end if
    end if
  next scan
  baseX = ownX
  baseY = ownY
  back = 2
  side = 0
  if screenKind = 1 then
    baseX = mateX
    baseY = mateY
    back = 1.4
    side = 1.3
  elseif creepDistance < 1000 then
    baseX = creepX
    baseY = creepY
    back = 3
  end if
  ux = baseX - foeX
  uy = baseY - foeY
  span = sqrt(ux * ux + uy * uy)
  if span < 0.2 then
    ux = ownX - foeX
    uy = ownY - foeY
    span = sqrt(foeDistance)
  end if
  ux = ux / span
  uy = uy / span
  ' Stay on our own side of the screen's line to the enemy.
  if (ownY - baseY) * ux - (ownX - baseX) * uy < 0 then
    side = -side
  end if
  spotX = baseX + back * ux - side * uy
  spotY = baseY + back * uy + side * ux
  ' Keep the attack target within 5.8 of the 6-tile range.
  gapX = spotX - aimX
  gapY = spotY - aimY
  reach = gapX * gapX + gapY * gapY
  if reach > 33.64 then
    reach = sqrt(reach)
    spotX = aimX + gapX * 5.8 / reach
    spotY = aimY + gapY * 5.8 / reach
  end if
  ' Never step nearer the enemy hero than we already stand.
  gapX = spotX - foeX
  gapY = spotY - foeY
  limit = sqrt(foeDistance) - 0.1
  if gapX * gapX + gapY * gapY < limit * limit then
    exit sub
  end if
  ' Rule 3 outranks the stutter: never into an unsafe tower's range + 1.
  checkTowers(spotX, spotY, 1)
  if towerOk = 0 then
    exit sub
  end if
  spotOk = 1
end sub

sub observe()
  leagueCarry = 0
  if self.class = Crossbowman and mixedTeam = 1 then
    leagueCarry = 1
  end if
  bestId = 0
  bestScore = -1000000
  bestDistance = 1000000
  bestKind = 0
  bestHp = 0
  bestGuard = 0
  leagueCrossbowman = 0
  if self.class = Crossbowman and mixedTeam = 1 then
    leagueCrossbowman = 1
  end if
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
  startDropped = 0
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
        ' A league Crossbowman leaves neutral camps alone unless one is on it.
        skipTarget = 0
        if kind = 6 and leagueCarry = 1 and objects(index).targetId <> self.id then
          skipTarget = 1
        end if
        ' A league Crossbowman marks enemy towers within 8 tiles of the enemy
        ' god as its guards, and opens a siege for the rest of the match once
        ' a guard or the god itself is exposed (alive).
        isGuard = 0
        if leagueCrossbowman = 1 and kind = 4 then
          gx = x - enemyX
          gy = y - enemyY
          if gx * gx + gy * gy <= 64 then
            isGuard = 1
          end if
        end if
        if leagueCrossbowman = 1 and objects(index).alive then
          if isGuard = 1 or kind = 1 then
            siegeOpen = 1
          end if
        end if
        ' In the siege it also skips creeps out of reach, so its attack-move
        ' keeps walking to the enemy god.
        if leagueCrossbowman = 1 and siegeOpen = 1 then
          if kind = 3 and distance > hitReach * hitReach then
            skipTarget = 1
          end if
        end if
        if distance <= 900 and objects(index).alive and skipTarget = 0 then
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
            ' In the siege a league Crossbowman hits a guard whatever it shoots.
            if isGuard = 1 and siegeOpen = 1 then
              score = score + 2500
            elseif objects(index).targetId >= 1000 then
              score = score + 2000
            end if
          elseif kind = 1 then
            if leagueCrossbowman = 1 and siegeOpen = 1 then
              score = score + 3000
            else
              score = score + 500
            end if
          end if
          if id = startTarget then
            score = score + 70
          end if
          if score > bestScore then
            ' Rules 3 and 4 run only for a would-be best target, which keeps
            ' the scan cheap and still finds the best target that passes.
            zoneOk = 1
            if leagueCrossbowman = 1 then
              siegeTarget = 0
              if kind = 1 or (isGuard = 1 and siegeOpen = 1) then
                siegeTarget = 1
              end if
              zoneTarget(index, siegeTarget)
            end if
            if zoneOk = 1 then
              bestScore = score
              bestId = id
              bestKind = kind
              bestHp = hp
              bestX = x
              bestY = y
              bestDistance = distance
              bestGuard = isGuard
            elseif id = startTarget then
              startDropped = 1
            end if
          end if
        end if
      end if
    end if
  next index
end sub

' Top the Poison Potion stack up to the limit while gold and a slot allow.
sub buyPoison(stackLimit)
  for purchase = 1 to 8
    if poisonCount < stackLimit and budget >= 40 and (poisonCount > 0 or empty > 0) then
      if buyItem(4) = 0 then
        exit sub
      end if
      if poisonCount = 0 then
        empty = empty - 1
      end if
      poisonCount = poisonCount + 1
      budget = budget - 40
    end if
  next purchase
end sub

sub economy()
  ' A league Crossbowman carries Poison Potions in place of the Dagger.
  leagueXbow = 0
  if self.class = Crossbowman and mixedTeam = 1 then
    leagueXbow = 1
  end if
  gearCount = 0
  healSlot = -1
  healCount = 0
  portalSlot = -1
  portalCount = 0
  poisonCount = 0
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
    elseif item = 4 then
      poisonCount = items(slot).count
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
    ' Every visit tops poison up to three before gear (the opener buys
    ' three and a heal with the starting 150 gold).
    if leagueXbow = 1 then
      buyPoison(3)
    end if
    if leagueXbow = 0 and hasDagger = 0 and budget >= 110 and empty > 0 then
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
    ' After minute 5, leftover gold tops poison up to a full stack of eight.
    if leagueXbow = 1 and match.battleTick >= match.tickRate * 300 then
      budget = self.gold
      buyPoison(8)
    end if
  else
    ' Without the Dagger a league Crossbowman's gear tops out at three.
    if gearCount < 4 - leagueXbow and self.gold >= 500 and threatDistance > 225 then
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
  ' A league Crossbowman buys back whenever it can afford it (macromackie
  ' v13 buys back 4.5 times a game and is dead 5% of the time).
  if price > 0 and self.class = Crossbowman and mixedTeam = 1 then
    if self.gold >= price then
      accepted = buyback()
    end if
  end if
  end
end if
if self.channelTicks > 0 or self.controls.stunTicks > 0 then
  end
end if

' Rule 2, league Crossbowman execute, every tick: a Poison Potion strikes the
' attack target for 35 within the basic-attack range, so finish the weakest
' enemy hero in reach, else an exposed tower, barracks or god, with exactly
' enough. Rule 1 outranks it: a retreat executes only heroes, never steps
' toward one, and walks home again in the same tick.
if self.class = Crossbowman and mixedTeam = 1 then
  poisonSlot = -1
  poisons = 0
  for slot = 0 to 5
    if items(slot).id = 4 then
      poisonSlot = slot
      poisons = items(slot).count
    end if
  next slot
  execId = 0
  if poisons > 0 then
    execHp = 0
    execHero = 0
    poisonCap = 35 * poisons
    for index = 0 to match.objectCount - 1
      kind = objects(index).kind
      execKind = 0
      if kind = 2 then
        execKind = 1
      elseif retreat = 0 and (kind = 1 or kind = 4 or kind = 5) then
        execKind = 1
      end if
      if execKind = 1 then
        hp = objects(index).hp
        if hp > 0 and hp <= poisonCap and objects(index).alive and objects(index).team <> self.team then
          ' Heroes and the god count center to center; towers and barracks
          ' about a tile sooner, from their footprint.
          reach = self.attackRange
          if kind = 4 or kind = 5 then
            reach = reach + 1
          end if
          ex = objects(index).position.x - self.position.x
          ey = objects(index).position.y - self.position.y
          if ex <= reach and ex >= 0 - reach and ey <= reach and ey >= 0 - reach then
            if ex * ex + ey * ey <= reach * reach then
              isHero = 0
              if kind = 2 then
                isHero = 1
              end if
              if execId = 0 or isHero > execHero or (isHero = execHero and hp < execHp) then
                execId = objects(index).id
                execHp = hp
                execHero = isHero
              end if
            end if
          end if
        end if
      end if
    next index
  end if
  if execId <> 0 then
    if startTarget <> execId then
      accepted = attackTarget(execId)
      lastGoalX = -1
    end if
    ' Poison hits the current attack target. A rejected first dose (a
    ' structure just out of reach) costs nothing, so fall through then.
    if self.targetId = execId then
      if useItem(poisonSlot) then
        doses = (execHp + 34) \ 35
        thrown = 1
        for dose = 2 to doses
          if thrown = 1 then
            thrown = useItem(poisonSlot)
          end if
        next dose
        ' The attack order replaced any walk, so the next think re-issues one.
        resumeTarget = 0
        lastGoalX = -1
        moveTick = match.tick
        if retreat = 1 and self.controls.rootTicks = 0 then
          accepted = walkTo(spawnX, spawnY)
          moveTick = match.tick + 24
        end if
        end
      end if
    end if
    ' A retreat never steps toward a rejected dose's target.
    if retreat = 1 then
      execId = 0
      if self.controls.rootTicks = 0 then
        accepted = walkTo(spawnX, spawnY)
        lastGoalX = -1
        moveTick = match.tick + 24
      end if
    end if
  end if
end if

' Stutter-step: after a landed hit, a quarter-tile walk resets the swing;
' the next think resumes the same target. Rule 5 for the league Crossbowman
' (v330 kiting): the step goes behind a screen from the nearest enemy hero.
' Rule 2 outranks it: no step while a dose waits on a step of its own.
if self.controls.rootTicks = 0 and execId = 0 then
  if resumeTarget > 0 then
    ' The league Crossbowman walks on to its screen spot for up to four
    ' ticks (about 0.4 tiles) before the attack resumes.
    if match.tick < spotUntil then
      sx = spotX - self.position.x
      sy = spotY - self.position.y
      if sx * sx + sy * sy > 0.09 then
        end
      end if
    end if
    if retreat = 0 and startTarget = 0 then
      accepted = attackTarget(resumeTarget)
      lastGoalX = -1
    end if
    resumeTarget = 0
  elseif retreat = 0 and startTarget > 0 and self.attacksLanded > previousHits then
    previousHits = self.attacksLanded
    resumeTarget = startTarget
    ' A league Crossbowman with an enemy hero within 12 tiles steps toward
    ' the far side of a screen from it instead of the quarter-tile walk.
    spotOk = 0
    if self.class = Crossbowman and mixedTeam = 1 then
      screenSpot(startTarget)
    end if
    if spotOk = 1 then
      if walkTo(spotX, spotY) then
        spotUntil = match.tick + 4
      end if
    else
      accepted = walkTo(myX + 0.25, myY + 0.25)
    end if
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
' Rules 3 and 4 zones come first: observe() drops targets inside them.
edgeCount = 0
foeCount = 0
if self.class = Crossbowman and mixedTeam = 1 then
  scanDangers()
end if
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
  ' Rule 1: a league Crossbowman turns home at once. An attack or
  ' attack-move order from before the retreat would otherwise run on
  ' until moveTick (up to 18 more ticks at low health).
  retreatNow = 0
  if leagueCrossbowman = 1 and (self.targetId <> 0 or lastGoalX <> -1) then
    retreatNow = 1
  end if
  if self.controls.rootTicks = 0 and (match.tick >= moveTick or retreatNow = 1) then
    accepted = walkTo(spawnX, spawnY)
    lastGoalX = -1
    moveTick = match.tick + 24
  end if
  end
end if

' Rule 2: a dose that waits on a step toward its target (the first one was
' just out of reach) keeps its attack order, so nothing below may move us.
if leagueCrossbowman = 1 and execId <> 0 then
  end
end if

' Rule 3, tower edge: inside an unsafe enemy tower's range, walk straight out
' to its range + 1 (away from all such towers at once, by depth). While
' escaping, the trigger widens to range + 0.9, so the walk finishes and the
' range edge cannot make it ping-pong.
if leagueCrossbowman = 1 and self.controls.rootTicks = 0 then
  escapeSlack = 0
  if escaping = 1 then
    escapeSlack = 0.9
  end if
  escapeX = 0
  escapeY = 0
  escapeDepth = 0
  for edge = 0 to edgeCount - 1
    edgeDx = self.position.x - edgeXs(edge)
    edgeDy = self.position.y - edgeYs(edge)
    edgeLimit = edgeRanges(edge) + escapeSlack
    if edgeDx > 0 - edgeLimit and edgeDx < edgeLimit and edgeDy > 0 - edgeLimit and edgeDy < edgeLimit then
      edgeSpan = sqrt(edgeDx * edgeDx + edgeDy * edgeDy)
      if edgeSpan < edgeLimit then
        if edgeSpan < 0.05 then
          ' On the tower's center: out toward our spawn.
          edgeDx = 1
          edgeDy = 1
          if spawnX < self.position.x then
            edgeDx = -1
          end if
          if spawnY < self.position.y then
            edgeDy = -1
          end if
          edgeSpan = 1.4142
        end if
        depth = edgeRanges(edge) + 1 - edgeSpan
        escapeX = escapeX + edgeDx / edgeSpan * depth
        escapeY = escapeY + edgeDy / edgeSpan * depth
        if depth > escapeDepth then
          escapeDepth = depth
        end if
      end if
    end if
  next edge
  escaping = 0
  if escapeDepth > 0 then
    escaping = 1
    escapeSpan = sqrt(escapeX * escapeX + escapeY * escapeY)
    walked = 0
    if escapeSpan > 0.05 then
      walked = walkTo(self.position.x + escapeX / escapeSpan * escapeDepth, self.position.y + escapeY / escapeSpan * escapeDepth)
    end if
    if walked = 0 then
      accepted = walkTo(spawnX, spawnY)
    end if
    lastGoalX = -1
    resumeTarget = 0
    spotUntil = 0
    moveTick = match.tick + 6
    end
  end if
end if

' Tower safety: step away from a tower that is on us, or one with no creeps.
' A league Crossbowman sieging a guard tanks it down to a quarter health. For
' the league Crossbowman this runs after rule 3, so in practice it covers the
' towers rule 3 leaves out (exposed guards in siege mode).
unsafe = 0
sieging = 0
if leagueCrossbowman = 1 and bestKind = 4 and bestId <> 0 and bestGuard = 1 then
  sieging = 1
  if self.hp * 100 < self.maxHp * 25 then
    unsafe = 1
  end if
end if
if towerAggro = 1 and self.hp * 100 < self.maxHp * 65 and sieging = 0 then
  unsafe = 1
end if
if bestKind = 4 and bestId <> 0 and tanks = 0 and sieging = 0 then
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

' Rule 4, hero spacing: step away from every enemy hero nearer than its
' attack range + 1.5, except (a) the hero we attack while it is in our reach
' and we outrange it. A hero that targets us with us inside its range (+0.5
' for the six ticks between thinks) means a 2-tile step away instead of an
' attack. Heroes our poison stack can kill (b) are not listed at all.
if leagueCrossbowman = 1 and self.controls.rootTicks = 0 then
  pushX = 0
  pushY = 0
  pushStep = 0
  for foe = 0 to foeCount - 1
    foeDx = self.position.x - foeXs(foe)
    foeDy = self.position.y - foeYs(foe)
    if foeDx > -9 and foeDx < 9 and foeDy > -9 and foeDy < 9 then
      foeSpan = sqrt(foeDx * foeDx + foeDy * foeDy)
      if foeSpan < 0.05 then
        ' On top of it: away toward our spawn.
        foeDx = 1
        foeDy = 1
        if spawnX < self.position.x then
          foeDx = -1
        end if
        if spawnY < self.position.y then
          foeDy = -1
        end if
        foeSpan = 1.4142
      end if
      if foeTargets(foe) = self.id and foeSpan <= foeRanges(foe) + 0.5 then
        pushX = pushX + foeDx / foeSpan * 2
        pushY = pushY + foeDy / foeSpan * 2
        pushStep = 2
      elseif foeSpan < foeRanges(foe) + 1.5 then
        spared = 0
        if foeIds(foe) = bestId and foeSpan <= self.attackRange and self.attackRange > foeRanges(foe) then
          spared = 1
        end if
        if spared = 0 then
          gap = foeRanges(foe) + 1.5 - foeSpan
          pushX = pushX + foeDx / foeSpan * gap
          pushY = pushY + foeDy / foeSpan * gap
          if pushStep < gap + 0.5 then
            pushStep = gap + 0.5
          end if
        end if
      end if
    end if
  next foe
  if pushStep > 0 then
    pushSpan = sqrt(pushX * pushX + pushY * pushY)
    ' Flanked heroes can cancel out: then there is no way out to step to.
    if pushSpan > 0.05 then
      if pushStep < 1 then
        pushStep = 1
      end if
      if pushStep > 2 then
        pushStep = 2
      end if
      awayX = self.position.x + pushX / pushSpan * pushStep
      awayY = self.position.y + pushY / pushSpan * pushStep
      ' Rule 3 outranks rule 4: never step into an unsafe tower's range + 1.
      checkTowers(awayX, awayY, 1)
      if towerOk = 0 then
        awayX = spawnX
        awayY = spawnY
      end if
      ' A rejected walk still cancels the attack (sim applyWalkTo), so an
      ' idle hero would auto-acquire the hero it backs away from.
      if walkTo(awayX, awayY) = 0 then
        accepted = walkTo(spawnX, spawnY)
      end if
      lastGoalX = -1
      resumeTarget = 0
      spotUntil = 0
      moveTick = match.tick + 6
      end
    end if
  end if
end if

healAllies()

' A Crossbowman closes on creeps it cannot reach when the fight is even.
' The league Crossbowman holds its screen spot instead while an enemy hero is
' within 12 tiles (v330: closing would walk it straight back in after each
' step), and closes only onto a spot outside rules 3 and 4.
holdSpot = 0
if self.class = Crossbowman and mixedTeam = 1 and bestKind = 3 then
  for scan = 0 to match.objectCount - 1
    if objects(scan).kind = 2 and objects(scan).team <> self.team and objects(scan).hp > 0 then
      sx = objects(scan).position.x - self.position.x
      sy = objects(scan).position.y - self.position.y
      if sx > -12 and sx < 12 and sy > -12 and sy < 12 then
        if sx * sx + sy * sy < 144 then
          holdSpot = 1
        end if
      end if
    end if
  next scan
end if
if self.class = Crossbowman and bestKind = 3 and bestId > 0 and holdSpot = 0 then
  if bestDistance > 25 and bestDistance <= 64 and enemyPower <= friendPower then
    closeX = (myX + bestX) / 2
    closeY = (myY + bestY) / 2
    closeOk = 1
    if leagueCrossbowman = 1 then
      checkTowers(closeX, closeY, 1)
      checkFoes(closeX, closeY, 0.5, 0)
      if towerOk = 0 or foeOk = 0 then
        closeOk = 0
      end if
    end if
    if closeOk = 1 then
      if self.controls.rootTicks = 0 then
        accepted = walkTo(closeX, closeY)
        lastGoalX = -1
        moveTick = match.tick + 6
      end if
      end
    end if
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
' Rule 7 hold for the league Crossbowman: when the straight way to the goal
' runs into an unsafe tower's range + 1 or a spaced hero's range + 1.5 whose
' edge is within 2.5 tiles, stand 0.2 outside that edge instead of walking in
' (macromackie waits at the tower edge for our wave). A walk is issued only
' to cancel an attack-move or a dropped chase, or to reach the edge.
if leagueCrossbowman = 1 and self.controls.rootTicks = 0 then
  holdFound = 0
  holdGap = 0
  wayX = (goalX - self.position.x) / 16
  wayY = (goalY - self.position.y) / 16
  wayLength = sqrt(wayX * wayX + wayY * wayY) * 16
  if wayLength > 1 then
    wayX = (goalX - self.position.x) / wayLength
    wayY = (goalY - self.position.y) / wayLength
    for edge = 0 to edgeCount - 1
      holdCheck(edgeXs(edge), edgeYs(edge), edgeRanges(edge) + 1)
    next edge
    for foe = 0 to foeCount - 1
      holdCheck(foeXs(foe), foeYs(foe), foeRanges(foe) + 1.5)
    next foe
  end if
  if holdFound = 1 then
    holdDx = holdX - self.position.x
    holdDy = holdY - self.position.y
    if lastGoalX <> -1 or startDropped = 1 or holdDx * holdDx + holdDy * holdDy > 0.25 then
      accepted = walkTo(holdX, holdY)
      lastGoalX = -1
    end if
    moveTick = match.tick + 6
    end
  end if
end if
' A chase after a target dropped by rules 3 and 4 ends with a fresh
' attack-move at once.
if leagueCrossbowman = 1 and startDropped = 1 then
  lastGoalX = -1
  moveTick = match.tick
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
