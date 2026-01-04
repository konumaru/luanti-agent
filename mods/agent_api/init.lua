-- Agent Control & Observation API for Luanti
-- This mod provides a native Lua API for AI agent control and observation

agent_api = {}

-- Constants
local PLAYER_EYE_HEIGHT = 1.5  -- Player eye level offset for raycast
local BLOCK_PLACE_OFFSET = {x = 0, y = 1, z = 0}  -- Default offset for block placement
local CLOSE_VISIBILITY_RADIUS = 1.5  -- Distance within which blocks are always considered visible

local DEFAULT_LIVING_MESH = "character.b3d"
if minetest.get_modpath("skinsdb") ~= nil then
    DEFAULT_LIVING_MESH = "skinsdb_3d_armor_character_5.b3d"
end

-- Configuration
agent_api.config = {
    -- Python bot server URL (can be overridden via minetest.conf)
    bot_server_url = minetest.settings:get("agent_api.bot_server_url") or "http://bot:8000",
    -- Polling interval in seconds
    poll_interval = tonumber(minetest.settings:get("agent_api.poll_interval")) or 0.2,
    -- Agent name
    agent_name = minetest.settings:get("agent_api.agent_name") or "AIAgent",
    -- Debug logging
    debug = minetest.settings:get_bool("agent_api.debug", false),
    -- Debug living agent spawn
    debug_spawn = minetest.settings:get_bool("agent_api.debug_spawn", false),
    debug_spawn_count = tonumber(minetest.settings:get("agent_api.debug_spawn_count")) or 3,
    -- Living agent visuals (optional integration with skinsdb / player_api)
    -- living_visual: "auto" (default), "character", or "cube"
    living_visual = minetest.settings:get("agent_api.living_visual") or "auto",
    living_mesh = minetest.settings:get("agent_api.living_mesh") or DEFAULT_LIVING_MESH,
    living_default_texture = minetest.settings:get("agent_api.living_default_texture") or "unknown_node.png",
    living_use_skinsdb = minetest.settings:get_bool("agent_api.living_use_skinsdb", true),
}

-- Active agents registry
agent_api.agents = {}

-- Logging helper
local function log(level, msg)
    local prefix = "[agent_api] "
    if level == "debug" and not agent_api.config.debug then
        return
    end
    minetest.log(level, prefix .. msg)
end

log("info", "secure.enable_security=" .. tostring(minetest.settings:get_bool("secure.enable_security")) ..
    " secure.http_mods=" .. tostring(minetest.settings:get("secure.http_mods")) ..
    " secure.trusted_mods=" .. tostring(minetest.settings:get("secure.trusted_mods")))

agent_api.http_api = minetest.request_http_api()
if not agent_api.http_api then
    log("error", "HTTP API not available. Add 'agent_api' to secure.http_mods in minetest.conf")
    log("error", "secure.enable_security=" .. tostring(minetest.settings:get_bool("secure.enable_security")) ..
        " secure.http_mods=" .. tostring(minetest.settings:get("secure.http_mods")) ..
        " secure.trusted_mods=" .. tostring(minetest.settings:get("secure.trusted_mods")))
end

-- Auto-create agent for configured player on join
agent_api.config.auto_create = minetest.settings:get_bool("agent_api.auto_create", false)

-- ============================================================================
-- Living Agent (autonomous demo NPC)
-- ============================================================================

local BEHAVIOR = {
    WANDER = "wander",
    FOLLOW = "follow",
    AVOID = "avoid",
    REST = "rest",
    IDLE = "idle",
}

local HUNGER_RATE = 0.35 -- per-second hunger increase
local FATIGUE_RATE = 0.25 -- per-second fatigue increase
local REST_RECOVERY = 0.8 -- recovery multiplier while resting
local NEED_MAX = 100
local FOLLOW_RADIUS = 8
local AVOID_RADIUS = 3
local FULL_ROTATION = 2 * math.pi
local RANDOM_STEPS = 3600
local YAW_OFFSET = math.pi / 2
local DEBUG_SPAWN_RADIUS = 2
local DEFAULT_LIVING_SEED = 0xBEEFFEED

agent_api.living_agents = {}
local living_seed = tonumber(minetest.settings:get("agent_api.living_seed")) or DEFAULT_LIVING_SEED
local living_rng = PcgRandom(living_seed) -- deterministic seed for reproducible demos
local living_agent_counter = 0
local living_skin_textures_cache = nil

local LIVING_COLLISIONBOX = {-0.3, -0.85, -0.3, 0.3, 0.85, 0.3}
local LIVING_SPAWN_Y_OFFSET = 0.85
local LIVING_VISUAL_SIZE = {x = 1.0, y = 1.0}

