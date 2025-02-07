---@diagnostic disable-next-line
local ru = Darkrit._internal.require_utils
local baton = ru.require_third_party('tesselode.baton') ---@module "baton"

---@class Darkrit.Input
---@field private baton tesselode.baton
---@field private input_maps table<string, tesselode.baton.Player>
---@field update function
local input =
{
    baton = {},
    input_maps = {}
}

---@alias Darkrit.InputMap tesselode.baton.Player

---Crates a new input map
---@param name string
---@param controls tesselode.baton.config
---@return Darkrit.InputMap
function input:new_map(name, controls)
    self.input_maps[name] = baton.new(controls)
    return self.input_maps[name]
end

---Gets an input map
---@param name string
---@return Darkrit.InputMap
function input:get_map(name)
    return self.input_maps[name]
end

--- Removes an input map
---@param name string
function input:remove_map(name)
    self.input_maps[name] = nil
end

function input:update()
    for _, player in pairs(self.input_maps) do
        player:update()
    end
end

return input