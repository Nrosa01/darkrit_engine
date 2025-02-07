local this_module_path = (...):match("(.-)[^%.]+$")
local modules_path = this_module_path .. 'modules.'
local require_utils = require(modules_path .. 'internal.require_utils') ---@module "require_utils"
require_utils.require_module('internal.debugger') ---@module "debugger"

---@class Darkrit.Internal
---@field require_utils Darkrit.Internal.RequireUtils
---@field script_cache table<string, any>

---@class Darkrit.Utils
---@field loading_screen Darkrit.Utils.LoadingSystem

---@alias Darkrit Engine

---@class Engine
---@field assets table
---@field input Darkrit.Input
---@field graphics Darkrit.Graphics
---@field vec NVec
---@field time bjornbytes.tick
---@field world Darkrit.World
---@field algorithm Darkrit.Algorithms
---@field package _internal Darkrit.Internal
---@field config Darkrit.Config

local engine = {
    assets = {},
    _internal = {}, ---@diagnostic disable-line
}

_G.Darkrit = engine

local time = require_utils.require_third_party('bjornbytes.tick') ---@module "tick"

---@return Darkrit.Config
local function load_config()
    local default_config = require_utils.require_from_root('darkrit_config') ---@module "config"
    local success, user_config = pcall(love.filesystem.load, 'darkrit_config.lua')
    if success and user_config then
        local loaded_config = user_config()

        -- Merge of loaded_config fields into the default config
        for k, v in pairs(loaded_config) do
            default_config[k] = v
        end
    end

    return default_config
end

--- Initializes the engine
function engine:init()
    self._internal.require_utils = require_utils
    self.config = load_config() ---@types Darkrit.Config

    ---@module "asset_loader"
    local asset_loader, script_cache = unpack(require_utils.require_module('asset_loader'))
    self._internal.script_cache = script_cache
    self.assets = asset_loader(self.config.assets_path)
    self.test_assets = asset_loader('engine/test/assets')
    self.components = self.assets[self.config.components_path]
    self.algorithm = require_utils.require_module('algorithm.algorithm') ---@module "algorithm"

    if not self.assets then
        error('Failed to load assets')
    end

    self.vec = require_utils.require_third_party('NPad93.nvec') ---@module "nvec"
    self.input = require_utils.require_module('input') ---@module "engine.modules.input"
    self.graphics = require_utils.require_module('graphics.graphics') ---@module "graphics.graphics"
    self.graphics:_init()
    self.time = time ---@module "tick"
    self.world = require_utils.require_module('entities.world') ---@module "entities.world"
    self.utils = {
        loading_screen = require_utils.require_module('utils.loading_screen') } ---@module "utils.loading_screen"
    self.physics_utils = require_utils.require_module('physics.physics_utils') ---@module "physics_utils"

    self.components_require_path = (self.config.assets_path .. self.config.components_path):gsub('/', '.')

    -- disable vsync
    love.window.setVSync(0)
    self.time.framerate = 60
    self.time.rate = 1 / engine.time.framerate
end

---Updates different parts of the engine
---@param dt number
function engine:update(dt)
    if love.update then
        love.update(dt)
    end
    self.input:update()
end

function engine:draw()
    local cam = Darkrit.graphics.camera
    
    -- Clear and reset aren't really needed. But 
    -- I added them just to avoid some edge case I'm not aware of
    -- Also to cover some misuse of the lib
    if love.draw then
        -- Despite love2d works saying this won't work retroactively for loaded images, it does xD
        -- Although weirdly enough, it only works before the camera push, I don't undertand why yet
        love.graphics.setDefaultFilter(Darkrit.config.graphics.filter_mode, Darkrit.config.graphics.filter_mode)
        
        cam:push()
        love.draw()
        cam:pop()
        if love.draw_ui then
            love.draw_ui()
        end
    end
end

function engine:resize(w,h)
    Darkrit.graphics.camera:resize(w,h)
end

function engine:test()
    require_utils.require('test', 'test')()
end

engine:init()

return engine
