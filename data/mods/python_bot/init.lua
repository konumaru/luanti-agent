local modname = minetest.get_current_modname()
local settings = minetest.settings
local http = minetest.request_http_api()

local BOT_NAME = settings:get("python_bot.name") or "PyBot"
local POLL_INTERVAL = tonumber(settings:get("python_bot.poll_interval")) or 0.2
local POLL_URL = settings:get("python_bot.url") or "http://host.docker.internal:8000/next"
local FOLLOW_PLAYER = settings:get("python_bot.follow_player")
local FOLLOW_DISTANCE = tonumber(settings:get("python_bot.follow_distance")) or 2
local FOLLOW_SPEED = tonumber(settings:get("python_bot.follow_speed")) or 2

local bot_object

local function get_spawn_pos()
  local pos = minetest.setting_get_pos("static_spawnpoint")
  if pos then
    return pos
  end
  return { x = 0, y = 2, z = 0 }
end

local function ensure_bot()
  if bot_object then
    local luaentity = bot_object:get_luaentity()
    if luaentity then
      return bot_object
    end
  end

  bot_object = minetest.add_entity(get_spawn_pos(), modname .. ":bot")
  if bot_object then
    bot_object:set_nametag_attributes({ text = BOT_NAME })
    if FOLLOW_PLAYER and FOLLOW_PLAYER ~= "" then
      local luaentity = bot_object:get_luaentity()
      if luaentity then
        luaentity._follow = {
          player = FOLLOW_PLAYER,
          distance = FOLLOW_DISTANCE,
          speed = FOLLOW_SPEED,
        }
      end
    end
  end
  return bot_object
end

local function apply_command(object, cmd)
  if not cmd or type(cmd) ~= "table" then
    return
  end

  local cmd_type = cmd.type
  if cmd_type == "teleport" then
    object:set_pos({ x = cmd.x or 0, y = cmd.y or 0, z = cmd.z or 0 })
    return
  end

  if cmd_type == "look" then
    if cmd.yaw then
      object:set_yaw(cmd.yaw)
    end
    return
  end

  if cmd_type == "stop" then
    object:set_velocity({ x = 0, y = 0, z = 0 })
    return
  end

  if cmd_type == "jump" then
    local velocity = object:get_velocity()
    velocity.y = cmd.y or 6
    object:set_velocity(velocity)
    return
  end

  if cmd_type == "follow" then
    local luaentity = object:get_luaentity()
    if not luaentity then
      return
    end
    local player_name = cmd.player or cmd.name
    if not player_name or player_name == "" then
      return
    end
    luaentity._follow = {
      player = player_name,
      distance = cmd.distance or FOLLOW_DISTANCE,
      speed = cmd.speed or FOLLOW_SPEED,
    }
    return
  end

  if cmd_type == "unfollow" then
    local luaentity = object:get_luaentity()
    if not luaentity then
      return
    end
    luaentity._follow = nil
    local velocity = object:get_velocity()
    object:set_velocity({ x = 0, y = velocity.y, z = 0 })
    return
  end

  if cmd_type == "move" or cmd_type == "set_velocity" then
    local duration = tonumber(cmd.duration)
    object:set_velocity({
      x = cmd.vx or 0,
      y = cmd.vy or 0,
      z = cmd.vz or 0,
    })

    if duration and duration > 0 then
      local luaentity = object:get_luaentity()
      if luaentity then
        luaentity._action_remaining = duration
        luaentity._action_stop = function(target)
          target:set_velocity({ x = 0, y = 0, z = 0 })
        end
      end
    end
    return
  end

  if cmd_type == "walk" then
    local yaw = cmd.yaw or object:get_yaw() or 0
    local speed = cmd.speed or 2
    local duration = tonumber(cmd.duration)
    object:set_yaw(yaw)
    object:set_velocity({
      x = math.cos(yaw) * speed,
      y = object:get_velocity().y,
      z = math.sin(yaw) * speed,
    })

    if duration and duration > 0 then
      local luaentity = object:get_luaentity()
      if luaentity then
        luaentity._action_remaining = duration
        luaentity._action_stop = function(target)
          target:set_velocity({ x = 0, y = 0, z = 0 })
        end
      end
    end
    return
  end