local function should_use_character_visual()
    local setting = (agent_api.config.living_visual or "auto"):lower()
    if setting == "cube" then
        return false
    end
    if setting == "character" then
        return true
    end
    if setting ~= "auto" then
        log("warning", "Invalid agent_api.living_visual=" .. setting .. " (expected auto/character/cube); using auto")
    end
    return minetest.get_modpath("player_api") ~= nil
        or minetest.get_modpath("skinsdb") ~= nil
        or minetest.get_modpath("skins") ~= nil
end

local function textureish(value)
    if type(value) ~= "string" then
        return nil
    end
    if value:find("%.png") then
        return value
    end
    return nil
end

local function discover_skinsdb_textures()
    local textures_set = {}

    local function add_texture(value)
        local texture = textureish(value)
        if texture then
            textures_set[texture] = true
        end
    end

    local function collect_from(provider)
        if type(provider) ~= "table" then
            return
        end

        if type(provider.get_skinlist) == "function" then
            local ok, skin_list = pcall(provider.get_skinlist)
            if ok and type(skin_list) == "table" then
                for _, skin in pairs(skin_list) do
                    if type(skin) == "table" then
                        add_texture(skin.texture)
                        if type(skin.textures) == "table" then
                            add_texture(skin.textures[1])
                        end
                    else
                        add_texture(skin)
                    end
                end
            end
        end

        if type(provider.skins) == "table" then
            for _, skin in pairs(provider.skins) do
                if type(skin) == "table" then
                    add_texture(skin.texture)
                    if type(skin.textures) == "table" then
                        add_texture(skin.textures[1])
                    end
                else
                    add_texture(skin)
                end
            end
        end
    end

    collect_from(rawget(_G, "skins"))
    local skinsdb_global = rawget(_G, "skinsdb")
    if type(skinsdb_global) == "table" then
        collect_from(skinsdb_global.skins or skinsdb_global)
    end

    local textures = {}
    for texture in pairs(textures_set) do
        table.insert(textures, texture)
    end
    table.sort(textures)
    return textures
end

local function get_living_skin_textures()
    if living_skin_textures_cache ~= nil then
        return living_skin_textures_cache
    end
    if not agent_api.config.living_use_skinsdb then
        living_skin_textures_cache = {}
        return living_skin_textures_cache
    end
    living_skin_textures_cache = discover_skinsdb_textures()
    return living_skin_textures_cache
end

