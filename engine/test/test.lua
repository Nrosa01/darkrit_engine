local module = (...):match("(.-)[^%.]+$")
local tests = {}
---@diagnostic disable-next-line
local test_system = require(module .. "test_system")

---@diagnostic disable-next-line
local ru = Darkrit._internal.require_utils

local function loadTests()
    local lfs = love.filesystem
    local module_to_path = module:gsub("%.", "/")
    local testDir = module_to_path .. "tests/"

    for _, file in ipairs(lfs.getDirectoryItems(testDir)) do
        local testName = file:sub(1, -5)
        local new_test = ru.require("tests." .. testName, 'test')

        if type(new_test) == "function" then
            -- Obtener información de los parámetros de la función
            local func_info = debug.getinfo(new_test, "u")
            -- Verificar que tenga exactamente 1 parámetro y no sea variádica
            if func_info.nparams == 1 and not func_info.isvararg then
                tests[testName] = new_test
            else
                print("Test function '" .. testName .. "' must accept only one parameter")
            end
        end
    end
end

local function runTests()
    if not next(tests) then
        loadTests()
    end
    
    for _, testModule in pairs(tests) do
        testModule(test_system)
    end

    test_system.run_all()
end

return runTests
