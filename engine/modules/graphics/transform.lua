local ru = Darkrit._internal.require_utils ---@module "require_utils"
local nvec = ru.require_third_party('NPad93.nvec') ---@module "nvec"

---@class Darkrit.Graphics.Transform
local transform = {}
transform.__index = transform

---Creates a new transform instance.
---@param position NVec|Darkrit.Graphics.Transform? The position of the transform.
---@param rotation number? The rotation of the transform in degrees.
---@param scale NVec? The scale of the transform.
---@return Darkrit.Graphics.Transform
---@overload fun(): Darkrit.Graphics.Transform
---@overload fun(other_transform: Darkrit.Graphics.Transform): Darkrit.Graphics.Transform
function transform.new(position, rotation, scale)
    if type(position) == "cdata" and position.position then
        -- Copy constructor overload: when the first argument is a transform.
        local other = position
        return setmetatable({
            position = other.position or nvec(0, 0),
            rotation = other.rotation or 0,
            scale = other.scale or nvec(1, 1)
        }, transform)
    else
        return setmetatable({
            position = position or nvec(0, 0),
            rotation = rotation or 0,
            scale = scale or nvec(1, 1)
        }, transform)
    end
end


--- Translates the transform by the given translation vector.
--- @param translation NVec
function transform:translate(translation)
    self.position = self.position + translation
end

--- Scales the transform by the given factor. It does addition not multiplaction
--- @param factor NVec | number
function transform:scale_by(factor)
    assert(type(factor) == "number" or factor.x and factor.y, "Factor must be a number or a vector")
    if type(factor) == "number" then
        factor = nvec(factor, factor)
    end    
    self.scale = self.scale + factor
end

--- Rotates the transform by the given angle in degrees.
---@param angle number
function transform:rotate(angle)
    self.rotation = self.rotation + angle
end

return transform
