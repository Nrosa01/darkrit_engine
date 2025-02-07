-- tick
-- https://github.com/bjornbytes/tick
-- MIT License

---@class bjornbytes.tick
---@field public framerate number?
---@field public rate number
---@field public timescale number
---@field public sleep number
---@field package dt number
---@field package accum number
---@field public frame number
local tick = {
  framerate = nil,
  rate = .016,
  timescale = 1,
  sleep = .001,
  dt = 0,
  accum = 0,
  frame = 1
}

local timer = love.timer
local graphics = love.graphics

-- Hardcoded here because it's easier for me
-- It was either this or modifying this to make a hook or something but
-- This is my engine so I can harcode some stuff idc
local engine = _G.Darkrit

---@diagnostic disable-next-line
love.run = function()
  if not timer then
    error('love.timer is required for tick')
  end

  if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
  timer.step()
  local lastframe = 0

  if love.update then love.update(0) end

  return function()
    tick.dt = timer.step() * tick.timescale
    tick.accum = tick.accum + tick.dt
    while tick.accum >= tick.rate do
      tick.accum = tick.accum - tick.rate

      if love.event then
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
          if name == 'quit' then
            if not love.quit or not love.quit() then
              return a or 0
            end
          end

          love.handlers[name](a, b, c, d, e, f)

          if name ~= 'update' and name ~= 'draw' then
            if Darkrit[name] then
              Darkrit[name](Darkrit, a, b, c, d, e, f)
            end
          end
        end
      end

      Darkrit:update(tick.rate)
    end

    while tick.framerate and timer.getTime() - lastframe < 1 / tick.framerate do
      timer.sleep(.0005)
    end

    lastframe = timer.getTime()
    if graphics and graphics.isActive() then
      graphics.origin()
      graphics.clear(graphics.getBackgroundColor())
      tick.frame = tick.frame + 1
      Darkrit:draw()
      graphics.present()
    end

    timer.sleep(tick.sleep)
  end
end

return tick
