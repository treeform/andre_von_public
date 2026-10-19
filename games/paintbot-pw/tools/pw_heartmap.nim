## Prints a replay map's homes and control hearts (position, owner at the start, in water).
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_heartmap tools/pw_heartmap.nim
##   tools/pw_heartmap <replay>

import
  std/[os, strformat],
  game, sim

proc main() =
  ## Loads the replay's world and lists its hearts.
  let recording = loadRecording(paramStr(1))
  let w = newWorld(recording.seed, recording.endTick)
  echo &"home red ({home(0).x}, {home(0).z})  home blue ({home(1).x}, {home(1).z})"
  echo &"glory config: {gloryRules()}"
  for i, h in w.controlHearts:
    let wet = terrainHeight(h.pos.x.int, h.pos.z.int) < RiverWaterHeight and riverBlend(h.pos.x.int, h.pos.z.int) > 0
    echo &"heart {i}: ({h.pos.x}, {h.pos.z}) owner {h.owner} water {wet}"

main()
