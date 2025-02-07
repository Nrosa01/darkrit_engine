local ru = Darkrit._internal.require_utils ---@module "require_utils"
local nvec = ru.require_third_party('NPad93.nvec') ---@module "nvec"

---@class Darkrit.Graphics.PhysicsTransform
---@field body love.Body The associated physics body.
---@field scale NVec The current scale.
---@field position NVec The current position.
---@field rotation number The current rotation.
local physics_transform = {}
physics_transform.__index = physics_transform

---Creates a new physics transform for the given physics body.
---@param body love.Body
---@param base_transform Darkrit.Graphics.Transform
---@return Darkrit.Graphics.PhysicsTransform
function physics_transform.new(body, base_transform)
    local self = setmetatable({}, physics_transform)
    self.body = body
    self.position = base_transform and base_transform.position or nvec(0, 0)
    self.rotation = base_transform and base_transform.rotation or 0
    local scale = base_transform and base_transform.scale or nvec(1, 1)
    if scale ~= nvec(1, 1) then
        self.scale = scale
    else
        rawset(self, "scale", scale)
    end
    return self
end

-- Proxy metamethods: reading "position" and "rotation" returns the physics body's values;
-- writing to them calls the corresponding methods. "scale" assignment calls updateScale.
function physics_transform.__index(self, key)
    if key == "position" then
        local x, y = self.body:getPosition()
        return nvec(x, y)
    elseif key == "rotation" then
        return math.deg(self.body:getAngle())
    elseif key == "scale" then
        return rawget(self, "scale")
    else
        return rawget(physics_transform, key)
    end
end

function physics_transform.__newindex(self, key, value)
    if key == "position" then
        self.body:setPosition(value.x, value.y)
    elseif key == "rotation" then
        self.body:setAngle(math.rad(value))
    elseif key == "scale" then
        self:update_scale(value)
    else
        rawset(self, key, value)
    end
end

---Translates the physics body by the given translation vector.
---@param translation NVec
function physics_transform:translate(translation)
    local pos = self.position
    self.position = pos + translation
end

---Rotates the physics body by the given angle (in degrees).
---@param angle number
function physics_transform:rotate(angle)
    self.body:setAngle(self.body:getAngle() + math.rad(angle))
end

---Scales the transform by a factor.
---Since Box2D doesn't support scaling, this method updates the stored scale and re-creates
---each fixture using the current shape parameters scaled by the ratio (newScale/oldScale).
---@param factor NVec|number
function physics_transform:scale_by(factor)
    if type(factor) == "number" then
        self:update_scale(nvec(self.scale.x + factor, self.scale.y + factor))
    else
        self:update_scale(self.scale + factor)
    end
end

---Updates the scale to newScale.
---This method computes the ratio (newScale / oldScale) and for each fixture currently
---attached to the body (via body:getFixtures()) it:
--- 1. Retrieves the current shape parameters.
--- 2. Computes new shape parameters by multiplying by the ratio.
--- 3. Destroys the old fixture and creates a new fixture with the new shape,
---    copying density, friction, restitution, and sensor status.
---@param newScale NVec The new scale to set.
function physics_transform:update_scale(newScale)
    local oldScale = self.scale

    -- If scale is going to be less than or equal to zero, set to a small positive value to avoid division by zero.
    if newScale.x <= 0 then newScale.x = 0.01 end
    if newScale.y <= 0 then newScale.y = 0.01 end

    local ratio = nvec(newScale.x / oldScale.x, newScale.y / oldScale.y)
    local body = self.body
    local fixtures = body:getFixtures()
    for _, fixture in ipairs(fixtures) do
        local density = fixture:getDensity()
        local friction = fixture:getFriction()
        local restitution = fixture:getRestitution()
        local sensor = fixture:isSensor()
        local shape = fixture:getShape()
        local shapeType = shape:getType()
        local newShape = nil
        if shapeType == "circle" then
            local oldRadius = shape:getRadius()
            local oldOffsetX, oldOffsetY = shape:getX(), shape:getY()
            local newRadius = oldRadius * ((ratio.x + ratio.y) / 2)
            local newOffsetX = oldOffsetX * ratio.x
            local newOffsetY = oldOffsetY * ratio.y
            newShape = love.physics.newCircleShape(newOffsetX, newOffsetY, newRadius)
        elseif shapeType == "polygon" then
            local points = { shape:getPoints() }
            local newPoints = {}
            for i, point in ipairs(points) do
                if i % 2 == 1 then
                    newPoints[i] = point * ratio.x
                else
                    newPoints[i] = point * ratio.y
                end
            end
            newShape = love.physics.newPolygonShape(newPoints)
        else
            error("Unsupported shape type: " .. shapeType)
        end
        fixture:destroy()
        local newFixture = love.physics.newFixture(body, newShape, density)
        newFixture:setFriction(friction)
        newFixture:setRestitution(restitution)
        newFixture:setSensor(sensor)
    end
    self.scale = newScale
end

return physics_transform
