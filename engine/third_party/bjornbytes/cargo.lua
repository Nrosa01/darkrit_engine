-- cargo v0.1.1
-- https://github.com/bjornbytes/cargo
-- MIT License

local cargo = {}

local function merge(target, source, ...)
  if not target or not source then return target end
  for k, v in pairs(source) do target[k] = v end
  return merge(target, ...)
end

local la, lf, lg = love.audio, love.filesystem, love.graphics

local function makeSound(path)
  local info = lf.getInfo(path, 'file')
  return la.newSource(path, (info and info.size and info.size < 5e5) and 'static' or 'stream')
end

local function makeFont(path)
  return function(size)
    return lg.newFont(path, size)
  end
end

local function loadFile(path)
  return lf.load(path)()
end

cargo.loaders = {
  lua = { loader = lf and loadFile, priority = 1 },
  png = { loader = lg and lg.newImage, priority = 1 },
  jpg = { loader = lg and lg.newImage, priority = 2 },
  dds = { loader = lg and lg.newImage, priority = 3 },
  ogv = { loader = lg and lg.newVideo, priority = 1 },
  glsl = { loader = lg and lg.newShader, priority = 1 },
  mp3 = { loader = la and makeSound, priority = 1 },
  ogg = { loader = la and makeSound, priority = 2 },
  wav = { loader = la and makeSound, priority = 3 },
  flac = { loader = la and makeSound, priority = 4 },
  txt = { loader = lf and lf.read, priority = 1 },
  ttf = { loader = lg and makeFont, priority = 1 },
  otf = { loader = lg and makeFont, priority = 2 },
  fnt = { loader = lg and lg.newFont, priority = 3 }
}

cargo.processors = {}

function cargo.init(config)
  if type(config) == 'string' then
    -- Check if the config is a directory
    local fileInfo = lf.getInfo(config, 'directory')
    if fileInfo then
      config = { dir = config }
    else
      return nil
    end
  end

  for ext, loader in pairs(config.loaders or {}) do
    if type(loader) == 'function' then
      config.loaders[ext] = { loader = loader, priority = 1 }
    end
  end

  local loaders = merge({}, cargo.loaders, config.loaders)
  local processors = merge({}, cargo.processors, config.processors)

  -- Ordenar loaders por prioridad
  local orderedLoaders = {}
  for ext, loaderInfo in pairs(loaders) do
    table.insert(orderedLoaders, {
      extension = ext,
      loader = type(loaderInfo) == "table" and loaderInfo.loader or loaderInfo,
      priority = type(loaderInfo) == "table" and loaderInfo.priority or 999
    })
  end
  table.sort(orderedLoaders, function(a, b) 
    return a.priority < b.priority
  end)

  local init

  local function halp(t, k)
    local path = (t._path .. '/' .. k):gsub('^/+', '')
    local fileInfo = lf.getInfo(path, 'directory')
    if fileInfo then
      rawset(t, k, init(path))
      return t[k]
    else
      for _, loaderData in ipairs(orderedLoaders) do
        local file = path .. '.' .. loaderData.extension
        local fileInfo = lf.getInfo(file)
        if loaderData.loader and fileInfo then
          local asset = loaderData.loader(file)
          rawset(t, k, asset)
          for pattern, processor in pairs(processors) do
            if file:match(pattern) then
              processor(asset, file, t)
            end
          end
          return asset
        end
      end
    end

    return rawget(t, k)
  end

  local function __call(t, recurse)
    for i, f in ipairs(love.filesystem.getDirectoryItems(t._path)) do
      local key = f:gsub('%..-$', '')
      halp(t, key)

      if recurse and love.filesystem.getInfo(t._path .. '/' .. f, 'directory') then
        t[key](recurse)
      end
    end

    return t
  end

  init = function(path)
    return setmetatable({ _path = path }, { __index = halp, __call = __call })
  end

  return init(config.dir)
end

return cargo