local function pick_living_agent_texture()
    local textures = get_living_skin_textures()
    if type(textures) == "table" and #textures > 0 then
        local index = living_rng:next(1, #textures)
        return textures[index]
    end
    return agent_api.config.living_default_texture
end

local function sanitize_textures(textures)
    if type(textures) == "string" then
        if textures ~= "" then
            return {textures}
        end
        return nil
    end

    if type(textures) ~= "table" then
        return nil
    end

    local out = {}
    for _, value in ipairs(textures) do
        if type(value) == "string" and value ~= "" then
            table.insert(out, value)
        end
    end

    if #out == 0 then
        return nil
    end
    return out
end

local function get_player_appearance(player)
    if not player or type(player.get_properties) ~= "function" then
        return nil
    end

    local props = player:get_properties() or {}
    if type(props) ~= "table" then
        return nil
    end

    local mesh = type(props.mesh) == "string" and props.mesh ~= "" and props.mesh or nil
    local textures = sanitize_textures(props.textures)
    local visual_size = type(props.visual_size) == "table" and props.visual_size or nil

    if not mesh or not textures then
        return nil
    end

    return {
        mesh = mesh,
        textures = textures,
        visual_size = visual_size,
    }
end

local function get_living_agent_initial_properties()
    if should_use_character_visual() then
        return {
            physical = true,
            collide_with_objects = true,
            collisionbox = LIVING_COLLISIONBOX,
            visual = "mesh",
            mesh = agent_api.config.living_mesh,
            visual_size = LIVING_VISUAL_SIZE,
            textures = {agent_api.config.living_default_texture},
        }
    end

    return {
        physical = true,
        collide_with_objects = true,
        collisionbox = LIVING_COLLISIONBOX,
        visual = "cube",
        visual_size = {x = 0.8, y = 1.2},
        textures = {
            -- Use engine-provided fallback texture so this mod doesn't depend on a specific game (e.g. Minetest Game).
            "unknown_node.png",
            "unknown_node.png",
            "unknown_node.png",
            "unknown_node.png",
            "unknown_node.png",
            "unknown_node.png",
        },
    }
end

local function apply_living_agent_appearance(self)
    local appearance = self.appearance
    if type(appearance) == "table" and type(appearance.mesh) == "string" and appearance.mesh ~= "" then
        local textures = sanitize_textures(appearance.textures) or {self.texture or agent_api.config.living_default_texture}
        self.object:set_properties({
            visual = "mesh",
            mesh = appearance.mesh,
            textures = textures,
            visual_size = type(appearance.visual_size) == "table" and appearance.visual_size or LIVING_VISUAL_SIZE,
            collisionbox = LIVING_COLLISIONBOX,
        })
        return
    end

    if should_use_character_visual() then
        self.texture = self.texture or pick_living_agent_texture()
        self.object:set_properties({
            visual = "mesh",
            mesh = agent_api.config.living_mesh,
            textures = {self.texture},
            visual_size = LIVING_VISUAL_SIZE,
            collisionbox = LIVING_COLLISIONBOX,
        })
        return
    end
end

local function clamp(value, min_v, max_v)
    if value < min_v then
        return min_v
    elseif value > max_v then
        return max_v
    end
    return value
end

local function yaw_to_dir(yaw)
    local dir = minetest.yaw_to_dir(yaw)
    return {x = dir.x, y = 0, z = dir.z}
end

local function find_nearest_players(pos)
    local nearest_focus = nil
    local nearest_focus_dist = nil
    local nearest_threat = nil
    local nearest_threat_dist = nil

    for _, player in ipairs(minetest.get_connected_players()) do
        local player_pos = player:get_pos()
        if player_pos then
            local dist = vector.distance(pos, player_pos)
            if dist <= FOLLOW_RADIUS and (not nearest_focus_dist or dist < nearest_focus_dist) then
                nearest_focus = player
                nearest_focus_dist = dist
            end
            if dist <= AVOID_RADIUS and (not nearest_threat_dist or dist < nearest_threat_dist) then
                nearest_threat = player
                nearest_threat_dist = dist
            end
        end
    end

    return nearest_focus, nearest_focus_dist, nearest_threat, nearest_threat_dist
end

local function default_decision(agent, perception)
    if agent.state.fatigue > 85 then
        return BEHAVIOR.REST
    end

    if perception.threat and perception.threat_distance and perception.threat_distance < AVOID_RADIUS then
        return BEHAVIOR.AVOID
    end

    if perception.focus and perception.focus_distance and perception.focus_distance < FOLLOW_RADIUS then
        return BEHAVIOR.FOLLOW
    end

    if agent.state.hunger > 60 and agent.state.fatigue < 60 then
        return BEHAVIOR.WANDER
    end

    return BEHAVIOR.IDLE
end

-- Decision provider can be swapped for future LLM/GOAP implementations
agent_api.living_decision = default_decision

function agent_api.set_living_decision(decider)
    if type(decider) == "function" then
        agent_api.living_decision = decider
        log("info", "Living agent decision function updated")
    else
        log("warning", "Attempted to set invalid living_decision")
    end
end

local function update_needs(agent, dtime, behavior)
    agent.state.hunger = clamp(agent.state.hunger + (HUNGER_RATE * dtime), 0, NEED_MAX)
    local fatigue_delta = FATIGUE_RATE * dtime
    if behavior == BEHAVIOR.REST then
        fatigue_delta = fatigue_delta * -REST_RECOVERY
    end
    agent.state.fatigue = clamp(agent.state.fatigue + fatigue_delta, 0, NEED_MAX)
end

local function act(agent, behavior, perception)
    local obj = agent.object
    if not obj then
        return
    end
    if obj:is_player() then
        return
    end

    if behavior == BEHAVIOR.REST or behavior == BEHAVIOR.IDLE then
        local velocity = obj:get_velocity() or {x = 0, y = 0, z = 0}
        obj:set_velocity({x = 0, y = velocity.y, z = 0})
        return
    end

    local pos = obj:get_pos()
    if not pos then
        return
    end
    if behavior == BEHAVIOR.WANDER then
        if agent.wander_timer <= 0 then
            agent.wander_timer = 2.5
            agent.wander_yaw = (living_rng:next(0, RANDOM_STEPS) / RANDOM_STEPS) * FULL_ROTATION
        else
            agent.wander_timer = agent.wander_timer - agent.step_interval
        end
        obj:set_yaw(agent.wander_yaw)
        local dir = yaw_to_dir(agent.wander_yaw)
        obj:set_velocity(vector.multiply(dir, 1.5))
    elseif behavior == BEHAVIOR.FOLLOW and perception.focus then
        local target_pos = perception.focus:get_pos()
        if not target_pos then
            return
        end
        local dir = vector.direction(pos, target_pos)
        local yaw = math.atan2(dir.z, dir.x) + YAW_OFFSET
        obj:set_yaw(yaw)
        obj:set_velocity(vector.multiply(yaw_to_dir(yaw), 2.0))
    elseif behavior == BEHAVIOR.AVOID and perception.threat then
        local target_pos = perception.threat:get_pos()
        if not target_pos then
            return
        end
        local dir = vector.direction(target_pos, pos)
        local yaw = math.atan2(dir.z, dir.x) + YAW_OFFSET
        obj:set_yaw(yaw)
        obj:set_velocity(vector.multiply(yaw_to_dir(yaw), 2.5))
    end
end

minetest.register_entity("agent_api:living_agent", {
    initial_properties = get_living_agent_initial_properties(),

    on_activate = function(self, staticdata, dtime_s)
        self.state = {hunger = 0, fatigue = 0, inventory = {}}
        self.behavior = BEHAVIOR.IDLE
        self.wander_timer = 0
        self.step_interval = 0.5
        self.step_accum = 0
        self.wander_yaw = 0
        self.texture = nil
        self.appearance = nil
        self.object:set_acceleration({x = 0, y = -9.8, z = 0})
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata) or {}
            self.state = data.state or self.state
            self.behavior = data.behavior or self.behavior
            self.wander_timer = data.wander_timer or self.wander_timer
            self.wander_yaw = data.wander_yaw or self.wander_yaw
            self.texture = data.texture or self.texture
            self.appearance = data.appearance or self.appearance
        end

        apply_living_agent_appearance(self)

        living_agent_counter = living_agent_counter + 1
        self.agent_id = "living_" .. tostring(living_agent_counter)
        agent_api.living_agents[self.agent_id] = self
        log("info", "Living agent spawned: " .. self.agent_id)
    end,

    get_staticdata = function(self)
        return minetest.serialize({
            state = self.state,
            behavior = self.behavior,
            wander_timer = self.wander_timer,
            wander_yaw = self.wander_yaw,
            texture = self.texture,
            appearance = self.appearance,
        })
    end,

    on_deactivate = function(self)
        if self.agent_id then
            agent_api.living_agents[self.agent_id] = nil
        end
    end,

    on_step = function(self, dtime)
        self.step_accum = self.step_accum + dtime
        if self.step_accum < self.step_interval then
            return
        end

        local perception = {}
        local pos = self.object:get_pos()
        if not pos then
            return
        end
        perception.focus, perception.focus_distance, perception.threat, perception.threat_distance = find_nearest_players(pos)
        if perception.threat and perception.focus and perception.threat == perception.focus then
            perception.focus = nil
        end
        perception.pos = pos

        local next_behavior = agent_api.living_decision(self, perception)
        if next_behavior ~= self.behavior then
            self.behavior = next_behavior
            log("debug", "Living agent " .. self.agent_id .. " behavior -> " .. next_behavior)
        end

        update_needs(self, self.step_accum, self.behavior)
        act(self, self.behavior, perception)
        self.step_accum = 0
    end,
})

