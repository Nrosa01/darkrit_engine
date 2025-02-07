-- Rioni's Entity System
--
-- Copyright (c) 2024 Nicolas Rosa
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
-- OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.

require("table.clear")

---@diagnostic disable-next-line
local ru = Darkrit._internal.require_utils ---@module "require_utils"
local Entity = ru.require_module('entities.entity') ---@module "entities.entity"
local algorithm = Darkrit.algorithm ---@module "algorithm"
local adaptive_sort = algorithm.adaptive_inplace_sort

----------------------
--- Entity Group ---
---------------------

--- @class Darkrit.EntityGroup
--- @field name string The name of the group
--- @field entities Darkrit.Entity[] The entities in the group
local EntityGroup = {}
EntityGroup.__index = EntityGroup

--- Creates a new entity group
--- @param name string The name of the group
--- @return Darkrit.EntityGroup
function EntityGroup.new(name)
    local instance = setmetatable({
        name = name,
        entities = {},
    }, EntityGroup)
    return instance
end

--- Adds an entity to the group
--- @param entity Darkrit.Entity
--- @return Darkrit.EntityGroup
function EntityGroup:add(entity)
    self.entities[entity] = entity
    entity.groups[self.name] = self
    return self
end

--- Removes an entity from the group
--- @param entity Darkrit.Entity
--- @return Darkrit.EntityGroup
function EntityGroup:remove(entity)
    self.entities[entity] = nil
    entity.groups[self.name] = nil
    return self
end

----------------------
--- Entity System ---
---------------------

--- @class Darkrit.World
--- @field private _entities_to_add Darkrit.Entity[] @Entities to be added to the group
--- @field private _updateable_component_to_add Darkrit.Entity.Component[] @Components to be added to the entities
--- @field private _draw_component_to_add Darkrit.Entity.Component[] @Components to be added to the entities
--- @field entities Darkrit.Entity[] @Entities in the group
--- @field private _updateable_queue Darkrit.Entity.Component[] @Entities to be updated
--- @field private _groups table<string, Darkrit.EntityGroup> @Groups of entities
--- @field private _render_queue Darkrit.Entity.Component[]  @Entities to be rendered
--- @field private _entity_deleted_this_frame boolean @Whether an entity was deleted this frame
--- @field private _draw_component_deleted_this_frame boolean @Whether a component was deleted this frame
--- @field private _updateable_component_deleted_this_frame boolean @Whether a component was deleted this frame
--- @field private _render_frame number @Frame counter for sorting
--- @field physics_world love.World @The physics world
--- @field events table<string, fun(args: ...)[]> @Events to be broadcasted
local World = {}
World.__index = World

--- Creates a new entity group
--- @return Darkrit.World
function World.new()
    local instance = setmetatable({
        _entities_to_add = {},
        entities = {},
        _groups = {},
        _updateable_queue = {},
        _render_queue = {},
        events = {},
        _updateable_component_to_add = {},
        _draw_component_to_add = {},
        _entity_deleted_this_frame = false,
        _draw_component_deleted_this_frame = false,
        _updateable_component_deleted_this_frame = false,
        _render_frame = 0,
        physics_world = love.physics.newWorld(0, 0, true),
    }, World)

    -- Set global collision callback for physics
    local function beginContact(a, b, contact)
        local entityA = a:getUserData() ---@type Darkrit.Entity
        local entityB = b:getUserData() ---@type Darkrit.Entity
        if entityA then
            if a:isSensor() or b:isSensor() then
                entityA:send_message("on_trigger_enter", entityB, contact)
            else
                entityA:send_message("on_collision_enter", entityB, contact)
            end
        end
        if entityB then
            if a:isSensor() or b:isSensor() then
                entityB:send_message("on_trigger_exit", entityA, contact)
            else
                entityB:send_message("on_collision_exit", entityA, contact)
            end
        end
    end

    local function endContact(a, b, contact)
        local entityA = a:getUserData()
        local entityB = b:getUserData()
        if entityA then
            if a:isSensor() or b:isSensor() then
                entityA:send_message("on_trigger_exit", entityB, contact)
            else
                entityA:send_message("on_collision_exit", entityB, contact)
            end
        end
        if entityB then
            if a:isSensor() or b:isSensor() then
                entityB:send_message("on_trigger_exit", entityA, contact)
            else
                entityB:send_message("on_collision_exit", entityA, contact)
            end
        end
    end

    instance.physics_world:setCallbacks(beginContact, endContact)

    return instance
