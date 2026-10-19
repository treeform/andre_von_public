import std/[os, strutils], ../brain
let b = newBrain()
for team in 0 .. 1:
  let spawn = if team == 0: (113, 12) else: (15, 116)
  echo "team ", team, " ranked nest cells: ", b.nestCells(team)[0 .. 7]
  for cell in b.nestCells(team)[0 .. 7]:
    echo "  cost spawn->", cell, " = ", b.routeCost(team, cell, spawn)
  if team == 0:
    for cell in [(21, 103), (21, 104), (22, 103), (21, 105), (22, 105), (21, 107)]:
      echo "  old nest ", cell, " cost = ", b.routeCost(team, cell, spawn)
for team in 0 .. 1:
  for goal in b.nestCells(team)[0 .. 4]:
    var (y, x) = (if team == 0: (113, 12) else: (15, 116))
    var path = ""
    var steps = 0
    while (y, x) != goal and steps < 600:
      let (dy, dx) = b.nextStep(team, y, x, goal)
      if dy == 0 and dx == 0: break
      y += dy; x += dx; inc steps
      if steps mod 12 == 0 or coveredByEnemyTower(y, x, team):
        path.add "(" & $y & "," & $x & (if coveredByEnemyTower(y, x, team): "!" else: "") & ") "
    echo "team ", team, " goal ", goal, " steps=", steps, " path: ", path
