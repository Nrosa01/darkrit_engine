------------- Pollygon collision detection functions -------------

-- Helper: Check if point is inside a convex polygon (ray-casting)
local function point_in_polygon(pt, polygon)
    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        if ((yi > pt.y) ~= (yj > pt.y)) and
            (pt.x < (xj - xi) * (pt.y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

-- Helper: Compute intersection of two lines given in normal form: dot(P, n)= c
local function line_intersection(n1, c1, n2, c2)
    local det = n1.x * n2.y - n2.x * n1.y
    if math.abs(det) < 1e-6 then return nil end -- parallel
    return {
        x = (c1 * n2.y - c2 * n1.y) / det,
        y = (n1.x * c2 - n2.x * c1) / det
    }
end

-- Computes the inset polygon from a convex polygon given the camera view half extents.
-- For each edge, the offset distance is:
--   d = |n.x| * half_width + |n.y| * half_height
local function compute_inset_polygon(polygon, half_width, half_height)
    local inset = {}
    local count = #polygon
    local lines = {}
    -- Assume polygon is defined in CCW order.
    for i = 1, count do
        local curr = polygon[i]
        local nxt = polygon[i % count + 1]
        local dx = nxt.x - curr.x
        local dy = nxt.y - curr.y
        -- Inward normal for CCW polygon is (-dy, dx) normalized.
        local len = math.sqrt(dx * dx + dy * dy)
        local n = { x = -dy / len, y = dx / len }
        local d = math.abs(n.x) * half_width + math.abs(n.y) * half_height
        local c = curr.x * n.x + curr.y * n.y + d
        lines[i] = { n = n, c = c }
    end
    -- Compute intersections of consecutive offset lines.
    for i = 1, count do
        local line1 = lines[i]
        local line2 = lines[i % count + 1]
        local pt = line_intersection(line1.n, line1.c, line2.n, line2.c)
        if pt then
            inset[#inset + 1] = pt
        end
    end
    return inset
end

-- Helper: Returns the closest point on segment AB to point P.
local function closest_point_on_segment(A, B, P)
    local ABx = B.x - A.x
    local ABy = B.y - A.y
    local t = ((P.x - A.x) * ABx + (P.y - A.y) * ABy) / (ABx * ABx + ABy * ABy)
    t = math.max(0, math.min(1, t))
    return { x = A.x + t * ABx, y = A.y + t * ABy }
end

-- Helper: Returns the distance between two points.
local function distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

------------- Camera class -------------

---@class Darkrit.Graphics.Point
---@field x number
---@field y number

---@class Darkrit.Graphics.Camera
---@field private _canvas_width number Internal canvas width
---@field private _canvas_height number Internal canvas height
---@field private _user_canvas_w number User-defined canvas width
---@field private _user_canvas_h number User-defined canvas height
---@field scale_mode Darkrit.Graphics.Camera.SCALE_MODES One of Camera.SCALE_MODES
---@field private _internal_canvas love.Canvas Internal canvas
---@field private _screen_scale number Physical screen scale
---@field private _screen_scale_x number Physical screen scale X
---@field private _screen_scale_y number Physical screen scale Y
---@field private _offset_x number Physical screen offset X
---@field private _offset_y number Physical screen offset Y
---@field x number Camera center X (world units)
---@field y number Camera center Y (world units)
---@field ortho_size number Half the visible height in world units
---@field rotation number Initial rotation in radians
---@field zoom number Initial zoom factor
---@field private _limits_polygon Darkrit.Graphics.Point[] Camera limits polygon
---@field private _transform love.Transform Camera transform
---@field debug boolean Debug flag
local Camera = {}
Camera.__index = Camera

--- Scaling modes enum.
---@enum Darkrit.Graphics.Camera.SCALE_MODES
Camera.SCALE_MODES = {
    NONE = 1,
    LETTERBOX = 2,
    PIXEL_PERFECT = 3,
    STRETCH = 4,
    BOUNDLESS_ASPECT = 5,
}

local modifier_properties = {
    x = true,
    y = true,
    ortho_size = true,
    rotation = true,
    zoom = true,
}

--- Creates a new Camera instance.
---@param canvas_w number? Internal canvas width
---@param canvas_h number? Internal canvas height
---@param scale_mode Darkrit.Graphics.Camera.SCALE_MODES? One of Camera.SCALE_MODES
---@param x number? Camera center X (world units)
---@param y number? Camera center Y (world units)
---@param ortho_size number? Half the visible height in world units
---@param rotation number? Initial rotation in radians
---@param zoom number? Initial zoom factor
---@param auto_adjust boolean? If true, adjust ortho_size to match the canvas resolution (1:1 mapping)
---@return Darkrit.Graphics.Camera
function Camera.new(canvas_w, canvas_h, scale_mode, x, y, ortho_size, rotation, zoom, auto_adjust)
    local rawCamera = {}

    -- I save this because boundless scale mode modifies the canvas size so I need to "remember" the original one
    -- Just in case the user request to return to another mode like letterbox
    rawCamera._user_canvas_w = canvas_w or love.graphics.getWidth()
    rawCamera._user_canvas_h = canvas_h or love.graphics.getHeight()

    rawCamera._canvas_width = canvas_w
    rawCamera._canvas_height = canvas_h
    rawCamera.scale_mode = scale_mode or Camera.SCALE_MODES.LETTERBOX
    rawCamera._internal_canvas = love.graphics.newCanvas(rawCamera._canvas_width, rawCamera._canvas_height)
    rawCamera._screen_scale = 1
    rawCamera._offset_x = 0
    rawCamera._offset_y = 0

    -- Camera transform parameters.
    rawCamera.x = x or 0
    rawCamera.y = y or 0
    rawCamera.ortho_size = ortho_size or (canvas_h / 2)
    rawCamera.rotation = rotation or 0
    rawCamera.zoom = zoom or 1
   
    -- Limits.
    rawCamera._limits_polygon = nil
    rawCamera._limits_box = nil
   
    -- Debug flag.
    rawCamera.debug = false
   
    rawCamera._transform = love.math.newTransform()

    -- I know proxies are "slow" but it's not like the user will be modifyined
    -- camera properties thousands of times per frame. I prefer this as it makes it
    -- Pretty comfortable to use
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t, key)
            return rawCamera[key] or Camera[key]
        end,
        __newindex = function(t, key, value)
            rawCamera[key] = value
            if modifier_properties[key] then
                t:_update_transform()
            end
        end,
    })

    -- Inicializamos la escala de pantalla usando el proxy (para acceder a los métodos de la clase)
    proxy:update_screen_scale(love.graphics.getWidth(), love.graphics.getHeight())

    if auto_adjust then
        proxy:adjust_to_resolution(love.graphics.getWidth(), love.graphics.getHeight())
    end

    proxy:_update_transform()

    return proxy
