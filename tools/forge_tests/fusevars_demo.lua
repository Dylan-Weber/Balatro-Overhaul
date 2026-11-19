FV = FV or {}
FV.results = {}

local Store = JokerForge.store

local function check(tag, ok, ...)
  FV.results[#FV.results + 1] = ok and true or false
  HLOG("fv_check", tag, ok and "OK" or "BAD", ...)
end

local function B() return ForgeBuilder end
local function reopen() JokerForge.ui.reopen("builder") end

local function draft(t, sec)
  B().new_draft(t)
  G.FUNCS.forge_b_mode({config = {ref_table = {mode = "advanced"}}})
  B().state.sec = sec or "rules"
  reopen()
end

local SAVE = {{when = "hand_played", only = {}, give = {{id = "var_add", var = 1, n = 1}}}}
function FV.piggy() draft({kind = "joker", id = "fvpiggy", name = "Piggy", vars = {{name = "Savings", start = 0}}, rules = SAVE}) end
function FV.hoarder() draft({kind = "joker", id = "fvhoard", name = "Hoarder", vars = {{name = "Savings", start = 0}}, rules = SAVE}) end
function FV.vault()
  draft({kind = "joker", id = "fvvault", name = "Vault", vars = {{name = "Savings", start = 0}},
    rules = {{when = "hand_played", only = {}, give = {{id = "var_mult", var = 1, n = 1}}}}}, "vars")
end
function FV.fusion()
  draft({kind = "fusion", id = "fvfuse", name = "Bank Merger", fields = {a = "j_forge_fvpiggy", b = "j_forge_fvhoard", c = "j_none", out = "j_forge_fvvault", on = "Jokers", auto = false, keep = true, cost = 0}}, "basics")
end
function FV.save() G.FUNCS.forge_b_save() end
function FV.saved()
  local f = Store.get_item("fvfuse")
  check("fusion saved with Keeps upgrades", f and f.fields and f.fields.keep == true and f.fields.out == "j_forge_fvvault", f and f.fields and tostring(f.fields.keep))
  check("Vault saved with Savings", Store.get("fvvault") and Store.get("fvvault").vars[1].name == "Savings")
end

function FV.start() G.FUNCS.start_run(nil, {stake = 1, seed = "FUSEVARS"}) end

local function add(key)
  local c = create_card("Joker", G.jokers, nil, nil, nil, nil, key, "fv")
  c:add_to_deck()
  G.jokers:emplace(c)
  return c
end

function FV.setup()
  FV.p = add("j_forge_fvpiggy")
  FV.h = add("j_forge_fvhoard")
end

local function var1(c) local x = c and c.ability and c.ability.extra return x and type(x.vars) == "table" and tonumber(x.vars[1]) or nil end

function FV.grew()
  check("Piggy and Hoarder each saved 2", var1(FV.p) == 2 and var1(FV.h) == 2, var1(FV.p), var1(FV.h))
end

function FV.fuse()
  local F = require("functions/forge/forge_fusion")
  FV.v = F.fuse(FV.p)
end

function FV.fused()
  local v
  for _, c in ipairs(G.jokers.cards) do if c.config.center.key == "j_forge_fvvault" then v = c end end
  FV.v = v
  check("Vault made", v ~= nil and #G.jokers.cards == 1, #G.jokers.cards)
  check("Vault starts with Savings 4", var1(v) == 4, var1(v))
end

function FV.hover() if FV.v then FV.v:hover() end end
function FV.unhover() if FV.v then FV.v:stop_hover() end end

function FV.reload_check()
  local v
  for _, c in ipairs(G.jokers.cards) do if c.config.center.key == "j_forge_fvvault" then v = c end end
  check("Savings kept after save and reload", var1(v) == 4, var1(v))
end

function FV.summary()
  local bad = 0
  for _, ok in ipairs(FV.results) do if not ok then bad = bad + 1 end end
  HLOG("fv_summary", #FV.results, "checks", bad, "bad", "rule errors", require("functions/forge/forge_rules").errors)
end
