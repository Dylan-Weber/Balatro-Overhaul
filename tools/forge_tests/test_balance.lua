package.path = "assets/?.lua;" .. package.path
mod_loc = function(s) return s end
G = {}
local Cat = require("functions/forge/forge_catalog")
local R = require("functions/forge/forge_rules")
local Store = require("functions/forge/forge_store")
local Bal = require("functions/forge/forge_balance")

local fails, total = 0, 0
local function check(name, ok, got)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (got ~= nil and (" got: " .. tostring(got)) or "")) end
end

local function W(when, only, give, alt) return {when = when, only = only or {}, give = give, alt = alt} end
local function g(id, n, v) return {id = id, n = n, v = v} end
local function vadd(n) return {id = "var_add", var = 1, n = n} end
local function var(op, n) return {id = "var", var = 1, op = op, n = n} end
local function fx(id, n, v) return {id = id, n = n, v = v} end

local src = io.open("tools/forge_tests/test_coverage.lua"):read("*a")
local helpers = src:match("(local function W%(.-)\nlocal J = {")
local function grab(name)
  local body = src:match("\nlocal " .. name .. " = (%b{})")
  local f = assert(load(helpers .. "\nlocal function fx(id, n, v) return {id = id, n = n, v = v} end\nreturn " .. body))
  return f()
end

local RAR = {}
for line in io.open("assets/game.lua"):lines() do
  if line:match("^%s+j_[%w_]+%s*=%s*{") then
    local r = tonumber(line:match("rarity%s*=%s*(%d)"))
    local n = line:match("name%s*=%s*[\"']([^\"']+)[\"']")
    if r and n then RAR[n] = r end
  end
end

local function joker(rar, rules, vars) return Store.clean({id = "t" .. tostring(rar), rarity = rar, rules = rules, vars = vars}) end
local function item(t) t.id = t.id or "t"; return Store.clean_item(t) end
local function level(c) return Bal.of(c).level end

local counts = {}
local J = grab("J")
local found = 0
for _, e in ipairs(J) do
  local rar = RAR[e[1]]
  if rar then
    found = found + 1
    local r = Bal.of(joker(rar, e[2], e[3]))
    counts[r.level] = (counts[r.level] or 0) + 1
    check("vanilla " .. e[1] .. " not above Strong", Bal.RANK[r.level] <= 3, r.level .. " " .. r.score)
  end
end
check("vanilla jokers found", found >= 140, found)
check("vanilla jokers mostly Fair", (counts.fair or 0) >= math.floor(found * 0.9), counts.fair)
check("vanilla jokers never Broken or Overpowered", (counts.broken or 0) + (counts.op or 0) == 0)

local T2 = {["Overstock Plus"] = 1, Liquidation = 1, ["Glow Up"] = 1, ["Reroll Glut"] = 1, ["Omen Globe"] = 1, Observatory = 1, ["Nacho Tong"] = 1, Recyclomancy = 1,
  ["Tarot Tycoon"] = 1, ["Planet Tycoon"] = 1, ["Money Tree"] = 1, Antimatter = 1, Illusion = 1, Petroglyph = 1, Retcon = 1, Palette = 1}
local sets = {
  {"ENH", function(e) return item({kind = "enhancement", fields = e[2], rules = e[3]}) end},
  {"SEALS", function(e) return item({kind = "seal", effects = e[2], rules = e[3]}) end},
  {"EDS", function(e) return item({kind = "edition", fields = e[2]}) end},
  {"VOUCHERS", function(e) return item({kind = "voucher", effects = e[2], fields = T2[e[1]] and {requires = "v_overstock_norm"} or nil}) end},
  {"TAGS", function(e) return item({kind = "tag", effects = e[2], rules = e[3]}) end},
  {"BOSSES", function(e) return item({kind = "blind", effects = e[2], fields = e[3]}) end},
}
for _, s in ipairs(sets) do
  for _, e in ipairs(grab(s[1])) do
    local c = s[2](e)
    local lv = c and level(c)
    check(s[1] .. " " .. e[1] .. " is Weak or Fair", lv == "fair" or (lv == "weak" and e[1] == "Blank"), lv)
  end
end

