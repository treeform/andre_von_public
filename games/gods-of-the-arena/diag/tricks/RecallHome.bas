' Portal toward home, then walk into the spawn fountain.
learn()
if selfChannelTicks = 0 then
  if ported = 0 then
    for slot = 0 to 5
      if itemId(slot) = 21 then
        accepted = useItemAt(slot, homeX, homeY)
        if accepted then
          ported = 1
        end if
      end if
    next slot
  end if
  if selfChannelTicks = 0 then
    accepted = walkTo(homeX, homeY)
  end if
end if
