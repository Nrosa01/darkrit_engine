local root = (...):match('^(%w+)')

--- Requires a module from the modules folder
--- @param module_path string The path to the module
--- @private
local require_from = function(module_path, folder)
    folder = folder or "modules"

    local success, result =  pcall(require, root .. "." .. folder .. "." .. module_path)

    if success then
        return result
    else
        -- Try searching init
        success, result = pcall(require, root .. "." .. folder .. "." .. module_path .. ".init")
        if success then
            return result
        else
            error('Failed to load module: ' .. module_path)
        end
    end
end

---@private
local require_third_party = function(module_path)
    return require_from(module_path, "third_party")
end

--- Requires a module from the modules folder
---@param module_path string The path to the module
---@private
local require_module = function(module_path)
    return require_from(module_path, "modules")
end

local require_from_root = function(module_path)
    return require(root .. "." .. module_path)
end

---@class Darkrit.Internal.RequireUtils
---@field require fun(module_path: string, folder: string): any
---@field require_module fun(module_path: string): any
---@field require_third_party fun(module_path: string): any
---@field require_from_root fun(module_path: string): any
local require_utils = {
    require = require_from,
    require_module = require_module,
    require_third_party = require_third_party,
    require_from_root = require_from_root
}

return require_utils