local broken = {
  {"Common +1000 Mult every hand", joker(1, {W("hand_played", nil, {g("mult", 1000)})})},
  {"Legendary X100 every hand", joker(4, {W("hand_played", nil, {g("xmult", 100)})})},
  {"Common $1000 every hand", joker(1, {W("hand_played", nil, {g("money", 1000)})})},
  {"Common $200 each round", joker(1, {W("round_end", nil, {g("money", 200)})})},
  {"Legendary ^2 Mult", joker(4, {W("hand_played", nil, {g("emult", 2)})})},
  {"Common gains X1 per card", joker(1, {W("card_scored", nil, {g("gain_xmult", 1)})})},
  {"Retrigger 10 every card", joker(2, {W("card_scored", nil, {g("retrigger", 10)})})},
  {"+10 hands", joker(3, {W("passive", nil, {g("p_hands", 10)})})},
  {"Variable trick", joker(1, {W("hand_played", {var("at_least", 1000000)}, {g("xmult", 1000000)}), W("hand_played", nil, {vadd(1000000)})}, {{name = "v", start = 0}})},
  {"Variable amount", joker(1, {W("hand_played", nil, {{id = "xmult", n = 2, nv = 1}}), W("hand_played", nil, {vadd(1000)})}, {{name = "v", start = 0}})},
  {"Deck $1000", item({kind = "deck", effects = {fx("dollars", 1000)}})},
  {"Deck +10 hands", item({kind = "deck", effects = {fx("hands", 10)}})},
  {"Stake blinds -99%", item({kind = "stake", effects = {fx("blind_scaling", -99)}})},
  {"Blind reward 1000", item({kind = "blind", fields = {size = 0.01, reward = 1000}})},
  {"Tarot $1e9", item({kind = "tarot", effects = {fx("money", 1e9)}})},
  {"Spectral +1000 Joker slots", item({kind = "spectral", effects = {fx("joker_slots_plus", 1000)}})},
  {"Enhancement X1e15", item({kind = "enhancement", fields = {xmult = 1e15}})},
  {"Seal retrigger 1000", item({kind = "seal", effects = {fx("scored_retrigger", 1000)}})},
  {"Voucher $1e9", item({kind = "voucher", effects = {fx("money", 1e9)}})},
  {"Tag $1e6", item({kind = "tag", effects = {fx("money", 1e6)}})},
  {"Edition X100", item({kind = "edition", fields = {xmult = 100}})},
  {"Boost a Joker X100", joker(3, {W("passive", nil, {g("boost_double", 100, "right")})})},
}
for _, b in ipairs(broken) do check(b[1] .. " is Broken", b[2] and level(b[2]) == "broken", b[2] and Bal.of(b[2]).score) end

local function lv(c, want, name) check(name .. " is " .. want, level(c) == want, Bal.of(c).level .. " " .. Bal.of(c).score) end
lv(joker(1, {W("hand_played", nil, {g("xmult", 3)})}), "strong", "Common X3 every hand")
lv(joker(2, {W("hand_played", nil, {g("xmult", 3)})}), "strong", "Uncommon X3 every hand")
lv(joker(3, {W("hand_played", nil, {g("xmult", 3)})}), "fair", "Rare X3 every hand")
lv(joker(1, {W("hand_played", nil, {g("xmult", 10)})}), "op", "Common X10 every hand")
lv(joker(4, {W("hand_played", nil, {g("xmult", 10)})}), "strong", "Legendary X10 every hand")
lv(joker(1, {W("hand_played", nil, {g("mult", 4)})}), "fair", "Plain Joker")
lv(joker(4, {W("hand_played", nil, {g("mult", 1)})}), "weak", "Legendary +1 Mult")
lv(joker(1, {}), "weak", "Empty Joker")
local bd = joker(3, {W("passive", nil, {g("boost_double", 2, "right")})})
check("Boost a Joker X2 is not above Strong", Bal.RANK[level(bd)] <= 3 and level(bd) ~= "weak", Bal.of(bd).level .. " " .. Bal.of(bd).score)
local grow = joker(1, {W("round_end", {{id = "every", n = 3}}, {g("become", nil, "Rare")})})
check("grow-up Joker is Fair", level(grow) == "fair", Bal.of(grow).level .. " " .. Bal.of(grow).score)
lv(item({kind = "deck", effects = {fx("hands", 1)}}), "fair", "Deck +1 hand")
lv(item({kind = "stake", effects = {fx("hands", 3)}}), "op", "Stake +3 hands")
lv(item({kind = "stake", effects = {fx("small_no_reward")}}), "fair", "Red Stake")
lv(item({kind = "collab", fields = {suit = "Hearts"}}), "fair", "Collab")
lv(item({kind = "booster", fields = {pack = "Arcana", size = "Normal", cost = 4}}), "fair", "Arcana pack")

