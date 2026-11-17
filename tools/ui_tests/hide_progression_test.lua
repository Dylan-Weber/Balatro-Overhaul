package.path = "assets/?.lua;" .. package.path
local fails, passes = 0, 0
local function ok(cond, msg)
  if cond then passes = passes + 1 else fails = fails + 1; print("FAIL " .. msg) end
end

local clock = 0
love = {timer = {getTime = function() return clock end}, filesystem = {getInfo = function() return nil end}}
function mod_loc(s) return s end
function mod_loc_register() end
function play_sound() end
function number_format(n) return tostring(n) end
Event = function(t) return t end
local function box(def, cfg)
  return {def = def, config = cfg, states = {collide = {}}, remove = function(self) self.REMOVED = true end,
    UIRoot = {children = {}}, alignment = {offset = {x = 0, y = 0}}}
end
UIBox = box
UIK = setmetatable({touch = function() return true end, portrait = function() return false end, C = {}}, {__index = function(t, k)
  return function(args) return {uik = k, args = args} end
end})
Game = {update = function() end}

local menu_btn = {T = {h = 0.5}}
G = {
  SETTINGS = {profile = 1, language = "en-us"},
  PROFILES = {[1] = {progression = {level = 1, xp = 0, total_xp = 0, milestones = {}, balacoin = 0}}},
  STAGES = {RUN = 1, MAIN_MENU = 2}, STAGE = 2,
  C = setmetatable({}, {__index = function() return {1, 1, 1, 1} end}),
  UIT = {ROOT = 0, R = 1, C = 2, T = 3, O = 4},
  E_MANAGER = {add_event = function() end},
  ROOM_ATTACH = {T = {x = 0, y = 0, w = 10, h = 10}},
  ROOM = {T = {x = 0}},
  MAIN_MENU_UI = {get_UIE_by_ID = function(_, id) return id == "progression_button" and menu_btn or nil end},
  FUNCS = {overlay_menu = function() end},
}

local ready = 2
QuestManager = {ready_count = function() return ready end, refresh = function() end, claimable = function() return true end,
  DEFS = {}, find = function() end}
dofile("assets/functions/progress_gate.lua")
dofile("assets/functions/progress_events.lua")
dofile("assets/functions/progression.lua")
dofile("assets/functions/progression_ui.lua")
local PUI = ProgressionUI
function progression_unclaimed_levels() return {} end

-- setting off: everything shows as before
G.SETTINGS.hide_progression = false
ok(progression_hidden() == false, "shown by default")
local toasts = {}
local real_toast = PUI.toast
PUI.toast = function(t) toasts[#toasts + 1] = t return real_toast(t) end
progression_notify("level", 3)
ok(#toasts == 1, "level toast with the setting off")
PUI.pump = function() end
PUI.queue = {}
real_toast({kind = "milestone", a = "X", b = 5})
ok(#PUI.queue == 1, "toast queued with the setting off")
PUI.badge_tick(true)
ok(G.progression_badge ~= nil and PUI.badge.text == "2", "red count on the Progression button with the setting off")

-- setting on
G.SETTINGS.hide_progression = true
ok(progression_hidden() == true, "hidden when the setting is on")
toasts = {}
progression_notify("level", 4)
progression_notify("milestone", "First Victory", 500)
progression_notify("mp_level", 2)
ok(#toasts == 0, "no level, milestone or multiplayer level toast")
PUI.queue = {}
real_toast({kind = "level", a = 4})
QuestManager.popup({id = "q"})
ok(#PUI.queue == 0, "quest and level toasts are not queued")
PUI.set_hidden()
ok(G.progression_badge == nil, "turning the setting on drops the red count")
clock = clock + 1
PUI.badge_tick(true)
ok(G.progression_badge == nil, "no red count while hidden, even with quests ready")
PUI.queue = {{kind = "level", a = 5}}
dofile("assets/functions/progression_ui.lua")
ProgressionUI.pump()
ok(#ProgressionUI.queue == 0 and ProgressionUI.box == nil, "a toast queued before the setting changed is dropped")

-- XP still counts while hidden, so turning it back on shows the real level
local pr = G.PROFILES[1].progression
local before = pr.total_xp
progression_add_xp(5000, "test")
ok(pr.total_xp == before + 5000, "XP still adds up while hidden")

-- Settings: default and toggle
UIK.toggle = function(args) return {toggle = args} end
SettingsUI = {}
G.SETTINGS.GRAPHICS = {}
G.SETTINGS.hide_progression = nil
dofile("assets/functions/settings/catalog.lua")
SettingsUI.defaults()
ok(G.SETTINGS.hide_progression == false, "defaults to shown")
local found
for _, c in ipairs(SettingsUI.CATS) do
  if c.key == "gameplay" then
    bom_match, FairLock = nil, nil
    localize = function(s) return s end
    local ok_build, sections = pcall(c.build, {map = {}, order = {}})
    ok(ok_build, "gameplay settings build: " .. tostring(sections))
    for _, s in ipairs(ok_build and sections or {}) do
      for _, it in ipairs(s.items or {}) do
        if type(it) == "table" and it.toggle and it.toggle.id == "set_hide_progression" then found = {section = s.title, args = it.toggle} end
      end
    end
  end
end
ok(found and found.section == "Progression", "Hide Progression toggle in Gameplay > Progression")
ok(found and found.args.ref_table == G.SETTINGS and found.args.ref_value == "hide_progression", "toggle saves to G.SETTINGS.hide_progression")
local changed = 0
PUI.set_hidden = function() changed = changed + 1 end
G.STAGE = G.STAGES.RUN
G.save_settings = function() end
if found then found.args.callback(true) end
ok(changed == 1, "toggling clears toasts and the red count right away")

-- The Casino: no Quests door while hidden
for _, k in ipairs({"open_quest_menu", "open_run_history", "open_shop_menu", "open_profile_menu"}) do G.FUNCS[k] = function() end end
dofile("assets/functions/town/town.lua")
local function tavern()
  for _, p in ipairs(Town.shown()) do
    if p.place.key == "tavern" then
      local names = {}
      for _, d in ipairs(p.doors) do names[d.button] = true end
      return names
    end
  end
  return {}
end
G.SETTINGS.hide_progression = false
ok(tavern().open_quest_menu, "Quests door shown with the setting off")
G.SETTINGS.hide_progression = true
local doors = tavern()
ok(not doors.open_quest_menu and doors.open_run_history, "Quests door hidden, Run History kept")

-- Jimbo never points at the quests
JIMBO_COMMENTS = nil
local ok_jc, err = pcall(dofile, "assets/functions/jimbo_comments.lua")
ok(ok_jc, "jimbo comments load: " .. tostring(err))
if ok_jc then
  local said = {}
  JIMBO_COMMENTS.show = function(text) said[#said + 1] = text return true end
  for _ = 1, 60 do JIMBO_COMMENTS.fire("menu", nil, nil, true) end
  local quests = 0
  for _, s in ipairs(said) do if s:find("quests") then quests = quests + 1 end end
  ok(#said == 60 and quests == 0, "no quest line from Jimbo while hidden")
  G.SETTINGS.hide_progression = false
  said = {}
  for _ = 1, 60 do JIMBO_COMMENTS.fire("menu", nil, nil, true) end
  quests = 0
  for _, s in ipairs(said) do if s:find("quests") then quests = quests + 1 end end
  ok(quests > 0, "quest line still used with the setting off")
end

print(string.format("hide progression tests: %d passed, %d failed", passes, fails))
os.exit(fails == 0 and 0 or 1)
