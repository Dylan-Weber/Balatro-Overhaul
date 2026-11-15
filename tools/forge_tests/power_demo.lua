FW = FW or {}

local F0 = {chips = 0, mult = 0, xmult = 1, money = 0}

function FW.make()
  local S = JokerForge.store
  S.put_item({id = "pwenh", kind = "enhancement", name = "Rule Card", mode = "advanced", enabled = true, fields = F0, effects = {}, rules = {
    {when = "card_scored", only = {{id = "rank", v = 13}}, give = {{id = "chips", n = 20}, {id = "mult", n = 4}, {id = "xmult", n = 2}}},
    {when = "card_scored", only = {{id = "rank", v = 2}}, give = {{id = "chips", n = 500}}},
  }})
  S.put_item({id = "pwsteel", kind = "enhancement", name = "Held Rule", mode = "advanced", enabled = true, fields = F0, effects = {}, rules = {
    {when = "card_held", only = {}, give = {{id = "xmult", n = 1.5}}},
  }})
  S.put_item({id = "pwvouch", kind = "voucher", name = "Rule Voucher", mode = "advanced", enabled = true, fields = {cost = 10}, effects = {}, rules = {
    {when = "hand_played", only = {{id = "hand", v = "High Card", mode = "is"}}, give = {{id = "chips", n = 15}}},
  }})
  S.put_item({id = "pwgrow", kind = "seal", name = "Grow Seal", mode = "advanced", enabled = true, fields = {}, effects = {}, rules = {
    {when = "card_scored", only = {}, give = {{id = "gain_chips", n = 10}}},
  }})
  ForgeKinds.register_all()
  HLOG("forge_power_make", G.P_CENTERS.m_forge_pwenh ~= nil, G.P_CENTERS.v_forge_pwvouch ~= nil, G.P_SEALS and G.P_SEALS.Forge_pwgrow ~= nil)
end

function FW.setup()
  G.GAME.used_vouchers.v_forge_pwvouch = true
  G.hand.cards[1]:set_ability(G.P_CENTERS.m_forge_pwenh, nil, true)
  G.hand.cards[2]:set_ability(G.P_CENTERS.m_forge_pwsteel, nil, true)
  G.hand.cards[2]:set_base(G.P_CARDS.S_3)
  HLOG("forge_power_setup", G.hand.cards[1].config.center.key, G.hand.cards[2].config.center.key)
end

local function plain_hand()
  for _, x in ipairs(G.hand.cards) do
    if x.config.center.forge_kind == "enhancement" then x:set_ability(G.P_CENTERS.c_base, nil, true) end
  end
end

function FW.seal_setup()
  plain_hand()
  local c = G.hand.cards[1]
  c:set_ability(G.P_CENTERS.c_base, nil, true)
  c:set_seal("Forge_pwgrow", true, true)
  FW.grow = c
  HLOG("forge_power_seal", c.seal)
end

function FW.replay()
  local c = FW.grow
  if c.area ~= G.hand then
    c.area:remove_card(c)
    G.hand:emplace(c)
  end
  plain_hand()
  for i, x in ipairs(G.hand.cards) do if x == c and i ~= 1 then G.hand.cards[i], G.hand.cards[1] = G.hand.cards[1], x end end
  HLOG("forge_power_grow_state", c.ability.forge_rs and c.ability.forge_rs.s_pwgrow and c.ability.forge_rs.s_pwgrow.chips)
end

local function draft(kind, name, rules, vars)
  local B = JokerForge.builder
  B.new_draft({kind = kind, mode = "advanced", name = name})
  local d = B.state.draft
  d.vars = vars or {}
  d.rules = rules
  B.state.rule_i = 1
  B.state.sec = "logic"
  JokerForge.ui.reopen("builder")
end

function FW.enh_draft()
  draft("enhancement", "Lucky Copy", {
    {when = "card_scored", only = {{id = "chance", n = 5}}, give = {{id = "mult", n = 20}}},
    {when = "card_scored", only = {{id = "chance", n = 15}}, give = {{id = "money", n = 20}}},
    {when = "card_scored", only = {{id = "var", var = 1, op = "at_least", n = 3}}, give = {{id = "xmult", n = 2}, {id = "var_set", var = 1, n = 0}}},
  }, {{name = "Hits", start = 0}})
end

function FW.voucher_draft()
  draft("voucher", "Rule Voucher", {
    {when = "blind_selected", only = {{id = "boss"}}, give = {{id = "hand_size", n = 1, run = true}, {id = "money", n = 3}}},
  })
end

function FW.sec(s)
  JokerForge.builder.state.sec = s
  JokerForge.ui.reopen("builder")
end

function FW.text()
  local D = require("functions/forge/forge_doc")
  local d = JokerForge.builder.state.draft
  HLOG("forge_power_text", table.concat(D.lines(d, "en"), " | "))
end
