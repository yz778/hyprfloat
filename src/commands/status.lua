return {
    run = function(args)
        local hyprland = require("lib.hyprland")
        local config = require("lib.config")
        local utils = require("lib.utils")

        local active_workspace = hyprland.get_activeworkspace()
        local cfgws = config.workspacegroup
        local group = utils.find_ws_group(cfgws.groups, active_workspace.id)
        local workspaces = hyprland.get_workspaces()

        local str = ""
        for i, g in ipairs(cfgws.groups) do
            if group == i then
                str = str .. cfgws.icons.active
            else
                local has_windows = false
                for _, ws in ipairs(g) do
                    if workspaces[ws].windows > 0 then
                        has_windows = true
                        break
                    end
                end

                str = str .. (has_windows and cfgws.icons.occupied or cfgws.icons.default)
            end
        end

        if utils.file_exists(utils.runtime_path("/overview.sock")) then
            str = str .. " Overview"
        end

        print(str)
    end,
    help = {
        short = "Prints workspace icons and current mode.",
        usage = "status",
        long = [[
Prints workspaces and current mode, typically for use with Waybar.
]]
    }
}
