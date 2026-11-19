SS = SS or {}
SS.results = {}

local Store = JokerForge.store
local S = require("functions/forge/forge_suits")

local function check(tag, ok, ...)
  SS.results[#SS.results + 1] = ok and true or false
  HLOG("ss_check", tag, ok and "OK" or "BAD", ...)
end

local function B() return ForgeBuilder end
local function reopen() JokerForge.ui.reopen("builder") end

function SS.suit()
  B().new_draft({kind = "suit", id = "ssstars", name = "Stars", fields = {colour = "PURPLE"}})
  B().state.sec = "basics"
  reopen()
end

function SS.save() G.FUNCS.forge_b_save() end

function SS.suit2()
  B().new_draft({kind = "suit", id = "ssmoons", name = "Moons", fields = {colour = "BLUE"}})
  B().state.sec = "basics"
  reopen()
end

function SS.yours()
  local SK = require("functions/forge/forge_suitskins")
  check("phone groups own suits", SK.grouped())
  local e = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("tab_but_" .. mod_loc("Your suits"))
  check("Your suits tab", e ~= nil)
  check("no separate Stars tab on phone", G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("tab_but_" .. localize(SS.key, "suits_plural")) == nil)
  if e then e:click() end
end

function SS.yours_next()
  require("functions/forge/forge_suitskins").pick_suit({to_key = 2})
end

function SS.yours_check(i)
  local SK = require("functions/forge/forge_suitskins")
  check("Your suits shows suit " .. i, SK.your_i == i and G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("tab_contents") ~= nil)
end

function SS.collab()
  local s = S.of_id("ssstars")
  SS.key = s and s.key
  SS.default = SS.key and G.COLLABS.options[SS.key] and G.COLLABS.options[SS.key][1]
  check("Stars suit live", s ~= nil, SS.key)
  Store.ensure_dirs()
  local P = require("functions/forge/forge_pixel")
  local doc = ForgePixelUI.sprite_data("Joker", {x = 0, y = 0})
  local data = love.image.newImageData(P.W, P.H)
  P.write_image_data(doc, data)
  love.filesystem.write("forge/art/sscourt_K.png", data:encode("png"):getString())
  Store.put_item({id = "sscourt", kind = "collab", name = "Star Court", enabled = true, fields = {suit = "suit_forge_ssstars"}, faces = {K = "forge/art/sscourt_K.png"}})
  ForgeKinds.register_all()
  local list = G.COLLABS.options[SS.key] or {}
  local has = false
  for _, v in ipairs(list) do if v == "collab_forge_sscourt" then has = true end end
  check("Star Court in the Stars skin list", has and #list == 2, #list)
end

function SS.open()
  if G.OVERLAY_MENU and G.FUNCS.exit_overlay_menu then G.FUNCS.exit_overlay_menu() end
  G.FUNCS.customize_deck()
end

function SS.tab()
  local e = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("tab_but_" .. localize(SS.key, "suits_plural"))
  check("Stars tab in Customize Deck", e ~= nil)
  if e then e:click() end
end

local function front_atlas(card)
  local f = card and card.children and card.children.front
  return f and f.atlas and f.atlas.name
end

function SS.pick(i)
  G.FUNCS.change_collab({cycle_config = {curr_suit = SS.key}, to_key = i})
end

local function find(node, f)
  if type(node) ~= "table" then return nil end
  if f(node) then return node end
  for _, ch in pairs(node.children or {}) do
    local hit = find(ch, f)
    if hit then return hit end
  end
  local obj = node.config and node.config.object
  if type(obj) == "table" and obj.UIRoot then return find(obj.UIRoot, f) end
end

function SS.arrow(side)
  local e = G.OVERLAY_MENU and find(G.OVERLAY_MENU.UIRoot, function(n)
    local c = n.config
    return c and c.button == "option_cycle" and c.ref_value == side and type(c.ref_table) == "table" and c.ref_table.curr_suit == SS.key
  end)
  check("skin arrow found", e ~= nil)
  if e then e:click() end
end

function SS.next_skin() SS.arrow("r") end
function SS.prev_skin() SS.arrow("l") end

function SS.picked(want)
  check("skin chosen: " .. tostring(want), G.SETTINGS.CUSTOM_DECK.Collabs[SS.key] == want, G.SETTINGS.CUSTOM_DECK.Collabs[SS.key])
end

function SS.close() if G.FUNCS.exit_overlay_menu then G.FUNCS.exit_overlay_menu() end end

function SS.start() G.FUNCS.start_run(nil, {stake = 1, seed = "SUITSKIN"}) end

function SS.setup()
  local s = S.of_id("ssstars")
  for i, r in ipairs({"K", "Q", "J"}) do
    local c = G.hand.cards[i]
    if c then c:set_base(G.P_CARDS[S.card_key(s, r)]) end
  end
  SS.k = G.hand.cards[1]
end

function SS.skin_check(court)
  local a = front_atlas(SS.k)
  if court then
    check("Stars King uses Star Court", a == "collab_forge_sscourt_1" or a == "collab_forge_sscourt_2", a)
  else
    check("Stars King back on its own art", a == S.atlas_key(S.of_id("ssstars")), a)
  end
end

function SS.summary()
  local bad = 0
  for _, ok in ipairs(SS.results) do if not ok then bad = bad + 1 end end
  HLOG("ss_summary", #SS.results, "checks", bad, "bad")
end
