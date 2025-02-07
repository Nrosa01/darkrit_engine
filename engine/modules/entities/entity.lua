---@diagnostic disable-next-line
local ru = Darkrit._internal.require_utils ---@module "require_utils"
local nvec = ru.require_third_party('NPad93.nvec') ---@module "nvec"
local component_module = ru.require_module('entities.component') ---@module "entities.component"
local transform_module = ru.require_module('graphics.transform') ---@module "graphics.transform"
local physics_transform_module = ru.require_module('entities.physics_transform') ---@module "graphics.physics_transform"

---@class Darkrit.Graphics.Transform
---@field position NVec
---@field rotation number
---@field scale NVec

---@class Darkrit.Entity
---@field private _active boolean Whether the entity is active and should be updated
---@field private _visible boolean Whether the entity should be rendered
---@field private _internal_transform love.Transform Internal LÖVE transform object
---@field transform Darkrit.Graphics.Transform The entity's transform
---@field offset NVec The offset of the entity
---@field name string Entity identifier
---@field children Darkrit.Entity[] List of child entities
---@field world Darkrit.World The system this entity belongs to
---@field groups Darkrit.EntityGroup List of groups this entity belongs to
---@field components Darkrit.Entity.Component[] List of components attached to this entity
---@field private _marked_for_deletion boolean Whether the entity is going to be removed from the world
---@field private _parent Darkrit.Entity? Parent entity
---@field private _transform_dirty_this_frame boolean Whether the entity was dirty this frame
local entity = {}
entity.__index = entity

local rad = math.rad
local deg = math.deg

---Creates a new entity instance
---@param world Darkrit.World The system this entity belongs to
---@param name string? The name of the entity
---@return Darkrit.Entity
function entity.new(world, name)
    return setmetatable({
        _active                     = true,
        _visible                    = true,
        _internal_transform         = love.math.newTransform(),
        _transform_dirty_this_frame = true,
        transform                   = transform_module.new(),
        offset                      = nvec(0, 0),
        name                        = name or "Entity",
        groups                      = {},
        components                  = {},
        world                       = world,
        _marked_for_deletion        = false,
        physics_body                = nil,
    }, entity)
end

--- Initializes physics for the entity.
---@param body_type string? By default, the body type is "dynamic".
--- | "'dynamic'" 
--- | "'static'"
--- | "'kinematic'"
function entity:init_physics(body_type)
    if self.physics then return end -- Already initialized
    local bodyType = body_type or "dynamic"
    local world = self.world.physics_world
    local body = love.physics.newBody(world, self.transform.position.x, self.transform.position.y, bodyType)
    self.physics_body = body
    self.transform = physics_transform_module.new(body, self.transform)
    -- Set the body’s user data so callbacks can retrieve the entity.
    body:setUserData(self)
end

---Removes physics from the entity.
---Destroys the physics body and restores transform as a normal table with the current values.
function entity:remove_physics()
    if not self.physics then return end
    local position = self.transform.position
    local angle = self.transform.rotation
    local scale = self.transform.scale
    self.physics_body:destroy()
    self.physics_body = nil
    self.transform = transform_module.new(position, angle, scale)
end

---@class Darkrit.Physics.ShapeOptions
---@field density number? The density of the shape
---@field isSensor boolean? Whether the shape is a sensor

--- Adds a physics shape to the entity's body.
---@param shape love.Shape The shape to add
---@param options Darkrit.Physics.ShapeOptions? Options for the shape
function entity:add_physics_shape(shape, options)
    if not self.physics_body then error("Physics not initialized for this entity") end
    options = options or {}
    local density = options.density or 1
    local isSensor = options.isSensor or false
    local fixture = love.physics.newFixture(self.physics_body, shape, density)
    fixture:setSensor(isSensor)
    fixture:setUserData(self)
    return fixture
end

function entity:__tostring()
    return self.name
end

function entity:receive_message(message, ...)
    for _, component in ipairs(self.components) do
        if component[message] then
            component[message](component, ...)
        end
    end
end

---Calls a method on all components of this entity
---@param event string The event to call
---@vararg any Arguments to pass to the event
function entity:send_message(event, ...)
    local componentCount = #self.components
    for i = 1, componentCount do
        local component = self.components[i]
        if component[event] then
            component[event](component, ...)
        end
    end
end

---Broadcasts a message to all children
---(calls a method on this entity components' and all children components)
---Only works when the entity is active
---@param event string The event to broadcast
---@vararg any Arguments to pass to the event
function entity:broadcast(event, ...)
    if self._active then
        self:send_message(event, ...)
    end
end

function entity:send_message_unsafe(message, ...)
    for _, component in ipairs(self.components) do
        component[message](component, ...)
    end
end

function entity:broadcast_unsafe(event, ...)
    self:send_message_unsafe(event, ...)
end

function entity:_force_update_transform()
    self._internal_transform:setTransformation(
        self.transform.position.x, self.transform.position.y,
        rad(self.transform.rotation),
        self.transform.scale.x, self.transform.scale.y,
        self.offset.x, self.offset.y)
end

function entity:_active_status_changed(status)
    self:broadcast("_entity_active_status_changed", status)
end

function entity:on_enable()
    self:_active_status_changed(true)
end

function entity:on_disable()
    self:_active_status_changed(false)
end

--- Destroys this entity and all of its children
--- Entity will be accessibile during the duration of the current update loop
function entity:on_destroy()
    self:broadcast("on_destroy")
end

---Adds a component to this entity
---@param component Darkrit.Entity.Component
---@param args ...?
function entity:add_component(component, args)
    local new_component = component_module._new(self, component, args)
    table.insert(self.components, new_component)
    self.world:add_component(new_component)
    return new_component
end

function entity:get_component(name)
    for _, component in ipairs(self.components) do
        if component.name == name then
            return component
        end
    end
end

function entity:set_active(active)
    if self._active ~= active then
        self._active = active
        self:_active_status_changed(active)
    end
end

function entity:set_visible(visible)
    self._visible = visible
end

return entity