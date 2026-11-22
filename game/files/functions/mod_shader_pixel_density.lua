-- A pixel shader's screen_coords are in pixels, but mouse_screen_pos and screen_scale are in
-- LOVE's screen units. On a high-density screen (a phone has about 2.4 pixels per unit) the two
-- disagree, so a shader that mixes them, like Cryptid's Astral star field, measures distances
-- 2.4 times too large: Astral blew out to white instead of its purple tint. Shaders that declare
-- overhaul_pixel_density get the pixels per unit to divide screen_coords by.
local mod_shader_pixel_density = {}

mod_shader_pixel_density.uniform_name = "overhaul_pixel_density"

function mod_shader_pixel_density.declares_uniform(shader_source)
    return type(shader_source) == "string"
        and shader_source:find("extern%s+[%w_]+%s+[%w_]*%s*" .. mod_shader_pixel_density.uniform_name) ~= nil
end

-- Makes the Steamodded shader object send the pixel density with its other variables.
function mod_shader_pixel_density.attach(shader_object, shader_source)
    if not (type(shader_object) == "table" and mod_shader_pixel_density.declares_uniform(shader_source)) then return false end
    if shader_object.overhaul_pixel_density_attached then return true end
    shader_object.overhaul_pixel_density_attached = true
    local mod_send_vars = shader_object.send_vars
    shader_object.send_vars = function(...)
        local variables = type(mod_send_vars) == "function" and mod_send_vars(...) or nil
        if type(variables) ~= "table" then variables = {} end
        variables[mod_shader_pixel_density.uniform_name] = love.graphics.getDPIScale()
        return variables
    end
    return true
end

return mod_shader_pixel_density