local x3 = Bal.of(joker(1, {W("hand_played", nil, {g("xmult", 3)})}))
check("reason en", Bal.line(x3, "en") == "Strong: X3 Mult every hand is above Rare Jokers", Bal.line(x3, "en"))
check("reason fr", Bal.line(x3, "fr") == "Fort : X3 Multi à chaque main dépasse les Jokers rares", Bal.line(x3, "fr"))
check("reason es", Bal.line(x3, "es") == "Fuerte: X3 multi en cada mano supera a los Jokers raros", Bal.line(x3, "es"))
local br = Bal.of(broken[1][2])
check("broken reason", Bal.line(br, "en") == "Broken: +1000 Mult every hand, progress turns off", Bal.line(br, "en"))
check("weak reason", Bal.line(Bal.of(joker(1, {})), "en") == "Weak: below Common Jokers", Bal.line(Bal.of(joker(1, {})), "en"))
for _, l in ipairs({"en", "fr", "es"}) do
  for k, v in pairs(Bal.TEXT[l]) do check("no em dash " .. l .. " " .. k, not v:find("\226\128\148", 1, true)) end
  for k in pairs(Bal.TEXT.en) do check("text " .. l .. " " .. k, Bal.TEXT[l][k] ~= nil) end
end

check("lg 8", Bal.lg(8) == 3)
check("lg 1.5", math.abs(Bal.lg(1.5) - 0.5849625007) < 1e-9, Bal.lg(1.5))
check("lg 1e15", math.abs(Bal.lg(1e15) - 49.82892142) < 1e-6, Bal.lg(1e15))

local a = {id = "k1", rarity = 2, rules = {W("hand_played", nil, {g("mult", 8)})}}
local b = {rules = {W("hand_played", nil, {g("mult", 8)})}, rarity = 2, id = "k2", name = "Other name"}
check("content key ignores id, name and order", Bal.content_key(Store.clean(a)) == Bal.content_key(Store.clean(b)))
local c1 = Store.clean(a)
local s1 = Bal.of(c1).score
Bal.by_table, Bal.by_content, Bal.content_n = setmetatable({}, {__mode = "k"}), {}, 0
check("same score after recompute", Bal.of(Store.clean(a)).score == s1)
local tamper = Store.clean({id = "tam", rarity = 1, rules = {W("hand_played", nil, {g("xmult", 1000)})}, level = "fair", balance = {level = "fair"}})
check("stored level is ignored", level(tamper) == "broken")
check("cleaning drops stored level", tamper.level == nil and tamper.balance == nil)

Store.list = {Store.clean({id = "bad1", name = "Bad", rarity = 1, rules = {W("hand_played", nil, {g("xmult", 1000)})}}),
  Store.clean({id = "ok1", name = "Fine", rarity = 1, rules = {W("hand_played", nil, {g("mult", 4)})}})}
Store.items_list = {item({id = "itm1", name = "Nice deck", kind = "deck", effects = {fx("hands", 1)}}), item({id = "itm2", name = "Cheat deck", kind = "deck", effects = {fx("dollars", 1000)}})}
local set = Bal.broken_set()
check("broken set has Bad", set.bad1 == "Bad")
check("broken set skips Fine", set.ok1 == nil)
check("broken set has Cheat deck", set.itm2 == "Cheat deck")
check("key j_forge_bad1", Bal.key_broken("j_forge_bad1") == "Bad")
check("key j_forge_ok1", Bal.key_broken("j_forge_ok1") == nil)
check("key b_forge_itm2", Bal.key_broken("b_forge_itm2") == "Cheat deck")
check("pool finds Bad", Bal.pool_broken() == "Bad")
Store.list[1].enabled = false
check("pool skips disabled", Bal.pool_broken() == nil)
check("pool skips decks", Bal.pool_broken() == nil)
Store.list[1].enabled = true
check("pack line broken", (Bal.pack_line(Store.list, "en")) == "Broken: Bad (progress off)", (Bal.pack_line(Store.list, "en")))
check("pack line fair", (Bal.pack_line({Store.list[2]}, "en")) == "Balance: up to Fair", (Bal.pack_line({Store.list[2]}, "en")))

local P = dofile("assets/functions/progress_gate.lua")
G.STAGES, G.STAGE = {RUN = 1}, 1
G.TIMERS = {REAL = 1}
G.GAME = {}
G.jokers = {cards = {{config = {center = {key = "j_forge_ok1", forge = true, forge_id = "ok1"}}}}}
check("fair joker keeps progress", P.forge_in_run() == nil)
check("run allowed with fair forge", P.allowed() == true)
G.jokers.cards[2] = {config = {center = {key = "j_forge_bad1", forge = true, forge_id = "bad1"}}}
G.TIMERS.REAL = 2
check("broken joker found", P.forge_in_run() == "Bad")
check("run blocked with broken forge", P.allowed() == false)
check("reason is forge_broken", G.GAME.progress_off == "forge_broken" and G.GAME.progress_why == "Bad")
check("notice names it", P.notice() == "Progress is off for this run: Broken Forge content (Bad)", P.notice())
G.GAME = {selected_back = {effect = {center = {key = "b_forge_itm2", forge = true}}}}
G.jokers.cards = {}
check("broken deck found", P.forge_in_run() == "Cheat deck")
G.GAME = {}
G.jokers.cards = {{edition = {forge = "ok1"}}}
check("fair edition ignored", P.forge_in_run() == nil)

