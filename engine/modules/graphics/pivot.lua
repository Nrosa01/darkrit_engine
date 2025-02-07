local Vec = Darkrit.vec

---@enum Darkrit.Graphics.Pivot
local PIVOT = {
    TOP_LEFT = Vec(0, 0),
    TOP = Vec(0.5, 0),
    TOP_RIGHT = Vec(1, 0),
    LEFT = Vec(0, 0.5),
    CENTER = Vec(0.5, 0.5),
    RIGHT = Vec(1, 0.5),
    BOTTOM_LEFT = Vec(0, 1),
    BOTTOM = Vec(0.5, 1),
    BOTTOM_RIGHT = Vec(1, 1)
}

-- ---@diagnostic disable-next-line
-- PIVOT.PIVOT_TO_NORMALIZED_COORDINATES = {
--     [PIVOT.TOP_LEFT] = Vec(0, 0),
--     [PIVOT.TOP] = Vec(0.5, 0),
--     [PIVOT.TOP_RIGHT] = Vec(1, 0),
--     [PIVOT.LEFT] = Vec(0, 0.5),
--     [PIVOT.CENTER] = Vec(0.5, 0.5),
--     [PIVOT.RIGHT] = Vec(1, 0.5),
--     [PIVOT.BOTTOM_LEFT] = Vec(0, 1),
--     [PIVOT.BOTTOM] = Vec(0.5, 1),
--     [PIVOT.BOTTOM_RIGHT] = Vec(1, 1)
-- }

return PIVOT