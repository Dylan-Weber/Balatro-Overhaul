package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name) end
end

local files, dirs = {}, {}
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
Event = function(t) return t end
pseudoseed = function(s) return s end
pseudorandom_element = function(list) return list[1], 1 end
local rnd = 0.01
pseudorandom = function() return rnd end
localize = function(a) if type(a) == "table" then return a.key end return a end
card_eval_status_text = function() end

local log
local function reset_game()
  log = {dollars = 0, hands = 0, discards = 0, created = {}, applied = {}, removed = 0}
  G = {
    GAME = {joker_buffer = 0, consumeable_buffer = 0, dollars = 10, probabilities = {normal = 1}, current_round = {hands_left = 3, discards_left = 2, hands_played = 0}, round_resets = {ante = 1}, blind = {boss = false}},
    play = {name = "play"}, hand = {name = "hand", highlighted = {}},
    jokers = {cards = {}, config = {card_limit = 5}}, consumeables = {cards = {}, config = {card_limit = 2}, emplace = function(self, c) self.cards[#self.cards + 1] = c end},
    E_MANAGER = {add_event = function(_, e) e.func() end},
    C = {FILTER = {}, GREEN = {}, MONEY = {}, MULT = {}, CHIPS = {}, BLUE = {}, RED = {}, SECONDARY_SET = {Planet = {}, Tarot = {}, Spectral = {}}},
    P_CENTERS = {m_gold = {key = "m_gold", set = "Enhanced"}},
    P_CENTER_POOLS = {Joker = {}, Tarot = {}, Planet = {}, Spectral = {}},
  }
end
reset_game()
ease_dollars = function(n) log.dollars = log.dollars + n; G.GAME.dollars = G.GAME.dollars + n end
ease_hands_played = function(n) log.hands = log.hands + n end
ease_discard = function(n) log.discards = log.discards + n end
create_card = function(kind)
  log.created[#log.created + 1] = kind
  return {add_to_deck = function() end, start_materialize = function() end}
end

local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local Cat = require("functions/forge/forge_catalog")
local T = require("functions/forge/forge_text")
local D = require("functions/forge/forge_doc")
local H = require("functions/forge/forge_hostrules")
local Mods = require("functions/forge/forge_mods")
json = require("bot.sim.json")
package.loaded["functions/forge/forge_run"] = {
  apply = function(e) log.applied[#log.applied + 1] = e.id .. ":" .. tostring(e.n) end,
  sources = function() return log.sources or {} end,
  previewing = function() return false end,
}

local function pcard(suit, id, o)
  o = o or {}
  local c = {ability = {set = o.set or "Enhanced"}, config = {center = o.center or {key = "c_base"}}, seal = o.seal, edition = o.edition, base = {suit = suit, id = id}}
  function c:get_id() return self.base.id end
  function c:is_suit(s) return self.base.suit == s end
  function c:is_face() return self.base.id >= 11 and self.base.id <= 13 end
  function c:start_dissolve() log.removed = log.removed + 1; self.removed = true end
  return c
end

local function put(kind, id, rules, vars, extra)
  local c = {id = id, kind = kind, name = id, fields = {}, effects = {}, rules = rules, vars = vars}
  for k, v in pairs(extra or {}) do c[k] = v end
  return Store.put_item(c) or Store.get_item(id)
end

local function enh_card(id, suit, rank)
  return pcard(suit or "Hearts", rank or 7, {center = {key = "m_forge_" .. id, forge_kind = "enhancement", forge_id = id}})
end

local function score(card)
  local ret = {}
  H.eval_card(card, {cardarea = G.play, full_hand = {card}, scoring_hand = {card}, poker_hand = "High Card"}, ret)
  return ret
end

check("hosts: enhancement is a card host", R.host_of("enhancement") == "card" and R.host_of("seal") == "card" and R.host_of("edition") == "card")
check("hosts: consumables and tags are use hosts", R.host_of("tarot") == "use" and R.host_of("spectral") == "use" and R.host_of("tag") == "use")
check("hosts: run kinds", R.host_of("voucher") == "run" and R.host_of("deck") == "run" and R.host_of("stake") == "run" and R.host_of("blind") == "run")
check("hosts: jokers keep every old trigger", #R.JOKER_WHEN == 36 and R.JOKER_WHEN[32] == "ante_up" and R.JOKER_WHEN[20] == "card_added" and R.JOKER_WHEN[21] == "passive" and R.when_ok("joker", "card_added") and not R.when_ok("joker", "used"))

local cl = R.clean_rules({
  {when = "card_scored", only = {}, give = {{id = "mult", n = 4}, {id = "sell_value", n = 2}, {id = "gain_chips", n = 5}}},
  {when = "hand_played", only = {}, give = {{id = "mult", n = 4}}},
  {when = "discard", only = {{id = "suit", v = "Spades"}}, give = {{id = "money", n = 2}}},
  {when = "round_end", only = {{id = "rank", v = 7}}, give = {{id = "money", n = 3}}},
}, "enhancement")
check("clean: card host keeps its triggers only", #cl == 3 and cl[1].when == "card_scored" and cl[2].when == "discard" and cl[3].when == "round_end")
check("clean: Joker-only gives dropped on cards", #cl[1].give == 2 and cl[1].give[2].id == "gain_chips")
check("clean: this card's suit / rank allowed on any card trigger", #cl[2].only == 1 and #cl[3].only == 1)
local cv = R.clean_rules({{when = "blind_selected", only = {}, give = {{id = "hand_size", n = 2}, {id = "money", n = 3}, {id = "bogus"}}}}, "voucher")
check("clean: run kinds can use run effects in rules", #cv == 1 and #cv[1].give == 2 and cv[1].give[1].run and cv[1].give[1].id == "hand_size" and cv[1].give[1].n == 2)
check("clean: run effects not offered to Jokers", #R.clean_rules({{when = "blind_selected", only = {}, give = {{id = "hand_size", n = 2}}}})[1].give == 0)
check("clean: blinds keep blind triggers", #R.clean_rules({{when = "shop_enter", give = {{id = "money", n = 1}}}}, "blind") == 0 and #R.clean_rules({{when = "round_end", give = {{id = "money", n = 1}}}}, "blind") == 1)
check("clean: consumables only have used", #R.clean_rules({{when = "used", give = {{id = "money", n = 1}}}, {when = "hand_played", give = {{id = "money", n = 1}}}}, "tarot") == 1)

put("enhancement", "lucky", {
  {when = "card_scored", only = {{id = "chance", n = 5}}, give = {{id = "mult", n = 20}}},
  {when = "card_scored", only = {{id = "chance", n = 15}}, give = {{id = "money", n = 20}}},
})
rnd = 0.01
local lucky = enh_card("lucky")
local r1 = score(lucky)
check("Lucky rebuilt: +20 Mult on a hit", r1.mult == 20)
check("Lucky rebuilt: $20 on a hit", r1.p_dollars == 20)
rnd = 0.9
local r2 = score(lucky)
check("Lucky rebuilt: nothing on a miss", r2.mult == nil and r2.p_dollars == nil)
rnd = 0.01

put("enhancement", "grow", {{when = "card_scored", only = {}, give = {{id = "gain_chips", n = 5}}}})
local g1, g2 = enh_card("grow"), enh_card("grow")
score(g1)
local s2 = score(g1)
check("per card gain: second score gives 10 Chips", s2.chips == 10)
check("per card gain: other cards keep their own value", score(g2).chips == 5)
check("per card gain lives in the card save", g1.ability.forge_rs and g1.ability.forge_rs.e_grow and g1.ability.forge_rs.e_grow.chips == 10)

put("enhancement", "count", {
  {when = "card_scored", only = {}, give = {{id = "var_add", var = 1, n = 1}}},
  {when = "card_scored", only = {{id = "var", var = 1, op = "at_least", n = 3}}, give = {{id = "xmult", n = 3}, {id = "var_set", var = 1, n = 0}}},
}, {{name = "Hits", start = 0}})
local cc = enh_card("count")
score(cc); score(cc)
check("per card variable counts", cc.ability.forge_rs.e_count.vars[1] == 2)
check("per card variable fires at 3", score(cc).x_mult == 3 and cc.ability.forge_rs.e_count.vars[1] == 0)

put("enhancement", "glass", {{when = "card_scored", only = {}, give = {{id = "xmult", n = 2}}}, {when = "card_scored", only = {{id = "chance", n = 4}}, give = {{id = "destroy_self"}}}})
local gl = enh_card("glass")
local gr = score(gl)
check("Glass rebuilt: X2", gr.x_mult == 2)
check("Glass rebuilt: breaks on a hit", gl.destroyed == true and log.removed == 1)

put("enhancement", "steel", {{when = "card_held", only = {}, give = {{id = "xmult", n = 1.5}}}})
local st = enh_card("steel")
local sr = {}
H.eval_card(st, {cardarea = G.hand}, sr)
check("Steel rebuilt: X1.5 held", sr.x_mult == 1.5)

put("enhancement", "gold", {{when = "round_end", only = {}, give = {{id = "money", n = 3}}}})
reset_game()
H.round_end(enh_card("gold"), {})
check("Gold rebuilt: $3 held at round end", log.dollars == 3)

put("seal", "red", {{when = "card_scored", only = {}, give = {{id = "retrigger", n = 1}}}, {when = "card_held", only = {}, give = {{id = "retrigger", n = 1}}}})
local rs = pcard("Spades", 5, {seal = "Forge_red", set = "Default"})
check("Red Seal rebuilt: scored retrigger", H.repeats(rs, {repetition = true, cardarea = G.play}) == 1)
check("Red Seal rebuilt: held retrigger", H.repeats(rs, {repetition = true, cardarea = G.hand}) == 1)

put("seal", "purple", {{when = "discard", only = {}, give = {{id = "create", v = "Tarot"}}}})
reset_game()
H.discard(pcard("Clubs", 9, {seal = "Forge_purple", set = "Default"}))
check("Purple Seal rebuilt: Tarot when discarded", log.created[1] == "Tarot")

put("seal", "spadeonly", {{when = "card_scored", only = {{id = "suit", v = "Spades"}}, give = {{id = "chips", n = 30}}}})
check("seal condition reads this card (match)", score(pcard("Spades", 5, {seal = "Forge_spadeonly", set = "Default"})).chips == 30)
check("seal condition reads this card (miss)", score(pcard("Hearts", 5, {seal = "Forge_spadeonly", set = "Default"})).chips == nil)

put("edition", "foil", {{when = "card_scored", only = {}, give = {{id = "chips", n = 50}}}})
check("edition rules on playing cards", score(pcard("Hearts", 3, {edition = {forge = "foil"}, set = "Default"})).chips == 50)

local jk = {ability = {set = "Joker"}, config = {center = {key = "j_joker"}}, edition = {forge = "foil"}}
local jr = {}
H.eval_card(jk, {cardarea = G.jokers, edition = true}, jr)
check("edition rules on Jokers", jr.jokers and jr.jokers.chip_mod == 50)
local deb = enh_card("lucky")
deb.debuff = true
check("debuffed cards do nothing", next(score(deb)) == nil)

reset_game()
local tarot = put("tarot", "rich", {{when = "used", only = {{id = "money", op = "at_most", n = 20}}, give = {{id = "money", n = 5}, {id = "hand_size", n = 1}}}})
H.use(tarot, nil)
check("consumable used: rule fires", log.dollars == 5 and log.applied[1] == "hand_size:1")
G.GAME.dollars = 50
H.use(tarot, nil)
check("consumable used: condition holds it back", log.dollars == 5)

reset_game()
local v = put("voucher", "vv", {
  {when = "blind_selected", only = {}, give = {{id = "hand", n = 1}}},
  {when = "hand_played", only = {{id = "hand", v = "Pair", mode = "contains"}}, give = {{id = "chips", n = 20}, {id = "xmult", n = 2}}},
  {when = "card_scored", only = {{id = "suit", v = "Hearts"}}, give = {{id = "mult", n = 3}}},
  {when = "round_end", only = {}, give = {{id = "var_add", var = 1, n = 1}}},
}, {{name = "Rounds", start = 0}})
log.sources = {{c = v, key = "v_forge_vv", times = 1}}
H.fire("blind_selected", {})
check("voucher rule on blind selected", log.hands == 1)
local Run = package.loaded["functions/forge/forge_run"]
Run.hand_name, Run.poker_hands = "Pair", {Pair = {{1}}}
local c2, m2, ch = H.score(10, 2)
check("voucher rule scores the hand", ch and c2 == 30 and m2 == 4)
Run.poker_hands = {Pair = {}}
Run.hand_name = "High Card"
local c3, _, ch3 = H.score(10, 2)
check("voucher rule condition on hand", not ch3 and c3 == 10)
check("voucher card rule on scored Hearts", score(pcard("Hearts", 4, {set = "Default"})).mult == 3)
check("voucher card rule skips Spades", score(pcard("Spades", 4, {set = "Default"})).mult == nil)
H.fire("round_end", {})
H.fire("round_end", {})
check("run variables live in the run save", G.GAME.forge_rs.r_v_forge_vv.vars[1] == 2)
log.sources = nil

check("text: card trigger reads this card", T.when_text("card_scored", "en", "enhancement") == "When this card scores")
check("text: fr and es", T.when_text("discard", "fr", "seal") == "Quand cette carte est défaussée" and T.when_text("used", "es", "tarot") == "Al usarla")
check("text: run triggers", T.when_text("now", "en", "voucher") == "When bought" and T.when_text("now", "en", "deck") == "At the start of the run")
local lines = D.lines({kind = "enhancement", name = "L", fields = {chips = 0}, effects = {}, rules = {{when = "card_scored", only = {{id = "chance", n = 5}}, give = {{id = "mult", n = 20}}}}}, "en")
local joined = table.concat(lines, " ")
check("text: rule line on an enhancement", joined:find("When this card scores", 1, true) ~= nil and joined:find("20", 1, true) ~= nil)
local vl = table.concat(D.lines({kind = "voucher", name = "V", fields = {}, effects = {}, rules = {{when = "blind_selected", only = {}, give = {{id = "hand_size", n = 2}}}}}, "en"), " ")
check("text: run effect inside a rule", vl:find("hand size", 1, true) ~= nil and vl:find("blind", 1, true) ~= nil)

local gtext = table.concat(D.lines(Store.get_item("grow"), "en"), " ")
check("live text: growing enhancement shows its current value", gtext:find("Currently", 1, true) ~= nil and gtext:find("#2#", 1, true) ~= nil)
local ctext = table.concat(D.lines(Store.get_item("count"), "en"), " ")
check("live text: variable on an enhancement is shown", ctext:find("Hits:", 1, true) ~= nil and ctext:find("#5#", 1, true) ~= nil)
check("live text: fr and es too", table.concat(D.lines(Store.get_item("grow"), "fr"), " "):find("Actuellement", 1, true) ~= nil and table.concat(D.lines(Store.get_item("grow"), "es"), " "):find("Actualmente", 1, true) ~= nil)
check("live text: a card says this card gains, not this joker", gtext:find("this card gains", 1, true) ~= nil and gtext:find("joker", 1, true) == nil)
check("live text: gain words in fr and es", table.concat(D.lines(Store.get_item("grow"), "fr"), " "):find("cette carte gagne", 1, true) ~= nil and table.concat(D.lines(Store.get_item("grow"), "es"), " "):find("esta carta gana", 1, true) ~= nil)
check("live vars: this card's own grown value", H.item_vars(Store.get_item("grow"), g1)[2] == "10")
check("live vars: other card keeps its own value", H.item_vars(Store.get_item("grow"), g2)[2] == "5")
check("live vars: no card shows the start value", H.item_vars(Store.get_item("grow"), nil)[2] == "0" and H.item_vars(Store.get_item("count"), nil)[5] == "0")
score(cc)
check("live vars: per card variable value", H.item_vars(Store.get_item("count"), cc)[5] == "1")
check("live vars: key lookup", H.item_of_key("m_forge_grow") == Store.get_item("grow") and H.item_of_key("m_forge_plainold") == nil and H.item_of_key("j_forge_grow") == nil)
H.describing = g1
local la = H.live_args({type = "descriptions", key = "m_forge_grow", set = "Enhanced", nodes = {}, vars = {}})
H.describing = nil
check("live vars: card text gets the hovered card's values", la.vars[2] == "10" and la.set == "Enhanced")
local plain_args = {type = "descriptions", key = "m_gold", set = "Enhanced", vars = {3}}
check("live vars: other cards untouched", H.live_args(plain_args) == plain_args)
check("live vars: run variable shows the run value", H.item_vars(Store.get_item("vv"), nil)[5] == "2")
G.STAGES, G.STAGE = {RUN = 2, MAIN_MENU = 1}, 1
check("live vars: outside a run shows the start value", H.item_vars(Store.get_item("vv"), nil)[5] == "0")
G.STAGE = 2
check("live vars: in a run again", H.item_vars(Store.get_item("vv"), nil)[5] == "2")
put("seal", "SgA", {{when = "card_scored", only = {}, give = {{id = "gain_mult", n = 2}}}})
local sc = pcard("Hearts", 5, {set = "Default", seal = "Forge_SgA"})
score(sc); score(sc)
check("live vars: seal key and per card value", H.item_of_key("forge_sga_seal") == Store.get_item("SgA") and H.live_args({type = "other", key = "forge_sga_seal"}).vars[3] == "0")
H.describing = sc
check("live vars: seal on the hovered card", H.live_args({type = "other", key = "forge_sga_seal"}).vars[3] == "4")
H.describing = nil
put("tag", "tg", {{when = "used", only = {}, give = {{id = "var_add", var = 1, n = 1}, {id = "money", n = 1}}}}, {{name = "Uses", start = 3}})
check("live vars: tag starts at its start value", H.live_args({type = "descriptions", set = "Tag", key = "tag_forge_tg"}).vars[5] == "3")
H.use(Store.get_item("tg"))
H.use(Store.get_item("tg"))
check("live vars: tag shows the run value after use", H.live_args({type = "descriptions", set = "Tag", key = "tag_forge_tg"}).vars[5] == "5")
check("live text: tag variable line", table.concat(D.lines(Store.get_item("tg"), "en"), " "):find("Uses:", 1, true) ~= nil)

local stored = Store.get_item("lucky")
check("store keeps rules on items", stored and #stored.rules == 2)
local plain = put("enhancement", "plainold", nil)
check("store: old items stay without rules", plain and plain.rules == nil)
check("version: rules on an item need file version 8", Cat.need_v(stored) == 8)
check("version: old item stays old", Cat.need_v(plain) < 8)
check("version: mods and rooms read 16", Mods.V == 16)
check("version: jokers without new blocks unchanged", R.need_v({{when = "hand_played", only = {}, give = {{id = "mult", n = 4}}}}) == 1)

json = json or require("bot.sim.json")
Store.put_item({id = "tt9", kind = "tarot", name = "Spark", fields = {}, effects = {{id = "money", n = 3}}})
Store.put_item({id = "sx9", kind = "seal", name = "Maker", fields = {}, effects = {}, rules = {{when = "discard", only = {}, give = {{id = "make_card", v = "c_forge_tt9"}}}}})
local raw, out = Mods.pack({name = "Seal pack"}, {"sx9"})
local got = {}
for _, c in ipairs(out and out.creations or {}) do got[c.id] = c end
check("export: rules pull the cards they name", got.tt9 and got.sx9)
check("export: file version 8", out and out.v == 8)
check("export: rules travel in the file", got.sx9 and got.sx9.rules and got.sx9.rules[1].give[1].v == "c_forge_tt9")
local mod = raw and Mods.parse(raw)
local seal, tar
for _, c in ipairs(mod and mod.creations or {}) do if c.kind == "seal" then seal = c elseif c.kind == "tarot" then tar = c end end
check("install: rule names the renamed card", seal and tar and seal.rules and seal.rules[1].give[1].v == "c_forge_" .. tar.id)
local t9 = json.decode(raw)
t9.v = 17
check("older game refuses v17", select(2, Mods.parse(json.encode(t9))) == "newer")

print(string.format("forge host rules: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
