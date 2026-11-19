package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok, extra)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "")) end
end

local items = {
  {id = "d1", kind = "edition", name = "Gilded", enabled = true, mode = "advanced", fields = {shader = "none", chips = 10}},
  {id = "d2", kind = "edition", name = "Void", enabled = true, mode = "advanced", fields = {shader = "foil", slot = true}},
}
G = {P_CENTERS = {e_forge_d1 = {key = "e_forge_d1"}, e_forge_d2 = {key = "e_forge_d2"}}, C = {SECONDARY_SET = {}}}
mod_loc = function(x) return x end
local Store = require("functions/forge/forge_store")
Store.live_items = function() return items end
Store.get_item = function(id) for _, c in ipairs(items) do if c.id == id then return c end end end
local R = require("functions/forge/forge_rules")
local Cat = require("functions/forge/forge_catalog")
local Mods = require("functions/forge/forge_mods")
local A = require("functions/forge/forge_always")
local json = require("bot.sim.json")
local function has(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end
local function field(kind)
  for _, f in ipairs(Cat.kind(kind).adv_fields or {}) do if f.id == "always_ed" then return f end end
end

for _, k in ipairs({"tarot", "planet", "spectral", "enhancement"}) do
  check("field: " .. k .. " has Always comes with", field(k) and field(k).label == "Always comes with")
end
for _, k in ipairs({"voucher", "tag", "blind", "stake", "deck", "seal", "booster", "edition"}) do
  check("field: " .. k .. " skipped", field(k) == nil)
end
local tv = Cat.field_values(field("tarot"))
check("field: tarot values", tv[1] == "none" and has(tv, "foil") and has(tv, "holo") and has(tv, "polychrome") and has(tv, "negative") and has(tv, "forge_d1") and has(tv, "forge_d2"))
check("field: no Overhaul shines", not has(tv, "tshine_gold") and #tv == 7, #tv)
local ev = Cat.field_values(field("enhancement"))
check("field: playing cards skip Negative", not has(ev, "negative") and has(ev, "polychrome") and has(ev, "forge_d1"))
local jv = Cat.field_values(A.JOKER_FIELD)
check("field: joker values", A.JOKER_FIELD.top and jv[1] == "none" and has(jv, "negative") and has(jv, "forge_d2") and #jv == 7)
check("label: none", Cat.value_label(Cat.field_what(A.JOKER_FIELD), "none") == "No edition")
check("label: nil reads none", Cat.value_label("always_edition", nil) == "No edition")
check("label: foil", Cat.value_label("always_edition", "foil") == Cat.value_label("shader", "foil") and Cat.value_label("always_edition", "foil") ~= "")
check("label: own edition", Cat.value_label("always_edition", "forge_d1"):find("Gilded", 1, true) ~= nil)
check("label: pack field unchanged", Cat.value_label("pack_edition", "none") == "As usual")

check("clean: kind keeps the value", Cat.clean_fields("tarot", {always_ed = "negative"}).always_ed == "negative")
check("clean: kind default none", Cat.clean_fields("spectral", {}).always_ed == "none")
check("clean: kind drops junk", Cat.clean_fields("planet", {always_ed = "tshine_gold"}).always_ed == "none")
check("clean: enhancement drops Negative", Cat.clean_fields("enhancement", {always_ed = "negative"}).always_ed == "none")
check("clean: own edition kept", Cat.clean_fields("tarot", {always_ed = "forge_d2"}).always_ed == "forge_d2")

local function joker(o)
  local c = {id = "j1", name = "J", rarity = 1, cost = 4, rules = {}, vars = {}, mode = "advanced"}
  for k, v in pairs(o or {}) do c[k] = v end
  return c
end
check("value: joker advanced", A.value(joker({always_ed = "polychrome"})) == "polychrome")
check("value: joker uses it in any mode", A.value(joker({always_ed = "polychrome", mode = "simple"})) == "polychrome")
check("value: tarot simple ignores it", A.value({kind = "tarot", mode = "simple", fields = {always_ed = "negative"}}) == nil)
check("value: none", A.value(joker({always_ed = "none"})) == nil)
check("value: draft kind joker", A.value({kind = "joker", mode = "advanced", always_ed = "foil"}) == "foil")
check("value: tarot", A.value({kind = "tarot", mode = "advanced", fields = {always_ed = "negative"}}) == "negative")
check("value: enhancement Negative refused", A.value({kind = "enhancement", mode = "advanced", fields = {always_ed = "negative"}}) == nil)
check("value: enhancement own edition", A.value({kind = "enhancement", mode = "advanced", fields = {always_ed = "forge_d1"}}) == "forge_d1")
check("value: voucher never", A.value({kind = "voucher", mode = "advanced", fields = {always_ed = "foil"}}) == nil)

check("need: tarot with it is 13", Cat.need_v({kind = "tarot", fields = {always_ed = "negative"}, effects = {}}) == 13)
check("need: tarot without it stays old", Cat.need_v({kind = "tarot", fields = {always_ed = "none"}, effects = {}}) < 13)
check("need: enhancement own edition 13", Cat.need_v({kind = "enhancement", fields = {always_ed = "forge_d1"}, effects = {}}) == 13)
check("need: joker with it is 13", Mods.needs_v({joker({always_ed = "foil"})}, {}) == 13)
check("need: joker without it stays old", Mods.needs_v({joker()}, {}) < 13)
check("need: joker none stays old", Mods.needs_v({joker({always_ed = "none"})}, {}) < 13)
check("need: format is 16, always stays 13", Mods.V >= 16 and A.V == 13)

check("store: joker keeps it", Store.clean(joker({always_ed = "negative"})).always_ed == "negative")
check("store: own edition kept", Store.clean(joker({always_ed = "forge_d2"})).always_ed == "forge_d2")
check("store: junk dropped", Store.clean(joker({always_ed = "tshine_gold"})).always_ed == nil and Store.clean(joker({always_ed = 5})).always_ed == nil and Store.clean(joker({always_ed = "none"})).always_ed == nil)

local raw = json.encode({format = "forgemod", v = 13, id = "abcd12", name = "Always", jokers = {{id = "jA", name = "A", rarity = 1, cost = 4, rules = {}, mode = "advanced", always_ed = "forge_e1"}},
  creations = {{id = "e1", kind = "edition", name = "Shiny", mode = "advanced", fields = {shader = "foil"}}, {id = "t1", kind = "tarot", name = "T", mode = "advanced", fields = {always_ed = "negative"}}, {id = "t2", kind = "spectral", name = "S", mode = "advanced", fields = {always_ed = "forge_e1"}}}})
local mod, err = Mods.parse(raw)
check("share: v13 parses", mod ~= nil, err)
local ed, tar, spe
for _, c in ipairs(mod and mod.creations or {}) do if c.kind == "edition" then ed = c elseif c.kind == "tarot" then tar = c elseif c.kind == "spectral" then spe = c end end
check("share: joker edition renamed with the mod", mod and ed and mod.jokers[1].always_ed == "forge_" .. ed.id, mod and mod.jokers[1].always_ed)
check("share: tarot keeps Negative", tar and tar.fields.always_ed == "negative")
check("share: spectral keeps the mod's own edition", spe and ed and spe.fields.always_ed == "forge_" .. ed.id, spe and spe.fields.always_ed)
local t14 = json.decode(raw)
t14.v = 18
check("share: newer refused", select(2, Mods.parse(json.encode(t14))) == "newer")
local old = json.decode(Mods.for_old_server(raw))
check("share: old server copy asks for 13", old.v == 1 and old.need == 13)
local Room = require("functions/forge/forge_room")
check("room: version follows mods", Room.V >= 16)

local base_text = {"{C:mult}+4{} Mult"}
local jl = A.with_line(joker({always_ed = "foil"}), base_text, "en")
check("text: line added", #jl == 2 and jl[2] == "Always {C:dark_edition}" .. R.ed_name("foil") .. "{}" and #base_text == 1, jl[2])
check("text: own edition name", A.line(joker({always_ed = "forge_d1"})):find("Gilded", 1, true) ~= nil)
check("text: custom text untouched", #A.with_line(joker({always_ed = "foil", text = {en = {"Mine"}}}), {"Mine"}, "en") == 1)
check("text: nothing when unset", #A.with_line(joker(), base_text, "en") == 1)
mod_loc = function(x) return x == "Always {C:dark_edition}%s{}" and "Toujours {C:dark_edition}%s{}" or x end
check("text: fr line", A.line(joker({always_ed = "negative"})):find("^Toujours") ~= nil)
mod_loc = function(x) return x end

local function fake_card(center)
  local c = {config = {center = center}, ability = {}, sets = 0}
  function c:set_edition(e)
    self.sets = self.sets + 1
    if not e or next(e) == nil then self.edition = nil return end
    self.edition = {}
    for k, v in pairs(e) do self.edition[k] = v end
    if e.forge then self.edition.type = "forge_" .. e.forge else self.edition.type = next(e) end
  end
  function c:set_cost() self.costed = true end
  return c
end
local c1 = fake_card({forge_start_ed = "negative"})
A.apply(c1)
check("apply: Negative", c1.edition and c1.edition.negative and c1.costed)
A.apply(c1)
check("apply: same edition not set twice", c1.sets == 1)
local c2 = fake_card({forge_start_ed = "forge_d1"})
A.apply(c2)
check("apply: own edition", c2.edition and c2.edition.forge == "d1")
local c3 = fake_card({forge_start_ed = "holo"})
c3.added_to_deck = true
A.apply(c3)
check("apply: never on a card already in the deck", c3.edition == nil)
local c4 = fake_card({forge_start_ed = "forge_zz"})
A.apply(c4)
check("apply: missing own edition does nothing", c4.edition == nil)

local Area = {}
Area.__index = Area
function Area.emplace(self, card) self.cards = self.cards or {}; self.cards[#self.cards + 1] = card end
CardArea = Area
Card = {}
Card.__index = Card
function Card.init(self, center) self.config = {center = center}; self.ability = {}; self.sets = 0 end
function Card.set_edition(self, e) return fake_card().set_edition(self, e) end
function Card.set_cost(self) self.costed = true end
local function new_card(center) local o = setmetatable({}, Card); o:init(center); return o end
local roll = nil
create_card = function(center)
  local c = new_card(center)
  c:set_edition(roll)
  return c
end
A.install()
local plain = {}
local cen = {forge_start_ed = "foil"}
local preview = new_card(cen)
check("hook: Card() gets it (Collection, preview)", preview.edition and preview.edition.foil and preview.forge_always_new)
check("hook: plain card untouched", new_card(plain).edition == nil)
roll = nil
local shop = create_card(cen)
check("hook: shop roll of no edition overridden", shop.edition and shop.edition.foil)
roll = {holo = true}
local made = create_card(cen)
check("hook: rolled Holo replaced", made.edition and made.edition.foil and not made.edition.holo)
check("hook: other jokers keep their roll", create_card(plain).edition.holo == true)
G.pack_cards = setmetatable({}, Area)
G.shop_jokers = setmetatable({}, Area)
local std = create_card(cen)
std:set_edition({polychrome = true})
G.pack_cards:emplace(std)
check("hook: pack roll after creation replaced on emplace", std.edition and std.edition.foil)
local bought = create_card(cen)
bought.added_to_deck = true
bought:set_edition({holo = true})
G.jokers = setmetatable({}, Area)
G.jokers:emplace(bought)
check("hook: Aura or Wheel later changes it", bought.edition.holo == true)

do
  local queued = {}
  G.E_MANAGER = {add_event = function(_, e) queued[#queued + 1] = e end}
  Event = function(t) return t end
  pseudoseed = function(x) return x end
  pseudorandom = function(_, lo) return lo end
  local function jk(ed) local c = fake_card({key = "j_joker"}); c.edition = ed; c.area = nil; return c end
  G.GAME = G.GAME or {}
  G.jokers = {cards = {}, config = {card_limit = 5}}
  local a, b, c = jk({holo = true, type = "holo"}), jk(nil), jk(nil)
  for _, x in ipairs({a, b, c}) do x.area = G.jokers; G.jokers.cards[#G.jokers.cards + 1] = x end
  check("ed joker: give listed", has(R.GIVE, "ed_joker") and R.HOST_GIVE.ed_joker.joker)
  local n1 = R.add_edition_jokers("negative", 1)
  local n2 = R.add_edition_jokers("negative", 5)
  check("ed joker: never picks the same Joker twice before it lands", n1 == 1 and n2 == 1, n1 .. "/" .. n2)
  for _, e in ipairs(queued) do e.func() end
  check("ed joker: Holo Joker untouched", a.edition.holo and not a.edition.negative and a.sets == 0)
  check("ed joker: the other two became Negative once", b.edition.negative and c.edition.negative and b.sets == 1 and c.sets == 1)
  queued = {}
  check("ed joker: nothing left to give", R.add_edition_jokers("foil", 3) == 0 and #queued == 0)
  local d = jk(nil); d.area = G.jokers; G.jokers.cards = {d}
  R.add_edition_jokers("foil", 1)
  d.edition = {polychrome = true}
  for _, e in ipairs(queued) do e.func() end
  check("ed joker: edition gained before the event keeps it", d.edition.polychrome and not d.edition.foil)
  local T2 = require("functions/forge/forge_text")
  check("ed joker: text", T2.give_text({id = "ed_joker", v = "foil", n = 1}, "en"):find("without an edition", 1, true) ~= nil and T2.give_text({id = "ed_joker", v = "negative", n = 2}, "fr"):find("sans édition", 1, true) ~= nil)
  check("ed joker: needs 13", R.need_v(R.clean_rules({{when = "hand_played", give = {{id = "ed_joker", v = "foil", n = 1}}}})) == 13)
  check("ed joker: old rules stay below 13", R.need_v(R.clean_rules({{when = "hand_played", give = {{id = "mult", n = 1}}}})) < 13)
  local kept = R.clean_rules({{when = "hand_played", give = {{id = "ed_joker", v = "tshine_gold", n = 2}}}})
  check("ed joker: bad edition cleaned to Foil", kept[1] and kept[1].give[1].id == "ed_joker" and kept[1].give[1].v == "foil")
  local pc = fake_card({key = "c_base"}); pc.edition = {holo = true, type = "holo"}
  R.change_card(pc, {id = "change", what = "edition", v = "polychrome"})
  check("change: card with an edition keeps it", pc.edition.holo and pc.sets == 0)
  local pc2 = fake_card({key = "c_base"})
  R.change_card(pc2, {id = "change", what = "edition", v = "polychrome"})
  check("change: card without one gets it", pc2.edition and pc2.edition.polychrome)
end

print(string.format("forge always: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
