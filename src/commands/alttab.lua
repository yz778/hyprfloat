local hyprland = require('lib.hyprland')
local utils = require('lib.utils')

local shared = {}
local mru_file = "/tmp/hyprfloat/alttab_mru.txt"

shared.selected_address = nil

function shared.mru_load(file_path)
    local mru = {}
    local file = io.open(file_path, "r")
    if file then
        for line in file:lines() do
            table.insert(mru, line)
        end
        file:close()
    end

    return mru
end

function shared.mru_save(file_path, mru_list)
    local file = io.open(file_path, "w")
    if file then
        for _, address in ipairs(mru_list) do
            file:write(address .. "\n")
        end
        file:close()
    end
end

function shared.mru_update(mru_list, selected_address)
    for i, address in ipairs(mru_list) do
        if address == selected_address then
            table.remove(mru_list, i)
            break
        end
    end

    table.insert(mru_list, 1, selected_address)
    while #mru_list > 2 do
        table.remove(mru_list)
    end
    return mru_list
end

function shared.mru_sort(clients, mru_list)
    local mru_map = {}
    for i, address in ipairs(mru_list) do
        mru_map[address] = i
    end
    table.sort(clients, function(a, b)
        local a_rank = mru_map[a.address] or a.focusHistoryID
        local b_rank = mru_map[b.address] or b.focusHistoryID
        return a_rank < b_rank
    end)
    return clients
end

function shared.mru_apply_direction(clients, mru_list, direction)
    clients = shared.mru_sort(clients, mru_list)
    local clientcount = #clients

    if clientcount <= 1 then
        return clients
    end

    if direction == "next" then
        if clientcount > 1 then
            local next_client = table.remove(clients, 2)
            table.insert(clients, 1, next_client)
        end
    elseif direction == "prev" then
        local prev_client = table.remove(clients, clientcount)
        table.insert(clients, 1, prev_client)
    end

    return clients
end

function shared.activate()
    local address = shared.selected_address
    utils.debug("Activating " .. address)
    local mru = shared.mru_load(mru_file)
    mru = shared.mru_update(mru, address)
    shared.mru_save(mru_file, mru)
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
    utils.check_args(not valid[action], "Invalid first argument, next or prev expected")

    local has_sameclass = args[2] == "sameclass"
    if has_sameclass then
        mru_file = mru_file:gsub("%.txt", "_sameclass.txt")
    end

    -- Get and filter clients
    local clients = hyprland.get_clients()
    if has_sameclass then
        local active_window = hyprland.get_active_window()
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

    -- Load MRU and apply direction
    local mru = shared.mru_load(mru_file)
    clients = shared.mru_apply_direction(clients, mru, action)
    shared.selected_address = clients[1].address

    -- UI Launcher Mode: Launch the full UI
    local alttab_ui = require('commands.alttab_ui')
    alttab_ui.launch({
        clients = clients,
        mru_file = mru_file,
        shared = shared
    })
end
