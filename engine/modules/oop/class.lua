local function createClass(definition)
    assert(type(definition) == "table", "Expected a table for class definition")

    local class = definition or {}
    class.__index = class

    local __init = class.__init

    local newIfExits = function(...)
        local instance = setmetatable({}, class)
        __init(instance, ...)   
        return instance
    end

    local newIfNotExits = function(...)
        return setmetatable({}, class)
    end

    class.new = __init and newIfExits or newIfNotExits

    return class
end

return createClass