function agent_api.spawn_living_agents(center_pos, count, opts)
    if not center_pos then
        return
    end
    count = count or 1

    local appearance = nil
    if type(opts) == "table" then
        appearance = opts.appearance
        if not appearance and opts.player then
            appearance = get_player_appearance(opts.player)
        end
    end

    local staticdata = ""
    if appearance then
        staticdata = minetest.serialize({appearance = appearance})
    end

    for i = 1, count do
        local offset = {
            x = living_rng:next(-DEBUG_SPAWN_RADIUS, DEBUG_SPAWN_RADIUS),
            y = LIVING_SPAWN_Y_OFFSET,
            z = living_rng:next(-DEBUG_SPAWN_RADIUS, DEBUG_SPAWN_RADIUS),
        }
        local spawn_pos = vector.add(center_pos, offset)
        minetest.add_entity(spawn_pos, "agent_api:living_agent", staticdata)
    end
end

-- ============================================================================
-- Player Join Handling
-- ============================================================================

-- Auto-create agent for configured player
minetest.register_on_joinplayer(function(player)
    if agent_api.config.auto_create then
        local name = player:get_player_name()
        if name == agent_api.config.agent_name then
            minetest.after(1.0, function()
                agent_api.create_agent(name)
                log("info", "Auto-created agent for: " .. name)
            end)
        end
    end
    if agent_api.config.debug_spawn then
        local pos = player:get_pos()
        if pos then
            local player_name = player:get_player_name()
            minetest.after(1.0, function()
                local spawner = minetest.get_player_by_name(player_name)
                agent_api.spawn_living_agents(pos, agent_api.config.debug_spawn_count, {player = spawner})
                log("info", "Debug spawned living agents near " .. player_name)
            end)
        end
    end
end)

