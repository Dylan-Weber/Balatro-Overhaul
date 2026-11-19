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

G = {
  P_CARDS = {}, P_CENTERS = {c_base = {key = "c_base"}}, P_CENTER_POOLS = {},
  C = {SUITS = {}, SO_1 = {}, SO_2 = {}}, SETTINGS = {language = "en-us"}, GAME = {probabilities = {normal = 1}},
  localization = {misc = {suits_plural = {}, suits_singular = {}, poker_hands = {}, poker_hand_descriptions = {}, dictionary = {}}, descriptions = {}},
}
G.P_CENTERS.j_hanging_chad = {key = "j_hanging_chad", set = "Joker"}
G.P_CENTERS.j_joker = {key = "j_joker", set = "Joker"}
G.P_CENTERS.c_fool = {key = "c_fool", set = "Tarot"}
G.P_CENTERS.v_grabber = {key = "v_grabber", set = "Voucher"}
G.P_CENTERS.p_arcana_normal_1 = {key = "p_arcana_normal_1", set = "Booster"}
G.P_CENTERS.p_arcana_jumbo_1 = {key = "p_arcana_jumbo_1", set = "Booster"}
G.P_CENTERS.m_glass = {key = "m_glass", set = "Enhanced"}
G.P_CENTER_POOLS.Joker = {G.P_CENTERS.j_joker, G.P_CENTERS.j_hanging_chad}
G.P_CENTER_POOLS.Tarot = {G.P_CENTERS.c_fool}
G.P_CENTER_POOLS.Voucher = {G.P_CENTERS.v_grabber}
G.P_TAGS = {tag_double = {key = "tag_double"}}
G.P_BLINDS = {bl_wall = {key = "bl_wall", boss = {min = 1}, order = 2}, bl_small = {key = "bl_small"}}
G.CHALLENGES = {
  {name = "Omelette", id = "c_omelette_1", rules = {custom = {{id = "no_reward"}, {id = "no_extra_hand_money"}}, modifiers = {{id = "dollars", value = 0}}},
    jokers = {{id = "j_joker", eternal = true, edition = "negative", pinned = true}}, consumeables = {}, vouchers = {{id = "v_grabber"}},
    deck = {type = "Challenge Deck", cards = {{s = "H", r = "A"}, {s = "S", r = "K"}, {s = "D", r = "2"}}},
    restrictions = {banned_cards = {{id = "p_arcana_normal_1", ids = {"p_arcana_normal_1", "p_arcana_jumbo_1"}}, {id = "v_grabber"}, {id = "j_joker"}}, banned_tags = {{id = "tag_double"}}, banned_other = {{id = "bl_wall", type = "blind"}}}},
}
G.CHALLENGES[2] = {name = "Mod", id = "c_mod_x", rules = {custom = {{id = "mod_only_rule"}}, modifiers = {}}, jokers = {}, deck = {type = "Challenge Deck"}, restrictions = {}}
G.localization.misc.challenge_names = {c_omelette_1 = "Omelette"}

local Cat = require("functions/forge/forge_catalog")
local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local D = require("functions/forge/forge_doc")
local Ch = require("functions/forge/forge_challenges")
local Mods = require("functions/forge/forge_mods")

check("kind: challenge is a Forge kind", Cat.BY_ID.challenge ~= nil and Cat.BY_ID.challenge.effects == "challenge")
check("kind: run rules host", R.host_of("challenge") == "run")
check("effects: run rules merged", Cat.effect("challenge", "blind_size") ~= nil and Cat.effect("challenge", "make_card") ~= nil)
check("effects: Simple has the Glass Cannon blocks", Cat.effect("challenge", "ch_enhance").simple and Cat.effect("challenge", "ch_joker").simple and Cat.effect("challenge", "ch_no_shop").simple)

