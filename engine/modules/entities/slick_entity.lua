---@diagnostic disable-next-line
local ru = Darkrit._internal.require_utils ---@module "require_utils"
local slick = ru.require_third_party('erinmaus.slick') ---@module "erinmaus.slick"
local physics_transform_slick = ru.require_module('entities.physics_transform_slick') ---@module "entities.physics_transform_slick"

---@class Darkrit.Entity.SlickEntity
---@field entity Darkrit.Entity
---@field slick_entity slick.entity
local slick_entity = {}
slick_entity.__index = slick_entity

---comment
---@param entity Darkrit.Entity
---@param shape slick.collision.shape
---@return Darkrit.Entity.SlickEntity
function slick_entity.new(entity, shape)
    local x = entity.transform.position.x
    local y = entity.transform.position.y
    local slick_entity = entity.world.physics_world:add(entity, x, y, shape)
    
    local instance = setmetatable({
        entity = entity,
        slick_entity = slick_entity,
    }, slick_entity)

    ---@diagnostic disable-next-line
    entity.transform = physics_transform_slick.new(instance, entity.transform)

    return instance
end

function slick_entity:_destroy()
    self.entity.world.physics_world:remove(self.slick_entity)
end

return slick_entity
