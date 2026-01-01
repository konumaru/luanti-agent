-- Agent Control & Observation API for Luanti
-- This mod provides a native Lua API for AI agent control and observation

agent_api = {}

-- Constants
local PLAYER_EYE_HEIGHT = 1.5  -- Player eye level offset for raycast
local BLOCK_PLACE_OFFSET = {x = 0, y = 1, z = 0}  -- Default offset for block placement
local CLOSE_VISIBILITY_RADIUS = 1.5  -- Distance within which blocks are always considered visible

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
}

-- Active agents registry
agent_api.agents = {}

local http_api_unavailable_logged = false

-- Auto-create agent for configured player on join
agent_api.config.auto_create = minetest.settings:get_bool("agent_api.auto_create", false)

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
                name = obj:get_entity_name() or "unknown",
            }
            
            -- Try to get additional info if it's a player
            if obj:is_player() then
                entity_data.type = "player"
                entity_data.player_name = obj:get_player_name()
            else
                entity_data.type = "entity"
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
    
    local http_api = minetest.request_http_api()
    if not http_api then
        if not http_api_unavailable_logged then
            http_api_unavailable_logged = true
            log("error", "HTTP API not available. Add 'agent_api' to secure.http_mods in minetest.conf")
            log("error", "secure.enable_security=" .. tostring(minetest.settings:get_bool("secure.enable_security")) ..
                " secure.http_mods=" .. tostring(minetest.settings:get("secure.http_mods")) ..
                " secure.trusted_mods=" .. tostring(minetest.settings:get("secure.trusted_mods")))
        end
        return
    end
    
    local url = agent_api.config.bot_server_url .. "/next"
    
    http_api:fetch({
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
