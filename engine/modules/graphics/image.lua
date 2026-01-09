local module = (...):match('(.-)[^%.]+$')
local SpriteSheet = require(module .. 'spritesheet')

---@diagnostic disable-next-line
local ru = Darkrit._internal.require_utils

---@module "peachy"
local peachy = ru.require_third_party("josh-perry.peachy")

---@alias AnimatedSprite Darkrit.Graphics.AnimatedSprite

---@class Darkrit.ImageAsset
---@field image love.Image
local ImageAssetCreator = {}
ImageAssetCreator.__index = ImageAssetCreator

--- Creates a new Image
--- @param path string
--- @return Darkrit.Graphics.AnimatedSprite | Darkrit.Graphics.SpriteSheet
function ImageAssetCreator.new(path)
    local image = love.graphics.newImage(path)
    local json_path = path:gsub('%.png$', '.json')
    local json = Darkrit.utils.json.decode(love.filesystem.read(json_path))

    if json.meta and json.meta.app == "Darkrit" then
        return SpriteSheet.new(image, json)
    else
        return peachy.new(json, image)
    end
end

return ImageAssetCreator