local module = (...):match('(.-)[^%.]+$')

---@diagnostic disable-next-line
local ru = Darkrit._internal.require_utils

---@module "peachy"
local peachy = ru.require_third_party("josh-perry.peachy")

---@alias AnimatedSprite Dakrit.Graphics.AnimatedSprite

---@class Darkrit.ImageAsset
---@field image love.Image
---@field peachy_instance Dakrit.Graphics.AnimatedSprite
local Image = {}
Image.__index = Image

--- Creates a new Image
--- @param path string
--- @return Darkrit.ImageAsset
function Image.new(path)
    local image = love.graphics.newImage(path)
    local json_path = path:gsub('%.png$', '.json')
    local instance = {
        image = image,
        peachy_instance = peachy.new(json_path, image)
    }
    setmetatable(instance, Image)
    return instance
end

--- Creates a new animation instance
--- @param starting_tag string?
--- @return AnimatedSprite
function Image:new_animation_instance(starting_tag)
    local instance = self.peachy_instance:clone()
    if starting_tag then
        instance:setTag(starting_tag)
    end
    return instance
end

return Image