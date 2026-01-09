local this_module_path = (...):match("(.-)[^%.]+$")
local modules_path = this_module_path .. 'modules.'
local require_utils = require(modules_path .. 'internal.require_utils') ---@module "require_utils"
require_utils.require_module('internal.debugger') ---@module "debugger"

---@class Darkrit.Utils
---@field loading_screen Darkrit.Utils.LoadingSystem
---@field json Darkrit.Utils.JSON

---@alias Darkrit Engine

---@class Engine
---@field assets table
---@field components table
---@field scenes table
---@field input Darkrit.Input
---@field graphics Darkrit.Graphics
---@field vec NVec
---@field time bjornbytes.tick
---@field world Darkrit.World
---@field algorithm Darkrit.Algorithms
---@field slick slick
---@field utils Darkrit.Utils
---@field package _internal Darkrit.Internal
---@field scene_system Darkrit.SceneSystem
---@field config Darkrit.Config
---@field physics Darkrit.Physics
---@field quit fun()

local engine = {
    assets = {},
}

_G.Darkrit = engine ---@type Engine

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
    self._internal = require_utils.require_module('internal.internal') ---@module "internal"
    
    self.config = load_config() ---@types Darkrit.Config

    ---@module "asset_loader"
    local asset_loader, script_cache = unpack(require_utils.require_module('asset_loader'))
    self._internal.script_cache = script_cache

    self.assets = asset_loader(self.config.assets_path)
    self.test_assets = asset_loader('engine/test/assets')
    self.scenes = self.assets[self.config.scenes_path]
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
        loading_screen = require_utils.require_module('utils.loading_screen'), ---@module "utils.loading_screen"
        json = require_utils.require_third_party('josh-perry.lib.json'), ---@module "josh-perry.lib.json"
    }
    self.slick = require_utils.require_third_party('erinmaus.slick') ---@module "erinmaus.slick"
    self.components_require_path = (self.config.assets_path .. self.config.components_path):gsub('/', '.')
    self.scene_system = require_utils.require_module('scene.scene_system').new() ---@module "scene.scene_system"
    -- disable vsync
    love.window.setVSync(0)
    self.time.framerate = 60
    self.time.rate = 1 / engine.time.framerate
    self.physics = require_utils.require_module('physics.physics') ---@module "physics.physics"
end

---@public
function engine:quit()
    love.event.quit()
end

function engine:test()
    require_utils.require('test', 'test')()
end

engine:init()

return engine