end

---Allows to hook to world events from outside the world
---@param event string
---@param callback fun(args: ...)
function World:on(event, callback)
    table.insert(self.events, { event, callback })
end

---Sends a message outside the world
---This is intended to let other systems know about world events
---@param event string
---@vararg any
function World:dispatch_outside(event, ...)
    for _, e in ipairs(self.events) do
        if e[1] == event then
            e[2](...)
        end
    end
end

--- Adds a new entity to the queue to be added to the group
--- @param name string? The name of the entity
--- @return Darkrit.Entity
function World:create_entity(name)
    local new_entity = Entity.new(self, name)
    table.insert(self._entities_to_add, new_entity)
    return new_entity
end

--- Finds an entity given the predicate. O(n) searched
--- @param predicate fun(entity: table): boolean
--- @param group string?
--- @return Darkrit.Entity?
function World:find(predicate, group)
    local entities = group and self._groups[group].entities or self.entities

    for _, e in ipairs(entities) do
        if predicate(e) then
            return e
        end
    end

    return nil
end

---Removes all entities that satisfy the given condition
---@param predicate fun(entity: table): boolean
function World:destroy_entities_matches_condition(predicate)
    for i, e in ipairs(self.entities) do
        if predicate(e) then
            self:destroy(e)
        end
    end
end

---Deletes a component or an entity by marking it for deletion
---@param world_element Darkrit.Entity | Darkrit.Entity.Component
function World:destroy(world_element)
    world_element._marked_for_deletion = true ---@diagnostic disable-line: invisible

    -- Check if metatable is the same as in entities
    if getmetatable(world_element) == Entity then
        self._entity_deleted_this_frame = true
    elseif world_element._component_type then
        self._draw_component_deleted_this_frame = world_element:_is_drawable()
        self._updateable_component_deleted_this_frame = world_element:_is_updateable()

        local entity = world_element.entity

        -- If entity component table is empty, is because it was deleted
        if not entity.components then
            return
        end

        -- Remove component from entity
        for i = 1, #entity.components do
            if entity.components[i] == world_element then
                table.remove(entity.components, i)
                break
            end
        end
    end
end

function World:add_component(component)
    if component:_is_drawable() then
        table.insert(self._draw_component_to_add, component)
    end

    if component:_is_updateable() then
        table.insert(self._updateable_component_to_add, component)
    end
end

---@private
function World:_remove_marked_entities()
    if not self._entity_deleted_this_frame then
        return
    end

    -- Order so entities marked for deletion are at the end, then just I
    -- Iterate backward setting the entities to nil until reaching one that is not marked
    -- This way I can delete many entities whithout shifting the array many times
    adaptive_sort(self.entities, function(a, b)
        return not a._marked_for_deletion and b._marked_for_deletion
    end)

    for i = #self.entities, 1, -1 do
        if self.entities[i]._marked_for_deletion then
            self.entities[i]:broadcast('on_destroy')
            for j = 1, #self.entities[i].components do
                self:destroy(self.entities[i].components[j])
            end
            self.entities[i].components = nil
            self.entities[i] = nil
        else
            break
        end
    end

    self._entity_deleted_this_frame = false
end

function World:get_entity_count()
    return #self.entities
end

