player_api = rawget(_G, "player_api") or {}

player_api.registered_models = player_api.registered_models or {}
player_api._state_by_player = player_api._state_by_player
    or setmetatable({}, {__mode = "k"})

local function normalize_textures(value)
    if type(value) == "string" then
        return {value}
    end
    if type(value) ~= "table" then
        return nil
    end
    local textures = {}
    for _, texture in ipairs(value) do
        if type(texture) == "string" then
            table.insert(textures, texture)
        end
    end
    return textures
end

local function shallow_copy(value)
    if type(value) ~= "table" then
        return {}
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = v
    end
    return out
end

function player_api.register_model(model_name, definition)
    if type(model_name) ~= "string" or model_name == "" then
        return
    end
    if type(definition) ~= "table" then
        definition = {}
    end
    local normalized = shallow_copy(definition)
    normalized.textures = normalize_textures(definition.textures) or {}
    player_api.registered_models[model_name] = normalized
end

local function get_state(player)
    local state = player_api._state_by_player[player]
    if state == nil then
        state = {}
        player_api._state_by_player[player] = state
    end
    return state
end

function player_api.set_model(player, model_name)
    if not player or type(player.set_properties) ~= "function" then
        return
    end

    local model = player_api.registered_models[model_name]
    if type(model) ~= "table" then
        return
    end

    local state = get_state(player)
    state.model = model_name

    local props = {
        mesh = model_name,
    }

    if model.collisionbox ~= nil then
        props.collisionbox = model.collisionbox
    end
    if model.eye_height ~= nil then
        props.eye_height = model.eye_height
    end
    if model.textures ~= nil and state.textures == nil then
        props.textures = model.textures
    end

    player:set_properties(props)
end

function player_api.set_textures(player, textures)
    if not player or type(player.set_properties) ~= "function" then
        return
    end
    local normalized = normalize_textures(textures)
    if not normalized then
        return
    end
    local state = get_state(player)
    state.textures = normalized
    player:set_properties({textures = normalized})
end

function player_api.get_textures(player)
    if not player then
        return nil
    end
    local state = player_api._state_by_player[player]
    return state and state.textures or nil
end
