local ru = Darkrit._internal.require_utils ---@module "require_utils"
local nvec = ru.require_third_party('NPad93.nvec') ---@module "nvec"
---@class Darkrit.Physics.Utils
local physics_utils = {}

--- Accelerates a physics body to a target velocity.
--- If the acceleration exceeds the max acceleration, it is clamped to the max acceleration.
--- This method works by calculating the force required to reach the target velocity, and applying that force to the body.
---@param body love.Body
---@param targetVelocity NVec
---@param maxAcceleration number?
---@return NVec
function physics_utils:accelerate_to(body, targetVelocity, maxAcceleration)
    -- Default maxAcceleration to math.huge if not provided
    maxAcceleration = maxAcceleration or math.huge
    
    -- Get current velocity as vector
    local currentVelocity = nvec(body:getLinearVelocity())
    
    -- Calculate delta velocity vector
    local deltaV = targetVelocity - currentVelocity
    
    -- Calculate acceleration vector (deltaV / dt)
    local dt = love.timer.getDelta()
    local acceleration = deltaV / dt
    
    -- Check if acceleration exceeds max acceleration
    if acceleration:len2() > maxAcceleration * maxAcceleration then
        acceleration = acceleration:normalize() * maxAcceleration
    end
    
    -- Apply force (F = ma)
    local force = acceleration * body:getMass()
    body:applyForce(force:unpack())
    
    return acceleration
end

return physics_utils
