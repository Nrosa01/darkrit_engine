local bit = require("bit")

---@class PhysicsEditor
---@field categories string[] List of collision categories
---@field n number Number of categories
---@field collisions table<number, table<number, boolean>> Collision matrix
---@field editing boolean Whether we're currently editing a category name
---@field editing_index number? Index of category being edited
---@field editing_text string Current text being edited
---@field last_click_time number Time of last click for double-click detection
---@field last_clicked_index number? Index of last clicked category
---@field on_exit function? Callback function to be called when exiting the editor
---@field hovered_button string? Name of the button being hovered
local PhysicsEditor = {}
PhysicsEditor.__index = PhysicsEditor

-- Constants
PhysicsEditor.GRID_SIZE = 500
PhysicsEditor.MARGIN_LEFT = 150
PhysicsEditor.MARGIN_TOP = 150  -- Increased to make room for controls
PhysicsEditor.MARGIN_RIGHT = -100
PhysicsEditor.DOUBLE_CLICK_THRESHOLD = 0.3
PhysicsEditor.MAX_CATEGORIES = 32
PhysicsEditor.CATEGORIES_PER_COLUMN = 8

-- Button dimensions
PhysicsEditor.BUTTON_WIDTH = 120
PhysicsEditor.BUTTON_HEIGHT = 30
PhysicsEditor.BUTTON_SPACING = 10

-- Button positions (Horizontal)
PhysicsEditor.BUTTON_START_X = 20
PhysicsEditor.BUTTON_Y = 20
PhysicsEditor.ADD_BUTTON_X = PhysicsEditor.BUTTON_START_X
PhysicsEditor.REMOVE_BUTTON_X = PhysicsEditor.ADD_BUTTON_X + PhysicsEditor.BUTTON_WIDTH + PhysicsEditor.BUTTON_SPACING
PhysicsEditor.EXPORT_BUTTON_X = PhysicsEditor.REMOVE_BUTTON_X + PhysicsEditor.BUTTON_WIDTH + PhysicsEditor.BUTTON_SPACING
PhysicsEditor.EXIT_BUTTON_X = PhysicsEditor.EXPORT_BUTTON_X + PhysicsEditor.BUTTON_WIDTH + PhysicsEditor.BUTTON_SPACING
PhysicsEditor.ADD_BUTTON_Y = PhysicsEditor.BUTTON_Y
PhysicsEditor.REMOVE_BUTTON_Y = PhysicsEditor.BUTTON_Y
PhysicsEditor.EXPORT_BUTTON_Y = PhysicsEditor.BUTTON_Y
PhysicsEditor.EXIT_BUTTON_Y = PhysicsEditor.BUTTON_Y

-- Button rectangles (x, y, width, height)
PhysicsEditor.ADD_BUTTON_RECT = {PhysicsEditor.ADD_BUTTON_X, PhysicsEditor.ADD_BUTTON_Y, PhysicsEditor.BUTTON_WIDTH, PhysicsEditor.BUTTON_HEIGHT}
PhysicsEditor.REMOVE_BUTTON_RECT = {PhysicsEditor.REMOVE_BUTTON_X, PhysicsEditor.REMOVE_BUTTON_Y, PhysicsEditor.BUTTON_WIDTH, PhysicsEditor.BUTTON_HEIGHT}
PhysicsEditor.EXPORT_BUTTON_RECT = {PhysicsEditor.EXPORT_BUTTON_X, PhysicsEditor.EXPORT_BUTTON_Y, PhysicsEditor.BUTTON_WIDTH, PhysicsEditor.BUTTON_HEIGHT}
PhysicsEditor.EXIT_BUTTON_RECT = {PhysicsEditor.EXIT_BUTTON_X, PhysicsEditor.EXIT_BUTTON_Y, PhysicsEditor.BUTTON_WIDTH, PhysicsEditor.BUTTON_HEIGHT}

local CONTROLS_TEXT = [[
Controls:
[A] Add category    [D] Remove category
[E] Export to Lua   [ESC] Exit
[Double-Click] Edit name
[Click] Toggle collision
]]

