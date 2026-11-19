package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok, extra)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "")) end
end

local files, dirs = {}, {forge = true, ["forge/art"] = true}
love = {filesystem = {
  getInfo = function(p) if files[p] then return {type = "file"} end if dirs[p] then return {type = "directory"} end return nil end,
  read = function(p) if files[p] then return files[p], #files[p] end return nil, "missing" end,
  write = function(p, d) files[p] = d return true end,
  createDirectory = function(p) dirs[p] = true return true end,
  remove = function(p) files[p] = nil return true end,
  getSaveDirectory = function() return "/save" end,
  getDirectoryItems = function() return {} end,
}}
package.loaded["functions/fast_fs"] = {write = function(p, d) files[p] = tostring(d) return true end}
mod_loc = function(s) return s end
localize = function(x) return type(x) == "string" and x or "?" end

G = {P_JOKER_RARITY_POOLS = {{}, {}, {}, {}},
  P_CARDS = {}, P_CENTERS = {c_base = {key = "c_base"}}, P_CENTER_POOLS = {},
  C = {SUITS = {}, SO_1 = {}, SO_2 = {}}, SETTINGS = {language = "en-us"}, GAME = {probabilities = {normal = 1}},
  localization = {misc = {suits_plural = {}, suits_singular = {}, poker_hands = {}, poker_hand_descriptions = {}, dictionary = {}}, descriptions = {}},
}
G.C.SET, G.C.SECONDARY_SET, G.C.UI = {}, {}, {TEXT_LIGHT = {1, 1, 1, 1}}
number_format = function(v) return tostring(v) end

local Cat = require("functions/forge/forge_catalog")
local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local D = require("functions/forge/forge_doc")
local Ra = require("functions/forge/forge_rarities")
local M = require("functions/forge/forge_mods")

check("kind: rarity is a Forge kind", Cat.BY_ID.rarity ~= nil)
local f = Cat.clean_fields("rarity", {colour = "GOLD", chance = 3.5})
check("fields: kept", f.colour == "GOLD" and f.chance == 3.5, f.chance)
local bad = Cat.clean_fields("rarity", {colour = "NOPE", chance = 400})
check("fields: bad colour falls back", bad.colour == "PURPLE")
check("fields: odds capped", bad.chance == 100, bad.chance)
check("fields: module odds capped", Ra.fields({fields = {chance = -2}}).chance == 0)
check("share: rarity needs format 16", Cat.need_v({kind = "rarity", fields = {colour = "GOLD", chance = 2}}) == 16)

