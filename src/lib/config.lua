local function load_config()
    local xdg_config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    local config_path = xdg_config_home .. "/hypr/hyprfloat.conf.lua"

    local success, result = pcall(function()
        return dofile(config_path)
    end)

    if success then
        return result or {}
    else
        local f = io.open(config_path, "r")
        if f == nil then return {} end
        f:close()
        print(string.format("Error loading %s: %s", config_path, tostring(result)))
        os.exit(1)
    end
end

return load_config()
