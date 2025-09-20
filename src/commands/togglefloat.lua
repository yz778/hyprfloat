return {
    run = function(args)
        local hyprland = require("lib.hyprland")
        local config = require("lib.config")
        local utils = require("lib.utils")

        local cfg = config.float_mode
        local mode = args[1]

        local active_workspace_id = hyprland.get_activeworkspace().id

        local windows = {}
        for _, win in ipairs(hyprland.get_clients()) do
            if win.workspace.id == active_workspace_id then
                table.insert(windows, win)
            end
        end

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
        local rule = is_floating and "unset" or "float"
        local cmd = string.format('keyword windowrule %s,workspace:%d', rule, active_workspace_id)
        utils.debug(cmd)
        table.insert(commands, cmd)


        local mode_commands = is_floating and cfg.tiling_commands or cfg.floating_commands
        for _, cmd in ipairs(mode_commands) do
            table.insert(commands, cmd)
        end

        for _, win in ipairs(windows) do
            if is_floating == win.floating then
                table.insert(commands, string.format("dispatch togglefloating address:%s", win.address))
            end
        end

        hyprland.hyprctl_batch(table.unpack(commands))

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
                hyprland.hyprctl_batch(table.unpack(restore_commands))
            end
        end

        for _, cmd in ipairs(cfg.commands) do
            utils.exec_cmd(cmd)
        end
    end,
    help = {
        short = "Toggles floating mode for the current workspace.",
        usage = "togglefloat [on|off]",
        long = [[
Switches all windows in the current workspace between floating and tiling layouts.

**Arguments:**
- `[on|off]` Optional. Explicitly set all windows to floating ('on') or tiling ('off'). If omitted, it toggles the current state.
]]
    }
}
