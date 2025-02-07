---@class DummyComp3 : Darkrit.Entity.Component
---@field sprite Dakrit.Graphics.AnimatedSprite
local DummyComp1 = {}
DummyComp1.__index = DummyComp1

--- Creates a new animated sprite component
function DummyComp1.new()
    return setmetatable({
        sorting_layer = Darkrit.graphics.SORTING_LAYER.CHARACTERS,
        sorting_order = -1,
        execution_order = 1
    }, DummyComp1)
end

---comment
function DummyComp1:on_created(asset)
    -- self:set_enabled(false)
end

function DummyComp1:on_update(dt)
    self.entity.position.x = self.entity.position.x + dt
end

function DummyComp1:on_draw()
    self.entity.position.x = self.entity.position.x + dt
end

return DummyComp1.new
