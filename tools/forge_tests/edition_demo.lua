FED = FED or {}

local Store = JokerForge.store
local K = ForgeKinds

function FED.art()
  local d = love.image.newImageData(71, 95)
  for x = 0, 70 do
    for y = 0, 94 do
      local dx, dy = x - 35, y - 47
      local r = math.sqrt(dx * dx + dy * dy)
      if r > 20 and r < 26 then d:setPixel(x, y, 1, 0.85, 0.2, 1) end
      if x < 4 or x > 66 or y < 4 or y > 90 then d:setPixel(x, y, 0.9, 0.2, 0.6, 1) end
    end
  end
  love.filesystem.createDirectory("forge/art")
  love.filesystem.write("forge/art/fed_test.png", d:encode("png"):getString())
end

function FED.make()
  Store.ensure_dirs()
  FED.art()
  Store.items_list = {}
  Store.put_item({id = "ef1", kind = "edition", name = "Fe Foil", fields = {shader = "foil", chips = 10}})
  Store.put_item({id = "ef2", kind = "edition", name = "Fe Gold Holo", fields = {shader = "holo", tint = "gold", power = 150, mult = 2}})
  Store.put_item({id = "ef3", kind = "edition", name = "Fe Prism", fields = {shader = "tshine_prism", xmult = 1.2}})
  Store.put_item({id = "ef4", kind = "edition", name = "Fe Red Ghost", fields = {shader = "tshine_ghost", tint = "red", chips = 5}})
  Store.put_item({id = "ef5", kind = "edition", name = "Fe Ring", fields = {shader = "tshine_scan"}, art = {file = "forge/art/fed_test.png"}})
  Store.put_item({id = "ef6", kind = "edition", name = "Fe Pink Neg", fields = {shader = "negative", tint = "pink"}})
  Store.put_item({id = "ef7", kind = "edition", name = "Fe Ring Only", fields = {shader = "none"}, art = {file = "forge/art/fed_test.png"}})
  K.register_all()
end

function FED.hand(list)
  for i, ed in ipairs(list) do
    local c = G.hand.cards[i]
    if c then c:set_edition(ed, true, true) end
  end
  local out = {}
  for i = 1, #list do
    local c = G.hand.cards[i]
    local e = c and c.edition or {}
    local keys = {}
    for k, v in pairs(e) do if v == true then keys[#keys + 1] = k end end
    table.sort(keys)
    out[#out + 1] = tostring(e.forge or e.key or e.type) .. "[" .. table.concat(keys, ",") .. "]"
  end
  HLOG("fed_hand", table.concat(out, " "))
end

function FED.debug()
  local FS = require("functions/forge/forge_shine")
  local c = G.hand.cards[2]
  HLOG("fed_debug", tostring(FS.installed), tostring(SMODS and SMODS.DrawSteps and SMODS.DrawSteps.edition ~= nil), tostring(FS.owns(c)), tostring(FS.card_look(c) ~= nil), tostring(FS.shaders.foil), tostring(c.edition and c.edition.forge))
end

function FED.debug_art()
  local FS = require("functions/forge/forge_shine")
  local c = JokerForge.store.get_item("ef5")
  local spr = c and FS.art(c)
  HLOG("fed_art", tostring(c and c.art and c.art.file), tostring(c and c.art and c.art.file and love.filesystem.getInfo(c.art.file) ~= nil), tostring(spr))
end

function FED.debug_draw()
  local FS = require("functions/forge/forge_shine")
  local card = G.hand.cards[6]
  local look, spr = FS.card_look(card)
  local ok, err = pcall(FS.draw, card)
  HLOG("fed_draw", tostring(look and look.shader), tostring(spr), tostring(ok), tostring(err), tostring(spr and spr.states.visible), tostring(spr and spr.atlas and spr.atlas.name), tostring(card.delay_edition))
end

function FED.swap_atlas()
  local FS = require("functions/forge/forge_shine")
  local hit = FS.arts.ef5
  HLOG("fed_swap", tostring(hit and hit.spr))
  if hit and hit.spr then hit.spr.atlas = G.ASSET_ATLAS.centers; hit.spr:set_sprite_pos({x = 2, y = 0}) end
end

function FED.start()
  local B = ForgeBuilder
  B.start_new()
  JokerForge.ui.open("builder")
  G.FUNCS.forge_b_kind({config = {ref_table = {kind = "edition"}}})
  HLOG("fed_start", #require("functions/forge/forge_doc").templates("edition"))
end

function FED.page(d) G.FUNCS.forge_b_page({config = {ref_table = {d = d}}}) end

function FED.pick(key)
  local list = require("functions/forge/forge_doc").templates("edition")
  for i, t in ipairs(list) do
    if t.key == key then G.FUNCS.forge_b_template({config = {ref_table = {i = i}}}) end
  end
  local d = ForgeBuilder.state.draft
  HLOG("fed_pick", tostring(d and d.name), tostring(d and d.fields.shader), tostring(d and d.fields.tint), tostring(d and d.fields.power))
end

function FED.set(k, v)
  ForgeBuilder.state.draft.fields[k] = v
  JokerForge.ui.reopen("builder")
end

function FED.save()
  local c = ForgeBuilder.save()
  local Cat = require("functions/forge/forge_catalog")
  HLOG("fed_save", tostring(c and c.id), tostring(c and c.fields.shader), tostring(c and c.fields.tint), tostring(c and c.fields.power), "need_v", tostring(c and Cat.need_v(c)))
end

function FED.paint()
  local P = require("functions/forge/forge_pixel")
  local PX = ForgePixelUI
  local d = PX.doc
  local _, _, _, a0 = P.unpack(P.get(d, 35, 47))
  local col = P.hex("ff5f9f")
  for x = 0, 70 do
    for y = 0, 94 do
      local dx, dy = x - 35, y - 47
      if math.abs(dx) + math.abs(dy) < 14 and math.abs(dx) + math.abs(dy) > 9 then P.set(d, x, y, col) end
    end
  end
  PX.sync_image()
  PX.save()
  HLOG("fed_paint", PX.state.kind, "alpha_before", tostring(a0))
end

function FED.list()
  local U = JokerForge.ui
  if U.state then U.state.kind = "edition" end
  ForgeBuilder.state.draft = nil
  U.reopen("my")
end

function FED.kind(k)
  local B = ForgeBuilder
  B.new_draft({kind = k, mode = "advanced"})
  B.state.sec = "basics"
  JokerForge.ui.reopen("builder")
end

function FED.wheel(n, dy)
  local ok, err = true, nil
  for _ = 1, n do
    ok, err = pcall(love.wheelmoved, 0, dy)
    if not ok then break end
    for _ = 1, 3 do
      ok, err = pcall(G.CONTROLLER.update, G.CONTROLLER, 0.016)
      if not ok then break end
    end
    if not ok then break end
  end
  HLOG("fed_wheel", tostring(ok), tostring(err))
end

function FED.nav(n)
  local ok, err = true, nil
  local was = G.CONTROLLER.HID.controller
  G.CONTROLLER.HID.controller = true
  local seq = {}
  for _ = 1, 14 do seq[#seq + 1] = "D" end
  for _, d in ipairs({"R", "U", "U", "U", "U", "U", "U", "L", "D", "D", "D", "D", "D", "D", "D", "D"}) do seq[#seq + 1] = d end
  for _, d in ipairs(seq) do
    ok, err = pcall(G.CONTROLLER.navigate_focus, G.CONTROLLER, d)
    if not ok then break end
  end
  G.CONTROLLER.HID.controller = was
  HLOG("fed_nav", tostring(ok), tostring(err))
end
