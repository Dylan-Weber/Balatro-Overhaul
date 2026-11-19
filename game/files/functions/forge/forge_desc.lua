local DE = {}

DE.COLOURS = {"mult", "chips", "money", "attention", "green", "purple", "tarot", "planet", "spectral", "enhanced", "legendary", "edition", "dark_edition", "hearts", "diamonds", "spades", "clubs", "inactive"}
DE.NAMES = {
  mult = "Mult", chips = "Chips", money = "Money", attention = "Attention", green = "Green", purple = "Purple", tarot = "Tarot", planet = "Planet",
  spectral = "Spectral", enhanced = "Enhanced", legendary = "Legendary", edition = "Edition", dark_edition = "Negative", hearts = "Hearts",
  diamonds = "Diamonds", spades = "Spades", clubs = "Clubs", inactive = "Grey", red = "Red", blue = "Blue", gold = "Gold", white = "White",
}

local function pieces(s)
  local lead = s:match("^[%(%[\"']+") or ""
  local rest = s:sub(#lead + 1)
  local trail = rest:match("[%.,:;!?%)%]\"']+$") or ""
  local core = rest:sub(1, #rest - #trail)
  local out = {}
  for _, p in ipairs({lead, core, trail}) do if p ~= "" then out[#out + 1] = p end end
  return out
end

function DE.parse(line)
  line = tostring(line or "")
  local words, simple = {}, true
  local cur, chars = nil, {}
  local function flush()
    if #chars == 0 then return end
    local s = {}
    for k, x in ipairs(chars) do s[k] = x[1] end
    local pos = 1
    for k, p in ipairs(pieces(table.concat(s))) do
      local c = chars[pos][2]
      for q = pos, pos + #p - 1 do if chars[q][2] ~= c then simple = false end end
      words[#words + 1] = {t = p, c = c, g = k > 1 or nil}
      pos = pos + #p
    end
    chars = {}
  end
  local i, n = 1, #line
  while i <= n do
    local ch = line:sub(i, i)
    local j = ch == "{" and line:find("}", i + 1, true)
    if j then
      local inner = line:sub(i + 1, j - 1)
      if inner == "" then
        cur = nil
      else
        local c = inner:match("^C:([%w_]+)$")
        if not c then
          simple = false
          c = inner:match("C:([%w_]+)")
          local bg = inner:match("X:([%w_]+)")
          if bg and (not c or c == "white") then c = bg end
        end
        cur = c
      end
      i = j + 1
    elseif ch == " " then
      flush()
      i = i + 1
    else
      if ch == "{" or ch == "}" then simple = false else chars[#chars + 1] = {ch, cur} end
      i = i + 1
    end
  end
  flush()
  return words, simple
end

function DE.build(words)
  local out, cur = {}, nil
  for k, w in ipairs(words or {}) do
    local sp = k > 1 and not w.g
    if w.c ~= cur then
      if cur then out[#out + 1] = "{}" end
      if sp then out[#out + 1] = " " end
      if w.c then out[#out + 1] = "{C:" .. w.c .. "}" end
      cur = w.c
    elseif sp then
      out[#out + 1] = " "
    end
    out[#out + 1] = w.t
  end
  if cur then out[#out + 1] = "{}" end
  return table.concat(out)
end

function DE.plain(words)
  local out = {}
  for k, w in ipairs(words or {}) do
    if k > 1 and not w.g then out[#out + 1] = " " end
    out[#out + 1] = w.t
  end
  return table.concat(out)
end

function DE.split(text)
  local out = {}
  for t in tostring(text or ""):gsub("[{}]", ""):gmatch("%S+") do
    for k, p in ipairs(pieces(t)) do out[#out + 1] = {t = p, g = k > 1 or nil} end
  end
  return out
end

function DE.retext(words, text, brush)
  words = words or {}
  local new = DE.split(text)
  local n, m = #words, #new
  local L = {}
  for i = 0, n do L[i] = {}; for j = 0, m do L[i][j] = 0 end end
  for i = n - 1, 0, -1 do
    for j = m - 1, 0, -1 do
      if words[i + 1].t == new[j + 1].t then L[i][j] = L[i + 1][j + 1] + 1 else L[i][j] = math.max(L[i + 1][j], L[i][j + 1]) end
    end
  end
  local out, i, j = {}, 0, 0
  local gap_old, gap_new = {}, {}
  local function close_gap()
    for k, t in ipairs(gap_new) do
      local c = brush
      if c == nil and gap_old[k] then c = gap_old[k].c end
      out[#out + 1] = {t = t.t, c = c, g = t.g}
    end
    gap_old, gap_new = {}, {}
  end
  while i < n or j < m do
    if i < n and j < m and words[i + 1].t == new[j + 1].t then
      close_gap()
      out[#out + 1] = {t = new[j + 1].t, c = words[i + 1].c, g = new[j + 1].g}
      i, j = i + 1, j + 1
    elseif j < m and (i >= n or L[i][j + 1] >= L[i + 1][j]) then
      gap_new[#gap_new + 1] = new[j + 1]
      j = j + 1
    else
      gap_old[#gap_old + 1] = words[i + 1]
      i = i + 1
    end
  end
  close_gap()
  return out
end

function DE.paint(words, k, brush)
  local w = words and words[k]
  if not w then return end
  if w.c == brush then w.c = nil else w.c = brush end
end

function DE.utf8(s)
  local out = {}
  for ch in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = ch end
  return out
end

function DE.to_chars(lines)
  local out = {}
  for li, line in ipairs(lines or {}) do
    if li > 1 then out[#out + 1] = {ch = "\n"} end
    local cur
    local s = tostring(line or "")
    local i, n = 1, #s
    while i <= n do
      local j = s:sub(i, i) == "{" and s:find("}", i + 1, true)
      if j then
        local inner = s:sub(i + 1, j - 1)
        cur = inner ~= "" and inner:match("C:([%w_]+)") or nil
        local bg = inner:match("X:([%w_]+)")
        if bg and (not cur or cur == "white") then cur = bg end
        i = j + 1
      else
        local ch = s:match("^[%z\1-\127\194-\244][\128-\191]*", i)
        if not ch or ch == "" then ch = s:sub(i, i) end
        if ch ~= "{" and ch ~= "}" then out[#out + 1] = {ch = ch, c = cur} end
        i = i + #ch
      end
    end
  end
  return out
end

function DE.from_chars(chars)
  local lines, buf, cur = {}, {}, nil
  local function close()
    if cur then buf[#buf + 1] = "{}" end
    cur = nil
    lines[#lines + 1] = table.concat(buf)
    buf = {}
  end
  for _, x in ipairs(chars or {}) do
    if x.ch == "\n" then
      close()
    else
      local c = x.c
      if x.ch == " " and cur and c ~= cur then c = cur end
      if c ~= cur then
        if cur then buf[#buf + 1] = "{}" end
        if c then buf[#buf + 1] = "{C:" .. c .. "}" end
        cur = c
      end
      buf[#buf + 1] = x.ch
    end
  end
  close()
  return lines
end

function DE.word_at(chars, i)
  local function sp(x) return not x or x.ch == " " or x.ch == "\n" end
  if sp(chars[i]) then return nil end
  local a, b = i, i
  while not sp(chars[a - 1]) do a = a - 1 end
  while not sp(chars[b + 1]) do b = b + 1 end
  return a, b
end

function DE.hex(c)
  return type(c) == "string" and c:match("^x(%x%x%x%x%x%x)$") or nil
end

function DE.custom(r, g, b)
  local function h(v) return string.format("%02x", math.max(0, math.min(255, math.floor((tonumber(v) or 0) + 0.5)))) end
  return "x" .. h(r) .. h(g) .. h(b)
end

local ok_h, Hooks = pcall(require, "overhaul.hooks")
if ok_h and Hooks and Hooks.wrap then
  Hooks.wrap(_G, "loc_colour", function(orig) return function(c, default, ...)
    local hx = DE.hex(c)
    if hx then return HEX(hx) end
    return orig(c, default, ...)
  end end, {id = "forge.desc.loc_colour"})
end

return DE
