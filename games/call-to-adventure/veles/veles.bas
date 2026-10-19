' Veles - Call to Adventure hero.
'
' Scoring is personal, not shared: a living hero who reached the surface
' with the most banked gold takes the win, and everyone else takes zero.
' Gold on the floor is the score, so this hero picks piles up ahead of
' picking fights. The other three will do the killing either way, and
' every pile they leave behind is free.
'
' Two changes to the bundled baseline:
'
'   1. Loot outranks attacking. The baseline swings first and collects
'      whatever is left over.
'   2. Drink earlier - at 60 percent rather than 50. A dead hero banks
'      nothing at all, however much it is carrying.
'
' Healing an ally still comes first, because only the cleric can do it
' and the call is refused outright for everyone else.
'
' Host surface (see ../docs/player.md):
'   selfId selfClass worldTick currentLevel x y hp maxHp mana maxMana
'   objectiveLevel objectiveX objectiveY
'   nearestEnemy() nearestLoot() woundedAlly()
'   walkTo(level, x, y) attackTarget(id) pickupTarget(id) healTarget(id)
'   useItem(slot) dropItem(slot)
'
' Only stop after a command that actually started. A failed attack or
' pickup would otherwise halt the hero in place for the tick.

if hp * 5 <= maxHp * 3 then
  if useItem(0) <> 0 then
    stop
  end if
  if useItem(1) <> 0 then
    stop
  end if
end if

friend = woundedAlly()
if friend <> 0 then
  if healTarget(friend) <> 0 then
    stop
  end if
end if

treasure = nearestLoot()
if treasure <> 0 then
  if pickupTarget(treasure) <> 0 then
    stop
  end if
end if

enemy = nearestEnemy()
if enemy <> 0 then
  if attackTarget(enemy) <> 0 then
    stop
  end if
end if

' The objective is the way down while the vault still holds monsters and
' the way home afterwards. Banked gold only counts on the surface.
discardResult = walkTo(objectiveLevel, objectiveX, objectiveY)
