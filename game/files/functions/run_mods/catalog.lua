local C = {}

local function L(s) return mod_loc and mod_loc(s) or s end
local function fmt(s, ...) local ok, r = pcall(string.format, L(s), ...) return ok and r or s end

C.VANILLA_DECKS = {"b_red", "b_blue", "b_yellow", "b_green", "b_black", "b_magic", "b_nebula", "b_ghost", "b_abandoned", "b_checkered", "b_zodiac", "b_painted", "b_anaglyph", "b_plasma", "b_erratic"}
C.VANILLA = {}
for i, k in ipairs(C.VANILLA_DECKS) do C.VANILLA[k] = i end

C.STATS = {
    {key = "hands", param = "hands", label = "Hands"},
    {key = "discards", param = "discards", label = "Discards"},
    {key = "hand_size", param = "hand_size", label = "Hand size"},
    {key = "joker_slot", param = "joker_slots", label = "Joker slots"},
    {key = "consumable_slot", param = "consumable_slots", label = "Consumable slots"},
    {key = "dollars", param = "dollars", label = "Starting money", money = true},
}
C.STAT_BY_KEY = {}
for _, s in ipairs(C.STATS) do C.STAT_BY_KEY[s.key] = s end

local function signed(n, money)
    n = tonumber(n) or 0
    local s = n >= 0 and "+" or "-"
    return s .. (money and "$" or "") .. tostring(math.abs(n))
end
C.signed = signed

local function name_of(key)
    local c = G and G.P_CENTERS and G.P_CENTERS[key]
    if not c then return tostring(key) end
    if localize then
        local ok, n = pcall(localize, {type = 'name_text', set = c.set, key = key})
        if ok and type(n) == "string" and n ~= "" and n ~= "ERROR" then return n end
    end
    return c.name or tostring(key)
end
C.name_of = name_of

C.HANDLERS = {
    {key = "hands", label = function(v) return fmt("%s hands", signed(v)) end},
    {key = "discards", label = function(v) return fmt("%s discards", signed(v)) end},
    {key = "hand_size", label = function(v) return fmt("%s hand size", signed(v)) end},
    {key = "joker_slot", label = function(v) return fmt("%s Joker slots", signed(v)) end},
    {key = "consumable_slot", label = function(v) return fmt("%s consumable slots", signed(v)) end},
    {key = "dollars", label = function(v) return fmt("%s starting money", signed(v, true)) end},
    {key = "reroll_discount", label = function(v) return fmt("Rerolls cost $%d less", tonumber(v) or 0) end},
    {key = "extra_hand_bonus", label = function(v) return fmt("$%d per hand left", tonumber(v) or 0) end},
    {key = "extra_discard_bonus", label = function(v) return fmt("$%d per discard left", tonumber(v) or 0) end},
    {key = "no_interest", label = function() return L("No interest") end},
    {key = "spectral_rate", label = function() return L("Spectral cards in the shop") end},
    {key = "remove_faces", label = function() return L("No face cards") end},
    {key = "randomize_rank_suit", label = function() return L("Random ranks and suits") end},
    {key = "ante_scaling", label = function(v) return fmt("Blinds x%s bigger", tostring(v)) end},
    {key = "edition", extra = {"edition_count"}, label = function(v, cfg)
        local n = tonumber(cfg.edition_count) or 1
        return fmt("%d cards get %s", n, name_of("e_" .. tostring(v)))
    end},
}
C.HANDLED = {voucher = true, vouchers = true, consumables = true}
for _, h in ipairs(C.HANDLERS) do
    C.HANDLED[h.key] = true
    for _, e in ipairs(h.extra or {}) do C.HANDLED[e] = true end
end

C.NAMED = {
    b_checkered = {{key = "suits", name = "Checkered Deck", label = "Only Spades and Hearts"}},
    b_anaglyph = {{key = "double_tag", trigger = "Anaglyph Deck", label = "Double Tag after each Boss Blind"}},
    b_plasma = {{key = "balance", trigger = "Plasma Deck", label = "Chips and Mult are balanced"}},
}

