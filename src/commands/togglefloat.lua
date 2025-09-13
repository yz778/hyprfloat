local hyprland = require("lib.hyprland")
local utils = require("lib.utils")
local user_config = require("lib.config")

local default_config = {
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
}

return function(args)
    local config = utils.deep_merge(default_config, user_config)
    local mode = args[1]

    local windows = hyprland.get_clients()
    local is_floating = (
        mode == "on" and false
        or mode == "off" and true
        or hyprland.has_floating(windows)
    )

    local commands = {}
    table.insert(commands, string.format('keyword windowrulev2 %s,class:.*', is_floating and "unset" or "float"))

    local mode_commands = is_floating and config.float_mode.tiling_commands or config.float_mode.floating_commands
    for _, cmd in ipairs(mode_commands) do
        table.insert(commands, cmd)
    end

    for _, win in ipairs(windows) do
        if is_floating == win.floating then
            table.insert(commands, string.format("dispatch togglefloating address:%s", win.address))
        end
    end

    hyprland.exec_hyprctl_batch(table.unpack(commands))

    if not is_floating then
        local updated_windows = hyprland.get_clients()
        local monitors = hyprland.get_monitors()

        local monitor_map = {}
        for _, monitor in ipairs(monitors) do
            monitor_map[monitor.id] = monitor
        end

        local border_gap = hyprland.get_border_gap_config()
        local clamp_commands = {}

        for _, win in ipairs(updated_windows) do
            if win.floating then
                local monitor = monitor_map[win.monitor]
                if monitor then
                    local effective_area = hyprland.calculate_effective_area(monitor, border_gap)
                    local win_at = win.at
                    local win_x, win_y, win_w, win_h = win_at[1], win_at[2], win.size[1], win.size[2]
                    local new_x, new_y, new_w, new_h = hyprland.clamp_window_to_area(win_x, win_y, win_w, win_h,
                        effective_area)
                    local needs_focus = false

                    if new_x ~= win_x or new_y ~= win_y then
                        needs_focus = true
                        table.insert(clamp_commands, string.format("dispatch moveactive exact %d %d", new_x, new_y))
                    end

                    if new_w ~= win_w or new_h ~= win_h then
                        needs_focus = true
                        table.insert(clamp_commands, string.format("dispatch resizeactive exact %d %d", new_w, new_h))
                    end

                    if needs_focus then
                        table.insert(clamp_commands, string.format("dispatch focuswindow address:%s", win.address))
                    end
                end
            end
        end

        if #clamp_commands > 0 then
            hyprland.exec_hyprctl_batch(table.unpack(clamp_commands))
        end
    end
end
