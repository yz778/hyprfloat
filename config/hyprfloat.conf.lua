return {
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

        options = {
            "general:col.active_border rgba(ffd700ee) rgba(ff8c00ee) 45deg",
            "general:col.inactive_border rgba(ffd70033) rgba(ff8c0033   ) 45deg",
            'general:border_size 5',
        }
    },

    float_mode = {
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
    }
}
