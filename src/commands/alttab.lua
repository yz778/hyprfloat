local hyprland = require('lib.hyprland')
local utils = require('lib.utils')

local shared = {}

shared.selected_address = nil

function shared.sort_and_apply_direction(clients, direction)
    local clientcount = #clients

    if clientcount <= 1 then
        return clients
    end

    if direction == "next" then
        -- Sort by focusHistoryID ascending (oldest focus first, so next in sequence comes first)
        table.sort(clients, function(a, b)
            return a.focusHistoryID < b.focusHistoryID
        end)
    elseif direction == "prev" then
        -- Sort by focusHistoryID descending (newest focus first, so prev in sequence comes first)
        table.sort(clients, function(a, b)
            return a.focusHistoryID > b.focusHistoryID
        end)
    end

    -- Always swap the first two items (two most relevant windows for the direction)
    if clientcount >= 2 then
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
    hyprland.exec_hyprctl_batch(
        string.format("dispatch focuswindow address:%s", address),
        "dispatch alterzorder top"
    )
end

return function(args)
    utils.debug("-----")
    utils.debug("alttab started with args: " .. table.concat(args, " "))

    utils.check_args(#args < 1, "Usage: hyprfloat alttab <next|prev> [sameclass]")
    local action = args[1]
    local valid = { next = true, prev = true }
    utils.check_args(not valid[action], "Invalid first argument")

    local has_sameclass = args[2] == "sameclass"

    -- Get and filter clients
    local clients = hyprland.get_clients()
    if has_sameclass then
        local active_window = hyprland.get_activewindow()
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
    clients = shared.sort_and_apply_direction(clients, action)
    shared.selected_address = clients[1].address

    -- UI Launcher Mode: Launch the full UI
    local alttab_ui = require('commands.alttab_ui')
    alttab_ui.launch({
        clients = clients,
        shared = shared
    })
end
