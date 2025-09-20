local otag = "overview"

local function wincmds(address, togglefloat, tag, x, y, w, h)
    local cmds = {}
    table.insert(cmds, string.format("dispatch tagwindow %s address:%s", tag, address))
    if togglefloat then
        table.insert(cmds, string.format("dispatch togglefloating address:%s", address))
    end
    table.insert(cmds, string.format("dispatch movewindowpixel exact %d %d, address:%s", x, y, address))
    table.insert(cmds, string.format("dispatch resizewindowpixel exact %d %d, address:%s", w, h, address))
    return cmds
end

return {
    run = function(args)
        -- Dependencies
        local hyprland = require("lib.hyprland")
        local utils = require("lib.utils")
        local config = require("lib.config")
        local posix = require("posix")
        local signal = require("posix.signal")
        local poll = require("posix.poll")

        -- Config and state
        local cfg = config.overview
        local socket_path = utils.runtime_path("/overview.sock")
        local state = {
            listenfd = nil,
            hyprsock = nil,
            orig_windows = {},
            interrupted = false,
        }

        -- Forward declaration for cleanup
        local cleanup_and_exit

        --- Toggles an existing instance of the overview if one is running.
        -- @return (boolean) true if an existing instance was found and toggled, false otherwise.
        local function toggle_existing_instance()
            local sockfd = posix.socket(posix.AF_UNIX, posix.SOCK_STREAM, 0)
            local addr = { family = posix.AF_UNIX, path = socket_path }

            if posix.access(socket_path, "f") then
                local ok, err = posix.connect(sockfd, addr)
                if ok then
                    posix.send(sockfd, "toggle\n")
                    posix.close(sockfd)
                    utils.debug("Another instance is running, sending toggle message.")
                    return true -- Handled
                else
                    -- Stale socket file
                    os.remove(socket_path)
                end
            end

            posix.close(sockfd)
            return false -- Not handled, continue execution
        end

        --- Sets up the control socket to listen for toggle commands.
        local function setup_control_socket()
            local addr = { family = posix.AF_UNIX, path = socket_path }
            state.listenfd = posix.socket(posix.AF_UNIX, posix.SOCK_STREAM, 0)
            assert(state.listenfd, "Failed to create control socket")
            local ok, err = posix.bind(state.listenfd, addr)
            assert(ok, "Failed to bind control socket: " .. (err or "unknown error"))
            posix.listen(state.listenfd, 1)
        end

        --- Executes the user-configured commands.
        local function run_configured_commands()
            for _, cmd in ipairs(cfg.commands) do
                utils.debug(cmd)
                utils.exec_cmd(cmd)
            end
        end

        --- Generates and returns a list of hyprctl commands to arrange windows in a grid.
        -- @param clients (table) A list of all client windows.
        -- @param workspaces (table) A list of all workspaces.
        -- @param monitors (table) A list of all monitors.
        -- @param border_gap (table) The border and gap configuration.
        -- @return (table) A list of hyprctl commands.
        local function arrange_windows_in_grid(clients, workspaces, monitors, border_gap)
            local commands = {}
            for _, ws in ipairs(workspaces) do
                local ws_windows = {}
                for _, win in ipairs(clients) do
                    if win.workspace.id == ws.id then
                        table.insert(ws_windows, win)
                    end
                end

                table.sort(ws_windows, function(a, b)
                    if a.workspace.id ~= b.workspace.id then
                        return a.workspace.id < b.workspace.id
                    elseif a.at[2] ~= b.at[2] then
                        return a.at[2] < b.at[2]
                    elseif a.at[1] ~= b.at[1] then
                        return a.at[1] < b.at[1]
                    else
                        return a.address < b.address
                    end
                end)

                local wincount = #ws_windows
                if wincount > 0 then
                    local mon
                    for _, m in ipairs(monitors) do
                        if m.id == ws.monitorID then
                            mon = m
                            break
                        end
                    end

                    local area = hyprland.calculate_effective_area(mon, border_gap)

                    local cols, rows
                    if wincount < 3 then
                        cols, rows = wincount, 1
                    elseif wincount < 5 then
                        cols, rows = 2, 2
                    else
                        cols = math.min(cfg.max_cols, math.ceil(math.sqrt(wincount * cfg.sqrt_multiplier)))
                        rows = math.ceil(wincount / cols)
                    end

                    local gap = math.max(cfg.min_gap, math.floor(math.min(area.w, area.h) * cfg.spacing_factor))
                    local margin = gap * cfg.margin_multiplier
                    local grid_w = area.w - (margin * 2)
                    local grid_h = area.h - (margin * 2)
                    local total_gap_w = (cols - 1) * gap
                    local total_gap_h = (rows - 1) * gap
                    local base_win_w = math.floor((grid_w - total_gap_w) / cols)
                    local base_win_h = math.floor((grid_h - total_gap_h) / rows)

                    local actual_ratio = base_win_w / base_win_h
                    local win_w, win_h
                    if actual_ratio > cfg.max_ratio then
                        win_w = math.floor(base_win_h * cfg.target_ratio)
                        win_h = base_win_h
                    elseif actual_ratio < cfg.min_ratio then
                        win_w = base_win_w
                        win_h = math.floor(base_win_w / cfg.target_ratio)
                    else
                        win_w = base_win_w
                        win_h = base_win_h
                    end

                    win_w = math.floor(math.max(win_w, cfg.min_w))
                    win_h = math.floor(math.max(win_h, cfg.min_h))

                    local actual_grid_w = cols * win_w + (cols - 1) * gap
                    local actual_grid_h = rows * win_h + (rows - 1) * gap
                    local grid_offset_x = math.floor((grid_w - actual_grid_w) / 2)
                    local grid_offset_y = math.floor((grid_h - actual_grid_h) / 2)

                    for i, win in ipairs(ws_windows) do
                        local row = math.floor((i - 1) / cols)
                        local col = (i - 1) % cols
                        local win_x = math.floor(area.x + margin + grid_offset_x + col * (win_w + gap))
                        local win_y = math.floor(area.y + margin + grid_offset_y + row * (win_h + gap))
                        local togglefloat = not win.floating
                        local cmds = wincmds(win.address, togglefloat, "+" .. otag, win_x, win_y, win_w, win_h)
                        for _, cmd in ipairs(cmds) do
                            table.insert(commands, cmd)
                        end
                    end
                end
            end
            return commands
        end

        --- Restores all windows to their original state before the overview was activated.
        -- @param activewin_addr (string, optional) The address of the window to focus after restoring.
        local function restore_windows(activewin_addr)
            local commands = {}
            local clients = hyprland.get_clients()
            for _, new in pairs(clients) do
                local old = state.orig_windows[new.address]
                if old then
                    local win_x = old.at[1]
                    local win_y = old.at[2]
                    local win_w = old.size[1]
                    local win_h = old.size[2]
                    local togglefloat = old.floating ~= new.floating

                    local cmds = wincmds(new.address, togglefloat, "-" .. otag, win_x, win_y, win_w, win_h)
                    for _, cmd in ipairs(cmds) do
                        table.insert(commands, cmd)
                    end
                end
            end

            if activewin_addr then
                table.insert(commands, string.format("dispatch focuswindow address:%s", activewin_addr))
                table.insert(commands, string.format("dispatch alterzorder top", activewin_addr))
            end

            hyprland.hyprctl_batch(table.unpack(commands))
        end

        --- The main event loop, listening for control messages or window focus changes.
        local function main_loop()
            local done = false
            while not done and not state.interrupted do
                -- TODO: uncomment to exit overview mode on window focus
                --
                -- local hypr_ready = poll.rpoll(state.hyprsock, 50)
                -- if hypr_ready and hypr_ready > 0 then
                --     local data = posix.recv(state.hyprsock, 4096)
                --     for eventline in data:gmatch("[^\r\n]+") do
                --         local addr = eventline:match("^activewindowv2>>(.+)$")
                --         if addr then
                --             cleanup_and_exit("0x" .. addr)
                --             done = true
                --             break
                --         end
                --     end
                -- end

                local control_ready = poll.rpoll(state.listenfd, 0)
                if not done and control_ready and control_ready > 0 then
                    local conn = posix.accept(state.listenfd)
                    if conn then
                        local msg = posix.recv(conn, 1024)
                        posix.close(conn)
                        if msg and msg:match("toggle") then
                            utils.debug("Received toggle message, exiting overview mode.")
                            cleanup_and_exit()
                            done = true
                        end
                    end
                end
            end
        end

        --- Sets up signal handlers to ensure graceful exit.
        local function setup_signal_handlers()
            local function signal_handler()
                state.interrupted = true
                cleanup_and_exit()
            end
            signal.signal(signal.SIGINT, signal_handler)
            signal.signal(signal.SIGTERM, signal_handler)
        end

        --- Cleans up resources and exits the script.
        -- @param activewin_addr (string, optional) The address of the window to focus on exit.
        cleanup_and_exit = function(activewin_addr)
            restore_windows(activewin_addr)

            if state.listenfd then
                posix.close(state.listenfd)
                os.remove(socket_path)
            end

            if state.hyprsock then
                posix.close(state.hyprsock)
            end

            run_configured_commands()

            utils.debug("Exiting overview mode")
            os.exit(0)
        end

        --
        -- Main Execution Flow
        --

        if toggle_existing_instance() then
            return
        end

        setup_control_socket()
        run_configured_commands()

        state.hyprsock = hyprland.get_hyprsocket('socket2')
        local clients = hyprland.get_clients()
        local monitors = hyprland.get_monitors()
        local workspaces = hyprland.get_workspaces()
        local border_gap = hyprland.get_border_gap_config()
        local active_window = hyprland.get_activewindow()

        -- Save original window states
        for _, win in ipairs(clients) do
            state.orig_windows[win.address] = win
        end

        -- Arrange windows
        local grid_commands = arrange_windows_in_grid(clients, workspaces, monitors, border_gap)
        table.insert(grid_commands, string.format("dispatch focuswindow address:%s", active_window.address))
        hyprland.hyprctl_batch(table.unpack(grid_commands))

        setup_signal_handlers()

        utils.debug("-----")
        utils.debug("Overview mode active")

        main_loop()

        cleanup_and_exit()
    end,
    help = {
        short = "Toggles a GNOME-style workspace overview.",
        usage = "overview",
        long =
        "Toggles a GNOME-style workspace overview, arranging all windows in a grid. Running the command again will exit overview mode."
    }
}