local function custom_code(center)
    if type(center) ~= "table" then return false end
    if center.mp_deck or center.forge_kind or center.forge then return true end
    if type(center.apply) == "function" or type(center.calculate) == "function" or type(center.trigger_effect) == "function" then return true end
    if center.mod and not C.VANILLA[center.key] then return true end
    for k in pairs(center.config or {}) do
        if not C.HANDLED[k] then return true end
    end
    return false
end
C.custom_code = custom_code

local function has_value(v)
    return v ~= nil and v ~= false and v ~= 0
end

function C.deck_pieces(center)
    if type(center) ~= "table" or not center.key then return {} end
    local key, cfg, out = center.key, center.config or {}, {}
    local function add(p)
        p.deck = key
        p.id = key .. ":" .. p.key
        out[#out + 1] = p
    end
    if cfg.customDeck then
        add({key = "own", own = true, label = L("The deck's own effect")})
        return out
    end
    for _, h in ipairs(C.HANDLERS) do
        local v = cfg[h.key]
        if has_value(v) then
            local pc = {[h.key] = v}
            for _, e in ipairs(h.extra or {}) do pc[e] = cfg[e] end
            add({key = h.key, cfg = pc, stat = C.STAT_BY_KEY[h.key] and h.key or nil, value = v, label = h.label(v, cfg)})
        end
    end
    local vouchers = {}
    if type(cfg.voucher) == "string" then vouchers[#vouchers + 1] = cfg.voucher end
    if type(cfg.vouchers) == "table" then for _, v in ipairs(cfg.vouchers) do vouchers[#vouchers + 1] = v end end
    for _, v in ipairs(vouchers) do
        add({key = "voucher_" .. v, cfg = {vouchers = {v}}, label = fmt("Voucher: %s", name_of(v))})
    end
    if type(cfg.consumables) == "table" and #cfg.consumables > 0 then
        local counts, order = {}, {}
        for _, c in ipairs(cfg.consumables) do
            if not counts[c] then order[#order + 1] = c end
            counts[c] = (counts[c] or 0) + 1
        end
        local parts = {}
        for _, c in ipairs(order) do parts[#parts + 1] = counts[c] > 1 and (name_of(c) .. " x" .. counts[c]) or name_of(c) end
        add({key = "consumables", cfg = {consumables = cfg.consumables}, label = fmt("Start with %s", table.concat(parts, ", "))})
    end
    for _, n in ipairs(C.NAMED[key] or {}) do
        add({key = n.key, name = n.name, trigger = n.trigger, label = L(n.label)})
    end
    if not C.VANILLA[key] and custom_code(center) then
        add({key = "own", own = true, label = L("The deck's own effect")})
    end
    return out
end

function C.deck_list()
    local out, seen = {}, {}
    local P = G and G.P_CENTERS or {}
    for _, k in ipairs(C.VANILLA_DECKS) do
        if P[k] then out[#out + 1] = P[k]; seen[k] = true end
    end
    local rest = {}
    for _, c in ipairs(G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Back or {}) do
        if type(c) == "table" and c.key and not seen[c.key] and not c.omit and c.key ~= "b_challenge" and not c.no_collection and #C.deck_pieces(c) > 0 then
            rest[#rest + 1] = c
            seen[c.key] = true
        end
    end
    table.sort(rest, function(a, b)
        local oa, ob = tonumber(a.order) or 999, tonumber(b.order) or 999
        if oa ~= ob then return oa < ob end
        return tostring(a.key) < tostring(b.key)
    end)
    for _, c in ipairs(rest) do out[#out + 1] = c end
    return out
end

function C.piece(id)
    if type(id) ~= "string" then return nil end
    local key = id:match("^([^:]+):")
    local center = key and G and G.P_CENTERS and G.P_CENTERS[key]
    if not center then return nil end
    for _, p in ipairs(C.deck_pieces(center)) do
        if p.id == id then return p end
    end
    return nil
end

local function flag_undo(name)
    return function(g) g.modifiers[name] = nil end
end

C.STAKE_PIECES = {
    stake_red = {{key = "small_reward", label = "Small Blind gives no reward money", undo = function(g)
        local nb = g.modifiers.no_blind_reward
        if type(nb) == "table" then nb.Small = nil; if next(nb) == nil then g.modifiers.no_blind_reward = nil end end
    end}},
    stake_green = {{key = "scaling", label = "Required score scales faster", scaling = 2}},
    stake_black = {{key = "eternal", label = "Shop can have Eternal Jokers", undo = flag_undo("enable_eternals_in_shop")}},
    stake_blue = {
        {key = "shop_tax", label = "Shop items cost $1 more", undo = flag_undo("ante_shop_tax")},
        {key = "reroll_step", label = "Rerolls go up by $2 each", undo = function(g) if g.modifiers.reroll_step == 2 then g.modifiers.reroll_step = nil end end},
    },
    stake_purple = {{key = "scaling", label = "Required score scales even faster", scaling = 3}},
    stake_orange = {{key = "perishable", label = "Shop can have Perishable Jokers", undo = flag_undo("enable_perishables_in_shop")}},
    stake_gold = {{key = "rental", label = "Shop can have Rental Jokers", undo = flag_undo("enable_rentals_in_shop")}},
    stake_chaos = {{key = "minus_choice", label = "Booster Packs have one less choice", undo = flag_undo("booster_minus_choice")}},
    stake_apocalypse = {{key = "boss_extra", label = "Boss Blinds gain an extra effect", undo = flag_undo("boss_additional_effect")}},
    stake_oblivion = {{key = "joker_disable", label = "A random Joker slot is off each round", undo = flag_undo("random_joker_disable")}},
    stake_transcendent = {{key = "finisher", label = "Boss Blinds are always Finisher Blinds", undo = flag_undo("boss_always_finisher")}},
}

C.FORGE_STAKE = {
    blind_scaling = {label = "Blinds grow %d%% bigger", undo = function(g, n) local sp = g.starting_params; sp.ante_scaling = (sp.ante_scaling or 1) / (1 + n / 100) end},
    discards_minus = {label = "%d fewer discards", undo = function(g, n) g.starting_params.discards = g.starting_params.discards + math.floor(n) end},
    hands_minus = {label = "%d fewer hands", undo = function(g, n) g.starting_params.hands = g.starting_params.hands + math.floor(n) end},
    no_interest = {label = "No interest", undo = function(g)
        local b = g.selected_back
        if not (b and b.effect and b.effect.config and b.effect.config.no_interest) then g.modifiers.no_interest = nil end
    end},
    small_no_reward = {label = "Small Blind gives no reward money", undo = C.STAKE_PIECES.stake_red[1].undo},
    prices_plus = {label = "Shop prices +$%d", undo = function(g, n) g.inflation = math.max(0, (g.inflation or 0) - math.floor(n)) end},
    eternal = {label = "Shop can have Eternal Jokers", undo = flag_undo("enable_eternals_in_shop")},
    perishable = {label = "Shop can have Perishable Jokers", undo = flag_undo("enable_perishables_in_shop")},
    rental = {label = "Shop can have Rental Jokers", undo = flag_undo("enable_rentals_in_shop")},
    win_ante = {label = "Win at Ante %d", undo = function(g) g.win_ante = 8 end},
}

local function forge_kinds()
    local ok, M = pcall(require, "functions/forge/forge_kinds_more")
    return ok and type(M) == "table" and M or nil
end

local function forge_stake(id)
    local ok, Store = pcall(require, "functions/forge/forge_store")
    if not (ok and Store and Store.get_item) then return nil end
    local c = Store.get_item(id)
    return c and c.kind == "stake" and c or nil
end
C.forge_stake = forge_stake

function C.stake_index(stake)
    local pool = G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake or {}
    if type(stake) == "number" then return math.max(1, math.min(#pool > 0 and #pool or 8, math.floor(stake))) end
    if type(stake) == "string" then
        for i, c in ipairs(pool) do if c.key == stake then return i end end
        local f = stake:match("^forge:(.+)$")
        if f then
            local M = forge_kinds()
            local c = forge_stake(f)
            return c and M and M.stake_base and M.stake_base(c) or 1, f
        end
    end
    if type(stake) == "table" then
        if stake.forge then
            local M = forge_kinds()
            local c = forge_stake(stake.forge)
            return (stake.stake or (c and M and M.stake_base and M.stake_base(c))) or 1, stake.forge
        end
        if stake.key then return C.stake_index(stake.key) end
    end
    return 1
end

local function smods_chain(key)
    local S = rawget(_G, "SMODS")
    if not (S and S.build_stake_chain and G.P_STAKES and G.P_STAKES[key]) then return nil end
    local ok, chain = pcall(S.build_stake_chain, G.P_STAKES[key])
    if not ok or type(chain) ~= "table" then return nil end
    local list = {}
    for k in pairs(chain) do
        if G.P_STAKES[k] then list[#list + 1] = G.P_STAKES[k] end
    end
    if #list == 0 then return nil end
    table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)
    return list
end

function C.stake_chain(stake)
    local idx, forge_id = C.stake_index(stake)
    local pool = G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake or {}
    local top = pool[idx]
    local chain = top and top.key and smods_chain(top.key)
    if not chain then
        chain = {}
        for i = 1, idx do if pool[i] then chain[#chain + 1] = pool[i] end end
    end
    return chain, idx, forge_id
end

function C.stake_name(c)
    if type(c) ~= "table" then return "" end
    if c.forge_name then return c.forge_name end
    if localize and c.key then
        local ok, n = pcall(localize, {type = 'name_text', set = 'Stake', key = c.key})
        if ok and type(n) == "string" and n ~= "" and n ~= "ERROR" then return n end
    end
    return c.name or tostring(c.key)
end

function C.stake_groups(stake)
    local chain, idx, forge_id = C.stake_chain(stake)
    local groups = {}
    for _, c in ipairs(chain) do
        local list = {}
        local defs = C.STAKE_PIECES[c.key]
        if defs then
            for _, d in ipairs(defs) do
                list[#list + 1] = {id = c.key .. ":" .. d.key, stake = c.key, key = d.key, label = L(d.label), undo = d.undo, scaling = d.scaling}
            end
        elseif c.key ~= "stake_white" and type(c.modifiers) == "function" then
            list[#list + 1] = {id = c.key .. ":own", stake = c.key, key = "own", own = true, label = L("The stake's own effect")}
        end
        if #list > 0 then groups[#groups + 1] = {stake = c, key = c.key, order = c.order, pieces = list} end
    end
    if forge_id then
        local fc = forge_stake(forge_id)
        if fc then
            local list = {}
            for i, e in ipairs(fc.effects or {}) do
                local d = C.FORGE_STAKE[e.id]
                if d and (e.when == nil or e.when == "now") then
                    local n = tonumber(e.n) or 1
                    list[#list + 1] = {id = "forge_" .. forge_id .. ":" .. e.id .. "_" .. i, stake = "forge_" .. forge_id, key = e.id, n = n, label = fmt(d.label, n), undo = function(g) d.undo(g, n) end}
                end
            end
            if #list > 0 then groups[#groups + 1] = {stake = {key = "forge_" .. forge_id, forge_name = fc.name}, key = "forge_" .. forge_id, forge = true, pieces = list} end
        end
    end
    return groups, idx
end

function C.stake_pieces(stake)
    local out = {}
    for _, g in ipairs((C.stake_groups(stake))) do
        for _, p in ipairs(g.pieces) do out[#out + 1] = p end
    end
    return out
end

if mod_loc_register then mod_loc_register{
    fr = {
        ["Hands"] = "Mains", ["Discards"] = "Défausses", ["Starting money"] = "Argent de départ",
        ["%s hands"] = "%s mains", ["%s discards"] = "%s défausses", ["%s hand size"] = "%s taille de main",
        ["%s Joker slots"] = "%s emplacements de Joker", ["%s consumable slots"] = "%s emplacements de consommable",
        ["%s starting money"] = "%s d'argent de départ", ["Rerolls cost $%d less"] = "Relances %d $ moins chères",
        ["$%d per hand left"] = "%d $ par main restante", ["$%d per discard left"] = "%d $ par défausse restante",
        ["Spectral cards in the shop"] = "Cartes Spectrales dans la boutique",
                ["Blinds x%s bigger"] = "Blindes x%s plus grosses", ["%d cards get %s"] = "%d cartes reçoivent %s",
        ["Voucher: %s"] = "Coupon : %s", ["Start with %s"] = "Commence avec %s",
        ["Only Spades and Hearts"] = "Seulement Piques et Cœurs", ["Double Tag after each Boss Blind"] = "Badge double après chaque Blinde de boss",
        ["Chips and Mult are balanced"] = "Jetons et Multi. équilibrés", ["The deck's own effect"] = "L'effet propre du jeu",
                ["Required score scales faster"] = "Le score requis monte plus vite",
        ["Required score scales even faster"] = "Le score requis monte encore plus vite",
        ["Shop can have Eternal Jokers"] = "Jokers Éternels en boutique", ["Shop items cost $1 more"] = "Articles de boutique +1 $",
        ["Rerolls go up by $2 each"] = "Relances : +2 $ chacune", ["Shop can have Perishable Jokers"] = "Jokers périssables en boutique",
        ["Shop can have Rental Jokers"] = "Jokers location en boutique", ["Booster Packs have one less choice"] = "Les paquets ont un choix de moins",
        ["Boss Blinds gain an extra effect"] = "Les Blindes de boss gagnent un effet en plus",
        ["A random Joker slot is off each round"] = "Un emplacement de Joker au hasard coupé à chaque manche",
        ["Boss Blinds are always Finisher Blinds"] = "Les Blindes de boss sont toujours finales",
        ["The stake's own effect"] = "L'effet propre de la mise",
        ["Blinds grow %d%% bigger"] = "Blindes %d%% plus grosses", ["%d fewer discards"] = "%d défausses en moins",
        ["%d fewer hands"] = "%d mains en moins", ["Shop prices +$%d"] = "Prix de boutique +%d $", ["Win at Ante %d"] = "Victoire à la mise initiale %d",
    },
    es = {
        ["Hands"] = "Manos", ["Discards"] = "Descartes", ["Starting money"] = "Dinero inicial",
        ["%s hands"] = "%s manos", ["%s discards"] = "%s descartes", ["%s hand size"] = "%s tamaño de mano",
        ["%s Joker slots"] = "%s espacios de comodín", ["%s consumable slots"] = "%s espacios de consumible",
        ["%s starting money"] = "%s de dinero inicial", ["Rerolls cost $%d less"] = "Renovar cuesta $%d menos",
        ["$%d per hand left"] = "$%d por mano restante", ["$%d per discard left"] = "$%d por descarte restante",
        ["Spectral cards in the shop"] = "Cartas espectrales en la tienda",
                ["Blinds x%s bigger"] = "Ciegas x%s más grandes", ["%d cards get %s"] = "%d cartas reciben %s",
        ["Voucher: %s"] = "Vale: %s", ["Start with %s"] = "Empiezas con %s",
        ["Only Spades and Hearts"] = "Solo picas y corazones", ["Double Tag after each Boss Blind"] = "Etiqueta doble tras cada ciega jefe",
        ["Chips and Mult are balanced"] = "Fichas y multi se equilibran", ["The deck's own effect"] = "El efecto propio de la baraja",
                ["Required score scales faster"] = "La puntuación requerida sube más rápido",
        ["Required score scales even faster"] = "La puntuación requerida sube aún más rápido",
        ["Shop can have Eternal Jokers"] = "Comodines eternos en la tienda", ["Shop items cost $1 more"] = "Artículos de tienda +$1",
        ["Rerolls go up by $2 each"] = "Renovar: +$2 cada vez", ["Shop can have Perishable Jokers"] = "Comodines perecederos en la tienda",
        ["Shop can have Rental Jokers"] = "Comodines de alquiler en la tienda", ["Booster Packs have one less choice"] = "Los sobres tienen una opción menos",
        ["Boss Blinds gain an extra effect"] = "Las ciegas jefe ganan un efecto extra",
        ["A random Joker slot is off each round"] = "Un espacio de comodín al azar se apaga cada ronda",
        ["Boss Blinds are always Finisher Blinds"] = "Las ciegas jefe son siempre finales",
        ["The stake's own effect"] = "El efecto propio del pozo",
        ["Blinds grow %d%% bigger"] = "Ciegas %d%% más grandes", ["%d fewer discards"] = "%d descartes menos",
        ["%d fewer hands"] = "%d manos menos", ["Shop prices +$%d"] = "Precios de la tienda +$%d", ["Win at Ante %d"] = "Victoria en la apuesta inicial %d",
    },
} end

return C
