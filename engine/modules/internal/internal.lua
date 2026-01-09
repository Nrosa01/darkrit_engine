local this_module_path = (...):match("(.-)[^%.]+$")
local require_utils = require(this_module_path .. 'require_utils') ---@type Darkrit.Internal.RequireUtils

---@class Darkrit.Internal
---@field require_utils Darkrit.Internal.RequireUtils
---@field script_cache table<string, any>
---@field callbacks Darkrit.Internal.Callbacks
---@field _start_config Darkrit.Config
---@field table_utils Darkrit.Internal.TableUtils
---@field state Darkrit.Internal.State

local internal = {
    require_utils = require_utils,
    script_cache = false,
    callbacks = require_utils.require_module('internal.callbacks').new(Darkrit), ---@module "internal.callbacks"
    table_utils = require_utils.require_module('internal.table_utils'), ---@module "internal.table_utils"
    state = require_utils.require_module('internal.state') ---@module "internal.state"
}
internal.__index = internal

return internal
