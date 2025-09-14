local default_config_file = get_script_root() .. "config/default.conf.lua"
local user_config_root = os.getenv("HOME") .. "/.config/hypr"
local user_config_file = user_config_root .. "/hyprfloat.config.lua"

function deep_merge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k]) == "table" then
            deep_merge(t1[k], v)
        else
            t1[k] = v
        end
    end
    return t1
end

local function load_config(filename)
    local success, result = pcall(function()
        return dofile(filename)
    end)

    if success then
        return result or {}
    else
        local f = io.open(filename, "r")
        if f == nil then return {} end
        f:close()
        print(string.format("Error loading %s: %s", filename, tostring(result)))
        os.exit(1)
    end
end

local function get_config()
    local default_config = load_config(default_config_file)
    local user_config = load_config(user_config_file)
    return deep_merge(default_config, user_config)
end

local config = get_config()
config.default_config_file = default_config_file
config.user_config_root = user_config_root
config.user_config_file = user_config_file

return config
