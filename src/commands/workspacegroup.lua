local hyprland = require("lib.hyprland")
local utils = require("lib.utils")
local config = require("lib.config")

local function find_group(groups, workspaceid)
    for i, group in ipairs(groups) do
        for _, v in ipairs(group) do
            if v == workspaceid then
                return i
            end
        end
    end

    return nil
end

return function(args)
    utils.check_args(#args < 1, "Usage: hyprfloat workspaceset <next|prev|status|group>")
    local action = args[1]
    local valid = { next = true, prev = true, status = true, group = true }
    utils.check_args(not valid[action], "Invalid first argument")

    local active_workspace = hyprland.get_activeworkspace()

    local cfg = config.workspacegroup
    local groupcount = #cfg.groups
    local group = find_group(cfg.groups, active_workspace.id)
    if not group then
        local err = string.format("Workspace %d not found in config.workspacegroup.groups", active_workspace.id)
        utils.debug(err)
        print(err)
        os.exit(1)
    end

    local function switch_group(nextgroup)
        -- switch all workspaces
        local commands = {}
        for _, wsid in ipairs(cfg.groups[nextgroup]) do
            table.insert(commands, "dispatch workspace " .. wsid)
        end
        table.insert(commands, "dispatch focusmonitor " .. active_workspace.monitor)
        hyprland.exec_hyprctl_batch(table.unpack(commands))

        -- run custom commands
        for _, cmd in ipairs(cfg.commands) do
            utils.exec_cmd(cmd)
        end
    end

    if action == "status" then
        local str = ""
        for i, _ in ipairs(cfg.groups) do
            str = str .. (group == i and cfg.icons.active or cfg.icons.default)
        end
        print(str)
    elseif action == "group" then
        local group = tonumber(args[2])
        utils.check_args(not group, "Invalid group number")
        switch_group(group)
    else
        local nextgroup = group + (action == "next" and 1 or -1)
        nextgroup = nextgroup > groupcount and groupcount
            or nextgroup < 1 and 1
            or nextgroup

        if group ~= nextgroup then
            switch_group(nextgroup)
        end
    end
end
