package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name) end
end

local files, dirs = {}, {}
love = {filesystem = {
  getInfo = function(p) if files[p] then return {type = "file", size = #files[p], modtime = 1} end if dirs[p] then return {type = "directory"} end return nil end,
  read = function(p) if files[p] then return files[p], #files[p] end return nil, "missing" end,
  write = function(p, d) files[p] = d return true end,
  createDirectory = function(p) dirs[p] = true return true end,
  remove = function(p) files[p] = nil return true end,
  getSaveDirectory = function() return "/save" end,
  getDirectoryItems = function() return {} end,
}}
package.loaded["functions/fast_fs"] = {write = function(p, d) files[p] = tostring(d) return true end}
mod_loc = function(s) return s end

local drawn = {}
G = {
  P_CENTERS = {e_foil = {key = "e_foil", set = "Edition", shader = "foil"}, e_negative = {key = "e_negative", set = "Edition", shader = "negative"},
    e_mymod_glitch = {key = "e_mymod_glitch", set = "Edition", shader = "mymod_glitch"}, e_other_gone = {key = "e_other_gone", set = "Edition", shader = "other_gone"}},
  P_CENTER_POOLS = {Edition = {}},
  P_SEALS = {},
  SHADERS = {foil = {}, holo = {}, polychrome = {}, negative = {}, negative_shine = {}, mymod_glitch = {}},
  shared_seals = {},
}
for _, k in ipairs({"e_foil", "e_negative", "e_mymod_glitch", "e_other_gone"}) do G.P_CENTER_POOLS.Edition[#G.P_CENTER_POOLS.Edition + 1] = G.P_CENTERS[k] end
rawset(_G, "localize", function(t) return ({e_foil = "Foil", e_holo = "Holographic", e_polychrome = "Polychrome", e_negative = "Negative"})[t.key] or "ERROR" end)

local json = require("bot.sim.json")
local Store = require("functions/forge/forge_store")
local M = require("functions/forge/forge_mods")
local FL = require("functions/forge/forge_forcedlook")
local D = require("functions/forge/forge_doc")

check("module v16", FL.V == 16 and M.V >= 16)
check("clean vanilla", FL.clean("e_polychrome") == "e_polychrome")
check("clean own", FL.clean("forge_abc12") == "forge_abc12")
check("clean mod", FL.clean("e_mymod_glitch") == "e_mymod_glitch")
check("clean none", FL.clean("none") == nil and FL.clean("") == nil and FL.clean(5) == nil and FL.clean("e_base") == nil)
check("clean junk", FL.clean("polychrome; os.exit()") == nil and FL.clean("e_forge_x") == nil)

local opts = FL.options()
local has = {}
for _, v in ipairs(opts) do has[v] = true end
check("options vanilla", opts[1] == "none" and has.e_foil and has.e_holo and has.e_polychrome and has.e_negative)
check("options loaded mod", has.e_mymod_glitch)
check("options missing shader skipped", not has.e_other_gone)
check("name", FL.name("e_polychrome") == "Polychrome" and FL.name(nil) == "None")

check("resolve vanilla", FL.resolve("e_polychrome").vanilla == "e_polychrome")
check("resolve mod", FL.resolve("e_mymod_glitch").mod == G.P_CENTERS.e_mymod_glitch)
check("resolve unknown mod falls back", FL.resolve("e_notloaded_shiny") == nil)
check("resolve lost own falls back", FL.resolve("forge_zzz999") == nil)

local function sprite(tag)
  return {role = {}, draw_shader = function(_, sh) drawn[#drawn + 1] = tag .. ":" .. sh end}
end
local function card(look, edition)
  return {config = {center = {key = "c_forge_t1", set = "Tarot", forge_look = look}}, children = {center = sprite("center")}, ARGS = {send_to_shader = {0, 0}},
    edition = edition, ability = {set = "Tarot", consumeable = {}}, sell_cost = 1, cost = 3}
end

local function snap(c)
  return json.encode({edition = c.edition, ability = c.ability, sell_cost = c.sell_cost, cost = c.cost})
end

drawn = {}
local poly = card("e_polychrome")
FL.draw(poly)
check("poly drawn", drawn[1] == "center:polychrome" and #drawn == 1)
check("poly no edition", poly.edition == nil)

drawn = {}
local neg = card("e_polychrome", {negative = true, type = "negative"})
local before = snap(neg)
FL.draw(neg)
check("poly under real negative drawn", drawn[1] == "center:polychrome")
check("real negative untouched", snap(neg) == before and neg.edition.negative == true and neg.edition.polychrome == nil and neg.edition.x_mult == nil)

drawn = {}
FL.draw(card("e_negative"))
check("negative look", drawn[1] == "center:negative" and drawn[2] == "center:negative_shine")

drawn = {}
FL.draw(card("e_notloaded_shiny"))
check("unknown mod draws nothing", #drawn == 0)

drawn = {}
local pv = card(nil)
FL.preview(pv, "e_foil")
FL.draw(pv)
check("preview override", drawn[1] == "center:foil")
FL.preview(pv, "none")
drawn = {}
FL.draw(pv)
check("preview none", #drawn == 0)

G.P_SEALS.Forge_s1 = {forge_look = "e_foil"}
G.shared_seals.Forge_s1 = sprite("seal")
drawn = {}
local sc = card(nil)
sc.seal = "Forge_s1"
FL.draw_seal(sc)
check("seal look on seal sprite", drawn[1] == "seal:foil")

files["forge/art/aaa111.png"] = (function()
  local function u32(n) return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256) end
  return "\137PNG\r\n\26\n" .. u32(13) .. "IHDR" .. u32(71) .. u32(95) .. "\8\6\0\0\0A" .. string.rep("\0\255\1", 30)
end)()
Store.list, Store.items_list = nil, nil
Store.put({id = "aaa111", name = "Shiny", rarity = 1, cost = 4, art = {file = "forge/art/aaa111.png"}, rules = {}, look = "e_holo"})
Store.put({id = "bbb222", name = "Plain", rarity = 1, cost = 4, art = {atlas = "Joker", x = 0, y = 0}, rules = {}, look = "nonsense look"})
Store.put_item({id = "ttt111", kind = "tarot", name = "Prism Tarot", fields = {}, effects = {}, look = "e_polychrome"})
Store.put_item({id = "eee111", kind = "edition", name = "My Shine", fields = {shader = "holo"}, effects = {}})
Store.put_item({id = "vvv111", kind = "voucher", name = "Own Look", fields = {}, effects = {}, look = "forge_eee111"})
Store.put_item({id = "mmm111", kind = "spectral", name = "Mod Look", fields = {}, effects = {}, look = "e_mymod_glitch"})
Store.put_item({id = "ddd111", kind = "edition", name = "No Look Edition", fields = {shader = "foil"}, effects = {}, look = "e_foil"})
Store.put_item({id = "dk1111", kind = "deck", name = "Shiny Deck", fields = {}, effects = {}, look = "e_foil"})
Store.put_item({id = "tg1111", kind = "tag", name = "Shiny Tag", fields = {}, effects = {}, look = "e_holo"})
Store.put_item({id = "bl1111", kind = "blind", name = "Shiny Blind", fields = {}, effects = {}, look = "e_polychrome"})
Store.put_item({id = "sk1111", kind = "stake", name = "Shiny Stake", fields = {}, effects = {}, look = "e_negative"})
Store.put_item({id = "co1111", kind = "collab", name = "Shiny Skin", fields = {suit = "Hearts"}, effects = {}, look = "e_mymod_glitch"})

check("joker saved", Store.get("aaa111").look == "e_holo")
check("bad look dropped", Store.get("bbb222").look == nil)
check("item saved", Store.get_item("ttt111").look == "e_polychrome")
check("own edition look saved", Store.get_item("vvv111").look == "forge_eee111")
check("edition kind gets no look", Store.get_item("ddd111").look == nil)
check("deck look saved", Store.get_item("dk1111").look == "e_foil")
check("tag look saved", Store.get_item("tg1111").look == "e_holo")
check("blind look saved", Store.get_item("bl1111").look == "e_polychrome")
check("stake look saved", Store.get_item("sk1111").look == "e_negative")
check("skin look saved", Store.get_item("co1111").look == "e_mymod_glitch")
for _, k in ipairs({"deck", "collab", "tag", "blind", "stake"}) do check("kind ok " .. k, FL.kind_ok(k)) end
for _, k in ipairs({"back", "skin", "blind", "tag", "stake"}) do check("pixel kind " .. k, FL.PX_KINDS[k] == true) end
check("edition kind not offered", not FL.kind_ok("edition") and not FL.PX_KINDS.edition)
local raw_store = files[Store.ITEMS_FILE]
check("look on disk", type(raw_store) == "string" and raw_store:find("e_polychrome", 1, true) ~= nil)
Store.items_list = nil
check("reload keeps look", Store.get_item("ttt111").look == "e_polychrome")

local old = Store.clean({id = "old1", name = "Old", rules = {}})
check("old creation loads with no look", old and old.look == nil)
local old_item = Store.clean_item({id = "old2", kind = "tarot", name = "Old Tarot", fields = {}, effects = {}})
check("old item loads with no look", old_item and old_item.look == nil)

local d = D.new("tarot", Store.copy(Store.get_item("ttt111")))
check("draft keeps look", d.look == "e_polychrome")

local raw, out = M.pack({name = "Looks"}, {"aaa111", "ttt111", "vvv111", "mmm111"})
check("pack ok", type(raw) == "string" and out.v <= M.V)
check("pack pulls own edition", (function() for _, c in ipairs(out.creations) do if c.id == "eee111" then return true end end return false end)())
local mod = M.parse(raw)
local by = {}
for _, c in ipairs(mod and mod.jokers or {}) do by[c.src] = c end
for _, c in ipairs(mod and mod.creations or {}) do by[c.src] = c end
check("import joker look", by.aaa111 and by.aaa111.look == "e_holo")
check("import item look", by.ttt111 and by.ttt111.look == "e_polychrome")
check("import own look remapped", by.vvv111 and by.vvv111.look == "forge_" .. by.eee111.id)
check("import mod look kept", by.mmm111 and by.mmm111.look == "e_mymod_glitch")

G.TIMERS = {REAL = 3}
G.GAME = {selected_back = {effect = {center = {key = "b_forge_dk1111", forge_look = "e_foil"}}}, viewed_back = {effect = {center = {key = "b_red"}}}}
local deck = {config = {type = "deck"}, cards = {}}
local function back_card(area, params)
  local c = {children = {center = sprite("center"), back = sprite("back")}, ARGS = {send_to_shader = {0, 0}}, area = area, params = params or {}, config = {center = {key = "c_base"}}}
  if area then area.cards[#area.cards + 1] = c end
  return c
end
local top, under = back_card(deck), back_card(deck)
drawn = {}
FL.draw_back(top)
check("deck back look on top card", drawn[1] == "back:foil" and #drawn == 1)
drawn = {}
FL.draw_back(under)
check("deck back look skipped under top", #drawn == 0)
drawn = {}
FL.draw_back(back_card(nil))
check("face down card back look", drawn[1] == "back:foil")
drawn = {}
FL.draw_back(back_card(nil, {viewed_back = true}))
check("viewed back without look", #drawn == 0)
drawn = {}
local pc = back_card(nil)
local before_back = json.encode({edition = pc.edition, ability = pc.ability})
FL.draw_back(pc)
check("back look changes nothing", json.encode({edition = pc.edition, ability = pc.ability}) == before_back)

G.SETTINGS = {CUSTOM_DECK = {Collabs = {Hearts = "collab_forge_co1111", Spades = "collab_AU_1"}}}
FL.SKIN.collab_forge_co1111 = FL.clean(Store.get_item("co1111").look)
local function face(value, suit)
  local c = card(nil)
  c.config.center = {key = "c_base", set = "Default"}
  c.base = {value = value, suit = suit}
  c.children.front = sprite("front")
  c.ability = {set = "Default", effect = ""}
  return c
end
check("skin look on hearts king", FL.of(face("King", "Hearts")) == "e_mymod_glitch")
check("no skin look on hearts ten", FL.of(face("10", "Hearts")) == nil)
check("no skin look on other suit", FL.of(face("King", "Spades")) == nil)
drawn = {}
FL.draw(face("Queen", "Hearts"))
check("skin look drawn on face", drawn[1] == "center:mymod_glitch" and drawn[2] == "front:mymod_glitch")

local spr_drawn = 0
local tagspr = {role = {}, states = {visible = true}, ID = 4, draw = function() spr_drawn = spr_drawn + 1 end}
tagspr.draw_shader = function(_, sh, _, send) drawn[#drawn + 1] = "spr:" .. sh .. ":" .. tostring(send and send[2]) end
FL.tag(tagspr, "e_holo")
drawn = {}
tagspr:draw()
check("tagged sprite keeps base draw", spr_drawn == 1)
check("tagged sprite gets look", drawn[1] == "spr:holo:3")
FL.tag(tagspr, "none")
drawn = {}
tagspr:draw()
check("untagged sprite no look", #drawn == 0 and spr_drawn == 2)
local negspr = FL.tag({role = {}, states = {visible = true}, draw = function() end, draw_shader = function(_, sh) drawn[#drawn + 1] = sh end}, "e_negative")
drawn = {}
negspr:draw()
check("negative sprite look", drawn[1] == "negative" and drawn[2] == "negative_shine")

G.GAME.forge_stake, G.GAME.stake = "sk1111", 2
check("stake look", FL.stake_look() == "e_negative")
G.GAME.forge_stake = nil
check("no forge stake no look", FL.stake_look() == nil)

G.P_BLINDS = {bl_forge_bl1111 = {key = "bl_forge_bl1111", forge_look = "e_polychrome"}}
G.GAME.round_resets = {blind_choices = {Small = "bl_small", Boss = "bl_forge_bl1111"}}
check("boss choice look", FL.blind_choice_look("Boss") == "e_polychrome" and FL.blind_choice_look("Small") == nil)
G.ANIMATION_ATLAS = {blind_chips = {}}
local chip = {atlas = G.ANIMATION_ATLAS.blind_chips, role = {}, states = {visible = true}, draw = function() end, draw_shader = function() end}
local other = {atlas = {}, role = {}, draw = function() end}
local tree = {nodes = {{config = {}, nodes = {{config = {object = other}}, {config = {object = chip}}}}}}
FL.tag_tree(tree, function(o) if o.atlas == G.ANIMATION_ATLAS.blind_chips then FL.tag(o, "e_polychrome") end end)
check("tree tags blind chip only", chip.forge_look == "e_polychrome" and other.forge_look == nil)

G.P_CENTERS.e_mymod_glitch = nil
check("skin mod look missing draws nothing", (function() drawn = {}; FL.draw(face("King", "Hearts")); return #drawn == 0 end)())
check("mod missing on receiver falls back", FL.resolve(by.mmm111.look) == nil)
drawn = {}
FL.draw(card(by.mmm111.look))
check("mod missing draws nothing", #drawn == 0)

local t = json.decode(raw)
t.creations[1].look = {evil = true}
local m2 = M.parse(json.encode(t))
check("bad look in share ignored", m2 and (function() for _, c in ipairs(m2.creations) do if type(c.look) == "table" then return false end end return true end)())

print(string.format("forge forced look: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