---Creates a new PhysicsEditor instance
---@param initial_filters? table<string, {category: number, mask: number}> Initial collision filters
---@param on_exit? function Callback function to be called when exiting the editor
---@return PhysicsEditor
function PhysicsEditor.new(initial_filters, on_exit)
    local self = setmetatable({}, PhysicsEditor)
    
    self.on_exit = on_exit
    self.hovered_button = nil
    
    if initial_filters and type(initial_filters) == "table" then
        -- Extract categories and sort them by category number
        local categories_map = {}
        for name, filter in pairs(initial_filters) do
            if type(filter.category) == "number" then
                local category_index = 1
                while filter.category > 1 do
                    filter.category = filter.category / 2
                    category_index = category_index + 1
                end
                categories_map[category_index] = name
            end
        end
        
        -- Convert to ordered array
        self.categories = {}
        for i = 1, 32 do
            if categories_map[i] then
                table.insert(self.categories, categories_map[i])
            end
        end
        
        if #self.categories == 0 then
            self.categories = {"Player", "Enemy", "Map", "Other"}
        end
    else
        self.categories = {"Player", "Enemy", "Map", "Other"}
    end

    self.editing = false
    self.editing_index = nil
    self.editing_text = ""
    self.last_click_time = 0
    self.last_clicked_index = nil
    self.n = #self.categories

    -- Initialize collision table
    self.collisions = {}
    for i = 1, self.n do
        self.collisions[i] = {}
        for j = i, self.n do
            -- Calculate if these categories collide based on masks
            if initial_filters then
                local cat1 = self.categories[i]
                local cat2 = self.categories[j]
                local filter1 = initial_filters[cat1]
                local filter2 = initial_filters[cat2]
                if filter1 and filter2 then
                    local cat1_bit = bit.lshift(1, i - 1)
                    local cat2_bit = bit.lshift(1, j - 1)
                    self.collisions[i][j] = bit.band(filter1.mask, cat2_bit) ~= 0 
                        or bit.band(filter2.mask, cat1_bit) ~= 0
                else
                    self.collisions[i][j] = false
                end
            else
                self.collisions[i][j] = false
            end
        end
    end

    return self
end

---Draws the physics editor interface
function PhysicsEditor:draw()
    -- Draw buttons
    self:_draw_button(self.ADD_BUTTON_RECT, "Add Category")
    self:_draw_button(self.REMOVE_BUTTON_RECT, "Remove Category")
    self:_draw_button(self.EXPORT_BUTTON_RECT, "Export to Lua")
    self:_draw_button(self.EXIT_BUTTON_RECT, "Exit")

    -- Calculate cell size based on fixed grid size
    local cell_size = self.GRID_SIZE / self.n

    -- Draw column headers (reverse order)
    for j = 1, self.n do
        local col_index = self.n - j + 1
        local x = self.MARGIN_LEFT + (j - 1) * cell_size
        local y = self.MARGIN_TOP - 40
        local is_first_category = col_index == 1
        local color = is_first_category and {0.5, 0.5, 0.5} or {1, 1, 1} -- Grey out if first category
        
        if self.editing and self.editing_index == col_index then
            -- Draw edit box instead of text
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", x + cell_size/2 - 40, y - 5, 80, 30)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", x + cell_size/2 - 40, y - 5, 80, 30)
            love.graphics.print(self.editing_text, x + cell_size/2 - 35, y)
        else
            love.graphics.setColor(color[1], color[2], color[3])
            love.graphics.print(self.categories[col_index], x + cell_size/2 - 20, y)
        end
    end

    -- Draw grid and row headers
    for i = 1, self.n do
        -- Row headers
        local x = self.MARGIN_LEFT - 140
        local y = self.MARGIN_TOP + (i - 1) * cell_size + cell_size/2 - 10
        local is_first_category = i == 1
        local color = is_first_category and {0.5, 0.5, 0.5} or {1, 1, 1} -- Grey out if first category
        
        if self.editing and self.editing_index == i then
            -- Draw edit box instead of text
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", x, y - 5, 130, 30)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", x, y - 5, 130, 30)
            love.graphics.print(self.editing_text, x + 5, y)
        else
            love.graphics.setColor(color[1], color[2], color[3])
            love.graphics.print(self.categories[i], x, y)
        end
        
        -- Grid cells
        for j = 1, self.n do
            local col_index = self.n - j + 1
            if i <= col_index then
                local cell_x = self.MARGIN_LEFT + (j - 1) * cell_size
                local cell_y = self.MARGIN_TOP + (i - 1) * cell_size
                
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.rectangle("fill", cell_x, cell_y, cell_size, cell_size)
                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("line", cell_x, cell_y, cell_size, cell_size)
                
                if self.collisions[i][col_index] then
                    love.graphics.line(cell_x, cell_y, cell_x + cell_size, cell_y + cell_size)
                    love.graphics.line(cell_x + cell_size, cell_y, cell_x, cell_y + cell_size)
                end
            end
        end
    end

    -- Draw filters in columns
    self:_draw_filters()

    -- Draw controls below the grid
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(CONTROLS_TEXT, self.MARGIN_LEFT, self.MARGIN_TOP + self.GRID_SIZE + 20)
end

