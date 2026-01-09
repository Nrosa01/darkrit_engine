---@meta

---@class Darkrit.Physics.Config.Filter
---@field category number
---@field mask number

---@alias Darkrit.Config.Graphics.ScaleMode
---| 1 None
---| 2 Letterbox
---| 3 Pixel perfect
---| 4 Stretch
---| 5 Stretch with aspect ratio (boundless)

---@alias Darkrit.Config.Graphics.VsyncMode
---| 0 No vsync
---| 1 Vsync
---| -1 Adaptive vsync
---| 2 Vsync with half refresh rate

---@alias Darkrit.Config.Graphics.FilterMode "nearest" | "linear"

---@alias Darkrit.Graphics.Config.FullscreenType
---| "desktop" -- Sometimes known as borderless fullscreen windowed mode. A borderless screen-sized window is created which sits on top of all desktop UI elements. The window is automatically resized to match the dimensions of the desktop, and its size cannot be changed.
---| "exclusive" -- Standard exclusive-fullscreen mode. Changes the display mode (actual resolution) of the monitor.
---| "normal" -- Standard exclusive-fullscreen mode. Changes the display mode (actual resolution) of the monitor.
---| "borderless" -- Sometimes known as borderless fullscreen windowed mode. A borderless screen-sized window is created which sits on top of all desktop UI elements. The window is automatically resized to match the dimensions of the desktop, and its size cannot be changed.

---@class Darkrit.Config
local config = {
    assets_path = 'assets/',
    scenes_path = 'scenes/',                 -- Scene folder relative to assets path
    scripts_path = 'scripts/',               -- Scripts folder relative to assets path
    components_path = 'scripts/components/', -- Components folder relative to assets path
    ---@class Darkrit.Config.Graphics
    graphics = {
        ---@class Darkrit.Config.Resolution
        resolution = {
            window_width = 640,
            window_height = 360,
            game_width = 320,
            game_height = 180,
            ---@type Darkrit.Config.Graphics.ScaleMode
            scale_mode = 3
        },
        ---@type love.FilterMode
        filter_mode = 'nearest',
        fullscreen = true,
        ---@type Darkrit.Graphics.Config.FullscreenType
        fullscreen_type = 'borderless',
        resizable = false,
        ---@type Darkrit.Config.Graphics.VsyncMode
        vsync = 1,
        y_sorting_config =
        {
            -- Whether to perform or not y sorting
            enabled = true,
            -- Number of frames to skip before performing y sorting
            frame_skip = 3
        },

        -- When enable, the default camera adjusts its ortographic size to the game resolution
        -- Otherwise the camera will have a default ortographic size of 300
        adjust_to_game_resolution = true
    },
    ---@class Darkrit.Config.Physics
    physics =
    {
        --- Physics layers define categories and which ones they can collide with
        ---@type Darkrit.Physics.Config.Filter[]
        layers = {},
        draw_physics = true,

        --- Specific draw options when using slick physics. Enabling text or quad_tree drawing significantly impacts performance
        draw_options_slick = {
            draw_text = false,
            draw_quad_tree = false,
            draw_shape_normals = false
        }
    },
    ---@class Darkrit.Config.Physics
    meta = {
        -- If true, changes made to the config during play mode will be kept
        keep_config_edits_after_play = false,
        -- If keep_config_edits_after_play is false, this is the location where the edited config will be saved.
        -- If it is empty, the edited config will not be saved.
        edited_config_save_location = ''
    }
}

return config
