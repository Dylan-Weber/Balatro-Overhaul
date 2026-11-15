package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name) end
end

mod_loc = function(s) return s end
localize = function(a) if type(a) == "table" then return a.key end return a end
copy_table = function(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy_table(v) end
  return o
end
get_starting_params = function()
  return {dollars = 4, hand_size = 8, discards = 3, hands = 4, reroll_cost = 5, joker_slots = 5, ante_scaling = 1, consumable_slots = 2, no_faces = false, erratic_suits_and_ranks = false}
end
delay = function() end
Event = function(t) return t end
play_sound = function() end
update_hand_text = function() end
ease_colour = function() end
attention_text = function() end
local tags = {}
add_tag = function(t) tags[#tags + 1] = t end
Tag = function(k) return {key = k} end
local created = {}
create_card = function(set, area, _, _, _, _, key) created[#created + 1] = key return {add_to_deck = function() end} end
local applied_vouchers = {}
Card = {apply_to_run = function(_, center) applied_vouchers[#applied_vouchers + 1] = center and center.key end}
local marked
Progress = {LABELS = {}, mark = function(r) marked = r end}

local centers = {}
do
  local f = io.open("assets/game.lua")
  local src = f:read("*a")
  f:close()
  local env = {self = {FTP_LOCKED = false}}
  for line in src:gmatch("[^\n]+") do
    local key, body = line:match("^%s*(b_%w+)=%s*({.-}),%s*$")
    local fn = key and load("return " .. body, key, "t", env)
    if fn then
      local ok, t = pcall(fn)
      if ok and type(t) == "table" then t.key = key; t.set = "Back"; centers[key] = t end
    end
  end
end
check("game.lua gives the 15 vanilla decks", (function() for _, k in ipairs({"b_red", "b_plasma", "b_erratic", "b_zodiac"}) do if not centers[k] then return false end end return true end)())
for _, v in ipairs({"v_crystal_ball", "v_telescope", "v_tarot_merchant", "v_planet_merchant", "v_overstock_norm"}) do centers[v] = {key = v, set = "Voucher"} end
for _, c in ipairs({"c_fool", "c_hex"}) do centers[c] = {key = c, set = "Tarot"} end
centers.b_challenge = {key = "b_challenge", name = "Challenge Deck", set = "Back", config = {}, omit = true}
centers.b_mp_custom = {key = "b_mp_custom", name = "Lobby Deck", set = "Back", config = {hands = 2, odd_thing = 3}, mp_deck = true, order = 40}

local stakes = {}
for i, k in ipairs({"stake_white", "stake_red", "stake_green", "stake_black", "stake_blue", "stake_purple", "stake_orange", "stake_gold", "stake_chaos", "stake_apocalypse", "stake_oblivion", "stake_transcendent"}) do
  stakes[i] = {key = k, order = i, stake_level = i, set = "Stake", name = k}
end

local back_pool = {}
for _, c in pairs(centers) do if c.set == "Back" then back_pool[#back_pool + 1] = c end end

local queue = {}
G = {
  P_CENTERS = centers,
  P_CENTER_POOLS = {Back = back_pool, Stake = stakes},
  P_STAKES = {},
  E_MANAGER = {add_event = function(_, e) queue[#queue + 1] = e end},
  FUNCS = {},
  C = {BLUE = {0, 0, 1, 1}, RED = {1, 0, 0, 1}},
  playing_cards = {},
  consumeables = {emplace = function() end},
}
for _, s in ipairs(stakes) do G.P_STAKES[s.key] = s end
local function flush() while #queue > 0 do local e = table.remove(queue, 1) e.func() end end

require("engine/object")
require("back")
local R = require("functions/run_mods/engine")
local Cat = R.Cat

local function ids(key)
  local out = {}
  for _, p in ipairs(Cat.deck_pieces(centers[key])) do out[#out + 1] = p.id end
  return table.concat(out, ",")
end

check("red: one discards piece", ids("b_red") == "b_red:discards")
check("blue: one hands piece", ids("b_blue") == "b_blue:hands")
check("yellow: money", ids("b_yellow") == "b_yellow:dollars")
check("green: three pieces", ids("b_green") == "b_green:extra_hand_bonus,b_green:extra_discard_bonus,b_green:no_interest")
check("black: hands and joker slot", ids("b_black") == "b_black:hands,b_black:joker_slot")
check("magic: voucher and consumables", ids("b_magic") == "b_magic:voucher_v_crystal_ball,b_magic:consumables")
check("nebula: slot and voucher", ids("b_nebula") == "b_nebula:consumable_slot,b_nebula:voucher_v_telescope")
check("ghost: spectral rate and hex", ids("b_ghost") == "b_ghost:spectral_rate,b_ghost:consumables")
check("abandoned: no faces", ids("b_abandoned") == "b_abandoned:remove_faces")
check("checkered: suits", ids("b_checkered") == "b_checkered:suits")
check("zodiac: three vouchers", ids("b_zodiac") == "b_zodiac:voucher_v_tarot_merchant,b_zodiac:voucher_v_planet_merchant,b_zodiac:voucher_v_overstock_norm")
check("painted: hand size and joker slot", ids("b_painted") == "b_painted:hand_size,b_painted:joker_slot")
check("anaglyph: double tag", ids("b_anaglyph") == "b_anaglyph:double_tag")
check("plasma: scaling and balance", ids("b_plasma") == "b_plasma:ante_scaling,b_plasma:balance")
check("erratic: random cards", ids("b_erratic") == "b_erratic:randomize_rank_suit")
check("custom deck gets its own effect piece", ids("b_mp_custom") == "b_mp_custom:hands,b_mp_custom:own")

local list = Cat.deck_list()
check("deck list: vanilla first in order", list[1].key == "b_red" and list[15].key == "b_erratic")
check("deck list: challenge deck left out, custom deck after", #list == 16 and list[16].key == "b_mp_custom")

local function fresh(stake, deck)
  queue, created, applied_vouchers, tags = {}, {}, {}, {}
  G.GAME = {starting_params = get_starting_params(), modifiers = {}, used_vouchers = {}, stake = stake or 1}
  local g = G.GAME
  if g.stake >= 2 then g.modifiers.no_blind_reward = {Small = true} end
  if g.stake >= 3 then g.modifiers.scaling = 2 end
  if g.stake >= 4 then g.modifiers.enable_eternals_in_shop = true end
  if g.stake >= 5 then g.modifiers.ante_shop_tax = true; g.modifiers.reroll_step = 2 end
  if g.stake >= 6 then g.modifiers.scaling = 3 end
  if g.stake >= 7 then g.modifiers.enable_perishables_in_shop = true end
  if g.stake >= 8 then g.modifiers.enable_rentals_in_shop = true end
  if g.stake >= 9 then g.modifiers.booster_minus_choice = true end
  if g.stake >= 10 then g.modifiers.boss_additional_effect = true end
  if g.stake >= 11 then g.modifiers.random_joker_disable = true end
  if g.stake >= 12 then g.modifiers.boss_always_finisher = true end
  g.selected_back = Back(centers[deck or "b_red"])
  g.selected_back:apply_to_run()
  return g
end

local function all_of(...)
  local out = {}
  for _, k in ipairs({...}) do for _, p in ipairs(Cat.deck_pieces(centers[k])) do out[#out + 1] = p.id end end
  return out
end

local g = fresh(1, "b_yellow")
R.apply_plan({decks = all_of("b_red", "b_blue", "b_black"), off = {}})
local sp = g.starting_params
check("yellow + red + blue + black: hands 4", sp.hands == 4)
check("yellow + red + blue + black: discards 4", sp.discards == 4)
check("yellow + red + blue + black: joker slots 6", sp.joker_slots == 6)
check("yellow + red + blue + black: money 14", sp.dollars == 14)

local function single(id)
  local gg = fresh(1, "b_red")
  R.apply_plan({decks = {id}, off = {}})
  flush()
  return gg
end
check("piece blue hands", single("b_blue:hands").starting_params.hands == 5)
check("piece red discards stacks with red deck", single("b_red:discards").starting_params.discards == 5)
check("piece yellow dollars", single("b_yellow:dollars").starting_params.dollars == 14)
local gr = single("b_green:extra_hand_bonus")
check("piece green hand bonus alone", gr.modifiers.money_per_hand == 2 and gr.modifiers.no_interest == nil and gr.modifiers.money_per_discard == nil)
check("piece green discard bonus", single("b_green:extra_discard_bonus").modifiers.money_per_discard == 1)
check("piece green no interest", single("b_green:no_interest").modifiers.no_interest == true)
check("piece black joker slot only", (function() local x = single("b_black:joker_slot") return x.starting_params.joker_slots == 6 and x.starting_params.hands == 4 end)())
check("piece black minus hand only", (function() local x = single("b_black:hands") return x.starting_params.hands == 3 and x.starting_params.joker_slots == 5 end)())
local gm = single("b_magic:voucher_v_crystal_ball")
check("piece magic voucher", gm.used_vouchers.v_crystal_ball == true and applied_vouchers[1] == "v_crystal_ball" and #created == 0)
single("b_magic:consumables")
check("piece magic two fools", #created == 2 and created[1] == "c_fool" and created[2] == "c_fool")
check("piece nebula slot", single("b_nebula:consumable_slot").starting_params.consumable_slots == 1)
check("piece nebula telescope", single("b_nebula:voucher_v_telescope").used_vouchers.v_telescope == true)
check("piece ghost rate", single("b_ghost:spectral_rate").spectral_rate == 2)
single("b_ghost:consumables")
check("piece ghost hex", created[1] == "c_hex")
check("piece abandoned", single("b_abandoned:remove_faces").starting_params.no_faces == true)
G.playing_cards = {}
local suits = {}
for _, s in ipairs({"Clubs", "Diamonds", "Spades", "Hearts"}) do
  local c = {base = {suit = s}}
  c.change_suit = function(self, to) self.base.suit = to end
  G.playing_cards[#G.playing_cards + 1] = c
  suits[#suits + 1] = c
end
single("b_checkered:suits")
check("piece checkered turns clubs and diamonds", suits[1].base.suit == "Spades" and suits[2].base.suit == "Hearts")
local gz = single("b_zodiac:voucher_v_planet_merchant")
check("piece zodiac single voucher", gz.used_vouchers.v_planet_merchant and not gz.used_vouchers.v_tarot_merchant)
check("piece painted hand size", single("b_painted:hand_size").starting_params.hand_size == 10)
check("piece painted minus joker", single("b_painted:joker_slot").starting_params.joker_slots == 4)
check("piece plasma scaling", single("b_plasma:ante_scaling").starting_params.ante_scaling == 2)
check("piece erratic", single("b_erratic:randomize_rank_suit").starting_params.erratic_suits_and_ranks == true)
check("deck pieces leave the main deck alone", single("b_plasma:balance").selected_back.name == "Red Deck")

local gt = fresh(1, "b_red")
gt.run_mods = {decks = {"b_anaglyph:double_tag", "b_plasma:balance"}, off = {}}
gt.last_blind = {boss = true}
R._tcache = nil
local orig_trigger = Back.trigger_effect
local function trig(args) return R.on_trigger(orig_trigger, gt.selected_back, args) end
trig({context = "eval"})
flush()
check("anaglyph piece adds a double tag after a boss", #tags == 1 and tags[1].key == "tag_double")
local c1, m1 = trig({context = "final_scoring_step", chips = 30, mult = 10})
check("plasma piece balances chips and mult", c1 == 20 and m1 == 20)
gt.run_mods = {decks = {"b_red:discards"}, off = {}}
local c2 = trig({context = "final_scoring_step", chips = 30, mult = 10})
check("no balance without the plasma piece", c2 == nil)

local gs = fresh(8, "b_red")
R.apply_plan({decks = {}, off = {"stake_black:eternal"}})
check("gold stake eternal off", gs.modifiers.enable_eternals_in_shop == nil and gs.modifiers.enable_rentals_in_shop == true and gs.modifiers.enable_perishables_in_shop == true)
check("gold stake keeps scaling", gs.modifiers.scaling == 3)
gs = fresh(8, "b_red")
R.apply_plan({decks = {}, off = {"stake_purple:scaling"}})
check("purple off falls back to green scaling", gs.modifiers.scaling == 2)
gs = fresh(8, "b_red")
R.apply_plan({decks = {}, off = {"stake_purple:scaling", "stake_green:scaling"}})
check("both scaling off", gs.modifiers.scaling == nil)
gs = fresh(8, "b_red")
R.apply_plan({decks = {}, off = {"stake_red:small_reward", "stake_blue:shop_tax", "stake_blue:reroll_step", "stake_orange:perishable", "stake_gold:rental"}})
check("red, blue, orange, gold pieces off", gs.modifiers.no_blind_reward == nil and gs.modifiers.ante_shop_tax == nil and gs.modifiers.reroll_step == nil
  and gs.modifiers.enable_perishables_in_shop == nil and gs.modifiers.enable_rentals_in_shop == nil and gs.modifiers.enable_eternals_in_shop == true)
gs = fresh(12, "b_red")
R.apply_plan({decks = {}, off = {"stake_chaos:minus_choice", "stake_apocalypse:boss_extra", "stake_oblivion:joker_disable", "stake_transcendent:finisher"}})
check("overhaul stakes off", not gs.modifiers.booster_minus_choice and not gs.modifiers.boss_additional_effect and not gs.modifiers.random_joker_disable and not gs.modifiers.boss_always_finisher)
gs = fresh(3, "b_red")
R.apply_plan({decks = {}, off = {"stake_black:eternal", "stake_purple:scaling"}})
check("off pieces above the stake do nothing", gs.modifiers.scaling == 2)
check("stake pieces for gold", #Cat.stake_pieces(8) == 8)
check("stake pieces for white", #Cat.stake_pieces(1) == 0)
check("stake pieces by key", #Cat.stake_pieces("stake_black") == 3)

package.loaded["functions/forge/forge_store"] = {get_item = function(id)
  if id == "fs1" then return {id = "fs1", kind = "stake", name = "Forge Stake", effects = {{id = "eternal"}, {id = "hands_minus", n = 1}, {id = "prices_plus", n = 2}, {id = "rental", when = "round"}}} end
end}
package.loaded["functions/forge/forge_kinds_more"] = {stake_base = function() return 2 end}
local fgroups = Cat.stake_groups("forge:fs1")
local fg = fgroups[#fgroups]
check("forge stake group with its now effects", fg and fg.forge and #fg.pieces == 3 and #fgroups == 2)
gs = fresh(2, "b_red")
gs.modifiers.enable_eternals_in_shop = true
gs.starting_params.hands = 3
gs.inflation = 2
R.apply_plan({decks = {}, off = {fg.pieces[1].id, fg.pieces[2].id, fg.pieces[3].id}}, {forge_stake = "fs1"})
check("forge stake pieces undo", gs.modifiers.enable_eternals_in_shop == nil and gs.starting_params.hands == 4 and gs.inflation == 0 and gs.modifiers.no_blind_reward and gs.modifiers.no_blind_reward.Small)
local ran = 0
G.P_STAKES.stake_mod = {key = "stake_mod", order = 13, set = "Stake", modifiers = function() ran = ran + 1 end}
local sw = R.swap_stakes({decks = {}, off = {"stake_mod:own"}})
G.P_STAKES.stake_mod.modifiers()
check("modded stake effect is switched off during the start", ran == 0 and #sw == 1)
for _, x in ipairs(sw) do x[1].modifiers = x[2] end
G.P_STAKES.stake_mod.modifiers()
check("modded stake effect comes back after", ran == 1)
stakes[13] = G.P_STAKES.stake_mod
local mg = Cat.stake_pieces(13)
check("modded stake gets its own effect piece", mg[#mg].id == "stake_mod:own")
stakes[13] = nil

local p = R.normalize({decks = {"b_red:discards", "b_red:discards", 5, "nope", string.rep("x", 70) .. ":y"}, off = "bad"})
check("normalize drops junk and repeats", #p.decks == 1 and #p.off == 0)
check("empty", R.empty({decks = {}, off = {}}) and not R.empty(p))

local q = {decks = {}, off = {}}
check("toggle deck adds every piece", R.toggle_deck(q, "b_green") == true and #q.decks == 3)
R.toggle_piece(q, "b_green:no_interest")
check("untick one piece", #q.decks == 2 and not R.piece_on(q, "b_green:no_interest"))
check("toggle deck with some on clears it", R.toggle_deck(q, "b_green") == false and #q.decks == 0)
R.toggle_stake(q, "stake_black:eternal")
check("stake summary", R.stake_summary(8, q) == "1 of 8 stake effects off" and R.stake_summary(2, q) == nil)

R.picks = {decks = {"b_blue:hands"}, off = {}}
check("active", R.active())
local snap = R.snapshot()
R.clear()
check("clear", not R.active())
R.restore(snap)
check("restore", R.active() and R.picks.decks[1] == "b_blue:hands")

check("plan: continue never re-applies", R.plan_for({savetext = {}, run_mods = snap}) == nil)
check("plan: plain start has none", R.plan_for({stake = 2}) == nil and R.plan_for(nil) == nil)
check("plan: armed solo start", R.plan_for({run_mods = snap}).src == "solo")
bom_match = {get_settings = function() return {run_mods = {decks = {"b_red:discards"}, off = {}}} end}
check("plan: mp start uses the lobby", R.plan_for({mp_start = true}).decks[1] == "b_red:discards")
bom_rulesets = {lock_kind = function() return "ranked" end}
check("plan: ranked never", R.plan_for({mp_start = true}) == nil)
bom_rulesets = nil
bom_match = {get_settings = function() return {run_mods = {}} end}
check("plan: lobby setting off", R.plan_for({mp_start = true}) == nil)
bom_match = nil

local raw_apply = Back.apply_to_run
Game = {}
local base_start = function(self, args)
  args = args or {}
  local gg = fresh(args.stake or 1, args.deck or "b_red")
  gg.selected_back_key = centers[args.deck or "b_red"]
  return "started"
end
Game.start_run = base_start
Game.main_menu = function() end
G.FUNCS.start_run = function(e, args) return Game.start_run(nil, args) end
R._installed = false
R.install()
marked = nil
R.picks = {decks = {"b_red:discards", "b_blue:hands"}, off = {"stake_black:eternal"}}
R.arm(true)
G.FUNCS.start_run(nil, {stake = 8, deck = "b_yellow"})
check("armed start applies the mix", G.GAME.starting_params.hands == 5 and G.GAME.starting_params.discards == 4 and G.GAME.starting_params.dollars == 14)
check("armed start drops eternal", G.GAME.modifiers.enable_eternals_in_shop == nil and G.GAME.modifiers.enable_rentals_in_shop == true)
check("run is saved with the mix", G.GAME.run_mods and G.GAME.run_mods.decks[2] == "b_red:discards" and G.GAME.run_mods.deck == "b_yellow")
check("progress marked off", marked == "run_mods")
check("arm is used once", R.armed == false)
marked = nil
G.FUNCS.start_run(nil, {stake = 8})
check("next plain start has no mix", G.GAME.run_mods == nil and G.GAME.starting_params.hands == 4 and G.GAME.modifiers.enable_eternals_in_shop == true and marked == nil)
R.arm(true)
G.FUNCS.start_run({config = {id = 'restart_button'}}, nil)
check("restart ignores the arm", G.GAME.run_mods == nil and R.armed == false)
R.arm(true)
Game.main_menu()
check("menu disarms", R.armed == false)
check("apply hook removed after start", Back.apply_to_run == raw_apply)

print(string.format("run modifiers: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
