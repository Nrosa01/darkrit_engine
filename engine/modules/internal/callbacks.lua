---@diagnostic disable: invisible

---@class Darkrit.Internal.Callbacks
---@field engine Engine
local callbacks = {}
callbacks.__index = callbacks

---@param engine Engine
---@return Darkrit.Internal.Callbacks
function callbacks.new(engine)
    local self = setmetatable({}, callbacks)
    self.engine = engine
    return self
end

--- I know I could do this differently, but I prefer to have handwritten
--- all love callbacks because I might need to customize them in the future

--- Helper method
---@param event string
---@param ... any
function callbacks:send_message(event, ...)
    self[event](self, ...)
end

function callbacks:load()
    self.engine.scene_system:send_message('load')
end

function callbacks:draw()
    local cam = Darkrit.graphics.camera

    -- Despite love2d works saying this won't work retroactively for loaded images, it does xD
    -- Although weirdly enough, it only works before the camera push, I don't undertand why yet
    love.graphics.setDefaultFilter(Darkrit.config.graphics.filter_mode, Darkrit.config.graphics.filter_mode)
    cam:attach()
    self.engine.scene_system:send_message('draw')
    cam:detach()
    self.engine.scene_system:send_message('draw_ui')
end

function callbacks:update(dt)
    self.engine.input:update()
    self.engine.scene_system:send_message('update', dt)
end

function callbacks:keypressed(key, scancode, isrepeat)
    self.engine.scene_system:send_message('keypressed', key, scancode, isrepeat)
end

function callbacks:keyreleased(key, scancode)
    self.engine.scene_system:send_message('keyreleased', key, scancode)
end

function callbacks:mousepressed(x, y, button, istouch, presses)
    self.engine.scene_system:send_message('mousepressed', x, y, button, istouch, presses)
end

function callbacks:mousereleased(x, y, button, istouch, presses)
    self.engine.scene_system:send_message('mousereleased', x, y, button, istouch, presses)
end

function callbacks:mousemoved(x, y, dx, dy, istouch)
    self.engine.scene_system:send_message('mousemoved', x, y, dx, dy, istouch)
end

function callbacks:wheelmoved(x, y)
    self.engine.scene_system:send_message('wheelmoved', x, y)
end

function callbacks:resize(w, h)
    self.engine.graphics.camera:resize(w, h)
    self.engine.scene_system:send_message('resize', w, h)
end

function callbacks:visible(visible)
    self.engine.scene_system:send_message('visible', visible)
end

function callbacks:focus(focus)
    self.engine.scene_system:send_message('focus', focus)
end

function callbacks:mousefocus(focus)
    self.engine.scene_system:send_message('mousefocus', focus)
end

function callbacks:textinput(text)
    self.engine.scene_system:send_message('textinput', text)
end

function callbacks:quit()
    -- Here I just unload all scenes
    while #self.engine.scene_system.scenes > 0 do
        self.engine.scene_system:pop()
    end

    -- Getting the edited config is mainly for dev
    -- If you want to save some config you should do it on your own file and system
    -- Think of Darkrit.Config as the start point to dev your project
    -- Of course you would also edit this an adapt it to your needs
    if love.filesystem.isFused() then
        return
    end

    -- Save modified config if there are changes
    local file, err = io.open('engine/darkrit_config.lua', 'r')
    if not file then
        error("Failed to open config file: " .. err)
    end

    local start_config = file:read('*a')
    file:close()

    local start_config_table, load_err = loadstring(start_config)()
    if not start_config_table then
        error("Failed to load start config: " .. load_err)
    end

    if not Darkrit._internal.table_utils.tables_are_equal(Darkrit.config, start_config_table) then
        local config_serializer = Darkrit._internal.require_utils.require_module('internal.config_serializer') ---@module "config_serializer"
        assert(config_serializer, 'Failed to load config serializer')

        local config_path = 'engine/darkrit_config.lua'
        local save_path = Darkrit.config.meta.keep_config_edits_after_play and config_path or
            Darkrit.config.meta.edited_config_save_location

        if save_path == "" then return
        elseif not string.match(save_path, "%.lua$") then
            save_path = save_path .. ".lua"
        end

        local success, save_err = pcall(config_serializer.save_config, config_path, save_path, Darkrit.config)
        if not success then
            error("Failed to save config: " .. save_err)
        end
    end
end

function callbacks:filedropped(file)
    self.engine.scene_system:send_message('filedropped', file)
end

function callbacks:directorydropped(path)
    self.engine.scene_system:send_message('directorydropped', path)
end

function callbacks:errhand(msg)
    self.engine.scene_system:send_message('errhand', msg)
end

function callbacks:threaderror(thread, errorstr)
    self.engine.scene_system:send_message('threaderror', thread, errorstr)
end

function callbacks:joystickadded(joystick)
    self.engine.scene_system:send_message('joystickadded', joystick)
end

function callbacks:joystickremoved(joystick)
    self.engine.scene_system:send_message('joystickremoved', joystick)
end

function callbacks:joystickaxis(joystick, axis, value)
    self.engine.scene_system:send_message('joystickaxis', joystick, axis, value)
end

function callbacks:joystickpressed(joystick, button)
    self.engine.scene_system:send_message('joystickpressed', joystick, button)
end

function callbacks:joystickreleased(joystick, button)
    self.engine.scene_system:send_message('joystickreleased', joystick, button)
end

function callbacks:joystickhat(joystick, hat, direction)
    self.engine.scene_system:send_message('joystickhat', joystick, hat, direction)
end

function callbacks:gamepadpressed(joystick, button)
    self.engine.scene_system:send_message('gamepadpressed', joystick, button)
end

function callbacks:gamepadreleased(joystick, button)
    self.engine.scene_system:send_message('gamepadreleased', joystick, button)
end

function callbacks:gamepadaxis(joystick, axis, value)
    self.engine.scene_system:send_message('gamepadaxis', joystick, axis, value)
end

function callbacks:touchpressed(id, x, y, dx, dy, pressure)
    self.engine.scene_system:send_message('touchpressed', id, x, y, dx, dy, pressure)
end

function callbacks:touchreleased(id, x, y, dx, dy, pressure)
    self.engine.scene_system:send_message('touchreleased', id, x, y, dx, dy, pressure)
end

function callbacks:touchmoved(id, x, y, dx, dy, pressure)
    self.engine.scene_system:send_message('touchmoved', id, x, y, dx, dy, pressure)
end

function callbacks:lowmemory()
    self.engine.scene_system:send_message('lowmemory')
end

function callbacks:displayrotated()
    self.engine.scene_system:send_message('displayrotated')
end

function callbacks:localechanged()
    self.engine.scene_system:send_message('localechanged')
end

function callbacks:sensorupdated(sensor, values)
    self.engine.scene_system:send_message('sensorupdated', sensor, values)
end

function callbacks:textedited(text, start, length)
    self.engine.scene_system:send_message('textedited', text, start, length)
end

function callbacks:run()
    self.engine.scene_system:send_message('run')
end

return callbacks
