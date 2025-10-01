return {
    -- Write debug output to /tmp/hyprfloat-debug.log
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

        -- Shell commands to run when toggling overview
        commands = {
            "pkill -RTMIN+8 waybar"
        }
    },

    dynamic_bind = {
        overview = {
            SUPER_LEFT  = 'hyprfloat:movefocus l',
            SUPER_RIGHT = 'hyprfloat:movefocus r',
            SUPER_UP    = 'hyprfloat:movefocus u',
            SUPER_DOWN  = 'hyprfloat:movefocus d'
        },
        tiling = {
            SUPER_LEFT  = 'dispatch movefocus l',
            SUPER_RIGHT = 'dispatch movefocus r',
            SUPER_UP    = 'dispatch movefocus u',
            SUPER_DOWN  = 'dispatch movefocus d'
        },
        floating = {
            SUPER_LEFT  = 'hyprfloat:snap 0.0 0.5 0.0 1.0',
            SUPER_RIGHT = 'hyprfloat:snap 0.5 1.0 0.0 1.0',
            SUPER_UP    = 'hyprfloat:center 1.25',
            SUPER_DOWN  = 'hyprfloat:center 0.75',
        },
    },

    float_mode = {
        -- These hyprctl commands are run when entering floating mode
        tiling_commands = {
        },

        -- These hyprctl commands are run when entering floating mode
        floating_commands = {
        },

        -- Shell commands to run after toggling floating status
        commands = {
            "pkill -RTMIN+8 waybar",
        }
    },

    alttab = {
        -- Milliseconds to wait before checking if the ALT key is held down.
        -- If this is too short, the check may incorrectly report that ALT is held down.
        altkey_wait_ms = 50,

        -- Milliseconds to wait before opening the main selector window.
        mainwindow_wait_ms = 100,

        -- Show thumbnails (slower)
        thumbnails = false,

        -- Number of concurrent grim processes to run
        max_concurrent = 8,

        -- Window scale for previews
        preview_scale = 0.15,

        -- Display and monitor
        default_monitor_index = 0,

        -- Tile dimensions
        base_tile_size = 160,
        selected_tile_size = 180,
        tile_container_size = 190,

        -- Grid spacing
        grid_row_spacing = 5,
        grid_column_spacing = 5,

        -- Window layout
        window_margin_top = 10,
        window_margin_bottom = 10,
        window_margin_left = 10,
        window_margin_right = 10,

        -- Window stylesheet
        stylesheet = [[
            #alttab-window {
                background: rgba(30, 30, 30, .75);
            }
            #alttab-outer {
                padding:10px;
            }
            .tile {
                background-color: transparent;
            }
            .tile.selected {
                background-color: rgba(100, 200, 255, .30);
                border: 3px solid #33ccff;
                border-radius: 8px;
            }
            #search {
                border: 1px solid #c0c0c0;
                margin-bottom:20px;
            }
            #label1 {
                margin-top:20px;
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
            occupied = "  ",
        },
        groups = {
            { 1, 2, 3 }, -- monitor 1
            { 4, 5, 6 }, -- monitor 2
            { 7, 8, 9 }, -- monitor 3
        },

        -- Shell commands to run after changing workspaces
        commands = {
            "pkill -RTMIN+8 waybar"
        }
    }
}
