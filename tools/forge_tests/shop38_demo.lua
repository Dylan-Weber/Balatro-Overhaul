SH = SH or {}

local function shop_card(area, center, kind)
  local c = Card(area.T.x + area.T.w / 2, area.T.y, G.CARD_W, G.CARD_H, G.P_CARDS.empty, center, {bypass_discovery_center = true, bypass_discovery_ui = true})
  create_shop_card_ui(c, kind, area)
  area:emplace(c)
  c:set_cost()
  return c
end

function SH.setup()
  G.GAME.dollars = 100
  SH.pack = shop_card(G.shop_jokers, G.P_CENTERS.p_arcana_normal_1, "Booster")
  SH.tarot = shop_card(G.shop_vouchers, G.P_CENTERS.c_fool, "Tarot")
  SH.planet = shop_card(G.shop_booster, G.P_CENTERS.c_pluto, "Planet")
  HLOG("sh_setup", "touch", tostring(G.CONTROLLER.HID.touch), "pc_select", tostring(G.SETTINGS.touch_pc_select), #G.shop_jokers.cards, #G.shop_vouchers.cards, #G.shop_booster.cards)
end

local function btn(card)
  local b = card.children.buy_button
  local found = {}
  local function walk(n)
    if type(n) ~= "table" then return end
    if n.config and (n.config.button or n.config.func) then found[#found + 1] = tostring(n.config.button) .. "/" .. tostring(n.config.func) end
    for _, ch in pairs(n.children or {}) do walk(ch) end
  end
  if b then walk(b.UIRoot) end
  if card.children.buy_and_use_button then walk(card.children.buy_and_use_button.UIRoot) end
  return table.concat(found, ",")
end

function SH.tap(which)
  local c = SH[which]
  c:single_tap()
  HLOG("sh_tap", which, "highlighted", tostring(c.highlighted), "buttons", btn(c))
end

function SH.press(which, func)
  local c = SH[which]
  local hit
  local function walk(n)
    if type(n) ~= "table" or hit then return end
    if n.config and n.config.func == func then hit = n end
    for _, ch in pairs(n.children or {}) do walk(ch) end
  end
  if c.children.buy_button then walk(c.children.buy_button.UIRoot) end
  if not hit and c.children.buy_and_use_button then walk(c.children.buy_and_use_button.UIRoot) end
  HLOG("sh_press", which, func, hit and tostring(hit.config.button) or "NO BUTTON")
  if hit then hit:click() end
end

function SH.swipe(which)
  SH[which]:swipe_up()
end

function SH.log(tag)
  HLOG("sh_state", tag, "state", G.STATE, "dollars", G.GAME.dollars, "consumeables", #G.consumeables.cards, "pack_cards", G.pack_cards and #G.pack_cards.cards or -1, "shop_v", #G.shop_vouchers.cards, "shop_b", #G.shop_booster.cards)
end

return SH
