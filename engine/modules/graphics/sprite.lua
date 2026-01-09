local ffi = require("ffi")

ffi.cdef[[
typedef struct {
    bool horizontal;
    bool vertical;
} Flip;
]]

---@class Darkrit.Graphics.Sprite
---@field image love.Image
---@field quad love.Quad
---@field color table
---@field flip Darkrit.Graphics.AnimatedSprite.Flip
---@field pivot NVec
---@field pivot_offset NVec
local sprite = {}
sprite.__index = sprite

function sprite.new(image, quad)
    local self = setmetatable({
        image = image,
        quad = quad,
        color = { 1, 1, 1, 1 },
        flip = ffi.new("Flip"),
        pivot = Darkrit.graphics.PIVOT.CENTER,      -- Default pivot point
        pivot_offset = Darkrit.graphics.PIVOT.TOP_LEFT:clone()
    }, sprite)
    
    self:_recalculate_pivot_offset()
    return self
end

---Set the pivot point for the sprite.
---You can pass either a NVec or a Darkrit.Graphics.Pivot enum value
---@param pivot Darkrit.Graphics.Pivot | NVec
function sprite:set_pivot(pivot)
    self.pivot = pivot
    self:_recalculate_pivot_offset()
end

function sprite:_recalculate_pivot_offset()
    local w, h = self:get_dimensions()
    self.pivot_offset.x = self.pivot.x * w
    self.pivot_offset.y = self.pivot.y * h
end

--- Draws the sprite
---@param x number
---@param y number
---@param r number
---@param sx number
---@param sy number
function sprite:draw(x, y, r, sx, sy)
    local prev_color = { love.graphics.getColor() }
    love.graphics.setColor(unpack(self.color))
    
    local w, h = self:get_dimensions()
    sx = sx or 1
    sy = sy or 1
    
    -- Apply flipping
    if self.flip.horizontal then
        sx = sx * -1
    end
    if self.flip.vertical then
        sy = sy * -1
    end
    
    -- Calculate offset considering pivot and flipping
    local ox = self.pivot_offset.x
    local oy = self.pivot_offset.y
    
    if self.flip.horizontal then
        ox = w - ox
    end
    if self.flip.vertical then
        oy = h - oy
    end
    
    love.graphics.draw(self.image, self.quad, x, y, r or 0, sx, sy, ox, oy)
    love.graphics.setColor(unpack(prev_color))
end

--- Set the color of the sprite tinting. 
--- Colours are in the range of 0-1
---@param r number
---@param g number
---@param b number
---@param a number
function sprite:set_color(r, g, b, a)
    if type(r) == "table" then
        self.color = { r[1], r[2], r[3], r[4] or 1 }
    else
        self.color = { r, g, b, a or 1 }
    end
end

function sprite:set_flip(horizontal, vertical)
    self.flip.horizontal = horizontal
    self.flip.vertical = vertical
end

function sprite:flip_horizontal()
    self.flip.horizontal = not self.flip.horizontal
end

function sprite:flip_vertical()
    self.flip.vertical = not self.flip.vertical
end

function sprite:get_horizontal_flip()
    return self.flip.horizontal
end

function sprite:get_vertical_flip()
    return self.flip.vertical
end

function sprite:get_dimensions()
    local _, _, w, h = self.quad:getViewport()
    return w, h
end

function sprite:get_center_position()
    local w, h = self:get_dimensions()
    local center_x = w/2
    local center_y = h/2
    return center_x - self.pivot_offset.x, center_y - self.pivot_offset.y
end

function sprite:clone()
    local new_sprite = setmetatable({
        image = self.image,
        quad = self.quad,
        color = { unpack(self.color) },
        flip = ffi.new("Flip"),
        pivot = self.pivot,
        pivot_offset = self.pivot_offset:clone()
    }, sprite)
    
    new_sprite.flip.horizontal = self.flip.horizontal
    new_sprite.flip.vertical = self.flip.vertical
    
    return new_sprite
end

return sprite
