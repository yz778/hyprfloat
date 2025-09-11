-- Configuration loading module
local function load_config()
    local xdg_config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    local success, result = pcall(function()
        return dofile(xdg_config_home .. "/hypr/hyprfloat.conf.lua")
    end)

    return success and result
        or {
            debug = false,
            overview = {
                -- Overview window sizes
                target_ratio = 1.6, -- 16:10
                min_w = 160,
                min_h = 100,
                -- Grid layout configuration
                sqrt_multiplier = 1.4,  -- Multiplier for calculating optimal grid dimensions
                max_cols = 5,           -- Maximum number of columns in grid
                spacing_factor = 0.024, -- Factor for calculating gap size based on screen dimensions
                min_gap = 8,            -- Minimum gap between windows
                margin_multiplier = 2,  -- Multiplier for margin (gap * margin_multiplier)
                -- Aspect ratio constraints
                max_ratio = 2.2,        -- Maximum width/height ratio before adjusting
                min_ratio = 0.9,        -- Minimum width/height ratio before adjusting

                options = {},
            },
            float_mode = {
                tiling_commands = {},
                floating_commands = {}
            }
        }
end

return load_config()
