---@diagnostic disable-next-line
local ru = Darkrit._internal.require_utils

---@module "pivot"
local pivot = ru.require_module("graphics.pivot") ---@module "graphics.pivot"
local sorting_layer = ru.require_module("graphics.sorting_layer") ---@module "graphics.sorting_layer"
local camera = ru.require_module("graphics.camera") ---@module "graphics.camera"

---@class Darkrit.Graphics
local Graphics =
{
    PIVOT = pivot,
    SORTING_LAYER = sorting_layer,
    camera = nil, ---@type Darkrit.Graphics.Camera
}

---@private
function  Graphics:_init()
    love.window.setVSync(Darkrit.config.graphics.vsync)

    love.window.updateMode(love.graphics.getWidth(), love.graphics.getHeight(), {
        resizable  = true,
        fullscreen = Darkrit.config.graphics.fullscreen,
        vsync      = Darkrit.config.graphics.vsync ~= 0,
        fullscreentype = Darkrit.config.graphics.fullscreen_type or 'desktop'
    })

    love.graphics.setDefaultFilter(Darkrit.config.graphics.filter_mode, Darkrit.config.graphics.filter_mode)

    self.camera = camera.new(Darkrit.config.graphics.resolution.game_width, Darkrit.config.graphics.resolution.game_height, 
    Darkrit.config.graphics.resolution.scale_mode, 0, 0, 300, 0, 1, 
    Darkrit.config.graphics.adjust_to_game_resolution)
end

function Graphics:get_game_resolution()
    return self.camera:get_raw_resolution()
end

function Graphics:get_game_width()
    return self.camera._canvas_width
end

function Graphics:get_game_height()
    return self.camera._canvas_height
end

function Graphics:get_windows_width()
    return love.graphics.getWidth()
end

function Graphics:get_windows_height()
    return love.graphics.getHeight()
end

function Graphics:screen_to_world(x, y)
    return self.camera:to_world(x, y)
end

function Graphics:world_to_screen(x, y)
    return self.camera:to_screen(x, y)
end

return Graphics