-- Clean up agent on player leave
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if agent_api.agents[name] then
        agent_api.remove_agent(name)
        log("info", "Agent removed on player leave: " .. name)
    end
end)

-- ============================================================================
-- Agent Entity Management
-- ============================================================================

-- Create a new agent by attaching to an existing player
function agent_api.create_agent(player_name)
    if not player_name then
        log("error", "Cannot create agent: player_name is required")
        return nil
    end
    
    local player = minetest.get_player_by_name(player_name)
    if not player then
        log("error", "Cannot create agent: player not found: " .. player_name)
        return nil
    end
    
    -- Check if agent already exists
    if agent_api.agents[player_name] then
        log("warning", "Agent already exists: " .. player_name)
        return agent_api.agents[player_name]
    end
    
    local agent = {
        name = player_name,
        player = player,
        state = "idle",
        last_pos = player:get_pos(),
        last_look_dir = player:get_look_dir(),
        action_queue = {},
        -- Observation settings
        filter_occluded_blocks = false,  -- Whether to filter out blocks not visible due to occlusion
    }
    
    agent_api.agents[player_name] = agent
    log("info", "Agent created for player: " .. player_name)
    return agent
end

-- Get agent by name
function agent_api.get_agent(name)
    return agent_api.agents[name]
end

-- Remove agent
function agent_api.remove_agent(name)
    local agent = agent_api.agents[name]
    if agent then
        -- Just remove from registry, don't remove the player
        agent_api.agents[name] = nil
        log("info", "Agent removed: " .. name)
        return true
    end
    return false
end

-- ============================================================================
-- Observation API
-- ============================================================================

-- Get agent's current position
function agent_api.get_position(agent)
    if not agent or not agent.player then return nil end
    return agent.player:get_pos()
end

-- Get agent's current orientation (yaw, pitch)
function agent_api.get_orientation(agent)
    if not agent or not agent.player then return nil end
    local look_horizontal = agent.player:get_look_horizontal()
    local look_vertical = agent.player:get_look_vertical()
    local look_dir = agent.player:get_look_dir()
    
    return {
        yaw = look_horizontal,
        pitch = look_vertical,
        look_dir = look_dir,
    }
end

-- Check if a block is visible from agent's eye position (not occluded)
local function is_block_visible(agent, block_pos)
    local eye_pos = vector.add(agent.player:get_pos(), {x = 0, y = PLAYER_EYE_HEIGHT, z = 0})
    local block_center = vector.add(block_pos, {x = 0.5, y = 0.5, z = 0.5})
    
    -- Use raycast to check if there's a clear line of sight
    local ray = minetest.raycast(eye_pos, block_center, false, false)
    local pointed = ray:next()
    
    -- If raycast hits the exact block we're checking, it's visible
    if pointed and pointed.type == "node" then
        local hit_pos = pointed.under
        -- Check if the hit position matches our target block
        if vector.equals(hit_pos, block_pos) then
            return true
        end
    end
    
    -- Also consider blocks very close to the agent as visible
    local distance = vector.distance(eye_pos, block_center)
    if distance < CLOSE_VISIBILITY_RADIUS then
        return true
    end
    
    return false
end

-- Get surrounding blocks (3x3x3 cube centered on agent)
function agent_api.get_surrounding_blocks(agent, radius)
    if not agent or not agent.player then return nil end
    
    radius = radius or 1
    local pos = agent.player:get_pos()
    local rounded_pos = vector.round(pos)
    local blocks = {}
    
    for x = -radius, radius do
        for y = -radius, radius do
            for z = -radius, radius do
                local check_pos = vector.add(rounded_pos, {x = x, y = y, z = z})
                local node = minetest.get_node(check_pos)
                
                -- Apply visibility filter if enabled
                local include_block = true
                if agent.filter_occluded_blocks then
                    include_block = is_block_visible(agent, check_pos)
                end
                
                if include_block then
                    table.insert(blocks, {
                        pos = check_pos,
                        name = node.name,
                        param1 = node.param1,
                        param2 = node.param2,
                    })
                end
            end
        end
    end
    
    return blocks
end

