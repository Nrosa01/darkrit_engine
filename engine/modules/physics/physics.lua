---@class Darkrit.Physics
local physics = {
    ---@type love.World[]
    worlds = {}
}
physics.__index = physics

function physics:add_box2d_world(world)
    table.insert(physics.worlds, world)
end

function physics:remove_box2d_world(world)
    for i, w in ipairs(self.worlds) do
        if w == world then
            table.remove(self.worlds, i)
            break
        end
    end
end

function physics:update_entities_filter(new_filter)
    Darkrit.config.physics.layers = new_filter
    self:update_entities_filter_category()
end

function physics:update_entities_filter_category()
    -- Tabhle for quickcly looking up masks for a given category
    local filter = Darkrit.config.physics.layers
    local lookup_table = {}

    for _, data in pairs(filter) do
        lookup_table[data.category] = data.mask
    end

    local worlds = self.worlds
    for _, world in ipairs(worlds) do
        for _, body in ipairs(world:getBodies()) do
            for _, fixture in ipairs(body:getFixtures()) do
                local categories, _, group = fixture:getFilterData()
                fixture:setFilterData(categories, lookup_table[categories], group)
            end
        end
    end
end

return physics
