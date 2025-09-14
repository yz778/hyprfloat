local hyprland = require("lib.hyprland")
local utils = require("lib.utils")
local config = require("lib.config")

return function(args)
    local cfg = config.float_mode
    local mode = args[1]

    local windows = hyprland.get_clients()
    local is_floating = (
        mode == "on" and false
        or mode == "off" and true
        or hyprland.has_floating(windows)
    )

    local saved_geometry = {}
    if not is_floating then
        for _, win in ipairs(windows) do
            saved_geometry[win.address] = { at = win.at, size = win.size }
        end
    end

    local commands = {}
    table.insert(commands, string.format('keyword windowrulev2 %s,class:.*', is_floating and "unset" or "float"))

    local mode_commands = is_floating and cfg.tiling_commands or cfg.floating_commands
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
        local restore_commands = {}
        for _, win in ipairs(hyprland.get_clients()) do
            if saved_geometry[win.address] then
                local geo = saved_geometry[win.address]
                local x, y = geo.at[1], geo.at[2]
                local w, h = geo.size[1], geo.size[2]

                table.insert(restore_commands, string.format("dispatch focuswindow address:%s", win.address))
                table.insert(restore_commands, string.format("dispatch resizeactive exact %d %d", w, h))
                table.insert(restore_commands, string.format("dispatch moveactive exact %d %d", x, y))
            end
        end

        if #restore_commands > 0 then
            hyprland.exec_hyprctl_batch(table.unpack(restore_commands))
        end
    end
end
