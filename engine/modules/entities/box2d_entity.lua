local nvec = Darkrit.vec

---@class Darkrit.Entity.Box2DEntity : love.Body
local box2d_entity = {}
-- I know this adds overhead, but it allows you to work with this as it was a love.Body, pretty cool if you ask me xD
box2d_entity.__index = function(self, key)
    local value = box2d_entity[key]
    if value ~= nil then
        return value
    end

    -- Body must not be nil or I'll have a stickoverflow here
    rawset(self, '_body_key', key)
    return box2d_entity.call_inner
    -- I keep the below comment just in case, but they shoudn't be needed as every 
    -- love.body field is a function. 

    -- if body_value ~= nil then
        -- if type(body_value) == 'function' then
            -- return function(_, ...)
            --     return body_value(body, ...)
            -- end
        -- else
            -- return body_value
        -- end
    -- end

    -- return nil
end

function box2d_entity.new(entity, body_type, shape, shape_options)
    local bodyType = body_type or "dynamic"
    local world = entity.world.physics_world_box2d
    
    ---@class Darkrit.Entity.Box2DEntity
    local instance = 
    {
        _body_key = "", ---@package
        entity = entity,
        body = love.physics.newBody(world, entity.transform.position.x, entity.transform.position.y, bodyType)
    }

    instance.body:setUserData(entity)
    setmetatable(instance, box2d_entity)

    instance:_add_physics_shape(shape, shape_options)
    return instance
end

function box2d_entity:_destroy()
    self.body:destroy()
end

---@class Darkrit.Physics.ShapeOptions
---@field density number? The density of the shape
---@field isSensor boolean? Whether the shape is a sensor
---@field filter_data Darkrit.Physics.Config.Filter

--- Adds a physics shape to the entity's body.
---@param shape love.Shape The shape to add
---@param options Darkrit.Physics.ShapeOptions? Options for the shape
---@private
function box2d_entity:_add_physics_shape(shape, options)
    options = options or {}
    local density = options.density or 1
    local isSensor = options.isSensor or false
    local fixture = love.physics.newFixture(self.body, shape, density)
    fixture:setSensor(isSensor)
    fixture:setUserData(self.entity)
    options.filter_data =  options.filter_data or Darkrit.config.physics.layers.Default
    fixture:setFilterData(options.filter_data.category, options.filter_data.mask, 0)
    return fixture
end

---Changes the physics layer of the entity, which affects collision detection.
---@param layer Darkrit.Physics.Config.Filter
function box2d_entity:set_physics_layer(layer)
    local fixtures = self.body:getFixtures()
    for _, fixture in ipairs(fixtures) do
        fixture:setFilterData(layer.category, layer.mask, 0)
    end
end

--- Sets the group index of the entity's fixtures.
---@param group_index number
function box2d_entity:set_group_index(group_index)
    local fixtures = self.body:getFixtures()
    for _, fixture in ipairs(fixtures) do
        fixture:setGroupIndex(group_index)
    end
end

--- Sets linear velocity to reach a target position within a world update
--- Be aware that if you don't reset the velocity to 0, the body will keep moving
---@param position NVec
function box2d_entity:move_position(position)
    local currentPos = self.entity.transform.position
    local deltaPos = position - currentPos
    local dt = love.timer.getDelta()
    local velocity = deltaPos / dt
    self.body:setLinearVelocity(velocity.x, velocity.y)
end

--- Accelerates a physics body to a target velocity.
--- If the acceleration exceeds the max acceleration, it is clamped to the max acceleration.
--- This method works by calculating the force required to reach the target velocity, and applying that force to the body.
---@param target_velocity NVec
---@param max_acceleration number?
---@return NVec
function box2d_entity:accelerate_to(target_velocity, max_acceleration)
    max_acceleration = max_acceleration or math.huge

    local current_velocity = nvec(self.body:getLinearVelocity())
    local delta_v = target_velocity - current_velocity
    local dt = love.timer.getDelta()
    local acceleration = delta_v / dt
    if acceleration:len2() > max_acceleration * max_acceleration then
        acceleration = acceleration:normalize() * max_acceleration
    end
    local force = acceleration * self.body:getMass()
    self.body:applyForce(force:unpack())
    return acceleration
end

---@package
function box2d_entity:call_inner(...)
    self.body[self._body_key](self.body, ...)
end

return box2d_entity.new