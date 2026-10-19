' runeguard_test.bas — micro-test: stand 4 tiles off the lip near the north
' spawn and hook any visible rune inside 30 tiles whenever the hook is ready.
if selfTeam = 0 then
  postX = riverWest - 4
else
  postX = riverEast + 4
end if
walkTo(postX, 20)
if hookReady = 1 then
  r = 0
  while r < runeCount()
    rdx = runeX(r) - selfX
    rdy = runeY(r) - selfY
    if rdx * rdx + rdy * rdy <= 900 then
      hookTo(runeX(r), runeY(r))
      r = runeCount()
    end if
    r = r + 1
  wend
end if