end

--- Adjusts the ortho_size so that the view shows exactly the canvas resolution in world units.
--- In our case, for a canvas of 320×320 and zoom = 1, the camera should display 320 pixels (i.e. 320 world units) horizontally.
--- Since ortho_size represents half the visible height, we set it to (min(canvas_w, canvas_h) / (2 * zoom)).
---@param phys_w number Physical screen width (not used in this calculation but kept for consistency)
---@param phys_h number Physical screen height
function Camera:adjust_to_resolution(phys_w, phys_h)
    -- We want a 1:1 mapping between canvas pixels and world units.
    local small_size = math.min(self._user_canvas_w, self._user_canvas_h)
    self.ortho_size = small_size / (2 * self.zoom)
end

function Camera:get_raw_resolution()
    return self._canvas_width, self._canvas_height
end

function Camera:get_resolution()
    return self._user_canvas_w, self._user_canvas_h
end

function Camera:set_resolution(w, h)
    self._user_canvas_w = w
    self._user_canvas_h = h
    self._canvas_width = self._user_canvas_w
    self._canvas_height = self._user_canvas_h
    self:update_screen_scale(love.graphics.getWidth(), love.graphics.getHeight())
end

function Camera:update_screen_scale(win_w, win_h)
    if self.scale_mode ~= Camera.SCALE_MODES.BOUNDLESS_ASPECT then
        -- There is the chance that the canvas didn't change, I could check the  sizes but it's not even worthy
        self._canvas_width = self._user_canvas_w
        self._canvas_height = self._user_canvas_h
        self._internal_canvas = love.graphics.newCanvas(self._canvas_width, self._canvas_height)
    else
        -- Boundless: adapt canvas to window aspect ratio while maintaining the smallest dimension
        local aspect_window = win_w / win_h
        if aspect_window >= 1 then
            -- Landscape or square: keep height, adjust width
            self._canvas_height = self._user_canvas_h
            self._canvas_width = math.floor(self._user_canvas_h * aspect_window)
        else
            -- Portrait: keep width, adjust height
            self._canvas_width = self._user_canvas_w
            self._canvas_height = math.floor(self._user_canvas_w / aspect_window)
        end
        self._internal_canvas = love.graphics.newCanvas(self._canvas_width, self._canvas_height)
    end

    if self.scale_mode == Camera.SCALE_MODES.NONE then
        self._screen_scale = win_w / self._canvas_width
        self._offset_x = 0
        self._offset_y = 0
    elseif self.scale_mode == Camera.SCALE_MODES.LETTERBOX then
        local scale_x = win_w / self._canvas_width
        local scale_y = win_h / self._canvas_height
        self._screen_scale = math.min(scale_x, scale_y)
        self._offset_x = (win_w - self._canvas_width * self._screen_scale) / 2
        self._offset_y = (win_h - self._canvas_height * self._screen_scale) / 2
    elseif self.scale_mode == Camera.SCALE_MODES.PIXEL_PERFECT then
        local scale_x = win_w / self._canvas_width
        local scale_y = win_h / self._canvas_height
        self._screen_scale = math.floor(math.min(scale_x, scale_y))
        if self._screen_scale < 1 then self._screen_scale = 1 end
        self._offset_x = math.floor((win_w - self._canvas_width * self._screen_scale) / 2)
        self._offset_y = math.floor((win_h - self._canvas_height * self._screen_scale) / 2)
    elseif self.scale_mode == Camera.SCALE_MODES.STRETCH or self.scale_mode == Camera.SCALE_MODES.BOUNDLESS_ASPECT then
        self._screen_scale_x = win_w / self._canvas_width
        self._screen_scale_y = win_h / self._canvas_height
        self._screen_scale = math.min(self._screen_scale_x, self._screen_scale_y)
        self._offset_x = 0
        self._offset_y = 0
    end
