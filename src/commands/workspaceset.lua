local hyprland = require("lib.hyprland")
local utils = require("lib.utils")

return function(args)
    utils.check_args(#args ~= 1, "Usage: hyprfloat workspaceset <next|prev>")

    local activewindow = hyprland.get_active_window()
    local activewsid = activewindow.workspace.id

    if arg[1] == "next" then
    elseif arg[2] == "prev" then
    else
        return
    end

    for i = 1, 3 do

    end

    local commands = {}
    table.insert(commands, "dispatch workspace 2")
    table.insert(commands, "dispatch workspace 5")
    table.insert(commands, "dispatch workspace 8")
    hyprland.exec_hyprctl_batch(table.unpack(commands))
end
