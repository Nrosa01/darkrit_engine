local ru = Darkrit._internal.require_utils ---@module "require_utils"
local nvec = ru.require_third_party('NPad93.nvec') ---@module "nvec"
local slick = ru.require_third_party('erinmaus.slick') ---@module "erinmaus.slick"

---@class Darkrit.Graphics.PhysicsTransformSlick
---@field body Darkrit.Entity.SlickEntity The associated physics body.
---@field scale NVec The current scale.
---@field position NVec The current position.
---@field rotation number The current rotation.
---@field slick_world slick.world The Slick physics world.
---@field slick_transform slick.geometry.transform The Slick transform object.
local physics_transform_slick = {}
physics_transform_slick.__index = physics_transform_slick

---Creates a new physics transform for the given physics body.
---@param body Darkrit.Entity.SlickEntity
---@param base_transform Darkrit.Graphics.Transform
---@return Darkrit.Graphics.PhysicsTransformSlick
function physics_transform_slick.new(body, base_transform)
    local self = setmetatable({}, physics_transform_slick)
    self.slick_world = body.entity.world.physics_world_slick
    self.body = body
    self.slick_transform = self.body.slick_entity.transform

    self.position = base_transform and base_transform.position or nvec(0, 0)
    self.rotation = base_transform and base_transform.rotation or 0
    self.scale = base_transform and base_transform.scale or nvec(1, 1)
    return self
end

function physics_transform_slick.__index(self, key)
    if key == "position" then
        return nvec(self.slick_transform.x, self.slick_transform.y)
    elseif key == "rotation" then
        return math.deg(self.slick_transform.rotation)
    elseif key == "scale" then
        local t = self.slick_transform
        return nvec(t.scaleX, t.scaleY)
    else
        return rawget(physics_transform_slick, key)
    end
end

function physics_transform_slick.__newindex(self, key, value)
    if key == "position" then
        self.slick_world:update(self.body.entity, value.x, value.y)
    elseif key == "rotation" then
        local transform = self.body.slick_entity.transform:clone()
        self.slick_world:update(self.body.entity, transform)
    elseif key == "scale" then
        local transform = self.body.slick_entity.transform:clone()
        transform.scaleX = value.x
        transform.scaleY = value.y
        self.slick_world:update(self.body.entity, transform)
    else
        rawset(self, key, value)
    end
end

---Translates the physics body by the given translation vector.
---@param translation NVec
function physics_transform_slick:translate(translation)
    local goal_x = self.slick_transform.x + translation.x
    local goal_y = self.slick_transform.y + translation.y
    self.slick_world:move(self.body.entity, goal_x, goal_y)
end

---Rotates the physics body by the given angle (in degrees).
---@param angle number
function physics_transform_slick:rotate(angle)
    self.slick_world:rotate(self.body.entity, math.rad(angle))
end

---Scales the transform by a factor.
---Since Box2D doesn't support scaling, this method updates the stored scale and re-creates
---each fixture using the current shape parameters scaled by the ratio (newScale/oldScale).
---@param factor NVec|number
function physics_transform_slick:scale_by(factor)
    error("Not implemented")
    if type(factor) == "number" then
    else
    end
end

return physics_transform_slick
