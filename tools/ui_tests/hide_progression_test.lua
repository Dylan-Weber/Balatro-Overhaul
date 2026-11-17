package.path = "assets/?.lua;" .. package.path
local fails, passes = 0, 0
local function ok(cond, msg)
  if cond then passes = passes + 1 else fails = fails + 1; print("FAIL " .. msg) end
end

local clock = 0
love = {timer = {getTime = function() return clock end}, filesystem = {getInfo = function() return nil end}}
function mod_loc(text) return text end
function mod_loc_register() end
function play_sound() end
function number_format(number) return tostring(number) end
Event = function(event_args) return event_args end
local function box(definition, config)
  return {def = definition, config = config, states = {collide = {}}, remove = function(self) self.REMOVED = true end,
    UIRoot = {children = {}}, alignment = {offset = {x = 0, y = 0}}}
end
UIBox = box
UIK = setmetatable({touch = function() return true end, portrait = function() return false end, C = {}}, {__index = function(_, element_kind)
  return function(args) return {uik = element_kind, args = args} end
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
G.SETTINGS.hide_progression, G.SETTINGS.hide_progression_popups = false, false
ok(progression_hidden() == false and progression_popups_hidden() == false, "shown by default")
local toasts = {}
local real_toast = PUI.toast
PUI.toast = function(toast) toasts[#toasts + 1] = toast return real_toast(toast) end
progression_notify("level", 3)
ok(#toasts == 1, "level toast with the setting off")
PUI.pump = function() end
PUI.queue = {}
real_toast({kind = "milestone", a = "X", b = 5})
ok(#PUI.queue == 1, "toast queued with the setting off")
PUI.badge_tick(true)
ok(G.progression_badge ~= nil and PUI.badge.text == "2", "red count on the Progression button with the setting off")

-- popups setting on: no toasts, but the badge and buttons stay
G.SETTINGS.hide_progression_popups = true
ok(progression_popups_hidden() == true and progression_hidden() == false, "popups setting is separate from the buttons setting")
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
ok(G.progression_badge ~= nil, "popups setting leaves the red count alone")
PUI.queue = {{kind = "level", a = 5}}
dofile("assets/functions/progression_ui.lua")
ProgressionUI.pump()
ok(#ProgressionUI.queue == 0 and ProgressionUI.box == nil, "a toast queued before the setting changed is dropped")

-- buttons setting on: no badge
G.SETTINGS.hide_progression = true
ok(progression_hidden() == true, "buttons hidden when the setting is on")
PUI.set_hidden()
ok(G.progression_badge == nil, "turning the buttons setting on drops the red count")
clock = clock + 1
PUI.badge_tick(true)
ok(G.progression_badge == nil, "no red count while hidden, even with quests ready")

-- XP still counts while hidden, so turning it back on shows the real level
local profile_progression = G.PROFILES[1].progression
local xp_before = profile_progression.total_xp
progression_add_xp(5000, "test")
ok(profile_progression.total_xp == xp_before + 5000, "XP still adds up while hidden")

-- Settings: default and toggle
UIK.toggle = function(args) return {toggle = args} end
SettingsUI = {}
G.SETTINGS.GRAPHICS = {}
G.SETTINGS.hide_progression, G.SETTINGS.hide_progression_popups = nil, nil
dofile("assets/functions/settings/catalog.lua")
SettingsUI.defaults()
ok(G.SETTINGS.hide_progression == false and G.SETTINGS.hide_progression_popups == false, "both default to shown")
local found, found_popups
for _, category in ipairs(SettingsUI.CATS) do
  if category.key == "gameplay" then
    bom_match, FairLock = nil, nil
    localize = function(text) return text end
    local built, sections = pcall(category.build, {map = {}, order = {}})
    ok(built, "gameplay settings build: " .. tostring(sections))
    for _, section in ipairs(built and sections or {}) do
      for _, item in ipairs(section.items or {}) do
        if type(item) == "table" and item.toggle and item.toggle.id == "set_hide_progression" then found = {section = section.title, args = item.toggle} end
        if type(item) == "table" and item.toggle and item.toggle.id == "set_hide_progression_popups" then found_popups = {section = section.title, args = item.toggle} end
      end
    end
  end
end
ok(found and found.section == "Progression" and found_popups and found_popups.section == "Progression", "both toggles in Gameplay > Progression")
ok(found_popups and found_popups.args.ref_value == "hide_progression_popups", "popups toggle saves to hide_progression_popups")
ok(found and found.args.ref_table == G.SETTINGS and found.args.ref_value == "hide_progression", "toggle saves to G.SETTINGS.hide_progression")
local changed = 0
PUI.set_hidden = function() changed = changed + 1 end
G.STAGE = G.STAGES.RUN
G.save_settings = function() end
if found then found.args.callback(true) end
if found_popups then found_popups.args.callback(true) end
ok(changed == 2, "toggling clears toasts and the red count right away")

-- The Casino: no Quests door while hidden
for _, func_name in ipairs({"open_quest_menu", "open_run_history", "open_shop_menu", "open_profile_menu"}) do G.FUNCS[func_name] = function() end end
dofile("assets/functions/town/town.lua")
local function tavern()
  for _, shown_place in ipairs(Town.shown()) do
    if shown_place.place.key == "tavern" then
      local names = {}
      for _, door in ipairs(shown_place.doors) do names[door.button] = true end
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

-- Jimbo never points at the quests (popups setting)
G.SETTINGS.hide_progression, G.SETTINGS.hide_progression_popups = false, true
JIMBO_COMMENTS = nil
local loaded, load_error = pcall(dofile, "assets/functions/jimbo_comments.lua")
ok(loaded, "jimbo comments load: " .. tostring(load_error))
if loaded then
  local said = {}
  JIMBO_COMMENTS.show = function(text) said[#said + 1] = text return true end
  for _ = 1, 60 do JIMBO_COMMENTS.fire("menu", nil, nil, true) end
  local quests = 0
  for _, line in ipairs(said) do if line:find("quests") then quests = quests + 1 end end
  ok(#said == 60 and quests == 0, "no quest line from Jimbo while hidden")
  G.SETTINGS.hide_progression_popups = false
  said = {}
  for _ = 1, 60 do JIMBO_COMMENTS.fire("menu", nil, nil, true) end
  quests = 0
  for _, line in ipairs(said) do if line:find("quests") then quests = quests + 1 end end
  ok(quests > 0, "quest line still used with the setting off")
end

print(string.format("hide progression tests: %d passed, %d failed", passes, fails))
os.exit(fails == 0 and 0 or 1)