--- Adds all pending entities to the group
--- @private
function World:_flush_entities()
    assert(self._entities_to_add, 'Entities to add is nil')

    local src = self._entities_to_add
    local len = #src
    if len == 0 then return end -- Proper empty check

    -- Bulk copy entities
    local entities = self.entities
    table.move(src, 1, len, #entities + 1, entities)

    -- Process events after bulk copy
    for i = 1, len do
        src[i]:broadcast('on_added')
    end

    table.clear(self._entities_to_add) -- Reuse table
end

---@private
function World:_flush_components()
    -- Bulk copy updateable components
    local update_src = self._updateable_component_to_add
    local update_len = #update_src
    if update_len > 0 then
        local dest = self._updateable_queue
        table.move(update_src, 1, update_len, #dest + 1, dest)
        self:_reorder_update_queue()
    end

    -- Bulk copy draw components
    local draw_src = self._draw_component_to_add
    local draw_len = #draw_src
    if draw_len > 0 then
        local dest = self._render_queue
        table.move(draw_src, 1, draw_len, #dest + 1, dest)
    end

    -- Reuse tables instead of recreating
    table.clear(self._updateable_component_to_add)
    table.clear(self._draw_component_to_add)
end

function World:_reorder_update_queue()
    adaptive_sort(self._updateable_queue, function(a, b)
        return a.execution_order < b.execution_order -- The first screen executed are the ones with the lowest order
    end)
end

function World:_remove_marked_components()
    if self._draw_component_deleted_this_frame then
        -- We are going to sort both tables so the marked components are at the end
        -- Then we are going to iterate backwards and remove the marked components
        if self._draw_component_deleted_this_frame then
            adaptive_sort(self._render_queue, function(a, b)
                return not a._marked_for_deletion and b._marked_for_deletion
            end)

            for i = #self._render_queue, 1, -1 do
                if self._render_queue[i]._marked_for_deletion then
                    table.remove(self._render_queue, i)
                else
                    break
                end
            end
        end

        self._draw_component_deleted_this_frame = false
    end

    if self._updateable_component_deleted_this_frame then
        if self._updateable_component_deleted_this_frame then
            adaptive_sort(self._updateable_queue, function(a, b)
                return not a._marked_for_deletion and b._marked_for_deletion
            end)

            for i = #self._updateable_queue, 1, -1 do
                if self._updateable_queue[i]._marked_for_deletion then
                    table.remove(self._updateable_queue, i)
                else
                    break
                end
            end
        end

        self._updateable_component_deleted_this_frame = false

        self:_reorder_update_queue()
    end
end

---@private
function World:_flush()
    self:_flush_entities()
    self:_flush_components()
end

---@private
function World:_remove_marked()
    self:_remove_marked_entities()
    self:_remove_marked_components()
end

function World:update(dt)
    self:_flush()
    self:_remove_marked()

    for i = 1, #self._updateable_queue do
        self._updateable_queue[i]:update(dt)
    end

    self.physics_world:update(dt)
end

local function sort_to_num(a)
    return a.sorting_layer.ordering * 1e10 + a.render_order * 1e5 + a.entity.position.y
end

function World:draw()
    --- Only sort every x frames to aliviate some CPU
    --- User shouldn't perceive the sort delay
    --- In the future I could sort dynamically depending on FPS
    --- So if the machine can with it, it will sort every frame, if not, every 3
    if Darkrit.config.graphics.y_sorting_config.enabled and self._render_frame % self._render_frame % Darkrit.config.graphics.y_sorting_config.frame_skip == 0 then
        adaptive_sort(self._render_queue)
    end

    for i = 1, #self._render_queue do
        self._render_queue[i]:draw()
    end

    self._render_frame = self._render_frame + 1
end

function World:get_entities_in_group(group_name)
    local group = self._groups[group_name]
    assert(group, 'Group does not exist')
    return group.entities
end

---Deletes a group of entities and optionally deletes the entities
---@param group_name string
---@param delete_entities? boolean
function World:delete_group(group_name, delete_entities)
    self._groups[group_name] = nil

    if delete_entities then
        for _, e in ipairs(self.entities) do
            if e.groups[group_name] then
                self:destroy(e)
            end
        end
    end
end

function World:add__to_group(entity, group_name)
    local group = self._groups[group_name]

    if not group then
        group = EntityGroup.new(group_name)
        self._groups[group_name] = group
    end

    group:add(entity)
end

function World:remove_from_group(entity, group_name)
    local group = self._groups[group_name]
    assert(group, 'Group does not exist')
    group:remove(entity)
end

--- Debug draws all physics bodies and their shapes.
function World:debugDrawPhysics()
    love.graphics.setColor(1, 0, 0, 1)
    for _, body in ipairs(self.physics_world:getBodies()) do
        for _, fixture in ipairs(body:getFixtures()) do
            local shape = fixture:getShape()
            local shapeType = shape:getType()
            if shapeType == "circle" then
                local x, y = body:getPosition()
                local radius = shape:getRadius()
                love.graphics.circle("line", x, y, radius)
            elseif shapeType == "polygon" then
                love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
            end
            -- Extend for other shape types as needed.
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return World
