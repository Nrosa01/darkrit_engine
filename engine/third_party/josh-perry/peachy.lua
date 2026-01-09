--- A parser/renderer for Aseprite animations in LÖVE.
-- @classmod peachy

---@class Darkrit.Graphics.AnimatedSprite
---@field _json_data table
---@field image love.Image
---@field frames table
---@field frame_tags table
---@field paused boolean
---@field tag table
---@field tag_name string
---@field direction string
---@field frame_index number?
---@field frame table
---@field pivot NVec
---@field pivot_offset NVec
---@field callback_on_loop function
---@field args_on_loop table
---@field json_path string | nil
---@field elapsed_time number
---@field flip Darkrit.Graphics.AnimatedSprite.Flip | ffi.cdata*
local peachy = {
  _VERSION = "1.0.0-alpha",
  _DESCRIPTION = "A parser/renderer for Aseprite animations in LÖVE.",
  _URL = "https://github.com/josh-perry/peachy",
  _LICENSE = [[
    MIT License

    Copyright (c) 2018 Josh Perry

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
  ]]
}

local PATH = (...):gsub("%.[^%.]+$", "")
local json = require(PATH .. ".lib.json")
local ffi = require("ffi")

---@class Darkrit.Graphics.AnimatedSprite.Flip
---@field public horizontal boolean
---@field public vertical boolean
ffi.cdef[[
typedef struct {
	bool horizontal;
	bool vertical;
} Flip;
]]

peachy.__index = peachy

--- Initialize events from the layers in the JSON metadata
function peachy:_initialize_events()
  -- Table to store events by tag and frame
  self.events = {}

  -- Process layers if they exist
  local layers = self._json_data.meta.layers
  if not layers then
    return
  end

  for _, layer in ipairs(layers) do
    if layer.cels then
      for _, cel in ipairs(layer.cels) do
        local frame = cel.frame + 1 -- Cels are 0-based, Lua uses 1-based indexing
        local event_data = cel.data

        -- Decode event data if it is in JSON format
        if type(event_data) == "string" then
          event_data = json.decode(event_data)
        end

        if event_data and event_data.event then
          local event_name = event_data.event.name
          local event_detail = event_data.event.data

          -- Find the tag that contains this frame
          for tag_name, tag_data in pairs(self.frame_tags) do
            for i, tag_frame in ipairs(tag_data.frames) do
              if tag_frame == self.frames[frame] then
                -- Store the event relative to the tag and frame index
                self.events[tag_name] = self.events[tag_name] or {}
                self.events[tag_name][i] = self.events[tag_name][i] or {}
                table.insert(self.events[tag_name][i], { name = event_name, data = event_detail })
                break
              end
            end
          end
        end
      end
    end
  end
end

function peachy:_initialize_pivot()
  self.pivot = Darkrit.graphics.PIVOT.CENTER

  -- override if there is a tag named "data" with a pivot field
  if self.frame_tags._meta then
    local json_data = self.frame_tags._meta.data
    local pivot = json_data.pivot:upper()
    self.pivot = Darkrit.graphics.PIVOT[pivot]

    if not self.pivot then
      self.pivot = Darkrit.graphics.PIVOT.CENTER
      print("Invalid pivot value: " .. pivot)
    end
  end

  self.pivot_offset = Darkrit.graphics.PIVOT.TOP_LEFT:clone()
  self:_recalculate_pivot_offset()
end

function peachy:_recalculate_pivot_offset()
  self.pivot_offset.x = self.pivot.x * self:get_width()
  self.pivot_offset.y = self.pivot.y * self:get_height()
end

--- Trigger events associated with the current frame
function peachy:_trigger_events()
  if not self.events[self.tag_name] or not self.events[self.tag_name][self.frame_index] or not self.event_callbacks then
    return
  end

  for _, event in ipairs(self.events[self.tag_name][self.frame_index]) do
    local callbacks = self.event_callbacks[event.name]
    if callbacks then
      for _, callback in ipairs(callbacks) do
        callback(event.data)
      end
    end
  end
end

--- Register a callback for a specific event
---@param event_name string Name of the event
---@param callback function Callback function to execute when the event is triggered
function peachy:on(event_name, callback)
  self.event_callbacks = self.event_callbacks or {}
  self.event_callbacks[event_name] = self.event_callbacks[event_name] or {}
  table.insert(self.event_callbacks[event_name], callback)
end

