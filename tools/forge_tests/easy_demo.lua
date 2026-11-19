EZ = EZ or {}

local Store = JokerForge.store

EZ.results = {}

local function check(tag, ok, ...)
  EZ.results[#EZ.results + 1] = ok and true or false
  HLOG("ez_check", tag, ok and "OK" or "BAD", ...)
end
EZ.check = check

function EZ.make()
  Store.ensure_dirs()
  Store.list = {}
  Store.save()
  Store.put({id = "ezheart", name = "Heart Fan", rarity = 1, cost = 4, enabled = true, art = {atlas = "Joker", x = 2, y = 11}, mode = "advanced",
    rules = {
      {when = "card_scored", only = {{id = "suit", v = "Hearts"}}, give = {{id = "mult", n = 4}}},
      {when = "hand_played", only = {{id = "hand", v = "Flush"}, {id = "chance", n = 4}}, give = {{id = "xmult", n = 2}, {id = "money", n = 3}}, alt = {{id = "chips", n = 30}}},
      {when = "discard", only = {{id = "money", op = "at_least", n = 10}}, give = {{id = "gain_mult", n = 1}}},
    }})
  JokerForge.joker.register_all()
  Store.set_setting("joker_view", nil)
  ForgeBuilder.state.jview = nil
end

function EZ.builder(id, rule_i)
  local B = ForgeBuilder
  B.edit(id)
  B.state.sec = "rules"
  B.state.rule_i = rule_i or 1
  JokerForge.ui.reopen("builder")
end

function EZ.summary()
  local bad = 0
  for _, ok in ipairs(EZ.results) do if not ok then bad = bad + 1 end end
  HLOG("ez_summary", #EZ.results, "checks", bad, "bad")
end

function EZ.dump()
  local R = require("functions/forge/forge_rules")
  local function ids(list) local o = {} for _, x in ipairs(list) do o[#o + 1] = tostring(x) end return table.concat(o, " ") end
  HLOG("ez_give", ids(R.GIVE))
  HLOG("ez_only", ids(R.ONLY))
  HLOG("ez_when", ids(R.whens("joker")))
end

local R = require("functions/forge/forge_rules")

local function give(slot)
  local B = ForgeBuilder
  return B.state.draft.rules[B.state.rule_i or 1].give[slot or 1]
end

function EZ.mode(m)
  G.FUNCS.forge_b_mode({config = {ref_table = {mode = m}}})
  check("sentence on " .. m, ForgeBuilder.sentence_on() == (m == "simple"))
end

function EZ.type(slot, text)
  local g = give(slot)
  G.FUNCS.forge_b_type({config = {ref_table = {t = g, k = "n", spec = ForgeBuilder.give_num(g)}}})
  ForgeBuilder.state.typing.text = text
  ForgeBuilder.type_commit()
end

function EZ.expect_n(slot, n, err)
  local g = give(slot)
  local ty = ForgeBuilder.state.typing
  check("n " .. tostring(n) .. (err and " with note" or ""), g.n == n and ((ty and ty.err) ~= nil) == err, tostring(g.n), ty and ty.err)
end

function EZ.pick_give(simple)
  G.FUNCS.forge_b_pick_give({config = {ref_table = {slot = #ForgeBuilder.state.draft.rules[ForgeBuilder.state.rule_i].give + 1}}})
  local p = ForgeBuilder.state.pick
  if simple then
    check("simple give picker is short", p and p.all ~= nil and #p.options <= 11 and p.tools == false, p and #p.options)
  else
    check("give picker has tools", p and p.tools == true, p and #p.options)
  end
end

function EZ.more()
  local p = ForgeBuilder.state.pick
  local E = require("functions/forge/forge_easy")
  G.FUNCS.forge_b_choose({config = {ref_table = {i = #p.options}}})
  p = ForgeBuilder.state.pick
  check("more opens the full list", p and p.all == nil and p.tools == true and #p.options > 40 and p.options[#p.options].value ~= E.MORE, p and #p.options)
end

function EZ.default_view()
  check("jokers open in simple", ForgeBuilder.sentence_on() == true)
end

function EZ.sec(name)
  G.FUNCS.forge_b_sec({config = {ref_table = {sec = name}}})
end

function EZ.sample(i, want_score)
  ForgeBuilder.state.sample = i
  JokerForge.ui.reopen("builder")
  local res = ForgeBuilder.sample_result()
  HLOG("ez_sample", i, res.hand, "chips", res.chips, "mult", res.mult, "score", res.score, "money", res.money)
  if want_score then check("sample " .. i .. " score", res.score == want_score, res.score) end
end

function EZ.start(kind)
  ForgeBuilder.start_new()
  G.FUNCS.forge_b_kind({config = {ref_table = {kind = kind}}})
  local n = #require("functions/forge/forge_doc").templates(kind)
  HLOG("ez_start", kind, n)
end

function EZ.start_search(q)
  if not G.CONTROLLER.text_input_hook then
    local input = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("text_input")
    if input then G.FUNCS.select_text_input(input) end
  end
  for _ = 1, 24 do G.FUNCS.text_input_key{key = "backspace"} end
  for ch in q:gmatch(".") do G.FUNCS.text_input_key{key = ch} end
  check("start search typed", ForgeBuilder.state.start_q == q, ForgeBuilder.state.start_q)
end

function EZ.start_pick(key)
  EZ.done_typing()
  local D = require("functions/forge/forge_doc")
  local kind = ForgeBuilder.state.start
  for i, t in ipairs(D.templates(kind)) do
    if t.key == key then
      G.FUNCS.forge_b_template({config = {ref_table = {i = i}}})
      local d = ForgeBuilder.state.draft
      check("started from " .. key, d and d.kind == kind and d.from == key, d and d.name)
      return
    end
  end
  check("template " .. key .. " found", false)
end

function EZ.pick_only()
  G.FUNCS.forge_b_pick_only({config = {ref_table = {slot = 2}}})
end

function EZ.group(g)
  G.FUNCS.forge_b_pick_group({config = {ref_table = {g = g}}})
end

function EZ.group_step(d)
  G.FUNCS.forge_b_pick_group({config = {ref_table = {d = d}}})
end

function EZ.search(q)
  if not G.CONTROLLER.text_input_hook then
    local input = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("text_input")
    if input then G.FUNCS.select_text_input(input) end
  end
  for _ = 1, 24 do G.FUNCS.text_input_key{key = "backspace"} end
  for ch in q:gmatch(".") do G.FUNCS.text_input_key{key = ch} end
  check("search typed", ForgeBuilder.state.pick.q == q, ForgeBuilder.state.pick.q)
end

function EZ.done_typing()
  if G.CONTROLLER.text_input_hook then G.FUNCS.text_input_key{key = "return"} end
end

function EZ.choose_search(id)
  local p = ForgeBuilder.state.pick
  local E = require("functions/forge/forge_easy")
  local shown = E.filter(p.options, p.q, p.group, p.list)
  local hit
  for _, i in ipairs(shown) do if p.options[i].value == id then hit = i end end
  check("search finds " .. id, hit ~= nil, #shown)
  EZ.done_typing()
  if hit then G.FUNCS.forge_b_choose({config = {ref_table = {i = hit}}}) end
end

function EZ.saved()
  G.FUNCS.forge_b_save()
  local c = Store.get("ezheart")
  local g = c and c.rules[1].give
  check("saved rule 1", g and g[1].n == 6 and g[2] and g[2].id == "xmult", g and #g)
  local txt = table.concat(JokerForge.joker.text_for(c, "en"), " ")
  HLOG("ez_text", txt)
end

function EZ.lang(l)
  G.SETTINGS.language = l
  JokerForge.ui.reopen("builder")
end
