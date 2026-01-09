---@class Darkrit.Scene
---@field new function():Darkrit.Scene
---@field load function(self:Darkrit.Scene)
---@field unload function(self:Darkrit.Scene)

---@class Darkrit.SceneSystem
---@field scenes table<number, Darkrit.Scene>
---@field private _background_scenes table<number, Darkrit.Scene>
local scene_system = {}
scene_system.__index = scene_system

function scene_system.new()
    local self = setmetatable({}, scene_system)
    self.scenes = {}
    self._background_scenes = {}
    return self
end

function scene_system:change_scene(scene, ...)
    self:pop()
    self:push(scene, ...)
end

function scene_system:add_background_scene(object)
    table.insert(self._background_scenes, object)
end

--- Pushes a scene to the scene stack
---@param scene Darkrit.Scene
---@param ... any
function scene_system:push(scene, ...)
    local new_scene = scene.new()
    new_scene._hooks = {}
    table.insert(self.scenes, new_scene)
    self:send_message('load', ...)
end

function scene_system:_get_current_scene()
    return self.scenes[#self.scenes]
end

function scene_system:pop()
    local current_scene = self:_get_current_scene()
    if current_scene.unload then
        current_scene:unload()
    end
    table.remove(self.scenes)
end

--- Sends a message to the current scene
---@param event string
---@param ... any
function scene_system:send_message(event, ...)
    for _, bg_scene in ipairs(self._background_scenes) do
        if bg_scene[event] then
            bg_scene[event](bg_scene, ...)
        end
    end

    local current_scene = self:_get_current_scene()
    if current_scene then
        if current_scene[event] then
            current_scene[event](current_scene, ...)
        end
    end
end

return scene_system
