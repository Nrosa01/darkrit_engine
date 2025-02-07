---@diagnostic disable-next-line
local ru = Darkrit._internal.require_utils
local cargo = ru.require_third_party("bjornbytes.cargo")
---@module "silent_command"
local run_silently = ru.require_module("internal.silent_command")
---@module "image"
local Image = ru.require_module("graphics.image")

--- Load an image from a given path
---@param path string
---@return table
local function load_image(path)
    return Image.new(path)
end

local load_filesystem_load = love.filesystem.load

local script_cache = {}

local function load_script(path)
    local script = load_filesystem_load(path)()
    script_cache[script] = path
    package.loaded[path] = script
    return script
end

--- Wait for a file to be created
--- @param path string
local function wait_for_file(path)
    while not love.filesystem.getInfo(path) do
        love.timer.sleep(0.05)
    end
end

local function load_aseprite(path)
    -- Search for aseprite.exe using `where` if Windows, or `which` if Unix
    local os = love.system.getOS()
    local command = os == 'Windows' and 'where' or 'which'
    local success, handle = run_silently(command .. ' aseprite')
    if not success then
        error('Failed to find aseprite: ' .. handle)
    end

    -- Get the aseprite file name without extension
    local file_name = path:match("([^/\\]+)%.aseprite$")
    if not file_name then
        error('Invalid aseprite file path')
    end


    -- Run aseprite to export the frames as PNGs, also exports JSON as array, without layers nor slices but with tags
    -- Export .png and .json names are the same as the .aseprite file
    -- Layout sheet type is packed, constraints none
    -- All visible layers are exported, all frames are exported
    local file_name_with_path = path:match("(.+)%.[^/\\]+$")
    command = string.format('aseprite -b --list-tags --list-layers --format json-array --sheet "%s.png" --sheet-pack --data "%s.json" "%s"', file_name_with_path, file_name_with_path, path)
    
    local success, handle = run_silently(command)
    if not success then
        error('Failed to run aseprite: ' .. handle)
    end

    local png_path = path:gsub('%.aseprite$', '.png')
    local json_path = path:gsub('%.aseprite$', '.json')

    wait_for_file(png_path)
    wait_for_file(json_path)

    return load_image(png_path)
end

--- Load assets from a given path
---@param path string
---@return table
local function init(path)
    local assets = cargo.init({
        dir = path,
        loaders = {
            aseprite = {
                loader = load_aseprite,
                priority = 0
            },
            png = load_image,
            jpg = load_image,
            lua = load_script
        }
    })
    if assets then
        return assets
    else
        error('Failed to load assets')
    end
end

return {init, script_cache}