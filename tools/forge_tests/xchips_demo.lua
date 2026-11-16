XC = XC or {}
local Store = JokerForge.store

function XC.make()
  Store.list = {}
  Store.put({id = "xca", name = "Chip Doubler", rarity = 1, cost = 4, enabled = true, art = {atlas = "Joker", x = 1, y = 1}, rules = {{when = "card_scored", give = {{id = "xchips", n = 2}}}}})
  Store.put({id = "xcb", name = "Chip Tripler", rarity = 1, cost = 4, enabled = true, art = {atlas = "Joker", x = 2, y = 1}, rules = {{when = "hand_played", give = {{id = "xchips", n = 3}}}}})
  Store.put({id = "xcc", name = "Chip Grower", rarity = 1, cost = 4, enabled = true, art = {atlas = "Joker", x = 3, y = 1}, rules = {{when = "blind_selected", give = {{id = "gain_xchips", n = 0.5}}}}})
  Store.save()
  JokerForge.joker.register_all()
end

function XC.add()
  for _, id in ipairs({"xca", "xcb", "xcc"}) do FPLAY.add(id) end
end

function XC.log(tag)
  local parts = {}
  for _, c in ipairs(G.jokers.cards) do parts[#parts + 1] = c.config.center.key .. "=[" .. (S12 and S12.card_text(c) or "") .. "]" end
  HLOG("xc_state", tag, "chips", G.GAME.chips, "hand_chips", hand_chips, "mult", mult, table.concat(parts, " "))
end

return XC
