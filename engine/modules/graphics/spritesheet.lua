local sprite = require("engine.modules.graphics.sprite")

---@class Darkrit.Graphics.SpriteSheet
---@field image love.Image
---@field tiles Darkrit.Graphics.Sprite[]
---@field groups table<string, Darkrit.Graphics.Sprite[]>
local sprite_sheet = {}
sprite_sheet.__index = function(self, key)
    local value = rawget(sprite_sheet, key)
    if value then return value end

    local named_tile = rawget(self, "tiles")[key]
    if named_tile then return named_tile end

    local group = rawget(self, "groups")[key]
    if group then return group end
    
    return nil
end

function sprite_sheet.new(image, json_data)
    local instance = setmetatable({
        image = image,
        tiles = {},      -- Numeric indexed array of sprites
        groups = {},     -- Group name to array of sprites mapping
        cell_size = nil
    }, sprite_sheet)
    
    instance:_initialize(json_data)
    return instance
end

function sprite_sheet:_initialize(data)
    self.cell_size = data.meta.cell_size
    local default_pivot = data.meta.default_pivot and 
        Darkrit.vec(data.meta.default_pivot.x, data.meta.default_pivot.y) or
        Darkrit.graphics.PIVOT.CENTER
    
    -- Create quads for all possible tiles
    local image_w, image_h = self.image:getDimensions()
    local cols = math.floor(image_w / self.cell_size)
    local rows = math.floor(image_h / self.cell_size)
    
    -- Create sprites array first without names
    for y = 0, rows - 1 do
        for x = 0, cols - 1 do
            local quad = love.graphics.newQuad(
                x * self.cell_size, y * self.cell_size,
                self.cell_size, self.cell_size,
                image_w, image_h
            )
            local spr = sprite.new(self.image, quad)
            spr:set_pivot(default_pivot)
            table.insert(self.tiles, spr)
        end
    end
    
    -- Map sprites by name and apply specific settings
    if data.sprites then
        for _, sprite_data in ipairs(data.sprites) do
            local index = sprite_data.sprite + 1  -- Convert to 1-based index
            if self.tiles[index] then
                -- Map name to sprite
                self.tiles[sprite_data.name] = self.tiles[index]
                
                -- Apply specific pivot if defined
                if sprite_data.pivot then
                    self.tiles[index]:set_pivot(
                        Darkrit.vec(sprite_data.pivot.x, sprite_data.pivot.y)
                    )
                end
            end
        end
    end
    
    -- Create groups
    if data.groups then
        for group_name, group_data in pairs(data.groups) do
            if type(group_data) == "table" then
                if group_data.from and group_data.to then
                    -- Range definition
                    self.groups[group_name] = {}
                    for i = group_data.from, group_data.to do
                        table.insert(self.groups[group_name], self.tiles[i])
                    end
                else
                    -- Array definition
                    self.groups[group_name] = {}
                    for _, index in ipairs(group_data) do
                        table.insert(self.groups[group_name], self.tiles[index])
                    end
                end
            end
        end
    end
end

-- Access methods
function sprite_sheet:get_tile(index)
    return self.tiles[index]
end

function sprite_sheet:get_tile_by_name(name)
    return self.tiles[name]
end

function sprite_sheet:get_group(name)
    return self.groups[name]
end

function sprite_sheet:get_random_from_group(name)
    local group = self.groups[name]
    if group then
        return group[love.math.random(#group)]
    end
    return nil
end

return sprite_sheet