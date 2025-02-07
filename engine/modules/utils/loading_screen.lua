---@class Darkrit.Utils.LoadingSystem.Config
---@field start_transition_duration? number
---@field end_transition_duration? number
---@field allow_loading_during_start? boolean
---@field max_frame_time? number
---@field start_transition_draw? fun(t_normalized: number, load_progress: number)
---@field end_transition_draw? fun(t_inverted: number)
---@field progress_draw fun(currently: number, total: number, data: table)
---@field on_load_complete? fun(data: table)
---@field on_start_transition_complete? fun()
---@field on_end_transition_complete? fun(data: table)

---@enum Darkrit.Utils.LoadingPhase
local LoadingPhase = {
    START_TRANSITION = "start_transition",
    LOADING = "loading",
    END_TRANSITION = "end_transition",
    COMPLETED = "completed"
}

---@class Darkrit.Utils.LoadingSystem.ProgressData
---@field current number
---@field total number

---@class Darkrit.Utils.LoadingSystem.TransitionParams
---@field end_duration number

---@class Darkrit.Utils.LoadingSystem.State
---@field phase Darkrit.Utils.LoadingPhase
---@field start_transition_time number
---@field end_transition_time number
---@field load_completed boolean

---@class Darkrit.Utils.LoadingSystem
---@field config Darkrit.Utils.LoadingSystem.Config
---@field state Darkrit.Utils.LoadingSystem.State
---@field loader thread
---@field progress_data Darkrit.Utils.LoadingSystem.ProgressData
---@field loaded_data table
local LoadingSystem = {}
LoadingSystem.__index = LoadingSystem

---Create a new LoadingSystem instance
---@param loader_iterator fun():any
---@param config Darkrit.Utils.LoadingSystem.Config
---@return Darkrit.Utils.LoadingSystem
function LoadingSystem.new(loader_iterator, config)
    local self = setmetatable({}, LoadingSystem)

    -- Calculate default durations based on transition presence
    local has_start_transition = config and config.start_transition_draw ~= nil
    local has_end_transition = config and config.end_transition_draw ~= nil

    -- Default configuration
    self.config = {
        start_transition_duration = has_start_transition and (config and config.start_transition_duration or 0) or 0,
        end_transition_duration = has_end_transition and (config and config.end_transition_duration or 0) or 0,
        allow_loading_during_start = config and config.allow_loading_during_start or false,
        max_frame_time = config and config.max_frame_time or 0.016,

        -- Transition draws default to empty functions if not provided
        start_transition_draw = config and config.start_transition_draw or function() end,
        end_transition_draw = config and config.end_transition_draw or function() end,
        progress_draw = assert(config and config.progress_draw, "progress_draw callback is required"),

        -- Completion callbacks
        on_load_complete = config and config.on_load_complete,
        on_start_transition_complete = config and config.on_start_transition_complete,
        on_end_transition_complete = config and config.on_end_transition_complete
    }

    -- State management
    self.state = {
        phase = LoadingPhase.START_TRANSITION,
        start_transition_time = 0,
        end_transition_time = 0,
        load_completed = false
    }

    -- Loader system
    self.loader = coroutine.create(loader_iterator)
    self.progress_data = { current = 0, total = 1 }
    self.loaded_data = {}

    self:update(0)

    return self
end

---Update the loading system state
---@param dt number Delta time in seconds
function LoadingSystem:update(dt)
    if self.state.phase == LoadingPhase.COMPLETED then return end

    -- Update transition timers
    if self.state.phase == LoadingPhase.START_TRANSITION then
        self.state.start_transition_time = math.min(
            self.state.start_transition_time + dt,
            self.config.start_transition_duration
        )
    elseif self.state.phase == LoadingPhase.END_TRANSITION then
        self.state.end_transition_time = math.min(
            self.state.end_transition_time + dt,
            self.config.end_transition_duration
        )
    end

    -- Handle loading process
    local should_load = self.config.allow_loading_during_start or self.state.phase == LoadingPhase.LOADING
    if should_load and not self.state.load_completed then
        local start_time = love.timer.getTime()

        repeat
            local success, current, total = coroutine.resume(self.loader, self.loaded_data)

            if not success then
                error(current)
            end

            if coroutine.status(self.loader) == "dead" then
                self:_handle_load_completion()
                break
            end

            if current and total then
                self.progress_data.current = current
                self.progress_data.total = total
            else
                error("Loader must yield current and total values (and not be nil)")
            end
        until love.timer.getTime() - start_time >= self.config.max_frame_time
    end

    -- Check phase transitions
    self:_check_start_transition_completion()
    self:_check_end_transition_completion()
end

---Draw the current loading state
function LoadingSystem:draw()
    if self.state.phase == LoadingPhase.COMPLETED then return end

    local phase = self.state.phase
    local load_progress = self.progress_data.current / math.max(self.progress_data.total, 1)

    if phase == LoadingPhase.START_TRANSITION then
        local t = self.state.start_transition_time / self.config.start_transition_duration
        self.config.start_transition_draw(t, load_progress)
    elseif phase == LoadingPhase.LOADING then
        self.config.progress_draw(self.progress_data.current, self.progress_data.total, self.loaded_data)
    elseif phase == LoadingPhase.END_TRANSITION then
        local t = 1 - (self.state.end_transition_time /  self.config.end_transition_duration)
        self.config.end_transition_draw(t)
    end
end

---Check if loading has completed (including transitions)
---@return boolean
function LoadingSystem:is_fully_completed()
    return self.state.phase == LoadingPhase.COMPLETED
end

---Internal: Handle load completion
---@private
function LoadingSystem:_handle_load_completion()
    -- Calculate adjusted end duration if completing during start transition
    if self.state.phase == LoadingPhase.START_TRANSITION then
        if self.config.on_start_transition_complete then
            self.config.on_start_transition_complete()
        end

        local t_normalized = self.state.start_transition_time / self.config.start_transition_duration
        self.state.end_transition_time = (1 - t_normalized) * self.config.end_transition_duration
    end

    self.state.load_completed = true
    self.state.phase = LoadingPhase.END_TRANSITION

    if self.config.on_load_complete then
        self.config.on_load_complete(self.loaded_data)
    end
end

---Internal: Check start transition completion
---@private
function LoadingSystem:_check_start_transition_completion()
    if self.state.phase == LoadingPhase.START_TRANSITION and
        self.state.start_transition_time >= self.config.start_transition_duration then
        self.state.phase = LoadingPhase.LOADING
        if self.config.on_start_transition_complete then
            self.config.on_start_transition_complete()
        end

        if not self.config.allow_loading_during_start then
            self:update(0) -- Force update to start loading
        end
    end
end

---Internal: Check end transition completion
---@private
function LoadingSystem:_check_end_transition_completion()
    if self.state.phase == LoadingPhase.END_TRANSITION and
        self.state.end_transition_time >= self.config.end_transition_duration then
        self.state.phase = LoadingPhase.COMPLETED
        if self.config.on_end_transition_complete then
            self.config.on_end_transition_complete(self.loaded_data)
        end
    end
end

return LoadingSystem