local fx = Cat.clean_effects("challenge", {{id = "ch_enhance", v = "m_glass"}, {id = "ch_joker", v = "j_hanging_chad"}, {id = "ch_no_shop", v = "Tarot"}, {id = "ch_dollars", n = 9}, {id = "ch_no_rank", v = "Ace"}, {id = "nope"}})
check("clean: keeps known effects", #fx == 5, #fx)
check("clean: keeps values", fx[1].v == "m_glass" and fx[2].v == "j_hanging_chad" and fx[3].v == "Tarot" and fx[4].n == 9 and fx[5].v == "Ace")
local bad = Cat.clean_effects("challenge", {{id = "ch_joker", v = "j_nope"}, {id = "ch_ban_tag", v = "nope"}})
check("clean: bad values fall back", bad[1].v == "j_joker" and bad[2].v == "tag_double", tostring(bad[1].v) .. " " .. tostring(bad[2].v))
check("clean: own Joker allowed", Cat.clean_effects("challenge", {{id = "ch_joker", v = "j_forge_abc"}})[1].v == "j_forge_abc")

Store.list, Store.items_list = {}, {}
local glass = {id = "glassc", kind = "challenge", name = "Glass Cannon", fields = {}, effects = {
  {id = "ch_enhance", v = "m_glass"}, {id = "ch_joker", v = "j_hanging_chad"}, {id = "ch_no_shop", v = "Tarot"}}}
Store.put_item(glass)
Store.put_item({id = "hard", kind = "challenge", name = "Hard", fields = {}, effects = {
  {id = "ch_dollars", n = 0}, {id = "ch_dollars", n = 7}, {id = "ch_hands", n = 2}, {id = "ch_no_interest"}, {id = "ch_flipped", n = 3}, {id = "ch_no_reward_b", v = "Small"},
  {id = "ch_eternal", v = "j_joker"}, {id = "ch_card", v = "c_fool"}, {id = "ch_voucher", v = "v_grabber"}, {id = "ch_no_faces"}, {id = "ch_no_suit", v = "Hearts"},
  {id = "ch_ban_card", v = "j_joker"}, {id = "ch_ban_card", v = "j_joker"}, {id = "ch_ban_pack", v = "Arcana"}, {id = "ch_ban_tag", v = "tag_double"}, {id = "ch_ban_blind", v = "bl_wall"},
  {id = "ch_no_shop", v = "Joker"}, {id = "blind_size", n = 0.5, when = "ante_up"}, {id = "ch_joker", v = "j_gone"}}})
Store.put_item({id = "omel", kind = "challenge", name = "Omelette 2", fields = {}, effects = {{id = "ch_deck_of", v = "c_omelette_1"}, {id = "ch_no_rank", v = "King"}, {id = "ch_seal", v = "Red"}}})
local live_before = Store.live_items
Store.live_items = function() return Store.items() end

local ch = Ch.build(glass)
check("build: id and name", ch.id == "chl_forge_glassc" and ch.name == "Glass Cannon" and ch.forge_ch == "glassc")
check("build: Glass deck", ch.deck.type == "Challenge Deck" and ch.deck.enhancement == "m_glass")
check("build: starts with Hanging Chad", #ch.jokers == 1 and ch.jokers[1].id == "j_hanging_chad" and not ch.jokers[1].eternal)
check("build: no Tarots in the shop", ch.forge_rates and ch.forge_rates.tarot_rate == 0)
check("build: lines for the rules screen", #ch.forge_lines == 2 and #ch.rules.custom == 2 and ch.rules.custom[1].id == "forge_glassc_1", #ch.forge_lines)
check("build: unlocked flag for Steamodded", ch.unlocked == true)

local h = Ch.build(Store.get_item("hard"))
local mods = {}
for _, m in ipairs(h.rules.modifiers) do mods[m.id] = m.value end
check("build: modifiers absolute, last wins", mods.dollars == 7 and mods.hands == 2 and #h.rules.modifiers == 2)
local cust = {}
for _, c in ipairs(h.rules.custom) do cust[c.id] = c.value or true end
check("build: native custom rules", cust.no_interest == true and cust.flipped_cards == 3 and cust.no_reward_specific == "Small" and cust.no_shop_jokers == true)
check("build: eternal Joker, consumable, voucher", h.jokers[1].eternal == true and #h.jokers == 2 and h.consumeables[1].id == "c_fool" and h.vouchers[1].id == "v_grabber", tostring(#h.jokers) .. tostring(h.jokers[1] and h.jokers[1].id) .. tostring(h.consumeables[1]) .. tostring(h.vouchers[1]))
check("build: no faces, no Hearts", h.deck.no_ranks.J and h.deck.no_ranks.Q and h.deck.no_ranks.K and h.deck.no_suits.H)
local r = h.restrictions
check("build: bans deduped", #r.banned_cards == 2 and r.banned_cards[1].id == "j_joker")
check("build: pack type ban lists every size", r.banned_cards[2].ids and #r.banned_cards[2].ids == 2)
check("build: tag and blind bans", r.banned_tags[1].id == "tag_double" and r.banned_other[1].id == "bl_wall" and r.banned_other[1].type == "blind")
local run_line = false
for _, l in ipairs(h.forge_lines) do if l:find("0.5") then run_line = true end end
check("build: run rule gets a line", run_line)

local o = Ch.build(Store.get_item("omel"))
check("build: deck of a game challenge, filtered", o.deck.cards and #o.deck.cards == 2 and o.deck.cards[1].g == "Red")
check("build: game deck not changed", #G.CHALLENGES[1].deck.cards == 3 and G.CHALLENGES[1].deck.cards[1].g == nil)

Ch.register()
check("register: added after the game ones", #G.CHALLENGES == 5 and G.CHALLENGES[1].id == "c_omelette_1" and G.CHALLENGES[3].forge_ch)
check("register: names", G.localization.misc.challenge_names.chl_forge_glassc == "Glass Cannon")
Ch.register()
check("register: no duplicates", #G.CHALLENGES == 5)
check("find", Ch.find("chl_forge_hard") ~= nil and Ch.item("chl_forge_hard") ~= nil and Ch.item("c_omelette_1") == nil)
Store.live_items = function() return {Store.get_item("glassc")} end
Ch.register()
check("register: removed ones leave", #G.CHALLENGES == 3)
Store.live_items = function() return Store.items() end

local t = Ch.templates()
check("templates: game challenges only, exact ones only", #t == 1 and t[1].key == "c_omelette_1", #t)
local ids = {}
for _, e in ipairs(t[1].effects) do ids[e.id] = (ids[e.id] or 0) + 1 end
check("templates: rebuilt from the game challenge", ids.ch_no_reward == 1 and ids.ch_no_extra == 1 and ids.ch_dollars == 1 and ids.ch_eternal == 1 and ids.ch_voucher == 1 and ids.ch_deck_of == 1)
check("templates: bans rebuilt", ids.ch_ban_pack == 1 and ids.ch_ban_voucher == 1 and ids.ch_ban_card == 1 and ids.ch_ban_tag == 1 and ids.ch_ban_blind == 1)
local d = D.from_template("challenge", t[1])
check("template: draft keeps every effect", #d.effects == #t[1].effects, #d.effects)
check("template: draft name", d.name == "Omelette")
local same = Ch.build({id = "x", kind = "challenge", name = "x", effects = d.effects})
check("template: rebuilt challenge matches", #same.jokers == 1 and same.jokers[1].eternal and same.jokers[1].edition == "negative" and same.jokers[1].pinned and #same.vouchers == 1 and #same.deck.cards == 3
  and #same.restrictions.banned_cards == 3 and #same.restrictions.banned_tags == 1 and #same.restrictions.banned_other == 1 and #same.rules.modifiers == 1)
local cc = {}
for _, c in ipairs(same.rules.custom) do cc[c.id] = true end
check("template: rules match", cc.no_reward and cc.no_extra_hand_money)

check("share: a challenge needs 16", Cat.need_v(glass) == 16 and Mods.needs_v({}, {glass}) == 16)
local renamed = {id = "x", kind = "challenge", effects = {{id = "ch_joker", v = "j_forge_old"}}}
R.map_refs(renamed, function(id) if id == "old" then return "new" end end)
check("share: own Joker id follows renames", renamed.effects[1].v == "j_forge_new")

G.GAME = {}
local applied = false
package.loaded["functions/forge/forge_run"] = {apply_now = function(c, src) applied = c.id == "glassc" and src.key == "chl_forge_glassc" end}
G.E_MANAGER = {add_event = function(_, ev) ev.func() end}
Event = function(t) return t end
Ch.on_start({challenge = Ch.find("chl_forge_glassc")})
check("start: no Tarots in the shop", G.GAME.tarot_rate == 0)
check("start: run rules applied", applied)
G.GAME.tarot_rate = 4
Ch.on_start({challenge = Ch.find("chl_forge_glassc"), savetext = {}})
check("start: loading a save does nothing", G.GAME.tarot_rate == 4)
G.PROFILES, G.SETTINGS.profile = {{challenges_unlocked = 1, challenge_progress = {completed = {}}}}, 1
check("unlocked: Forge challenges always", Ch.unlocked(Ch.find("chl_forge_glassc"), 99) == true)
check("unlocked: game challenges by count", Ch.unlocked(G.CHALLENGES[1], 1) == true and not Ch.unlocked({id = "c_x"}, 5))
Store.live_items = live_before

print(string.format("forge challenges: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