local M = Bal.MAPS
local SKIP_KIND = {collab = true, suit = true, hand = true, ctype = true, challenge = true, rarity = true, sticker = true, fusion = true}
local function map_of(k)
  if k == "tarot" or k == "spectral" or k == "planet" then return M.USE end
  if k == "tag" then return M.TAG end
  if k == "seal" then return M.SEAL end
  return M.RUN
end
local unrated = {}
for _, k in ipairs(Cat.KINDS) do
  if not SKIP_KIND[k.id] then
    for _, e in ipairs(Cat.effects_for(k.id) or {}) do
      if not (map_of(k.id)[e.id] or M.RUN[e.id] or M.DO[e.id] or e.id == "money" or Bal.NEUTRAL[e.id] or (k.id == "blind" and M.BOSS[e.id])) then unrated[#unrated + 1] = k.id .. ":" .. e.id end
    end
  end
end
check("guard: every effect of every kind is rated", #unrated == 0, table.concat(unrated, " "))
local undone = {}
for _, id in ipairs(R.GIVE) do if not (M.DO[id] or M.RUN[id] or Bal.NEUTRAL[id]) then undone[#undone + 1] = id end end
check("guard: every Joker DO is rated", #undone == 0, table.concat(undone, " "))

local huge = Bal.compute(item({kind = "tag", effects = {fx("level_all", 1e12)}}))
check("Tag that levels every hand 1e12 times is broken", huge.level == "broken", huge.level .. " " .. tostring(huge.score))
local one = Bal.compute(item({kind = "tag", effects = {fx("level_all", 1)}}))
check("Tag that levels every hand once is not weak", one.level ~= "weak", one.level .. " " .. tostring(one.score))
check("more levels rate higher", huge.score > one.score)
local lv1 = Bal.compute(item({kind = "tag", effects = {fx("level_up", 1, "Flush")}}))
local lv9 = Bal.compute(item({kind = "tag", effects = {fx("level_up", 1e9, "Flush")}}))
check("Tag level up 1e9 is above 1 level", lv9.score > lv1.score and Bal.RANK[lv9.level] > Bal.RANK[lv1.level], lv1.level .. " " .. lv9.level)
local sk1 = Bal.compute(joker(1, {W("round_end", nil, {{id = "stick_self", v = "eternal"}})}))
local sk2 = Bal.compute(joker(1, {W("round_end", nil, {{id = "unstick_card", v = "rental"}})}))
check("removing Rental rates above adding Eternal", sk2.score > sk1.score, sk1.score .. " " .. sk2.score)
local ax = Bal.compute(joker(1, {W("blind_selected", nil, {{id = "blind_x", n = 0.5}})}))
local ax2 = Bal.compute(joker(1, {W("blind_selected", nil, {{id = "blind_x", n = 2}})}))
check("halving the Blind rates above doubling it", ax.score > ax2.score, ax.score .. " " .. ax2.score)

local big = joker(3, {
  W("card_scored", {{id = "suit", v = "Hearts"}, {id = "chance", n = 3}}, {g("mult", 5), g("xmult", 1.5), g("money", 2)}, {g("chips", 30)}),
  W("hand_played", {var("at_least", 3)}, {g("xmult", 3), {id = "var_set", var = 1, n = 0}}, {vadd(1)}), W("passive", nil, {g("p_hand_size", 1)})}, {{name = "v", start = 0}})
local t0 = os.clock()
for _ = 1, 2000 do Bal.compute(big) end
local dt = os.clock() - t0
check("2000 ratings under 1 s", dt < 1, dt)
local t1 = os.clock()
for _ = 1, 100000 do Bal.of(big) end
check("cached lookups are cheap", os.clock() - t1 < 0.5, os.clock() - t1)

check("broken set is reused", Bal.broken_set() == Bal.broken_set())
Store.list, Store.items_list = {Store.list[2]}, {Store.items_list[1]}
G.GAME = {}
G.jokers.cards = {{config = {center = {key = "j_forge_ok1", forge = true, forge_id = "ok1"}}}}
local t2 = os.clock()
for _ = 1, 100000 do P.forge_in_run() end
check("scan with no Broken content is cheap", os.clock() - t2 < 0.5, os.clock() - t2)
check("scan with no Broken content finds nothing", P.forge_in_run() == nil)

print(string.format("balance: %d / %d passed, %d failed", total - fails, total, fails))
os.exit(fails == 0 and 0 or 1)
