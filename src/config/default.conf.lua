return {
    -- Write debug output to /tmp/hyprfloat/debug.log
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
        max_ratio = 2.2, -- Maximum width/height ratio before adjusting
        min_ratio = 0.9, -- Minimum width/height ratio before adjusting

        -- These options are set when entering Overview mode. When leaving Overview mode, their
        -- original values will be restored.
        options = {
            "general:col.active_border rgba(ffd700ee) rgba(ff8c00ee) 45deg",
            "general:col.inactive_border rgba(ffd70033) rgba(ff8c0033) 45deg",
            'general:border_size 5',
        }
    },

    float_mode = {
        -- These hyprctl commands are run when entering floating mode
        tiling_commands = {
            'keyword general:col.active_border rgba(33ccffee) rgba(00ff99ee) 45deg',
            'keyword general:col.inactive_border rgba(595959aa)',
            'keyword general:gaps_in 2',
            'keyword general:gaps_out 2',
            'keyword general:border_size 5',
            'keyword unbind SUPER, LEFT',
            'keyword unbind SUPER, RIGHT',
            'keyword unbind SUPER, UP',
            'keyword unbind SUPER, DOWN',
            'keyword bind SUPER, LEFT, movefocus, l',
            'keyword bind SUPER, RIGHT, movefocus, r',
            'keyword bind SUPER, UP, movefocus, u',
            'keyword bind SUPER, DOWN, movefocus, d',
        },

        -- These hyprctl commands are run when entering floating mode
        floating_commands = {
            'keyword general:col.active_border rgba(00ff99ee) rgba(33ccffee) 45deg',
            'keyword general:col.inactive_border rgba(595959aa)',
            'keyword general:gaps_in 1',
            'keyword general:gaps_out 1',
            'keyword general:border_size 2',
            'keyword unbind SUPER, LEFT',
            'keyword unbind SUPER, RIGHT',
            'keyword unbind SUPER, UP',
            'keyword unbind SUPER, DOWN',
            'keyword bind SUPER, LEFT, exec, hyprfloat snap 0.0 0.5 0.0 1.0',
            'keyword bind SUPER, RIGHT, exec, hyprfloat snap 0.5 1.0 0.0 1.0',
            'keyword bind SUPER, UP, exec, hyprfloat center 1.25',
            'keyword bind SUPER, DOWN, exec, hyprfloat center 0.75',
        }
    },

    alttab = {
        -- Milliseconds to wait before checking if the ALT key is held down.
        -- If this is too short, the check may incorrectly report that ALT is held down.
        altkey_wait_ms = 50,

        -- Milliseconds to wait before opening the main selector window.
        mainwindow_wait_ms = 100,

        -- Number of concurrent grim processes to run
        max_concurrent = 8,

        -- Window scale for previews
        preview_scale = 0.15,

        -- Display and monitor
        default_monitor_index = 0,

        -- Tile dimensions
        base_tile_size = 240,
        selected_tile_size = 280,
        tile_container_size = 300,

        -- Grid spacing
        grid_row_spacing = 5,
        grid_column_spacing = 5,

        -- Window layout
        window_margin_top = 20,
        window_margin_bottom = 20,
        window_margin_left = 20,
        window_margin_right = 20,

        -- Window stylesheet
        stylesheet = [[
            #alttab-window {
                background: rgba(30, 30, 30, .75);
            }
            .tile {
                background-color: transparent;
                border: 1px solid transparent;
                border-radius: 4px;
                padding: 4px;
            }
            .tile.selected {
                background-color: #4A90E2;
                border: 3px solid #2E5C8A;
                border-radius: 8px;
                padding: 4px;
            }
            #label1 {
                color: #ddeeff;
                font-size: 16px;
                font-weight: bold;
            }
            #label2 {
                color: #ddeeff;
                font-size: 16px;
            }
        ]]
    },

    workspacegroup = {
        icons = {
            active = "  ",
            default = "  ",
        },
        groups = {
            { 1, 2, 3 }, -- monitor 1
            { 4, 5, 6 }, -- monitor 2
            { 7, 8, 9 }, -- monitor 3
        },
        commands = {
            "pkill -RTMIN+8 waybar"
        }
    }
}
