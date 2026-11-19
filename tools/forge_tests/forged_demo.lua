FF = FF or {}

local Mods = ForgeMods
local O = ForgeOnline

FF.results = FF.results or {}
local function ok(tag, cond, ...)
  FF.results[#FF.results + 1] = cond and true or false
  HLOG("forge_forged", tag, cond and "OK" or "BAD", ...)
end

local function rows() return O.state.data and O.state.data.mods or {} end
local function ref(t) return {config = {ref_table = t}} end

function FF.tab(key)
  UIK.open_tab(key)
end

function FF.on_tab(key)
  return O.state.tab == key and (O.state.status == "ready" or O.state.status == "offline")
end

function FF.check_theme(tag)
  local th = O.state.data and O.state.data.theme
  ok(tag, O.state.status == "ready" and type(th) == "table" and type(th.key) == "string" and O.theme_label(th) ~= "", th and th.key, th and th.week, th and th.left)
end

function FF.check_featured_empty()
  ok("featured starts empty", O.state.tab == "featured" and #rows() == 0)
end

function FF.enter()
  G.FUNCS.forge_online_enter()
end

function FF.check_picker()
  local win = UIK._win
  ok("enter picker lists my mod", win and win.id == "forge_enter" and G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("forge_enter_" .. tostring(FMOD.id)) ~= nil, FMOD.id)
end

function FF.enter_go()
  G.FUNCS.forge_online_enter_go(ref({id = FMOD.id}))
end

function FF.check_entered()
  local m = rows()[1]
  ok("entry shows in the theme", m ~= nil and m.id == FMOD.id and m.theme == true and m.mine == true, m and m.id, m and tostring(m.theme))
end

function FF.rate_open()
  G.FUNCS.forge_online_rate(ref({id = FMOD.remote, name = "Heart Pack"}))
end

function FF.rate_go(n)
  G.FUNCS.forge_online_rate_go(ref({stars = n}))
end

local function row_of(id)
  for _, r in ipairs(rows()) do if r.id == id then return r end end
end

function FF.check_rate_locked(tag)
  local m = row_of(FMOD.remote)
  local btn = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("forge_rate_locked_" .. tostring(FMOD.remote))
  ok(tag or "rate locked before a play", m ~= nil and m.played == nil and btn ~= nil, m and tostring(m.played), btn ~= nil)
end

function FF.rate_locked_tap()
  G.FUNCS.forge_online_rate(ref({id = FMOD.remote, name = "Heart Pack", locked = true}))
end

function FF.check_locked_hint()
  local msg = O.state.msg
  ok("locked rate shows the hint", msg ~= nil and msg.text == mod_loc("Play a run with it first, then you can rate it.") and not (UIK._win and UIK._win.id == "forge_rate"), msg and msg.text)
end

function FF.rate_try(n)
  O.rate(FMOD.remote, n)
end

function FF.check_rate_refused()
  local m = row_of(FMOD.remote)
  local msg = O.state.msg
  ok("server refuses a rating before a play", m ~= nil and tonumber(m.votes) == 0 and m.my == nil and msg ~= nil and msg.text == O.err_text("not_played"), m and m.votes, msg and msg.text)
end

function FF.check_rate_unlocked()
  local m = row_of(FMOD.remote)
  local locked = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("forge_rate_locked_" .. tostring(FMOD.remote))
  ok("rate unlocks after the play", m ~= nil and m.played == true and locked == nil, m and tostring(m.played))
end

function FF.online_remix()
  local m = row_of(FMOD.remote)
  FF.had_local = Mods.get(FMOD.remote) ~= nil
  G.FUNCS.forge_online_remix(ref({id = FMOD.remote, version = m and m.version or 1}))
end

function FF.remix_open()
  local st = ForgeModsUI.export
  return st ~= nil and st.remix == true
end

function FF.check_online_remix()
  local src = Mods.get(FMOD.remote)
  ok("online remix downloads the original first", FF.had_local == false and src ~= nil and not src.mine, tostring(FF.had_local))
end

function FF.check_rated(n)
  local m
  for _, r in ipairs(rows()) do if r.id == FMOD.remote then m = r end end
  ok("rating saved", m ~= nil and tonumber(m.my) == n and tonumber(m.votes) == 1 and tonumber(m.rating) == n, m and m.my, m and m.votes, m and m.rating)
end

function FF.played()
  O.note_run()
end

function FF.counted()
  local raw = love.filesystem.read(O.PLAYED)
  local okj, t = pcall(require("bot.sim.json").decode, raw or "")
  return okj and type(t) == "table" and type(t.sent) == "table" and t.sent[FMOD.remote] == true
end

function FF.remix()
  G.FUNCS.forge_mods_remix(ref({id = FMOD.remote}))
end

function FF.check_remix_export()
  local st = ForgeModsUI.export
  local n = 0
  for _ in pairs(st and st.pick or {}) do n = n + 1 end
  local src = Mods.get(FMOD.remote)
  local want = src and #Mods.all_of(src) or -1
  ok("remix opens the export with its cards", st ~= nil and st.remix == true and n == want and st.info.name == "Heart Pack " .. mod_loc("Remix"), n, st and st.info.name)
end

function FF.export_go()
  G.FUNCS.forge_export_go()
end

function FF.check_remix_mod()
  FF.remix_id = nil
  for _, m in ipairs(Mods.list) do
    if m.mine and m.remix and m.remix[1] and m.remix[1].id == FMOD.remote then FF.remix_id = m.id end
  end
  local m = FF.remix_id and Mods.get(FF.remix_id)
  ok("remix is mine with the credit", m ~= nil and m.remix[1].name == "Heart Pack" and m.remix[1].author == "Tester", FF.remix_id)
end

function FF.publish_remix()
  G.FUNCS.forge_mods_publish(ref({id = FF.remix_id}))
end

function FF.check_newest_credit()
  local m
  for _, r in ipairs(rows()) do if r.id == FF.remix_id then m = r end end
  local c = m and m.remix and m.remix[1]
  ok("online remix row credits the original", c ~= nil and c.id == FMOD.remote and c.name == "Heart Pack" and c.author == "Tester", m and m.id)
  local orig
  for _, r in ipairs(rows()) do if r.id == FMOD.remote then orig = r end end
  ok("original counts its remix", orig ~= nil and tonumber(orig.remixes) == 1, orig and orig.remixes)
end

function FF.check_played_tab()
  local m = rows()[1]
  ok("most played lists the played mod first", m ~= nil and m.id == FMOD.remote and tonumber(m.plays) == 1, m and m.id, m and m.plays)
end

function FF.check_winner()
  local m = rows()[1]
  ok("last week's best is featured", m ~= nil and m.name == "Heart Pack" and tonumber(m.featured) == 1 and tonumber(m.rating) == 5, m and m.name, m and m.featured)
  FMOD.remote = m and m.id
end

function FF.check_best()
  local m = rows()[1]
  ok("best rated lists it first", m ~= nil and m.name == "Heart Pack" and tonumber(m.votes) == 1, m and m.name, m and m.votes)
end

function FF.summary()
  local n, bad = #FF.results, 0
  for _, r in ipairs(FF.results) do if not r then bad = bad + 1 end end
  HLOG("forge_forged_summary", n, bad)
end
