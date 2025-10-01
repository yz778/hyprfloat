local hyprland = require('lib.hyprland')
local utils = require('lib.utils')
local config = require('lib.config')

local shared = {}

shared.selected_address = nil

function shared.sort_and_apply_direction(workspaceid, clients, direction)
    table.sort(clients, function(a, b)
        -- Special: focusHistoryID 0 or 1 always come first
        local a_special = (a.focusHistoryID <= 1) and 1 or 0
        local b_special = (b.focusHistoryID <= 1) and 1 or 0
        if a_special ~= b_special then
            return a_special > b_special
        end

        -- Then prioritize same workspace
        local a_same_ws = a.workspace.id == workspaceid and 1 or 0
        local b_same_ws = b.workspace.id == workspaceid and 1 or 0
        if a_same_ws ~= b_same_ws then
            return a_same_ws > b_same_ws
        end

        -- Then by focusHistoryID according to direction
        if direction == "next" then
            return a.focusHistoryID < b.focusHistoryID
        else -- "prev"
            return a.focusHistoryID > b.focusHistoryID
        end
    end)

    -- Always swap the first two items (two most relevant windows for the direction)
    if #clients >= 2 then
        local first = clients[1]
        local second = clients[2]
        clients[1] = second
        clients[2] = first
    end

    return clients
end

function shared.activate()
    local address = shared.selected_address
    utils.debug("Activating " .. address)
    hyprland.hyprctl_batch(
        "dispatch focuswindow address:" .. address,
        "dispatch alterzorder top"
    )
end

local function mainloop(action, sameclass)
    -- build list of clients, taking into account whether we are filtering by the sameclass
    local active_window = hyprland.get_activewindow()
    local clients = hyprland.get_clients()
    if sameclass then
        local active_class = active_window and active_window.class
        if active_class then
            local filtered_clients = {}
            for _, client in ipairs(clients) do
                if client.class == active_class then
                    table.insert(filtered_clients, client)
                end
            end
            clients = filtered_clients
        end
    end

    -- Sort by focus history and apply direction
    if #clients > 1 then
        clients = shared.sort_and_apply_direction(active_window.workspace.id, clients, action)
    end
    shared.selected_address = clients[1].address

    -- UI Launcher Mode: Launch the full UI
    local cfg = config.alttab
    local luafile = cfg.thumbnails and 'commands.alttab_ui' or 'commands.alttab_ui_lite'
    local alttab_ui = require(luafile)
    alttab_ui.launch({ clients = clients, shared = shared })
end

return {
    run = function(args)
        if args[1] == "mainloop" then
            local action = args[2]
            local sameclass = args[3] == "1"
            mainloop(action, sameclass)
            return
        end

        utils.debug("-----")
        utils.debug("alttab started with args: " .. table.concat(args, " "))
        utils.check_args(#args < 1, "Usage: hyprfloat alttab <next|prev> [sameclass]")
        local action = args[1]
        local valid = { next = true, prev = true }
        utils.check_args(not valid[action], "Invalid first argument")

        local sameclass = args[2] == "sameclass" and "1" or "0"
        local me = get_script_root() .. '/hyprfloat'

        -- call self to run mainloop in new process in case it segfaults
        hyprland.hyprctl("dispatch submap alttab")
        local cmd = string.format("lua '%s' alttab mainloop %s %s", me, action, sameclass)
        os.execute(cmd)
        hyprland.hyprctl("dispatch submap reset")
    end,
    help = {
        short = "Focuses the next or previous window.",
        usage = "alttab <next|prev> [sameclass]",
        long = [[
Switches focus to the next or previous window in the focus history.

**Arguments:**
- `<next|prev>` Required. Specifies whether to switch to the next or the previous window.
- `[sameclass]` Optional. If provided, the window selection is restricted to windows of the same class as the currently active window.
]]
    }
}
