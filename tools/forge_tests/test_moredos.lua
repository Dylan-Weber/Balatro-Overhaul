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
local T = require("functions/forge/forge_text")
local X = require("functions/forge/forge_moredos")
local Bal = require("functions/forge/forge_balance")
G.C.RED = {1, 0, 0, 1}
local said
card_eval_status_text = function(_, _, _, _, _, o) said = o end
Event = function(t) return t end
local events = {}
G.E_MANAGER = {add_event = function(_, e) events[#events + 1] = e end}

check("WHEN: Before a discard for Jokers", R.when_ok("joker", "before_discard"))
check("WHEN: Before a discard for run rules", R.when_ok("deck", "before_discard") and R.when_ok("voucher", "before_discard"))
check("WHEN: not for playing card hosts", not R.when_ok("card", "before_discard"))
check("DO: Cancel only before a discard", R.allowed_give("before_discard", "cancel_discard", "joker") and not R.allowed_give("hand_played", "cancel_discard", "joker"))
check("DO: Discard the card only when drawn", R.allowed_give("card_drawn", "discard_drawn", "joker") and not R.allowed_give("discard", "discard_drawn", "joker"))
check("DO: Draw on card hosts", R.allowed_give("discard", "draw", "card") and R.allowed_give("card_scored", "draw", "card"))
check("DO: Draw on run rules", R.allowed_give("hand_played", "draw", "run"))
check("DO: Draw still not on use hosts", not R.allowed_give("used", "draw", "use"))

local bouncer = Store.clean({id = "bouncer", name = "Bouncer", rules = {{when = "before_discard", only = {}, give = {{id = "cancel_discard"}}}}})
check("clean: Bouncer kept", bouncer.rules[1] and bouncer.rules[1].when == "before_discard" and bouncer.rules[1].give[1].id == "cancel_discard")
check("share: 16", R.need_v(bouncer.rules) == 16)
local bad = R.clean_rules({{when = "hand_played", only = {}, give = {{id = "cancel_discard"}, {id = "mult", n = 4}}}})
check("clean: Cancel dropped on another moment", bad[1] and #bad[1].give == 1 and bad[1].give[1].id == "mult")
check("text en", T.sentence(bouncer.rules[1], "en"):find("Before a discard", 1, true) and T.sentence(bouncer.rules[1], "en"):find("cancel the discard", 1, true), T.sentence(bouncer.rules[1], "en"))
check("text fr", T.sentence(bouncer.rules[1], "fr"):find("Avant une défausse", 1, true) and T.sentence(bouncer.rules[1], "fr"):find("annule la défausse", 1, true), T.sentence(bouncer.rules[1], "fr"))
check("text es", T.sentence(bouncer.rules[1], "es"):find("Antes de un descarte", 1, true) and T.sentence(bouncer.rules[1], "es"):find("cancela el descarte", 1, true), T.sentence(bouncer.rules[1], "es"))

local jk = {ability = {extra = {}}, config = {center = {key = "j_forge_bouncer"}}, T = {}}
X.cancel = false
R.calculate(jk, {forge_when = "before_discard", full_hand = {{}, {}}}, bouncer.rules)
check("DO: Cancel sets the flag", X.cancel == true and said and said.message == "Cancelled!")
X.cancel = false
R.calculate(jk, {forge_when = "hand_played"}, bouncer.rules)
check("DO: no cancel on other moments", X.cancel == false)

G.STATE, G.STATES = 1, {SELECTING_HAND = 1}
G.STAGE, G.STAGES = 2, {RUN = 2}
G.hand = {highlighted = {{}, {}}, cards = {}}
G.jokers = {cards = {}}
local ran = 0
local function orig() ran = ran + 1 end
local Mo = require("functions/forge/forge_moments")
local fire = Mo.fire
Mo.fire = function(when) if when == "before_discard" then X.cancel = true end end
X.discard(orig)
check("discard: cancelled discard never happens", ran == 0)
X.discard(orig, nil, true)
check("discard: The Hook's forced discard is never cancelled", ran == 1)
Mo.fire = function() end
X.discard(orig)
check("discard: goes through when nothing cancels", ran == 2)
G.hand.highlighted = {}
X.discard(orig)
check("discard: no cards selected goes straight through", ran == 3)
Mo.fire = fire

local drawn = {area = nil}
G.hand = {highlighted = {}, cards = {drawn}}
drawn.area = G.hand
G.discard = {}
local moved
draw_card = function(from, to, _, _, _, c) moved = {from, to, c} end
local picky = Store.clean({id = "picky", name = "Picky Eater", rules = {{when = "card_drawn", only = {}, give = {{id = "discard_drawn"}, {id = "draw", n = 1}}}}})
check("clean: Picky Eater kept", picky.rules[1] and #picky.rules[1].give == 2, picky.rules[1] and #picky.rules[1].give)
R.DOS.discard_drawn({id = "discard_drawn"}, jk, jk, {forge_when = "card_drawn", other_card = drawn})
for _, e in ipairs(events) do e.func() end
check("Discard the card: drawn card goes to the discard pile", moved and moved[1] == G.hand and moved[2] == G.discard and moved[3] == drawn)
check("text: Discard the card", T.sentence(picky.rules[1], "en"):find("discard the card", 1, true) ~= nil, T.sentence(picky.rules[1], "en"))

local quill = Store.clean_item({id = "quill", kind = "seal", name = "Quill", rules = {{when = "discard", only = {}, give = {{id = "draw", n = 1}}}}})
check("seal: Draw cards kept", quill.rules and quill.rules[1] and quill.rules[1].give[1].id == "draw", quill.rules and #quill.rules)
check("seal with Draw cards needs 16", Cat.need_v(quill) == 16, Cat.need_v(quill))
local flow = Store.clean_item({id = "flow", kind = "deck", name = "Flow Deck", rules = {{when = "hand_played", only = {}, give = {{id = "draw", n = 1}}}}})
check("deck: Draw cards kept", flow.rules and flow.rules[1] and flow.rules[1].give[1].id == "draw")
local plainj = Store.clean({id = "dj", name = "Drawer", rules = {{when = "hand_played", only = {}, give = {{id = "draw", n = 1}}}}})
check("joker Draw cards keeps its old format", R.need_v(plainj.rules) < 16, R.need_v(plainj.rules))

local miser = Store.clean({id = "miser", name = "Miser", rules = {{when = "before_discard", only = {{id = "discards_left", op = "at_most", n = 1}}, give = {{id = "cancel_discard"}}}}})
check("IF on Before a discard: discards left", miser.rules[1] and #miser.rules[1].only == 1, miser.rules[1] and #miser.rules[1].only)
check("balance: Bouncer rated", Bal.of(bouncer) and Bal.of(bouncer).level ~= nil)

local function pc(suit, rank) return {base = {suit = suit, id = rank, value = tostring(rank)}, config = {center = {key = "c_base"}}, ability = {}, is_suit = function(self, x) return self.base.suit == x end, get_id = function(self) return self.base.id end, is_face = function(self) return self.base.id >= 11 and self.base.id <= 13 end} end
local anyh = Store.clean({id = "anyh", name = "Heart Guard", rules = {{when = "before_discard", only = {{id = "discard_any", v = "Hearts"}}, give = {{id = "cancel_discard"}}}}})
check("IF any discarded card kept on Before a discard", anyh.rules[1] and anyh.rules[1].only[1] and anyh.rules[1].only[1].id == "discard_any" and anyh.rules[1].only[1].v == "Hearts")
check("IF any: no count left over", anyh.rules[1].only[1].op == nil and anyh.rules[1].only[1].n == nil)
local allf = Store.clean({id = "allf", name = "Face Toss", rules = {{when = "discard", only = {{id = "discard_all", v = "face"}}, give = {{id = "mult", n = 2}}}}})
check("IF all discarded cards kept on Discard", allf.rules[1] and allf.rules[1].only[1] and allf.rules[1].only[1].id == "discard_all")
check("IF any/all need 16", R.need_v(allf.rules) == 16, R.need_v(allf.rules))
check("IF any not offered on Hand played", not R.allowed_only("hand_played", "discard_any", "joker"))
check("IF any offered on Before a discard", R.allowed_only("before_discard", "discard_any", "joker") and R.allowed_only("before_discard", "discard_all", "joker"))
local h, s2, k = pc("Hearts", 5), pc("Spades", 13), pc("Clubs", 12)
check("any: one Heart among Spades", R.check({id = "discard_any", v = "Hearts"}, {full_hand = {s2, h}}))
check("any: no Heart", not R.check({id = "discard_any", v = "Hearts"}, {full_hand = {s2, k}}))
check("all: two faces", R.check({id = "discard_all", v = "face"}, {full_hand = {s2, k}}))
check("all: a 5 breaks it", not R.check({id = "discard_all", v = "face"}, {full_hand = {s2, k, h}}))
check("all: empty discard is false", not R.check({id = "discard_all", v = "face"}, {full_hand = {}}))
check("text en any", T.only_text({id = "discard_any", v = "Hearts"}, "en", {}):find("the discard includes", 1, true) ~= nil, T.only_text({id = "discard_any", v = "Hearts"}, "en", {}))
check("text fr all", T.only_text({id = "discard_all", v = "face"}, "fr", {}):find("que des", 1, true) ~= nil, T.only_text({id = "discard_all", v = "face"}, "fr", {}))
check("text es any", T.only_text({id = "discard_any", v = "face"}, "es", {}):find("incluye", 1, true) ~= nil)
local vals = R.VALUES_ONLY.discard_any()
check("values: picker lists cards", #vals > 5 and vals[1].label ~= nil, #vals)

print(string.format("moredos: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
