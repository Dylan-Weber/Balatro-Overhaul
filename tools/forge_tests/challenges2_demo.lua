CX = CX or {}
CX.results = {}

local Store = JokerForge.store

local function check(tag, ok, ...)
  CX.results[#CX.results + 1] = ok and true or false
  HLOG("cx_check", tag, ok and "OK" or "BAD", ...)
end

local function B() return ForgeBuilder end
local function reopen() JokerForge.ui.reopen("builder") end

function CX.save() G.FUNCS.forge_b_save() end

function CX.saved(id, want)
  local c = Store.get_item(id)
  if not c then for _, j in ipairs(Store.all()) do if j.id == id then c = j end end end
  local s = require("bot.sim.json").encode(c and c.effects or {})
  HLOG("cx_item", id, s)
  check("saved " .. id, c ~= nil and (not want or s:find(want, 1, true) ~= nil), s)
end

function CX.party()
  local p = G.PROFILES[G.SETTINGS.profile]
  p.challenges_unlocked = math.max(p.challenges_unlocked or 0, 5)
  B().new_draft({kind = "challenge", id = "cxparty", name = "Ace Party", fields = {}, effects = {
    {id = "ch_copies", n = 2}, {id = "ch_add_rank", v = "Ace", n = 8}, {id = "ch_add_suit", v = "Hearts", n = 13},
    {id = "ch_enh_n", v = "m_glass", n = 5}, {id = "ch_seal_n", v = "Red", n = 3}, {id = "ch_ed_n", v = "foil", n = 2},
    {id = "ch_joker", v = "j_joker"}, {id = "ch_joker_rental"}, {id = "hand_size", n = 1}, {id = "start_consumable", v = "Tarot", n = 1},
  }})
  G.FUNCS.forge_b_mode({config = {ref_table = {mode = "advanced"}}})
  B().state.sec = "rules"
  reopen()
end

function CX.start()
  local Ch = require("functions/forge/forge_challenges")
  local at
  for i, ch in ipairs(G.CHALLENGES or {}) do
    if type(ch) == "table" and ch.forge_ch and Ch.id_of(ch.id) == "cxparty" then at = i end
  end
  check("Ace Party challenge exists", at ~= nil)
  if at then G.FUNCS.start_challenge_run({config = {id = at}}) end
end

function CX.deck()
  local n, aces, hearts, glass, red, foil = #G.playing_cards, 0, 0, 0, 0, 0
  for _, c in ipairs(G.playing_cards) do
    if c.base.value == "Ace" then aces = aces + 1 end
    if c.base.suit == "Hearts" then hearts = hearts + 1 end
    if c.config.center.key == "m_glass" then glass = glass + 1 end
    if c.seal == "Red" then red = red + 1 end
    if c.edition and c.edition.foil then foil = foil + 1 end
  end
  check("deck: 52 x 2 + 8 Aces + 13 Hearts = 125 cards", n == 125, n)
  check("deck: 17 Aces (8 + 8 extra + the Ace of the extra Hearts)", aces == 17, aces)
  check("deck: at least 39 Hearts", hearts >= 39, hearts)
  check("deck: 5 Glass, 3 Red Seals, 2 Foil", glass == 5 and red == 3 and foil == 2, glass, red, foil)
  check("deck: starting deck size follows", G.GAME.starting_deck_size == 125, G.GAME.starting_deck_size)
  local j = G.jokers.cards[1]
  check("Joker: the starting Joker is Rental", j and j.ability.rental == true, j and tostring(j.ability.rental))
  check("hand size +1", G.hand.config.card_limit == 9, G.hand.config.card_limit)
  check("starts with a Tarot", #G.consumeables.cards == 1 and G.consumeables.cards[1].ability.set == "Tarot", #G.consumeables.cards)
end

function CX.small() G.FUNCS.select_blind(G.blind_select_opts[string.lower(G.GAME.blind_on_deck)]:get_UIE_by_ID("select_blind_button")) end

function CX.summary()
  local ok, bad = 0, 0
  for _, r in ipairs(CX.results) do if r then ok = ok + 1 else bad = bad + 1 end end
  HLOG("cx_summary", ok, "ok", bad, "bad")
end
