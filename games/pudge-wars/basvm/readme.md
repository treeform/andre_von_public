# basvm — the local .bas bot as a hosted league player

`basvm.nim` embeds the polyworld BASIC interpreter (`basic.nim`, copied
verbatim from the engine) and runs `policy.bas` (= `bas/myasnik_v75.bas`)
against the coworld websocket observations. Every observation becomes the
script's host data (`selfX`, `hookReady`, `worldTick`, ...) and its
object / hook / rune lists; the script's `walkTo` / `hookTo` / `blinkTo` /
`attackTarget` / `rotToggle` / `halt` / `ping` / `placeWall` / `placeMine`
calls become the action JSON. `buyUpgrade` / `buyPower` / `itemRank`
return 0: the hosted protocol has no shop action. `rotToggle` also returns 0
unless built with `-d:basvmRot`: the hosted observation does not report
our own rot state, so the script's toggle flickers and burns us (v1: 9.5
deaths per seat-game; v2 with rot off: 5.1, score 0.50 -> 0.745 vs the
top 3).

Mapping notes: tiles are `floor(x)`, `riverWest` = river_west - 1 and
`riverEast` = river_east + 1 (the script wants the last land columns), a
hook with no victim reads as flying, `homeX/Y` fall back to the spawn
pads by team and lane rank when the observation has none.

Build and upload (from the repo root):

    games/pudge-wars/basvm/build.sh
    uv --project ~/p/metta run coworld player use ply_3d22435e-30a2-4f2a-b037-a5c249583788
    uv --project ~/p/metta run coworld upload-policy myasnik-bas:latest --name myasnik-bas --run /bin/policy_player

Self-test without docker: `nim c -d:basvmTest -r basvm.nim` prints the
actions for two synthetic observations.
