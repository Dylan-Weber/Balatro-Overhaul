TW = TW or {}

local ART = {atlas = "Joker", x = 0, y = 0}
local T = require("functions/forge/forge_text")

function TW.make()
  JokerForge.store.put({id = "twper", name = "Toll Booth", rarity = 1, cost = 4, enabled = true, mode = "advanced", art = ART,
    rules = {{when = "hand_played", only = {{id = "boss"}}, give = {{id = "money_per", n = 1, per = "jokers"}}, alt = {{id = "lose_money_per", n = 2, per = "jokers"}}}}})
  JokerForge.store.put({id = "twvar", name = "Tax Ledger", rarity = 1, cost = 4, enabled = true, mode = "advanced", art = ART, vars = {{name = "Debt", start = 3}},
    rules = {{when = "hand_played", only = {{id = "boss"}}, give = {{id = "var_money", n = 1, var = 1}}, alt = {{id = "var_lose_money", n = 1, var = 1}}}}})
  JokerForge.joker.register_all()
  for _, lang in ipairs({"en", "fr", "es"}) do
    for _, c in ipairs(JokerForge.store.all()) do
      HLOG("tw_text", lang, c.id, table.concat(T.rule_lines(c, lang) or {}, " | "))
    end
  end
end

function TW.ready()
  G.GAME.dollars = 20
  TW.hp = G.GAME.current_round.hands_played
  HLOG("tw_ready", G.GAME.dollars, #G.jokers.cards, tostring(G.GAME.blind.boss))
end

function TW.idle()
  return G.STATE == G.STATES.SELECTING_HAND and G.hand and #G.hand.cards > 0 and not G.CONTROLLER.locked and G.GAME.current_round.hands_played > (TW.hp or 0)
end

function TW.check(expect)
  local ok = G.GAME.dollars == expect
  HLOG("tw_check", "dollars", tostring(G.GAME.dollars), "expect", expect, ok and "OK" or "BAD", "rule errors", require("functions/forge/forge_rules").errors)
end

function TW.hover(id)
  for _, c in ipairs(G.jokers.cards) do
    if c.config.center.key == "j_forge_" .. id then c:hover() end
  end
end
