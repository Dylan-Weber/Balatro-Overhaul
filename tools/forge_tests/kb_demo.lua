FKB = FKB or {}

function FKB.open()
  FKB.ref = {name = "abc"}
  local input = create_text_input({ref_table = FKB.ref, ref_value = "name", max_length = 20, w = 5, h = 0.6, text_scale = 0.4, extended_corpus = true, prompt_text = "type"})
  G.FUNCS.overlay_menu({definition = create_UIBox_generic_options({contents = {{n = G.UIT.R, config = {align = "cm", padding = 0.2}, nodes = {input}}}})})
end

function FKB.select()
  local e = G.OVERLAY_MENU:get_UIE_by_ID("text_input")
  G.FUNCS.select_text_input(e)
end

local function drift(box)
  local worst = 0
  local function walk(n)
    if n.VT and n.T then worst = math.max(worst, math.abs(n.VT.x - n.T.x), math.abs(n.VT.y - n.T.y)) end
    for _, c in pairs(n.children or {}) do walk(c) end
  end
  if box and box.UIRoot then walk(box.UIRoot) end
  return worst
end

function FKB.state(tag)
  local kb = G.CONTROLLER.screen_keyboard
  HLOG("fkb_state", tag, "setting", tostring(G.SETTINGS.ingame_keyboard), "osk", tostring(kb ~= nil), "hook", tostring(G.CONTROLLER.text_input_hook ~= nil))
end

function FKB.watch(get)
  FKB.get = get or function() return G.CONTROLLER and G.CONTROLLER.screen_keyboard end
  if FKB.watching then return end
  FKB.watching = true
  local raw = Game.draw
  Game.draw = function(self, ...)
    local kb = FKB.get()
    if kb and kb ~= FKB.last then
      FKB.last = kb
      local key = kb.UIRoot and kb.UIRoot.children and kb.UIRoot.children[1]
      local function pos(n) return n and n.VT and string.format("%.2f,%.2f", n.VT.x, n.VT.y) or "nil" end
      FKB.first = {pos(kb), pos(key)}
      HLOG("fkb_first_draw", "root", pos(kb), "child", pos(key))
      G.E_MANAGER:add_event(Event({trigger = "after", delay = 0.3, blocking = false, blockable = false, func = function()
        HLOG("fkb_settled", "root", pos(kb), "child", pos(key))
        return true
      end}))
    end
    return raw(self, ...)
  end
end

function FKB.press(key)
  G.FUNCS.key_button({config = {ref_table = {key = key}}})
end

function FKB.report()
  HLOG("fkb_max_drift", string.format("%.3f", FKB.max or -1))
end

function FKB.next_page()
  local hit
  local function walk(n)
    if hit or not n then return end
    if n.config and n.config.button == "uik_page" and n.config.ref_table and n.config.ref_table.d == 1 then hit = n return end
    for _, c in pairs(n.children or {}) do walk(c) end
    if n.config and n.config.object and n.config.object.UIRoot then walk(n.config.object.UIRoot) end
  end
  walk(G.OVERLAY_MENU and G.OVERLAY_MENU.UIRoot)
  HLOG("fkb_next", tostring(hit and hit.config.id))
  if hit then hit:click() end
  local t = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("set_ingame_keyboard")
  HLOG("fkb_toggle_found", tostring(t ~= nil))
end
