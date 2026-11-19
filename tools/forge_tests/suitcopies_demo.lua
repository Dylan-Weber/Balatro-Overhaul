HC = HC or {}
HC.results = {}

local Suits = require("functions/forge/forge_suits")

local function check(tag, ok, ...)
  HC.results[#HC.results + 1] = ok and true or false
  HLOG("hc_check", tag, ok and "OK" or "BAD", ...)
end

function HC.field_shown(n)
  local f = ForgeBuilder.state.draft.fields
  check("builder keeps " .. n .. " copies", tonumber(f.copies) == n, f.copies)
end

function HC.start(seed)
  HC.t0 = love.timer.getTime()
  G.FUNCS.start_run(nil, {stake = 1, seed = seed or "COPIES"})
end

function HC.ready()
  local dt = love.timer.getTime() - (HC.t0 or love.timer.getTime())
  HLOG("hc_start_seconds", string.format("%.2f", dt))
  check("run starts in under 8 s", dt < 8, dt)
end

function HC.deck(id, copies)
  local s = Suits.of_id(id)
  local n, per = 0, {}
  for _, c in ipairs(G.playing_cards) do
    if s and c.base.suit == s.key then
      n = n + 1
      per[c.base.value] = (per[c.base.value] or 0) + 1
    end
  end
  local even = true
  for _, v in pairs(per) do if v ~= copies then even = false end end
  check("deck: " .. (13 * copies) .. " cards of the suit", n == 13 * copies, n)
  check("deck: " .. copies .. " of each rank", even)
  check("deck: size", #G.playing_cards == 52 + 13 * copies, #G.playing_cards)
  check("deck: starting size", G.GAME.starting_deck_size == #G.playing_cards, G.GAME.starting_deck_size)
  check("deck: draw pile limit", G.deck.config.card_limit == #G.playing_cards, G.deck.config.card_limit)
end

function HC.save_size()
  local t = love.timer.getTime()
  save_run()
  local raw = STR_PACK(G.ARGS.save_run)
  local packed = love.data.compress("string", "deflate", raw, 1)
  local dt = love.timer.getTime() - t
  HLOG("hc_save", "raw", #raw, "compressed", #packed, "seconds", string.format("%.2f", dt))
  check("save under 2 MB compressed", #packed < 2 * 1024 * 1024, #packed)
end

function HC.view_deck()
  HC.t1 = love.timer.getTime()
  G.FUNCS.overlay_menu({definition = G.UIDEF.view_deck()})
  HLOG("hc_view_deck_seconds", string.format("%.2f", love.timer.getTime() - HC.t1))
end

function HC.fps()
  local f = love.timer.getFPS()
  HLOG("hc_fps", f)
  check("stays above 10 fps off-screen", f >= 10, f)
end

function HC.summary()
  local ok, bad = 0, 0
  for _, r in ipairs(HC.results) do if r then ok = ok + 1 else bad = bad + 1 end end
  HLOG("hc_summary", ok, "ok", bad, "bad", "rule errors", require("functions/forge/forge_rules").errors)
end

function HC.type_copies(n)
  local K = require("functions/forge/forge_catalog").kind("suit")
  local spec
  for _, list in ipairs({K.fields or {}, K.adv_fields or {}}) do
    for _, f in ipairs(list) do if f.id == "copies" then spec = f.num end end
  end
  ForgeBuilder.state.typing = {t = ForgeBuilder.state.draft.fields, k = "copies", spec = spec, text = tostring(n)}
  ForgeBuilder.type_commit()
end