-- Get nearby entities
function agent_api.get_nearby_entities(agent, radius)
    if not agent or not agent.player then return nil end
    
    radius = radius or 10
    local pos = agent.player:get_pos()
    local entities = {}
    
    local objects = minetest.get_objects_inside_radius(pos, radius)
    for _, obj in ipairs(objects) do
        if obj ~= agent.player then
            local entity_pos = obj:get_pos()
            local entity_data = {
                pos = entity_pos,
                distance = vector.distance(pos, entity_pos),
                name = "unknown",
            }

            if obj:is_player() then
                entity_data.type = "player"
                entity_data.player_name = obj:get_player_name()
                entity_data.name = entity_data.player_name
            else
                entity_data.type = "entity"
                local luaentity = obj:get_luaentity()
                if luaentity and luaentity.name then
                    entity_data.name = luaentity.name
                end
            end

            table.insert(entities, entity_data)
        end
    end
    
    return entities
end

-- Get what agent is looking at (raycast)
function agent_api.get_look_target(agent, max_distance)
    if not agent or not agent.player then return nil end
    
    max_distance = max_distance or 5
    local pos = agent.player:get_pos()
    local look_dir = agent.player:get_look_dir()
    local eye_pos = vector.add(pos, {x = 0, y = PLAYER_EYE_HEIGHT, z = 0})
    local end_pos = vector.add(eye_pos, vector.multiply(look_dir, max_distance))
    
    local ray = minetest.raycast(eye_pos, end_pos, true, false)
    local pointed = ray:next()
    
    if pointed and pointed.type == "node" then
        local node = minetest.get_node(pointed.under)
        return {
            type = "node",
            pos = pointed.under,
            name = node.name,
            distance = vector.distance(eye_pos, pointed.under),
        }
    elseif pointed and pointed.type == "object" then
        return {
            type = "object",
            object = pointed.ref,
            distance = vector.distance(eye_pos, pointed.ref:get_pos()),
        }
    end
    
    return nil
end

-- Collect full observation data
function agent_api.observe(agent)
    if not agent or not agent.player then return nil end
    
    return {
        position = agent_api.get_position(agent),
        orientation = agent_api.get_orientation(agent),
        surrounding_blocks = agent_api.get_surrounding_blocks(agent, 2),
        nearby_entities = agent_api.get_nearby_entities(agent, 10),
        look_target = agent_api.get_look_target(agent, 5),
        health = agent.player:get_hp(),
        state = agent.state,
    }
end

-- ============================================================================
-- Action API
-- ============================================================================

-- Move agent in a direction
function agent_api.action_move(agent, direction, speed)
    if not agent or not agent.player then return false end
    
    speed = speed or 1.0
    local vel = {x = 0, y = 0, z = 0}
    
    if direction == "forward" then
        local look_dir = agent.player:get_look_dir()
        vel = vector.multiply(look_dir, speed)
    elseif direction == "backward" then
        local look_dir = agent.player:get_look_dir()
        vel = vector.multiply(look_dir, -speed)
    elseif direction == "left" then
        local look_dir = agent.player:get_look_dir()
        local right = vector.new(-look_dir.z, 0, look_dir.x)
        vel = vector.multiply(right, -speed)
    elseif direction == "right" then
        local look_dir = agent.player:get_look_dir()
        local right = vector.new(-look_dir.z, 0, look_dir.x)
        vel = vector.multiply(right, speed)
    elseif direction == "up" then
        vel = {x = 0, y = speed, z = 0}
    elseif direction == "down" then
        vel = {x = 0, y = -speed, z = 0}
    end
    
    agent.player:add_velocity(vel)
    log("debug", "Agent " .. agent.name .. " moving " .. direction)
    return true
end

-- Rotate agent
function agent_api.action_rotate(agent, yaw_delta, pitch_delta)
    if not agent or not agent.player then return false end
    
    local current_yaw = agent.player:get_look_horizontal()
    local current_pitch = agent.player:get_look_vertical()
    
    if yaw_delta then
        agent.player:set_look_horizontal(current_yaw + yaw_delta)
    end
    
    if pitch_delta then
        agent.player:set_look_vertical(current_pitch + pitch_delta)
    end
    
    log("debug", "Agent " .. agent.name .. " rotated")
    return true
end

-- Set absolute look direction
function agent_api.action_look_at(agent, yaw, pitch)
    if not agent or not agent.player then return false end
    
    if yaw then
        agent.player:set_look_horizontal(yaw)
    end
    
    if pitch then
        agent.player:set_look_vertical(pitch)
    end
    
    log("debug", "Agent " .. agent.name .. " looking at yaw=" .. tostring(yaw) .. " pitch=" .. tostring(pitch))
    return true
