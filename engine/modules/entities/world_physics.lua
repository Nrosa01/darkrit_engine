--- This is just a helper to not bloat the world.lua file.
--- You shouldn't need editing this file
---@class Darkrit.World.PhysicsHelpers
local world_physcis = {}
---@diagnostic disable-next-line
local slick = Darkrit._internal.require_utils.require_third_party('erinmaus.slick') ---@module "erinmaus.slick"

-- Set global collision callback for physics
function world_physcis.begin_contact_box2d(a, b, contact)
    local entityA = a:getUserData() ---@type Darkrit.Entity
    local entityB = b:getUserData() ---@type Darkrit.Entity
    assert(entityA, "Entity A is nil")
    assert(entityB, "Entity B is nil")

    if a:isSensor() or b:isSensor() then
        entityA:send_message("on_trigger_enter", entityB, contact)
        entityB:send_message("on_trigger_enter", entityA, contact)
    else
        entityA:send_message("on_collision_enter", entityB, contact)
        entityB:send_message("on_collision_enter", entityA, contact)
    end
end

function world_physcis.end_contact_box2d(a, b, contact)
    local entityA = a:getUserData()
    local entityB = b:getUserData()
    assert(entityA, "Entity A is nil")
    assert(entityB, "Entity B is nil")

    if a:isSensor() or b:isSensor() then
        entityA:send_message("on_trigger_exit", entityB, contact)
        entityB:send_message("on_trigger_exit", entityA, contact)
    else
        entityA:send_message("on_collision_exit", entityB, contact)
        entityB:send_message("on_collision_exit", entityA, contact)
    end
end

local function is_box2d(world)
    return world.type and world:type() == "World"
end

function world_physcis.update(world, dt)
    if not world then
        return
    end

    if is_box2d(world) then
        world:update(dt)
    end
end

--- Debug draws all physics bodies and their shapes.
---@param physics_world love.World|slick.world?
function world_physcis.debug_draw_physics(physics_world)
    if physics_world == nil then
        return
    end

    if not is_box2d(physics_world) then
        ---@cast physics_world slick.world
        slick.drawWorld(physics_world, nil, Darkrit.config.physics.draw_options_slick)
        return
    end


    love.graphics.setColor(1, 0, 0, 1)
    for _, body in ipairs(physics_world:getBodies()) do
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
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return world_physcis
