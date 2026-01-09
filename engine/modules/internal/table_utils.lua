---@class Darkrit.Internal.TableUtils
local table_utils = {}

function table_utils.tables_are_equal(t1, t2)
    for k, v in pairs(t1) do
        if type(v) == "table" and type(t2[k]) == "table" then
            if not table_utils.tables_are_equal(v, t2[k]) then
                return false
            end
        else
            if v ~= t2[k] then
                return false
            end
        end
    end

    return true
end

return table_utils