local config_serializer = {}

-- Convert a non-table value to its string representation
local function to_string(value)
    if type(value) == "string" then
        return string.format("%q", value)
    else
        return tostring(value)
    end
end

-- Serialize a table with indentation
local function serialize_table(t, indent)
    indent = indent or ""
    local lines = {"{"}
    local next_indent = indent .. "    "
    for k, v in pairs(t) do
        local key_str = (type(k) == "number") and ("[" .. k .. "]") or k
        if type(v) == "table" then
            table.insert(lines, next_indent .. key_str .. " = " .. serialize_table(v, next_indent) .. ",")
        else
            table.insert(lines, next_indent .. key_str .. " = " .. to_string(v) .. ",")
        end
    end
    table.insert(lines, indent .. "}")
    return table.concat(lines, "\n")
end

function config_serializer.save_config(original_path, edited_path, modified_config)
    -- Read original file content
    local original_content = love.filesystem.read(original_path)
    if not original_content then
        return false, "Could not read original config"
    end

    -- Extract header (everything before "local config = {")
    local header, _ = original_content:match("^(.-)\n(local%s+config%s*=%s*{)")
    header = header or ""

    -- Serialize modified config
    local serialized_config = serialize_table(modified_config, "")

    -- Build new content preserving header and adding "return config"
    local new_content = header .. "local config = " .. serialized_config .. "\n\nreturn config"

    -- Write new content to edited file
    local file = io.open(edited_path, "w")
    if not file then
        return false, "Could not open output file"
    end
    file:write(new_content)
    file:close()

    return true
end

return config_serializer