--- Creates a new Peachy animation object.
--
-- If imageData isn't specified then Peachy will attempt to load it using the
-- filename from the JSON data.
--
-- If no initial tag is set then the object will be paused (i.e. not displayed) with no tag.
-- The animation will start playing immediately once created.
--
-- @usage
-- -- Load the image ourselves and set animation tag to "Spin".
-- -- Will start playing immediately.
-- spinner = peachy.new("spinner.json", love.graphics.newImage("spinner.png"), "Spin")
--
---@param data_file string | table a path to an Aseprite JSON file. It is also possible to pass a predecoded table, which is useful for performance when creating large amounts of the same animation.
---@param image_data love.Image a LÖVE image to animate.
---@param initial_tag string? the name of the animation tag to use initially.
---@return Darkrit.Graphics.AnimatedSprite
function peachy.new(data_file, image_data, initial_tag)
  assert(data_file ~= nil, "No JSON data!")

  local self = setmetatable({}, peachy)

  -- check if datafile is a lua table (i.e. pre decoded)
  if type(data_file) == 'table' then
    self._json_data = data_file
  else
    --store the path to the passed json file
    self.json_path = data_file
    -- Read the data
    self._json_data = json.decode(love.filesystem.read(data_file))
  end

  -- Load the image
  self.image = image_data or love.graphics.newImage(self._json_data.meta.image)

  self:_check_image_size()
  self.frame_index = 1
  self:_initialize_frames()
  self:_initialize_tags()
  self:_initialize_events()
  self:_initialize_pivot()

  self.paused = true
  self.elapsed_time = 0

  self.flip = ffi.new("Flip")
  self.flip.horizontal = false
  self.flip.vertical = false

  self.tag = nil
  self.tag_name = nil
  self.direction = nil

  if not initial_tag or initial_tag == '_meta' then
    for k, _ in pairs(self.frame_tags) do
      if k ~= '_meta' then
        initial_tag = k
        break
      end
    end
  end

  self:set_tag(initial_tag)
  self.paused = false

  return self
end

--- Clone the current instance of peachy.
-- Shares table references but resets the timer and other elements that should not be shared.
-- @return josh-perry.peachy
function peachy:clone()
  local clone = setmetatable({}, peachy)

  -- Share constant references
  clone._json_data = self._json_data
  clone.image = self.image
  clone.frames = self.frames
  clone.frame_tags = self.frame_tags
  clone.events = self.events
  clone.event_callbacks = self.event_callbacks

  -- Deep copy of mutable values
  clone.paused = self.paused
  clone.tag = self.tag
  clone.tag_name = self.tag_name
  clone.direction = self.direction
  clone.frame_index = self.frame_index
  clone.pivot = self.pivot
  clone.pivot_offset = self.pivot_offset:clone()
  clone.frame = self.frame
  clone.callback_on_loop = self.callback_on_loop
  clone.args_on_loop = self.args_on_loop
  clone.json_path = self.json_path
  clone.elapsed_time = 0
  clone.flip = ffi.new("Flip")
  clone.flip.horizontal = self.flip.horizontal
  clone.flip.vertical = self.flip.vertical

  return clone
end