end

minetest.register_entity(modname .. ":bot", {
  initial_properties = {
    visual = "cube",
    visual_size = { x = 0.6, y = 1.8 },
    textures = { "character.png", "character.png", "character.png", "character.png", "character.png", "character.png" },
    physical = true,
    collide_with_objects = true,
    pointable = true,
  },
  on_activate = function(self)
    self.object:set_armor_groups({ immortal = 1 })
  end,
  on_step = function(self, dtime)
    if not self._action_remaining then
      local follow = self._follow
      if not follow then
        return
      end
      self._follow_tick = (self._follow_tick or 0) - dtime
      if self._follow_tick > 0 then
        return
      end
      self._follow_tick = 0.1

      local player = minetest.get_player_by_name(follow.player)
      if not player then
        return
      end

      local pos = self.object:get_pos()
      local target = player:get_pos()
      local dx = target.x - pos.x
      local dz = target.z - pos.z
      local dist = math.sqrt(dx * dx + dz * dz)
      local velocity = self.object:get_velocity()

      if dist > follow.distance then
        local yaw = math.atan2(dz, dx)
        self.object:set_yaw(yaw)
        self.object:set_velocity({
          x = math.cos(yaw) * follow.speed,
          y = velocity.y,
          z = math.sin(yaw) * follow.speed,
        })
      else
        self.object:set_velocity({ x = 0, y = velocity.y, z = 0 })
      end
      return
    end
    self._action_remaining = self._action_remaining - dtime
    if self._action_remaining <= 0 then
      local stop = self._action_stop
      self._action_remaining = nil
      self._action_stop = nil
      if stop then
        stop(self.object)
      end
    end
  end,
})

local function handle_response(res)
  if not res.succeeded or res.code ~= 200 or not res.data or res.data == "" then
    return
  end
  local payload = minetest.parse_json(res.data)
  if not payload then
    return
  end

  local object = ensure_bot()
  if not object then
    return
  end

  local commands = payload.commands or payload.command or payload
  if type(commands) == "table" and commands.type == nil then
    for _, cmd in ipairs(commands) do
      apply_command(object, cmd)
    end
  else
    apply_command(object, commands)
  end
end

local function poll_server()
  if not http then
    minetest.log("error", "[" .. modname .. "] HTTP API not available. Add python_bot to secure.http_mods.")
    return
  end

  http.fetch({ url = POLL_URL, timeout = 2 }, function(res)
    handle_response(res)
    minetest.after(POLL_INTERVAL, poll_server)
  end)
end

minetest.register_chatcommand("pybot_spawn", {
  description = "Respawn the python bot at the spawn point.",
  func = function()
    if bot_object then
      bot_object:remove()
      bot_object = nil
    end
    if ensure_bot() then
      return true, "PyBot spawned."
    end
    return false, "Failed to spawn PyBot."
  end,
})

minetest.register_chatcommand("pybot_follow", {
  params = "[name]",
  description = "Make the python bot follow you or another player.",
  func = function(name, param)
    local object = ensure_bot()
    if not object then
      return false, "Failed to spawn PyBot."
    end
    local luaentity = object:get_luaentity()
    if not luaentity then
      return false, "PyBot entity unavailable."
    end
    local target = param ~= "" and param or name
    luaentity._follow = {
      player = target,
      distance = FOLLOW_DISTANCE,
      speed = FOLLOW_SPEED,
    }
    return true, "PyBot now follows " .. target .. "."
  end,
})

minetest.register_chatcommand("pybot_unfollow", {
  description = "Stop the python bot from following.",
  func = function()
    if not bot_object then
      return false, "PyBot is not spawned."
    end
    local luaentity = bot_object:get_luaentity()
    if not luaentity then
      return false, "PyBot entity unavailable."
    end
    luaentity._follow = nil
    local velocity = bot_object:get_velocity()
    bot_object:set_velocity({ x = 0, y = velocity.y, z = 0 })
    return true, "PyBot follow disabled."
  end,
})

minetest.after(1, function()
  ensure_bot()
  poll_server()
end)
