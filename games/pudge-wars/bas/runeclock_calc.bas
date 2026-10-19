' runeclock_calc.bas — pre-throw at the north rune spawn with the launch tick
' computed from our distance: windup 9 ticks, then the head flies
' 0.6 tiles/tick + 0.03/tick^2 (cap 1.8). Solve 0.6n + 0.015n^2 >= d in
' integer hundredths: 60n + 3n^2/2 >= 100d, ramp cap after 40 ticks.
postX = POSTX
postY = POSTY
walkTo(postX, postY)
sdx = 64 - selfX
sdy = 16 - selfY
d2 = sdx * sdx + sdy * sdy
' integer sqrt by iteration (d <= 60)
d = 0
while (d + 1) * (d + 1) <= d2
  d = d + 1
wend
n = 0
covered = 0
while covered < d * 100 and n < 200
  n = n + 1
  if n <= 40 then
    covered = 60 * n + (3 * n * n) / 2
  else
    covered = 4800 + 180 * (n - 40)
  end if
wend
launch = 640 - 9 - n + 1   ' head on the point one tick after the spawn (hooks step before runes)
phase = worldTick mod 640
if hookReady = 1 and phase = launch and d2 <= 3136 then
  hookTo(64, 16)
end if
