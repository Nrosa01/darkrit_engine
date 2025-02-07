---@class Darkrit.Config
local config = {
    assets_path = 'assets/',
    scripts_path = 'scripts/', -- Relative to assets path
    components_path = 'scripts/components/', -- Relative to assets path
    ---@class Darkrit.Config.Graphics
    graphics = {
        resolution = {
            game_width = 320,
            game_height = 180,
            --- Scales modes are:
            --- 1: None
            --- 2: Letterbox
            --- 3: Pixel perfect
            --- 4: Stretch
            --- 5: Stretch with aspect ratio (boundless)
            scale_mode = 3
        },
        -- Options are 'nearest', 'linear'
        filter_mode = 'nearest',
        fullscreen = true,
        --- Options are 'desktop', 'exclusive' (not recommended)
        fullscreen_type = 'desktop',
        resizable = false,
        --- Options
        --- 0: No vsync
        --- 1: Vsync
        --- -1: Adaptive vsync
        --- 2: Vsync with half refresh rate
        vsync = 1,
        y_sorting_config = 
        {
            enabled = true,
            frame_skip = 3
        },
        adjust_to_game_resolution = true
    }
}

return config