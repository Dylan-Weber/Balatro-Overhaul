-- On OpenGL ES (phones), LOVE compiles pixel shaders at medium float precision. Mod shaders
-- are written and tested on desktop, where every float is 32-bit, and their math can overflow
-- medium precision: on a Pixel, Cryptid's Astral star field and Glitched random numbers turned
-- whole cards black. This compiles each mod shader at high precision where the GPU has it.
--
-- A plain "precision highp float;" at the top does not compile: LOVE declares effect() before
-- the mod's code at the default precision, and GLSL ES needs the definition to match that
-- declaration. So the mod's helpers get high precision, effect()'s parameters keep the default,
-- and effect()'s body switches to high precision again.
local mod_shader_precision = {}

mod_shader_precision.high_precision = "#if defined(PIXEL) && defined(GL_FRAGMENT_PRECISION_HIGH)\nprecision highp float;\n#endif\n"
mod_shader_precision.default_precision = "#if defined(PIXEL) && defined(GL_FRAGMENT_PRECISION_HIGH)\nprecision mediump float;\n#endif\n"

function mod_shader_precision.raise(shader_source)
    if type(shader_source) ~= "string" then return shader_source end
    -- the mod already chose its precision, or uses a GLSL version where this works differently
    if shader_source:find("precision%s+%a+p%s+float") or shader_source:find("#pragma%s+language") then return shader_source end
    local effect_start = shader_source:find("vec4%s+effect%s*%(")
    if not effect_start then return shader_source end
    local body_open = shader_source:find("{", effect_start, true)
    local body_close = body_open and mod_shader_precision.matching_brace(shader_source, body_open)
    if not body_close then return shader_source end
    -- functions after effect() can be declared before it, so they get high precision again
    return mod_shader_precision.high_precision
        .. shader_source:sub(1, effect_start - 1)
        .. mod_shader_precision.default_precision
        .. shader_source:sub(effect_start, body_open) .. "\n"
        .. mod_shader_precision.high_precision
        .. shader_source:sub(body_open + 1, body_close) .. "\n"
        .. mod_shader_precision.high_precision
        .. shader_source:sub(body_close + 1)
end

-- Position of the brace that closes the one at open_position, skipping comments.
function mod_shader_precision.matching_brace(shader_source, open_position)
    local depth, position = 0, open_position
    while position <= #shader_source do
        local character = shader_source:sub(position, position)
        local next_two = shader_source:sub(position, position + 1)
        if next_two == "//" then
            position = (shader_source:find("\n", position, true) or #shader_source) + 1
        elseif next_two == "/*" then
            position = (select(2, shader_source:find("*/", position + 2, true)) or #shader_source) + 1
        else
            if character == "{" then depth = depth + 1
            elseif character == "}" then
                depth = depth - 1
                if depth == 0 then return position end
            end
            position = position + 1
        end
    end
    return nil
end

-- Compiles a mod shader, at high precision on OpenGL ES. If the raised shader does not
-- compile there, the mod's shader is compiled exactly as written instead.
function mod_shader_precision.compile(shader_source)
    if love.graphics.getRendererInfo() ~= "OpenGL ES" then return love.graphics.newShader(shader_source) end
    local raised_source = mod_shader_precision.raise(shader_source)
    if raised_source ~= shader_source then
        local stub_shader = rawget(_G, "SMODS") and SMODS.shader_stub
        local compiled, raised_shader = pcall(love.graphics.newShader, raised_source)
        if compiled and raised_shader and raised_shader ~= stub_shader then return raised_shader end
    end
    return love.graphics.newShader(shader_source)
end

return mod_shader_precision
