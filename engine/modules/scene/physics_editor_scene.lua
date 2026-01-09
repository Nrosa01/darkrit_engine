---@diagnostic disable:invisible

local PhysicsEditor = Darkrit._internal.require_utils.require_module('physics.physics_editor') ---@module "physics.physics_editor"
local scene = {}
scene.__index = scene

function scene.new()
    return setmetatable({}, scene)
end

function scene:load()
    local width, height, mode = love.window.getMode()
    self.init_config = {
        width = width,
        height = height,
        mode = mode
    }
    self.editor = PhysicsEditor.new(Darkrit.config.physics.layers, function ()
        Darkrit.scene_system:pop()
    end)
    love.window.setMode(Darkrit.graphics:get_screen_dimensions())
    self.cam = Darkrit.graphics.camera.new(nil, nil, 5, 600, 400, nil, nil, nil, true)

    -- love.window.setMode(1200, 800)
end

function scene:mousemoved(x, y, dx, dy, istouch)
    local world_x, world_y = self.cam:to_world(x, y)
    self.editor:mousemoved(world_x, world_y, dx, dy, istouch)
end

function scene:unload()
    love.window.setMode(self.init_config.width, self.init_config.height, self.init_config.mode)
    Darkrit.physics:update_entities_filter(self.editor:compute_filters())
end

function scene:draw_ui()
    love.graphics.clear(0.2, 0.2, 0.2)
    self.cam:attach()
    self.editor:draw()
    self.cam:detach()
end

function scene:mousepressed(x, y, button)
    local world_x, world_y = self.cam:to_world(x, y)
    self.editor:mousepressed(world_x, world_y, button)
end

function scene:textinput(t)
    self.editor:textinput(t)
end

function scene:keypressed(key, scancode, isrepeat)
    -- Darkrit.config.physics.layers.
    self.editor:keypressed(key)

    -- if key == 'q' and love.keyboard.isDown('lctrl', 'rctrl') then
        -- Darkrit.scene_system:pop()
    -- end
end

return scene
