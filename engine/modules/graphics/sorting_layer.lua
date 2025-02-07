---@class Darkrit.Graphics.SortingLayerValue
local SortingLayerValue = {
    ordering = 0,
}

-- TODO: Be able to define this from the config file

---@enum Darkrit.Graphics.SortingLayer
local SortingLayer =
{
    BACKGROUND = { ordering = 1 },
    ENVIRONMENT = { ordering = 2 },
    CHARACTERS = { ordering = 3 },
    OVERLAY = { ordering = 4 },
    UI = { ordering = 5 }
}

return SortingLayer