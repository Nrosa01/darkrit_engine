local bit = require("bit")

---@class Darkrit.Entity.Component
---@field name string The name of the component
---@field entity Darkrit.Entity The associated Entity to this component
---@field world Darkrit.World The world this component is in
---@field sorting_layer Darkrit.Graphics.SortingLayerValue?
---@field render_order number?
---@field execution_order number?
---@field _component_type Darkrit.Entity.ComponentType
---@field private _marked_for_deletion boolean Whether this component is marked for deletion
---@field protected _enabled boolean Whether this component is enabled
local component = {}

local component_name_storage = {}

---@enum Darkrit.Entity.ComponentType
local COMPONENT_TYPE = {
    COMPONENT = 1,  -- 00000001
    UPDATEABLE = 2, -- 00000010
    DRAWABLE = 4    -- 00000100
}

---@private
component.__index = component

local function get_component_name(component)
    if component_name_storage[component] then
        return component_name_storage[component]
    end

    local full_path_name = Darkrit._internal.script_cache[component]
    -- Darkrit.config has the following
    -- assets_path = 'assets/'
    -- scripts_path = 'scripts/'
    -- components_path = 'scripts/components/'
    -- Script path and component paths are relative to the assets path
    -- The component name must be without the assets path and the components path
    -- So if a script is located in 'assets/scripts/components/player/player_movement.lua'
    -- The component name must be 'player.player_movement'

    local stripped = full_path_name:gsub("^" .. Darkrit.config.assets_path, "")
    stripped = stripped:gsub("^/" .. Darkrit.config.components_path, "")
    stripped = stripped:gsub("%.lua$", "")
    stripped = stripped:gsub("^/+", "")
    local name = stripped:gsub("/+$", ""):gsub("/", ".")
    component_name_storage[component] = name
    return name
end

-- This engine uses y sortering
---Sort the entities first by SortingLayer.ordering and then by render_order, finally by y position
---This method shouldn't be here, but I want to have it as a local for faster access
---@param a Darkrit.Entity.Component
---@param b Darkrit.Entity.Component
local lt = function(a, b)
    return a.sorting_layer.ordering < b.sorting_layer.ordering or
        (a.sorting_layer.ordering == b.sorting_layer.ordering and
            (a.render_order < b.render_order or
                a.render_order == b.render_order and
                (a.entity.transform.position.y < b.entity.transform.position.y)))
end

--- Testing if using this is faster than the branching with if else
---@param a Darkrit.Entity.Component
local function sort_to_num(a)
    return a.sorting_layer.ordering * 1e10 + a.render_order * 1e5 + a.entity.transform.position.y
end

---Creates a new component
---@param entity Darkrit.Entity The entity to associate with this component
---@param component_constructor Darkrit.Entity.Component
---@param args table? Optional table with additional functions and variables for the component
---@private
function component._new(entity, component_constructor, args)
    local data = component_constructor()

    -- Use data as the base table
    local instance = data or {}
    local instance_meta = getmetatable(instance) or {}
    instance_meta.__lt = lt

    -- Copy the fixed fields from component into the instance
    instance._component_type = COMPONENT_TYPE.COMPONENT
    instance.name = get_component_name(component_constructor)
    instance.entity = entity
    instance.world = entity.world
    instance._enabled = true
    instance._marked_for_deletion = false

    -- To avoid the slight overhead of the metatable, we copy the methods directly
    instance.on_update = instance_meta.on_update
    instance.on_draw = instance_meta.on_draw


    -- If it's an updateable, it must have an execution_order
    if instance.on_update then
        instance.execution_order = instance.execution_order or 0
        instance._component_type = bit.bor(instance._component_type, COMPONENT_TYPE.UPDATEABLE)
    end

    -- Only for drawables
    if instance.on_draw then
        if not instance.sorting_layer then
            instance.sorting_layer = Darkrit.graphics.SORTING_LAYER.BACKGROUND
        end

        instance.render_order = instance.render_order or 0
        instance._component_type = bit.bor(instance._component_type, COMPONENT_TYPE.DRAWABLE)
    end


    -- Copy the methods from component into the instance
    for k, v in pairs(component) do
        if instance[k] == nil  and type(v) == "function" then
            instance[k] = v
        end
    end

    if instance.on_created then
        instance:on_created(args)
    end

    return instance
end

function component:_is_updateable()
    return bit.band(self._component_type, COMPONENT_TYPE.UPDATEABLE) ~= 0
end

function component:_is_drawable()
    return bit.band(self._component_type, COMPONENT_TYPE.DRAWABLE) ~= 0
end

---@private
function component:_dispatch(message, ...)
    if self[message] then
        self[message](self, ...)
    end
end

function component:update(dt)
    if self._enabled then
        self:_dispatch('on_update', dt)
    end
end

function component:draw()
    if self.entity._visible then
        love.graphics.push()
        self.entity:_force_update_transform()
        love.graphics.applyTransform(self.entity._internal_transform)

        self:_dispatch('on_draw')

        love.graphics.pop()
    end
end

-- If the entity is disabled, the component is disabled as well, but
-- given components have their own enabled status, we have to take that into account
-- To not use more variables and not complicate the system, I built this function
-- Basically, if the component was enabled and the entity is disabled, the component will dispatch the on_disable event
-- For that reason, if the component was enabled and the entity is enabled, th component will dispatch the on_enable event
-- Because we can tell that the on_disable had to be call previously and the state of the component SHOULDN't have change while not active
-- For that same reason, if the component is set as disabled, it won't dispatch the on_enable event when the entity gets active
---@private
function component:_entity_active_status_changed(status)
    if self._enabled and not status then
        self:_dispatch('on_disable')
    end

    if not self._enabled and status then
        self:_dispatch('on_enable')
    end
end

---Enables the component
---@param enabled boolean
function component:set_enabled(enabled)
    if enabled ~= self._enabled then
        self._enabled = enabled

        if enabled then
            self:_dispatch('on_enable')
        else
            self:_dispatch('on_disable')
        end
    end
end

return component