end

--- Sets the camera scale mode and updates the screen scale.
---@param scale_mode Darkrit.Graphics.Camera.SCALE_MODES  One of Camera.SCALE_MODES
function Camera:set_scale_mode(scale_mode)
    self.scale_mode = scale_mode or self.scale_mode
    self:update_screen_scale(love.graphics.getWidth(), love.graphics.getHeight())
end

--- Should be called from love.resize.
---@param win_w number Window width
---@param win_h number Window height
function Camera:resize(win_w, win_h)
    self:update_screen_scale(win_w, win_h)
end

--- Sets the camera transform parameters.
---@param x number Camera center X (world units)
---@param y number Camera center Y (world units)
---@param ortho_size number Half visible height (world units)
---@param rotation number Rotation in radians
---@param zoom number Zoom factor
function Camera:set_camera(x, y, ortho_size, rotation, zoom)
    self.x = x or self.x
    self.y = y or self.y
    self.ortho_size = ortho_size or self.ortho_size
    self.rotation = rotation or self.rotation
    self.zoom = zoom or self.zoom
    self:apply_limits()
end

--- Sets camera limits using a polygon (an array of points {x, y}).
-- Note: Polygon must be convex and defined in counter-clockwise order.
---@param polygon table
function Camera:set_limits(polygon)
    self._limits_polygon = polygon
end

--- Clamps the camera position within the limits, if any.
-- When a polygon is set as limits, the camera view is clamped so that
-- its view rectangle stays within the polygon.
function Camera:apply_limits()
    if self._limits_polygon then
        local aspect = self._canvas_width / self._canvas_height
        local half_width = (self.ortho_size * aspect) / self.zoom
        local half_height = self.ortho_size / self.zoom

        -- Compute inset polygon from limits polygon.
        local inset = compute_inset_polygon(self._limits_polygon, half_width, half_height)
        local center = { x = self.x, y = self.y }
        if point_in_polygon(center, inset) then
            return
        end

        -- If outside, find the closest point on the inset polygon.
        local closest = nil
        local min_dist = math.huge
        local count = #inset
        for i = 1, count do
            local A = inset[i]
            local B = inset[i % count + 1]
            local pt = closest_point_on_segment(A, B, center)
            local d = distance(center, pt)
            if d < min_dist then
                min_dist = d
                closest = pt
            end
        end
        if closest then
            self.x = closest.x
            self.y = closest.y
        end
    end
end