end

-- Dig/mine block at look target
function agent_api.action_dig(agent)
    if not agent or not agent.player then return false end
    
    local target = agent_api.get_look_target(agent, 5)
    if target and target.type == "node" then
        -- Check if area is protected
        if minetest.is_protected(target.pos, agent.name) then
            log("debug", "Agent " .. agent.name .. " cannot dig protected area at " .. minetest.pos_to_string(target.pos))
            return false
        end
        
        -- Check if node is diggable
        local node = minetest.get_node(target.pos)
        local node_def = minetest.registered_nodes[node.name]
        if node_def and node_def.diggable == false then
            log("debug", "Agent " .. agent.name .. " cannot dig undiggable node: " .. node.name)
            return false
        end
        
        minetest.remove_node(target.pos)
        log("debug", "Agent " .. agent.name .. " dug at " .. minetest.pos_to_string(target.pos))
        return true
    end
    
    return false
end

-- Place block at look target
function agent_api.action_place(agent, node_name)
    if not agent or not agent.player then return false end
    
    node_name = node_name or "default:dirt"
    
    -- Validate node name exists and is registered
    if not minetest.registered_nodes[node_name] then
        log("warning", "Agent " .. agent.name .. " tried to place unknown node: " .. node_name)
        return false
    end
    
    local target = agent_api.get_look_target(agent, 5)
    if target and target.type == "node" then
        -- Place above the targeted node
        local place_pos = vector.add(target.pos, BLOCK_PLACE_OFFSET)
        
        -- Check if area is protected
        if minetest.is_protected(place_pos, agent.name) then
            log("debug", "Agent " .. agent.name .. " cannot place in protected area at " .. minetest.pos_to_string(place_pos))
            return false
        end
        
        local node = minetest.get_node(place_pos)
        
        if node.name == "air" then
            minetest.set_node(place_pos, {name = node_name})
            log("debug", "Agent " .. agent.name .. " placed block at " .. minetest.pos_to_string(place_pos))
            return true
        end
    end
    
    return false
end

-- Use/interact with target
function agent_api.action_use(agent)
    if not agent or not agent.player then return false end
    
    local target = agent_api.get_look_target(agent, 5)
    if target then
        log("debug", "Agent " .. agent.name .. " used/interacted with target")
        
        -- Note: Basic interaction is logged but not yet implemented.
        -- Future enhancements could include:
        -- - Right-click simulation on nodes (opening chests, doors, etc.)
        -- - Punching entities
        -- - Using held items
        -- Implementation depends on specific use cases and Luanti API capabilities.
        
        return true
    end
    
    return false
end

-- Set observation options
function agent_api.action_set_observation_options(agent, options)
    if not agent or not options then return false end
    
    if options.filter_occluded_blocks ~= nil then
        agent.filter_occluded_blocks = options.filter_occluded_blocks
        log("debug", "Agent " .. agent.name .. " occlusion filter: " .. tostring(agent.filter_occluded_blocks))
    end
    
    return true
end

-- Send chat message
function agent_api.action_chat(agent, message)
    if not agent or not agent.player then return false end
    
    if not message or message == "" then
        log("warning", "Agent " .. agent.name .. " tried to send empty chat message")
        return false
    end
    
    -- Send chat message from the agent
    minetest.chat_send_all("<" .. agent.name .. "> " .. message)
    log("debug", "Agent " .. agent.name .. " sent chat: " .. message)
    
    return true
end

-- Execute an action command
function agent_api.execute_action(agent, action)
    if not agent or not action then return false end
    
    local action_type = action.type
    
    if action_type == "move" then
        return agent_api.action_move(agent, action.direction, action.speed)
    elseif action_type == "rotate" then
        return agent_api.action_rotate(agent, action.yaw_delta, action.pitch_delta)
    elseif action_type == "look_at" then
        return agent_api.action_look_at(agent, action.yaw, action.pitch)
    elseif action_type == "dig" then
        return agent_api.action_dig(agent)
    elseif action_type == "place" then
        return agent_api.action_place(agent, action.node_name)
    elseif action_type == "use" then
        return agent_api.action_use(agent)
    elseif action_type == "set_observation_options" then
        return agent_api.action_set_observation_options(agent, action.options)
    elseif action_type == "chat" then
        return agent_api.action_chat(agent, action.message)
    else
        log("warning", "Unknown action type: " .. tostring(action_type))
        return false
    end
end

-- ============================================================================
-- Communication Layer (HTTP to Python)
-- ============================================================================

