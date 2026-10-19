' Drink everything that heals, then walk home to the spawn fountain.
learn()
if selfHp < selfMaxHp then
  for slot = 0 to 5
    item = itemId(slot)
    if item = 2 or item = 1 then
      accepted = useItem(slot)
    end if
  next slot
end if
accepted = walkTo(homeX, homeY)