local epic = {id = "epic", kind = "rarity", name = "Epic", fields = {colour = "PINK", chance = 4}}
local mythic = {id = "myth", kind = "rarity", name = "Mythic", fields = {colour = "GOLD", chance = 0}}
Store.put_item(epic)
Store.put_item(mythic)
local live_before = Store.live_items
Store.live_items = function() return Store.items() end
Ra.register()
check("register: two rarities", #Ra.list == 2, #Ra.list)
check("register: pool", G.P_JOKER_RARITY_POOLS.rarity_forge_epic ~= nil and G.P_JOKER_RARITY_POOLS.rarity_forge_myth ~= nil)
check("register: colour", G.C.RARITY and G.C.RARITY.rarity_forge_epic ~= nil)
check("register: badge name", G.localization.misc.dictionary.k_rarity_forge_epic == "Epic")
check("values: own rarities offered", (function() for _, v in ipairs(Cat.values("rarity")) do if v == "rarity_forge_epic" then return true end end return false end)())
check("values: base list stays plain", #Cat.values("rarity", true) == 4)
check("label: own name", Cat.value_label("rarity", "rarity_forge_epic") == "Epic")

check("joker: own rarity used", Ra.of_joker({own_rarity = "rarity_forge_epic"}) == "rarity_forge_epic")
check("joker: missing rarity falls back", Ra.of_joker({own_rarity = "rarity_forge_gone"}) == nil)
check("joker: junk ignored", Ra.of_joker({own_rarity = "rarity_forge_a b"}) == nil)
local j = Store.clean({id = "jx", name = "Big", rarity = 3, own_rarity = "rarity_forge_epic"})
check("store: own rarity kept", j.own_rarity == "rarity_forge_epic" and j.rarity == 3)
check("store: junk own rarity dropped", Store.clean({id = "jy", own_rarity = "Epic"}).own_rarity == nil)
check("doc: own rarity copied", D.new("joker", {own_rarity = "rarity_forge_epic"}).own_rarity == "rarity_forge_epic")
check("doc: junk rarity not copied", D.new("joker", {own_rarity = "x"}).own_rarity == nil)

check("pick: no live Jokers, no own rarity", Ra.pick(0) == nil)
G.P_JOKER_RARITY_POOLS.rarity_forge_epic[1] = {key = "j_forge_jx", forge_on = true}
check("pick: low roll picks Epic", Ra.pick(0) and Ra.pick(0).id == "epic")
check("pick: odds", Ra.pick(3.9 / 104) ~= nil and Ra.pick(4.01 / 104) == nil)
check("pick: zero odds never rolled", (function() G.P_JOKER_RARITY_POOLS.rarity_forge_myth[1] = {key = "j_forge_jz"} local r = Ra.pick(0) return r and r.id == "epic" end)())
G.P_JOKER_RARITY_POOLS.rarity_forge_epic[1].forge_on = false
check("pick: switched off Jokers do not count", Ra.pick(0) == nil)
G.P_JOKER_RARITY_POOLS.rarity_forge_epic[1].forge_on = true

local seen = {}
get_current_pool = function(_type, _rarity, _legendary, _append)
  seen = {type = _type, rarity = _rarity, append = _append, pool = G.P_JOKER_RARITY_POOLS[1]}
  return {"x"}, "k"
end
pseudorandom = function() return 0 end
G.GAME.round_resets = {ante = 1}
Ra.install_hooks()
get_current_pool("Joker", "rarity_forge_epic", nil, "sho")
check("pool: own rarity swaps the pool", seen.pool == G.P_JOKER_RARITY_POOLS.rarity_forge_epic and seen.rarity == 0, seen.rarity)
check("pool: restored after", G.P_JOKER_RARITY_POOLS[1] ~= G.P_JOKER_RARITY_POOLS.rarity_forge_epic)
check("pool: own seed", seen.append == "frepicsho", seen.append)
get_current_pool("Joker", nil, nil, "sho")
check("pool: roll lands on Epic", seen.pool == G.P_JOKER_RARITY_POOLS.rarity_forge_epic)
pseudorandom = function() return 0.5 end
get_current_pool("Joker", nil, nil, "sho")
check("pool: high roll stays vanilla", seen.pool ~= G.P_JOKER_RARITY_POOLS.rarity_forge_epic and seen.rarity == nil)
get_current_pool("Joker", nil, true, "sho")
check("pool: Legendary untouched", seen.rarity == nil and seen.pool ~= G.P_JOKER_RARITY_POOLS.rarity_forge_epic)
get_current_pool("Tarot", nil, nil, "sho")
check("pool: other sets untouched", seen.type == "Tarot")

local g = {id = "create_rarity", v = "rarity_forge_epic", n = 1}
R.CLEAN_GIVE.create_rarity(g)
check("rule: create an Epic Joker kept", g.v == "rarity_forge_epic")
local g2 = {id = "create_rarity", v = "Bogus"}
R.CLEAN_GIVE.create_rarity(g2)
check("rule: junk rarity cleaned", g2.v == "Common")
check("rule: own rarity needs format 16", R.need_v({{when = "hand_played", only = {}, give = {{id = "create_rarity", v = "rarity_forge_epic", n = 1}}}}) == 16)
local sp = {kind = "spectral", fields = {cost = 4, select = 0}, effects = {{id = "rare_joker", v = "rarity_forge_epic"}}}
check("spectral: own rarity needs format 16", Cat.need_v(sp) == 16)
local cl = Cat.clean_effects and Cat.clean_effects("spectral", sp.effects)
check("spectral: own rarity kept when cleaned", not cl or (cl[1] and cl[1].v == "rarity_forge_epic"), cl and cl[1] and cl[1].v)

check("mods: joker with own rarity needs 16", M.needs_v({j}, {}) == 16)
check("mods: plain joker stays old", M.needs_v({Store.clean({id = "jq", rarity = 2})}, {}) == 1)
local mod = M.parse and M.parse('{"format":"' .. tostring(M.FORMAT) .. '","v":16,"id":"abcd","name":"T","jokers":[{"id":"big","name":"Big","rarity":3,"own_rarity":"rarity_forge_epic"}],"creations":[{"id":"epic","kind":"rarity","name":"Epic","fields":{"colour":"PINK","chance":4}}]}')
check("mods: import maps the rarity to the imported one", mod and mod.jokers[1] and mod.jokers[1].own_rarity == "rarity_forge_" .. mod.creations[1].id, mod and mod.jokers[1] and mod.jokers[1].own_rarity)

SMODS = {Rarities = {}, Rarity = {obj_buffer = {}}, ObjectTypes = {Joker = {rarities = {{key = "Common", weight = 0.7}}, rarity_pools = {}}}}
Ra.register()
check("smods: rarity objects", SMODS.Rarities.rarity_forge_epic ~= nil and SMODS.Rarities.rarity_forge_epic.forge_rarity == "epic")
check("smods: Joker rarities list", #SMODS.ObjectTypes.Joker.rarities == 3 and SMODS.ObjectTypes.Joker.rarities[2].weight == 0.04, #SMODS.ObjectTypes.Joker.rarities)
check("smods: empty rarities skipped", SMODS.Rarities.rarity_forge_epic.disable_if_empty == true)
Ra.register()
check("smods: register twice keeps one each", #SMODS.ObjectTypes.Joker.rarities == 3 and #SMODS.Rarity.obj_buffer == 2)
Store.live_items = function() return {} end
Ra.register()
check("smods: removed rarity leaves", SMODS.Rarities.rarity_forge_epic == nil and #SMODS.ObjectTypes.Joker.rarities == 1)
check("register: removed rarities leave the list", #Ra.list == 0 and Ra.of_joker({own_rarity = "rarity_forge_epic"}) == nil)
SMODS = nil
Store.live_items = live_before

print(string.format("forge rarities: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
