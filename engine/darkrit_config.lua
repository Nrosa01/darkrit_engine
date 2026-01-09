---@class Darkrit.Config
local config = {
    components_path = "scripts/components/",
    scenes_path = "scenes/",
    scripts_path = "scripts/",
    physics = {
        draw_options_slick = {
            draw_quad_tree = false,
            draw_shape_normals = false,
            draw_text = false,
        },
        layers = {
            Default = {
                mask = 6,
                category = 1,
            },
            Map = {
                mask = 5,
                category = 2,
            },
            Characters = {
                mask = 3,
                category = 4,
            },
        },
        draw_physics = true,
    },
    assets_path = "assets/",
    graphics = {
        adjust_to_game_resolution = true,
        y_sorting_config = {
            enabled = true,
            frame_skip = 3,
        },
        filter_mode = "nearest",
        vsync = 1,
        resolution = {
            window_width = 640,
            window_height = 360,
            scale_mode = 3,
            game_width = 320,
            game_height = 180,
        },
        fullscreen_type = "borderless",
        resizable = false,
        fullscreen = false,
    },
    meta = {
        keep_config_edits_after_play = false,
        edited_config_save_location = "darkrit_config.lua",
    },
}

return config