-- Send observation data to Python server
function agent_api.send_observation(agent, observation)
    if not agent then return end
    
    -- Store observation for future use
    agent.last_observation = observation
    agent.last_observation_time = minetest.get_us_time()
    
    -- Note: Observation pushing to Python is not yet implemented.
    -- Currently, the Python side polls for commands, and observations
    -- are stored locally. Future enhancement could include a POST endpoint
    -- on the Python server to receive observations.
end

-- Poll Python server for action commands
function agent_api.poll_commands(agent)
    if not agent then return end
    
    if not agent_api.http_api then
        return
    end
    
    local url = agent_api.config.bot_server_url .. "/next"
    
    agent_api.http_api.fetch({
        url = url,
        timeout = 1,
        method = "GET",
    }, function(result)
        if result.succeeded and result.code == 200 then
            local success, data = pcall(minetest.parse_json, result.data)
            if success and data and data.commands then
                for _, cmd in ipairs(data.commands) do
                    local cmd_success, cmd_json = pcall(minetest.write_json, cmd)
                    if cmd_success then
                        log("debug", "Received command: " .. cmd_json)
                    else
                        log("debug", "Received command (unable to serialize for logging)")
                    end
                    agent_api.execute_action(agent, cmd)
                end
            elseif not success then
                log("warning", "Failed to parse JSON response: " .. tostring(data))
            end
        elseif not result.succeeded then
            log("debug", "Poll failed: " .. (result.error or "unknown error"))
        else
            log("debug", "Poll returned code: " .. tostring(result.code))
        end
    end)
end

-- ============================================================================
-- Main Control Loop
-- ============================================================================

-- Global timer for agent control loop
local control_timer = 0

minetest.register_globalstep(function(dtime)
    control_timer = control_timer + dtime
    
    if control_timer >= agent_api.config.poll_interval then
        control_timer = 0
        
        -- Process each active agent
        for name, agent in pairs(agent_api.agents) do
            if agent and agent.player then
                -- Gather observations
                local obs = agent_api.observe(agent)
                
                -- Send to Python (store for now)
                agent_api.send_observation(agent, obs)
                
                -- Poll for commands
                agent_api.poll_commands(agent)
            end
        end
    end
end)

-- ============================================================================
-- Chat Commands for Manual Agent Control
-- ============================================================================

minetest.register_chatcommand("agent_create", {
    description = "Create an AI agent from the calling player",
    params = "",
    func = function(name, param)
        local agent = agent_api.create_agent(name)
        if agent then
            return true, "Agent created for player: " .. agent.name
        else
            return false, "Failed to create agent"
        end
    end,
})

minetest.register_chatcommand("agent_switch", {
    description = "Create an AI agent from the calling player",
    params = "",
    func = function(name, param)
        local create_cmd = minetest.registered_chatcommands["agent_create"]
        if create_cmd and create_cmd.func then
            return create_cmd.func(name, param)
        end
        return false, "Agent creation command unavailable"
    end,
})

minetest.register_chatcommand("agent_attach", {
    description = "Attach agent to another player (requires server privilege)",
    params = "<player_name>",
    privs = {server = true},
    func = function(name, param)
        if param == "" then
            return false, "Usage: /agent_attach <player_name>"
        end
        
        local agent = agent_api.create_agent(param)
        if agent then
            return true, "Agent attached to player: " .. agent.name
        else
            return false, "Failed to attach agent to player: " .. param
        end
    end,
})

minetest.register_chatcommand("agent_remove", {
    description = "Remove AI agent control from a player",
    params = "[player_name]",
    func = function(name, param)
        local target_name = param ~= "" and param or name
        
        if agent_api.remove_agent(target_name) then
            return true, "Agent removed: " .. target_name
        else
            return false, "Agent not found: " .. target_name
        end
    end,
})

minetest.register_chatcommand("agent_spawn_debug", {
    description = "Spawn living demo agents near you",
    params = "[count]",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end
        local count = tonumber(param) or agent_api.config.debug_spawn_count or 3
        agent_api.spawn_living_agents(player:get_pos(), count, {player = player})
        return true, "Spawned " .. count .. " living agents nearby"
    end,
})

minetest.register_chatcommand("agent_list", {
    description = "List all agents",
    func = function(name, param)
        local count = 0
        local list = ""
        for agent_name, _ in pairs(agent_api.agents) do
            count = count + 1
            list = list .. agent_name .. " "
        end
        
        if count == 0 then
            return true, "No agents active"
        else
            return true, "Active agents (" .. count .. "): " .. list
        end
    end,
})

log("info", "Agent API initialized")