---@private
function Camera:_get_scale()
    local small_size = self._canvas_width < self._canvas_height and self._canvas_width or self._canvas_height
    local scale = small_size / (2 * self.ortho_size) * self.zoom
    return scale
end

--- Begins rendering to the internal canvas and applies the camera transformation.
--- Call this instead of love.graphics.push().
function Camera:push()
    -- I don't trust the user is calling love.resize, so I check the window size here xD
    local win_w, win_h = love.graphics.getWidth(), love.graphics.getHeight()
    if win_w ~= self._canvas_width or win_h ~= self._canvas_height then
        self:update_screen_scale(win_w, win_h)
    end

    love.graphics.setCanvas(self._internal_canvas)
    love.graphics.clear()
    love.graphics.push("all")
    -- Reset and reuse the existing transform instead of creating a new one:
    self:_update_transform()
    love.graphics.applyTransform(self._transform)
end

---@private
function Camera:_update_transform()
    local scale = self:_get_scale()
    self._transform:reset()
    self._transform:translate(self._canvas_width / 2, self._canvas_height / 2)
    self._transform:rotate(-self.rotation)
    self._transform:scale(scale, scale)
    self._transform:translate(-self.x, -self.y)
end

--- Ends rendering to the internal canvas and draws it to the physical screen.
--- Call this instead of love.graphics.pop().
function Camera:pop()
    love.graphics.pop()       -- revert camera transform
    love.graphics.setCanvas() -- back to physical screen
    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)
    if self.scale_mode == Camera.SCALE_MODES.STRETCH or self.scale_mode == Camera.SCALE_MODES.BOUNDLESS_ASPECT then
        love.graphics.scale(self._screen_scale_x, self._screen_scale_y)
    else
        love.graphics.scale(self._screen_scale, self._screen_scale)
    end
    love.graphics.draw(self._internal_canvas, 0, 0)
    love.graphics.pop()

    if self.debug then
        love.graphics.setColor(1, 0, 0)
        -- Draw camera center
        local center_x, center_y
        if self.scale_mode == Camera.SCALE_MODES.STRETCH or self.scale_mode == Camera.SCALE_MODES.BOUNDLESS_ASPECT then
            center_x = self._canvas_width / 2 * self._screen_scale_x + self._offset_x
            center_y = self._canvas_height / 2 * self._screen_scale_y + self._offset_y
        else
            center_x = self._canvas_width / 2 * self._screen_scale + self._offset_x
            center_y = self._canvas_height / 2 * self._screen_scale + self._offset_y
        end
        love.graphics.circle("line", center_x, center_y, 5)

        if self._limits_polygon then
            local pts = {}
            for i, pt in ipairs(self._limits_polygon) do
                local sx, sy = self:to_screen(pt.x, pt.y)
                pts[#pts + 1] = sx
                pts[#pts + 1] = sy
            end
            love.graphics.polygon("line", pts)
        end

        love.graphics.setColor(1, 1, 1)
    end
end

--- Converts internal screen (physical) coordinates to world coordinates.
---@param screen_x number
---@param screen_y number
---@return number world_x, number world_y
function Camera:to_world(screen_x, screen_y)
    local ix, iy
    if self.scale_mode == Camera.SCALE_MODES.STRETCH or self.scale_mode == Camera.SCALE_MODES.BOUNDLESS_ASPECT then
        ix = (screen_x - self._offset_x) / self._screen_scale_x
        iy = (screen_y - self._offset_y) / self._screen_scale_y
    else
        ix = (screen_x - self._offset_x) / self._screen_scale
        iy = (screen_y - self._offset_y) / self._screen_scale
    end
    local invT = self._transform:clone():inverse()
    return invT:transformPoint(ix, iy)
end

--- Converts world coordinates to physical screen coordinates.
---@param world_x number
---@param world_y number
---@return number screen_x, number screen_y
function Camera:to_screen(world_x, world_y)
    -- Use the transform to convert world coordinates to internal canvas coordinates.
    local ix, iy = self._transform:transformPoint(world_x, world_y)
    local sx, sy
    if self.scale_mode == Camera.SCALE_MODES.STRETCH or self.scale_mode == Camera.SCALE_MODES.BOUNDLESS_ASPECT then
        sx = ix * self._screen_scale_x + self._offset_x
        sy = iy * self._screen_scale_y + self._offset_y
    else
        sx = ix * self._screen_scale + self._offset_x
        sy = iy * self._screen_scale + self._offset_y
    end
    return sx, sy
end

return Camera
