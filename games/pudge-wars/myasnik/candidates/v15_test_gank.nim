## Offline harness for the 0.3.2 blink-gank layer. No sim, no sockets:
## synthetic observations through `decide`, asserting the blink-in, the
## enemy-bank rot/melee fight, the low-HP flee, the river escape, and the
## initiator/follower split. Run from this directory:
##   nim r --hints:off -d:myasnikTest test_gank.nim

include ../myasnik/myasnik

const
  riverWest = 53.0
  riverEast = 75.0

proc pudge(slot, team: int, x, y: float, hp = 840.0, hooked = false,
    blinkReady = false, rot = false, inRiver = false, id = -1): JsonNode =
  %*{
    "id": (if id < 0: 100 + slot else: id), "slot": slot, "team": team,
    "x": x, "y": y, "hp": hp, "max_hp": 840.0, "alive": true,
    "hooked": hooked, "shield": false, "hook_ready": true,
    "blink_ready": blinkReady, "rot": rot, "in_river": inRiver,
    "layer": (if inRiver: 2 elif x < riverWest: 0 else: 1)
  }

proc observation(me: JsonNode, others: seq[JsonNode] = @[], tick = 100.0): JsonNode =
  var pudges = %*[]
  pudges.add me
  for other in others:
    pudges.add other
  %*{
    "type": "observation", "tick": tick, "slot": me{"slot"}.getInt,
    "width": 128, "height": 128, "river_west": riverWest, "river_east": riverEast,
    "self": me, "visible": {"pudges": pudges, "hooks": %[], "runes": %[]},
    "ally_ping": newJNull()
  }

var checks = 0

proc pass(name: string) =
  inc checks
  echo "ok ", name

## 1. Home bank, blink ready, enemy visible on their bank: blink onto it.
block:
  let action = decide(observation(pudge(1, 0, 41.0, 64.0, blinkReady = true),
    @[pudge(4, 1, 80.0, 60.0)]), Memory())
  let hop = action{"blink_to"}
  doAssert not hop.isNil, "no blink-in on a visible enemy"
  doAssert abs(hop[0].getFloat - 80.0) < 0.5 and abs(hop[1].getFloat - 60.0) < 0.5,
    "blink-in not aimed at the enemy: " & $hop
  doAssert not action{"ping"}.isNil, "blink-in did not ping the target"
  pass "blink-in onto a visible enemy-bank target"

## 2. Same, blink cooling: no blink, ordinary post play continues.
block:
  let action = decide(observation(pudge(1, 0, 41.0, 64.0),
    @[pudge(4, 1, 80.0, 60.0)]), Memory())
  doAssert action{"blink_to"}.isNil, "blinked with the blink cooling"
  doAssert not action{"walk_to"}.isNil, "no post walk while cooling"
  pass "cooling blink falls through to post play"

## 3. Low HP at home: no blink-in even when ready.
block:
  let action = decide(observation(pudge(1, 0, 41.0, 64.0, hp = 300.0, blinkReady = true),
    @[pudge(4, 1, 80.0, 60.0)]), Memory())
  doAssert action{"blink_to"}.isNil, "blinked in at 36% HP"
  pass "no blink-in below the HP floor"

## 4. Initiator vs follower with nothing visible: seat 0 opens blind onto
##    the mirrored camper post, seat 1 holds.
block:
  let opener = decide(observation(pudge(0, 0, 41.0, 64.0, blinkReady = true)), Memory())
  let hop = opener{"blink_to"}
  doAssert not hop.isNil, "initiator did not open"
  doAssert hop[0].getFloat > riverEast, "initiator hop not onto the enemy bank: " & $hop
  let follower = decide(observation(pudge(1, 0, 41.0, 64.0, blinkReady = true)), Memory())
  doAssert follower{"blink_to"}.isNil, "follower blinked blind"
  pass "initiator opens blind, follower waits"

## 5. On the enemy bank next to an enemy: rot on and melee it.
block:
  let action = decide(observation(pudge(0, 0, 88.0, 64.0),
    @[pudge(4, 1, 92.0, 64.0, id = 7)]), Memory())
  doAssert action{"rot_toggle"}.getBool(false), "rot not toggled on in reach"
  doAssert action{"attack_target"}.getInt(-1) == 7, "no melee order on the adjacent enemy"
  doAssert action{"blink_to"}.isNil, "blinked away mid-fight"
  pass "enemy-bank fight: rot on, melee the neighbour"

## 6. On the enemy bank, rot already on, enemy 7 tiles away (inside the
##    cloud, outside melee): keep rot, chase, point-blank hook. At 12
##    tiles the cloud would only burn us, so rot goes off.
block:
  let action = decide(observation(pudge(0, 0, 84.0, 64.0, rot = true),
    @[pudge(4, 1, 91.0, 64.0)]), Memory())
  doAssert action{"rot_toggle"}.isNil, "rot toggled off while an enemy is in reach"
  let far = decide(observation(pudge(0, 0, 84.0, 64.0, rot = true),
    @[pudge(4, 1, 96.0, 64.0)]), Memory())
  doAssert far{"rot_toggle"}.getBool(false), "rot left burning with nobody in reach"
  doAssert not action{"walk_to"}.isNil, "no chase order"
  doAssert action{"walk_to"}[0].getFloat > 84.0, "chase went the wrong way"
  doAssert not action{"hook_to"}.isNil, "no point-blank hook while closing"
  pass "enemy-bank chase with a point-blank hook"

## 7. Low HP on the enemy bank with rot on: toggle rot off (a cloud pins
##    blinks); next tick with rot off and blink ready, blink home.
block:
  let first = decide(observation(pudge(0, 0, 88.0, 64.0, hp = 200.0, rot = true,
    blinkReady = true), @[pudge(4, 1, 92.0, 64.0)]), Memory())
  doAssert first{"rot_toggle"}.getBool(false), "rot left on while fleeing"
  doAssert first{"blink_to"}.isNil, "blinked inside own rot cloud"
  let second = decide(observation(pudge(0, 0, 88.0, 64.0, hp = 200.0,
    blinkReady = true), @[pudge(4, 1, 92.0, 64.0)]), Memory())
  let hop = second{"blink_to"}
  doAssert not hop.isNil, "no flee blink"
  doAssert hop[0].getFloat < riverWest, "flee blink not aimed home: " & $hop
  pass "low-HP flee: rot off, then blink home"

## 8. In the river with blink ready: blink home, never a river walk.
block:
  let action = decide(observation(pudge(2, 0, 60.0, 64.0, inRiver = true,
    blinkReady = true)), Memory())
  let hop = action{"blink_to"}
  doAssert not hop.isNil, "no river escape blink"
  doAssert hop[0].getFloat < riverWest, "river escape not aimed home: " & $hop
  pass "river escape by blink"

## 9. East team mirror: blink-in and flee point the other way.
block:
  let action = decide(observation(pudge(4, 1, 87.0, 64.0, blinkReady = true),
    @[pudge(1, 0, 48.0, 60.0)]), Memory())
  let hop = action{"blink_to"}
  doAssert not hop.isNil and hop[0].getFloat < riverWest, "east blink-in wrong: " & $hop
  let flee = decide(observation(pudge(4, 1, 40.0, 64.0, hp = 200.0, blinkReady = true),
    @[pudge(1, 0, 44.0, 64.0)]), Memory())
  doAssert not flee{"blink_to"}.isNil and flee{"blink_to"}[0].getFloat > riverEast,
    "east flee blink wrong: " & $flee{"blink_to"}
  pass "east-team mirror"

echo checks, " checks passed"