---Draws a button
---@param rect {number, number, number, number} Button rectangle (x, y, width, height)
---@param text string Button text
function PhysicsEditor:_draw_button(rect, text)
    local is_hovered = self.hovered_button == text
    local fill_color = is_hovered and {0.2, 0.2, 0.2} or {0.4, 0.4, 0.4}
    local line_color = {1, 1, 1}
    local text_color = {1, 1, 1}
    local text_offset_x = 5
    local text_offset_y = 5
    
    -- Draw background
    love.graphics.setColor(fill_color[1], fill_color[2], fill_color[3])
    love.graphics.rectangle("fill", rect[1], rect[2], rect[3], rect[4])
    
    -- Draw border
    love.graphics.setColor(line_color[1], line_color[2], line_color[3])
    love.graphics.rectangle("line", rect[1], rect[2], rect[3], rect[4])
    
    -- Draw text
    love.graphics.setColor(text_color[1], text_color[2], text_color[3])
    love.graphics.print(text, rect[1] + text_offset_x, rect[2] + text_offset_y)
end

---Draws the filters panel
---@private
function PhysicsEditor:_draw_filters()
    local filters = self:compute_filters()
    local base_filter_x = self.MARGIN_LEFT + self.GRID_SIZE + 50
    
    -- Draw filters in columns of 8
    for col = 0, math.floor((#self.categories - 1) / self.CATEGORIES_PER_COLUMN) do
        local filter_x = base_filter_x + (col * 200)  -- 200 pixels between columns
        local filter_y = self.MARGIN_TOP
        
        -- Draw column header
        love.graphics.print("Column " .. (col + 1), filter_x, filter_y - 20)
        
        -- Draw filters for this column
        for i = 1, self.CATEGORIES_PER_COLUMN do
            local index = i + (col * self.CATEGORIES_PER_COLUMN)
            if index <= #self.categories then
                local cat = self.categories[index]
                local f = filters[cat]
                local text = string.format("%s:\n  category: %d\n  mask: %d", 
                    cat, f.category, f.mask)
                love.graphics.print(text, filter_x, filter_y + (i - 1) * 60)
            end
        end
    end
end

---Handles mouse click events
---@param x number Mouse X position
---@param y number Mouse Y position
---@param button number Mouse button pressed
function PhysicsEditor:mousepressed(x, y, button)
    if button == 1 then
        self.hovered_button = nil -- Reset hovered button

        -- Check if any button was clicked
        if self:_is_point_in_rect(x, y, self.ADD_BUTTON_RECT) then
            self:add_category()
        elseif self:_is_point_in_rect(x, y, self.REMOVE_BUTTON_RECT) then
            self:remove_category()
        elseif self:_is_point_in_rect(x, y, self.EXPORT_BUTTON_RECT) then
            self:export_to_lua()
        elseif self:_is_point_in_rect(x, y, self.EXIT_BUTTON_RECT) then
            if self.on_exit then
                self.on_exit()
            end
        else
            local cell_size = self.GRID_SIZE / self.n
            local current_time = love.timer.getTime()
            
            if self.editing then
                -- Check if click is outside the edit box
                local is_click_in_edit_box = false
                local edit_x, edit_y, edit_w, edit_h
                
                if self.editing_index then
                    -- Calculate edit box position based on whether it's a row or column
                    if y < self.MARGIN_TOP then
                        -- Column header
                        local col_x = self.MARGIN_LEFT + ((self.n - self.editing_index) - 1) * cell_size
                        edit_x = col_x + cell_size/2 - 40
                        edit_y = self.MARGIN_TOP - 45
                        edit_w = 80
                        edit_h = 30
                    else
                        -- Row header
                        edit_x = self.MARGIN_LEFT - 140
                        edit_y = self.MARGIN_TOP + (self.editing_index - 1) * cell_size + cell_size/2 - 15
                        edit_w = 130
                        edit_h = 30
                    end
                    
                    is_click_in_edit_box = x >= edit_x and x <= edit_x + edit_w and 
                                     y >= edit_y and y <= edit_y + edit_h
                end
                
                if not is_click_in_edit_box then
                    -- Cancel editing if clicked outside
                    self.editing = false
                    self.editing_index = nil
                    self.editing_text = ""
                    return
                end
            end

            -- Handle row/column label editing
            local is_column_header = y < self.MARGIN_TOP and y > self.MARGIN_TOP - 50
            if is_column_header and x >= self.MARGIN_LEFT and x <= self.MARGIN_LEFT + self.GRID_SIZE then
                local col_index = self.n - math.floor((x - self.MARGIN_LEFT) / cell_size)
                if col_index == 1 then return end -- Prevent editing first category
                if self.last_clicked_index == col_index and (current_time - self.last_click_time) < self.DOUBLE_CLICK_THRESHOLD then
                    self.editing = true
                    self.editing_index = col_index
                    self.editing_text = self.categories[col_index]
                end
                self.last_click_time = current_time
                self.last_clicked_index = col_index
                return
            end
            
            -- Handle row editing
            if x < self.MARGIN_LEFT then
                for i = 1, self.n do
                    local label_y = self.MARGIN_TOP + (i - 1) * cell_size
                    if y >= label_y and y <= label_y + cell_size then
                        if i == 1 then return end -- Prevent editing first category
                        if self.last_clicked_index == i and (current_time - self.last_click_time) < self.DOUBLE_CLICK_THRESHOLD then
                            self.editing = true
                            self.editing_index = i
                            self.editing_text = self.categories[i]
                        end
                        self.last_click_time = current_time
                        self.last_clicked_index = i
                        break
                    end
                end
                return
            end

            -- Handle grid clicks only if not editing
            if not self.editing and x >= self.MARGIN_LEFT and y >= self.MARGIN_TOP and 
               x <= self.MARGIN_LEFT + self.n * cell_size and y <= self.MARGIN_TOP + self.n * cell_size then
                self:_handle_grid_click(x, y, cell_size)
            end
        end
    end
end

---Handles mouse movement
---@param x number Mouse X position
---@param y number Mouse Y position
function PhysicsEditor:mousemoved(x, y)
    if self:_is_point_in_rect(x, y, self.ADD_BUTTON_RECT) then
        self.hovered_button = "Add Category"
    elseif self:_is_point_in_rect(x, y, self.REMOVE_BUTTON_RECT) then
        self.hovered_button = "Remove Category"
    elseif self:_is_point_in_rect(x, y, self.EXPORT_BUTTON_RECT) then
        self.hovered_button = "Export to Lua"
    elseif self:_is_point_in_rect(x, y, self.EXIT_BUTTON_RECT) then
        self.hovered_button = "Exit"
    else
        self.hovered_button = nil
    end
end

---Checks if a point is within a rectangle
---@param x number Point X position
---@param y number Point Y position
---@param rect {number, number, number, number} Rectangle (x, y, width, height)
---@return boolean
function PhysicsEditor:_is_point_in_rect(x, y, rect)
    return x >= rect[1] and x <= rect[1] + rect[3] and y >= rect[2] and y <= rect[2] + rect[4]
end

---Handles grid clicks
---@param x number Mouse X position
---@param y number Mouse Y position
---@param cell_size number Size of each grid cell
---@private
function PhysicsEditor:_handle_grid_click(x, y, cell_size)
    for i = 1, self.n do
        for j = 1, self.n do
            local col_index = self.n - j + 1
            if i <= col_index then
                local cell_x = self.MARGIN_LEFT + (j - 1) * cell_size
                local cell_y = self.MARGIN_TOP + (i - 1) * cell_size
                if x >= cell_x and x <= cell_x + cell_size and y >= cell_y and y <= cell_y + cell_size then
                    self.collisions[i][col_index] = not self.collisions[i][col_index]
                end
            end
        end
    end
end

---Handles text input events
---@param t string Text input
function PhysicsEditor:textinput(t)
    if self.editing then
        self.editing_text = self.editing_text .. t
    end
end

---Handles keyboard events
---@param key string Key pressed
---@param scancode string Scancode of the key
---@param isrepeat boolean Whether this is a key repeat event
function PhysicsEditor:keypressed(key, scancode, isrepeat)
    if self.editing then
        if key == "backspace" then
            if love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
                -- Clear entire textbox when Ctrl+Backspace is pressed
                self.editing_text = ""
            else
                -- Normal backspace behavior
                self.editing_text = self.editing_text:sub(1, #self.editing_text - 1)
            end
        elseif key == "return" then
            -- Only validate emptiness when trying to confirm
            if #self.editing_text > 0 then
                self.categories[self.editing_index] = self.editing_text
                self.editing = false
                self.editing_index = nil
                self.editing_text = ""
            end
        elseif key == "escape" then
            self.editing = false
            self.editing_index = nil
            self.editing_text = ""
        end
        return
    end

    if key == "a" and #self.categories < self.MAX_CATEGORIES then
        self:add_category()
    elseif key == "d" then
        self:remove_category()
    elseif key == "e" then
        self:export_to_lua()
    elseif key == "escape" then
        if self.on_exit then
            self.on_exit()
        end
    end
end

---Computes collision filters from the current state
---@return table<string, {category: number, mask: number}>
function PhysicsEditor:compute_filters()
    local filters = {}
    for i = 1, self.n do
        local cat_value = 2^(i - 1)
        local mask = 0
        for j = 1, self.n do
            if i == j then
                if self.collisions[i][i] then
                    mask = mask + 2^(i - 1)
                end
            elseif i < j then
                if self.collisions[i][j] then
                    mask = mask + 2^(j - 1)
                end
            else
                if self.collisions[j][i] then
                    mask = mask + 2^(j - 1)
                end
            end
        end
        filters[self.categories[i]] = { category = cat_value, mask = mask }
    end
    return filters
end

---Adds a new category
function PhysicsEditor:add_category()
    local name = "Category " .. (#self.categories + 1)
    local old_n = #self.categories
    table.insert(self.categories, name)
    self.n = #self.categories
    
    -- Update collision table
    for i = 1, old_n do
        for j = old_n + 1, self.n do
            if i <= j then
                self.collisions[i][j] = false
            end
        end
    end
    self.collisions[self.n] = {}
    self.collisions[self.n][self.n] = false
end

---Removes the last category
function PhysicsEditor:remove_category()
    if #self.categories <= 1 then return end
    
    local old_n = #self.categories
    table.remove(self.categories, old_n)
    self.collisions[old_n] = nil
    for i = 1, #self.categories do
        for j = #self.categories + 1, old_n do
            self.collisions[i][j] = nil
        end
    end
    self.n = #self.categories
end

---Exports the current filters to a Lua file
function PhysicsEditor:export_to_lua()
    local filters = self:compute_filters()
    local lines = {"local physics_filters = {"}
    
    for name, filter in pairs(filters) do
        table.insert(lines, string.format('    ["%s"] = { category = %d, mask = %d },', 
            name, filter.category, filter.mask))
    end
    
    table.insert(lines, "}")
    table.insert(lines, "\nreturn physics_filters")
    
    local content = table.concat(lines, "\n")
    
    -- Save to project root
    local filepath = "physics_filters.lua"
    local file, error = io.open(filepath, "w")
    if file then
        file:write(content)
        file:close()
        print("Exported physics filters to: " .. filepath)
    else
        print("Failed to save filters to: " .. filepath .. "\nError: " .. error)
    end
end

return PhysicsEditor