--- Switch to a different animation tag.
-- In the case that we're attempting to switch to the animation currently playing,
-- nothing will happen.
--
---@param tag string
---@param keep_frame boolean?
function peachy:set_tag(tag, keep_frame)
  assert(tag, "No animation tag specified!")
  assert(self.frame_tags[tag], "Tag " .. tag .. " not found in frametags!")

  if self.tag == self.frame_tags[tag] then
    return
  end

  keep_frame = keep_frame or false

  self.tag_name = tag
  self.tag = self.frame_tags[self.tag_name]
  self.frame_index = keep_frame and (self.frame_index % #self.tag.frames) or nil
  self.direction = self.tag.direction

  if self.direction == "pingpong" then
    self.direction = "forward"
  end

  self:next_frame()
end

--- Jump to a particular frame index (1-based indexes) in the current animation.
--
-- Errors if the frame is outside the tag's frame range.
--
-- @usage
-- -- Go to the 4th frame
-- sound:setFrame(4)
--
---@param frame number
function peachy:set_frame(frame)
  if frame < 1 or frame > #self.tag.frames then
    error("Frame " .. frame .. " is out of range of tag '" .. self.tag_name .. "' (1.." .. #self.tag.frames .. ")")
  end

  self.frame_index = frame
  self.frame = self.tag.frames[self.frame_index]
  self.elapsed_time = 0
end

--- Get the current frame of the current animation
-- @usage
-- Get the 2nd frame
-- local f = sound:getFrame()
--
---@return number
function peachy:get_frame()
  return self.frame_index
end

--- Get the json path passed in the object
-- @usage
-- Get the (string) JSON path
-- local str_json = obj:getJSON()
---
---@return string | nil
function peachy:get_json()
  return self.json_path
end

--- Draw the animation's current frame in a specified location.
---@param  x number? the x position.
---@param  y number? the y position.
---@param  rot number? the rotation to draw at.
---@param  sx number?  the x scaling.
---@param  sy number?  the y scaling.
---@param  ox number?  the origin offset x.
---@param  oy number?  the origin offset y.
function peachy:draw(x, y, rot, sx, sy, ox, oy)
  assert(self.frame, "No frame to draw!")

  local frame = self.frame
  local w, h = frame.w, frame.h
  ox = (ox or 0) + self.pivot_offset.x
  oy = (oy or 0) + self.pivot_offset.y
  sx = sx or 1
  sy = sy or 1

  if self.flip.horizontal then
    sx = sx * -1
    ox = w - ox
  end

  if self.flip.vertical then
    sy = sy * -1
    oy = h - oy
  end

  love.graphics.draw(
    self.image,
    frame.quad,
    x, y,
    rot,
    sx, sy,
    ox, oy
  )
end

--- Update the animation.
---@param dt number frame delta. Should be called from love.update and given the dt.
function peachy:update(dt)
  assert(dt, "No dt passed into update!")

  if self.paused then
    return
  end

  -- If we're trying to play an animation and it's nil or hasn't been set up
  -- properly then error
  assert(self.tag, "No animation tag has been set!")
  assert(self.frame, "Frame hasn't been initialized!")

  self.elapsed_time = self.elapsed_time + dt

  local original_frame_duration = self.frame.duration / 1000
  while self.elapsed_time >= original_frame_duration do
    self.elapsed_time = self.elapsed_time - self.frame.duration / 1000
    self:next_frame()
  end
end

--- Move to the next frame.
-- Internal: unless you want to skip frames, this generally will not ever
-- need to be called manually.
function peachy:next_frame()
  local forward = self.direction == "forward"

  if forward then
    self.frame_index = (self.frame_index or 0) + 1
  else
    self.frame_index = (self.frame_index or #self.tag.frames + 1) - 1
  end

  -- Looping
  if forward and self.frame_index > #self.tag.frames then
    if self.tag.direction == "pingpong" then
      self:_pingpong_bounce()
    else
      self.frame_index = 1
    end
    self:call_on_loop()
  elseif not forward and self.frame_index < 1 then
    if self.tag.direction == "pingpong" then
      self:_pingpong_bounce()
    else
      self.frame_index = #self.tag.frames
      self:call_on_loop()
    end
  end

  -- Get next frame
  self.frame = self.tag.frames[self.frame_index]
  self:_recalculate_pivot_offset()

  -- Trigger events associated with the current frame
  self:_trigger_events()
end

--- Check for callbacks
function peachy:call_on_loop()
  if self.callback_on_loop then self.callback_on_loop(unpack(self.args_on_loop)) end
end

--- Pauses the animation.
function peachy:pause()
  self.paused = true
end

--- Unpauses the animation.
function peachy:play()
  self.paused = false
end

--- Stops the animation (pause it then return to first frame or last if specified)
function peachy:stop(on_last)
  local index = 1
  self.paused = true
  if on_last then index = #self.tag.frames end
  self:set_frame(index)
end

--- Adds a callback function that will be called when the animation loops
function peachy:on_loop(fn, ...)
  self.callback_on_loop = fn
  self.args_on_loop = { ... }
end

function peachy:is_paused()
  return self.paused
end

--- Toggle between playing/paused.
function peachy:toggle_play()
  if self.paused then
    self:play()
  else
    self:pause()
  end
end

--- Provides width stored in the metadata of a current frame
function peachy:get_width()
  return self.frames[self.frame_index].w
end

--- Provides height stored in the metadata of a current frame
function peachy:get_height()
  return self.frames[self.frame_index].h
end

--- Provides dimensions stored in the metadata of a current frame
function peachy:get_dimensions()
  return self:get_width(), self:get_height()
end

--- Internal: handles the ping-pong animation type.
--
-- Should only be called when we actually want to bounce.
-- Swaps the direction.
function peachy:_pingpong_bounce()
  -- We need to increment/decrement frame index by 2 because
  -- at this point we've already gone to the next frame
  if self.direction == "forward" then
    self.direction = "reverse"
    self.frame_index = self.frame_index - 2
  else
    self.direction = "forward"
    self.frame_index = self.frame_index + 2
  end
end

local QUAD_CACHE = {}

--- Internal: loads all of the frames
--
-- Loads quads and frame duration data from the JSON.
--
-- Called from peachy.new
function peachy:_initialize_frames()
  assert(self._json_data ~= nil, "No JSON data!")
  assert(self._json_data.meta ~= nil, "No metadata in JSON!")
  assert(self._json_data.frames ~= nil, "No frame data in JSON!")

  -- Initialize all the quads
  self.frames = {}
  for _, frame_data in ipairs(self._json_data.frames) do
    local frame = {}

    local fd = frame_data.frame
    local key = string.format("%d_%d_%d_%d_%d_%d", fd.x, fd.y, fd.w, fd.h, self._json_data.meta.size.w,
      self._json_data.meta.size.h)
    if not QUAD_CACHE[key] then
      QUAD_CACHE[key] = love.graphics.newQuad(fd.x, fd.y, fd.w, fd.h, self._json_data.meta.size.w,
        self._json_data.meta.size.h)
    end
    frame.quad = QUAD_CACHE[key]
    frame.duration = frame_data.duration
    frame.w = fd.w
    frame.h = fd.h

    table.insert(self.frames, frame)
  end
end

--- Internal: loads all of the animation tags
--
-- Called from peachy.new
function peachy:_initialize_tags()
  assert(self._json_data ~= nil, "No JSON data!")
  assert(self._json_data.meta ~= nil, "No metadata in JSON!")
  assert(self._json_data.meta.frameTags ~= nil, "No frame tags in JSON! Make sure you exported them in Aseprite!")

  self.frame_tags = {}

  for _, frame_tag in ipairs(self._json_data.meta.frameTags) do
    local ft = {}
    ft.direction = frame_tag.direction
    ft.data = frame_tag.data and self.decode(frame_tag.data) or nil
    ft.frames = {}

    for frame = frame_tag.from + 1, frame_tag.to + 1 do
      table.insert(ft.frames, self.frames[frame])
    end

    self.frame_tags[frame_tag.name] = ft
  end
end

---Set the pivot point for the sprite.
---You can pass either a NVec or a Darkrit.Graphics.Pivot enum value
---@param pivot Darkrit.Graphics.Pivot | NVec
function peachy:set_pivot(pivot)
  self.pivot = pivot
  self:_recalculate_pivot_offset()
end

--- Internal: checks that the loaded image size matches the metadata
--
-- Called from peachy.new
function peachy:_check_image_size()
  local image_width, image_height = self._json_data.meta.size.w, self._json_data.meta.size.h
  assert(image_width == self.image:getWidth(), "Image width metadata doesn't match actual width of file")
  assert(image_height == self.image:getHeight(), "Image height metadata doesn't match actual height of file")
end

--- Decode a JSON string into a Lua table.
---@param data string
---@return table
function peachy.decode(data)
  return json.decode(data)
end

--- Set horizontal flip.
---@param horizontal boolean
function peachy:set_horizontal_flip(horizontal)
  self.flip.horizontal = horizontal
end

--- Set vertical flip.
---@param vertical boolean
function peachy:set_vertical_flip(vertical)
  self.flip.vertical = vertical
end

--- Set both horizontal and vertical flip.
---@param horizontal boolean
---@param vertical boolean
function peachy:set_flip(horizontal, vertical)
  self.flip.horizontal = horizontal
  self.flip.vertical = vertical
end

--- Flip the sprite horizontally.
function peachy:flip_horizontal()
  self.flip.horizontal = not self.flip.horizontal
end

--- Flip the sprite vertically.
function peachy:flip_vertical()
  self.flip.vertical = not self.flip.vertical
end

--- Get horizontal flip.
---@return boolean horizontal flip
function peachy:get_horizontal_flip()
  return self.flip.horizontal
end

--- Get vertical flip.
---@return boolean vertical flip
function peachy:get_vertical_flip()
  return self.flip.vertical
end

--- Returns the center position of the sprite relative to the pivot point
---@return number x, number y
function peachy:get_center_position()
    local w = self:get_width()
    local h = self:get_height()
    
    -- Calculate center based on sprite dimensions
    local center_x = w/2
    local center_y = h/2
    
    -- Adjust for pivot offset
    -- pivot_offset is from top-left, so we need to subtract it to get the actual center
    return center_x - self.pivot_offset.x, center_y - self.pivot_offset.y
end

return peachy
