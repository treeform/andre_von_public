' runeclock_test.bas — micro-test: pre-throw at the north spawn point on the
' rune clock so the blade passes (64,16) as the rune materializes.
if selfTeam = 0 then
  postX = riverWest - 4
else
  postX = riverEast + 4
end if
walkTo(postX, 20)
phase = worldTick mod 640
if hookReady = 1 and phase = preTicks then
  hookTo(64, 16)
end if
