-- Overview mode command
local hyprland = require("lib.hyprland")
local utils = require("lib.utils")
local config = require("lib.config")
local posix = require("posix")
local signal = require("posix.signal")
local poll = require("posix.poll")

local default_config = {
    overview = {
        -- Overview window sizes
        target_ratio = 1.6, -- 16:10
        min_w = 160,
        min_h = 100,
        -- Grid layout configuration
        sqrt_multiplier = 1.4,  -- Multiplier for calculating optimal grid dimensions
        max_cols = 5,           -- Maximum number of columns in grid
        spacing_factor = 0.024, -- Factor for calculating gap size based on screen dimensions
        min_gap = 8,            -- Minimum gap between windows
        margin_multiplier = 2,  -- Multiplier for margin (gap * margin_multiplier)
        -- Aspect ratio constraints
        max_ratio = 2.2,        -- Maximum width/height ratio before adjusting
        min_ratio = 0.9,        -- Minimum width/height ratio before adjusting

        options = {},
    },
}

return function(args)
    local cfg = utils.deep_merge(default_config, config).overview

    -- if another instance is running, untoggle the overview
    local socket_path = "/tmp/hyprfloat_overview.sock"
    local sockfd = posix.socket(posix.AF_UNIX, posix.SOCK_STREAM, 0)
    local addr = { family = posix.AF_UNIX, path = socket_path }
    if posix.access(socket_path, "f") then
        local ok, err = posix.connect(sockfd, addr)
        if ok then
            posix.send(sockfd, "toggle\n")
            posix.close(sockfd)
            print("Sent toggle to running overview instance.")
            return
        else
            os.remove(socket_path)
        end
    end
    posix.close(sockfd)

    -- create new socket listern
    local listenfd = posix.socket(posix.AF_UNIX, posix.SOCK_STREAM, 0)
    assert(listenfd, "Failed to create control socket")
    local ok, err = posix.bind(listenfd, addr)
    assert(ok, "Failed to bind control socket: " .. (err or "unknown error"))
    posix.listen(listenfd, 1)

    local hyprsock = hyprland.get_hyprsocket()
    local clients = hyprland.get_clients()
    local monitors = hyprland.get_monitors()
    local workspaces = hyprland.get_workspaces()
    local border_gap = hyprland.get_border_gap_config()

    -- Run option commands, saving original values
    local orig_options = {}
    local opt_commands = {}
    for _, opt in ipairs(cfg.options) do
        local key, newval = opt:match("^([^%s]+)%s*(.*)")
        local origval = utils.get_cmd_json(string.format("hyprctl getoption %s -j", key))
        table.insert(orig_options, origval)
        table.insert(opt_commands, string.format("keyword %s %s", key, newval))
    end
    hyprland.exec_hyprctl_batch(table.unpack(opt_commands))

    -- Save all window states
    local active_window = hyprland.get_active_window()
    local orig_windows = {}
    for _, win in ipairs(clients) do
        orig_windows[win.address] = win
    end

    -- For each workspace, float all windows and arrange in grid
    local grid_commands = {}
    for _, ws in ipairs(workspaces) do
        local ws_windows = {}
        for _, win in ipairs(clients) do
            if win.workspace.id == ws.id then
                table.insert(ws_windows, win)
            end
        end

        local wincount = #ws_windows
        if wincount > 0 then
            local monitorid = ws.monitorID
            local mon
            for _, m in ipairs(monitors) do
                if m.id == monitorid then
                    mon = m
                    break
                end
            end

            local area = hyprland.calculate_effective_area(mon, border_gap)

            -- Modern grid layout with optimal spacing and visual hierarchy
            local cols, rows
            if wincount < 3 then
                cols, rows = wincount, 1
            elseif wincount < 5 then
                cols, rows = 2, 2
            else
                cols = math.min(cfg.max_cols,
                    math.ceil(math.sqrt(wincount * cfg.sqrt_multiplier)))
                rows = math.ceil(wincount / cols)
            end

            -- Clean, minimal spacing inspired by modern desktop environments
            local gap = math.max(cfg.min_gap,
                math.floor(math.min(area.w, area.h) * cfg.spacing_factor))
            local margin = gap * cfg.margin_multiplier

            -- Total available space for the grid
            local grid_w = area.w - (margin * 2)
            local grid_h = area.h - (margin * 2)

            -- Calculate optimal window size considering gaps between windows
            local total_gap_w = (cols - 1) * gap
            local total_gap_h = (rows - 1) * gap
            local base_win_w = math.floor((grid_w - total_gap_w) / cols)
            local base_win_h = math.floor((grid_h - total_gap_h) / rows)

            -- Maintain reasonable aspect ratio (prefer 16:10 to 4:3 range)
            local actual_ratio = base_win_w / base_win_h

            local win_w, win_h
            if actual_ratio > cfg.max_ratio then
                -- Too wide, reduce width to maintain good proportions
                win_w = math.floor(base_win_h * cfg.target_ratio)
                win_h = base_win_h
            elseif actual_ratio < cfg.min_ratio then
                -- Too tall, reduce height
                win_w = base_win_w
                win_h = math.floor(base_win_w / cfg.target_ratio)
            else
                -- Good ratio, use calculated dimensions
                win_w = base_win_w
                win_h = base_win_h
            end

            -- Ensure minimum usable size
            win_w = math.floor(math.max(win_w, cfg.min_w))
            win_h = math.floor(math.max(win_h, cfg.min_h))

            -- Center the entire grid if windows are smaller than available space
            local actual_grid_w = cols * win_w + (cols - 1) * gap
            local actual_grid_h = rows * win_h + (rows - 1) * gap
            local grid_offset_x = math.floor((grid_w - actual_grid_w) / 2)
            local grid_offset_y = math.floor((grid_h - actual_grid_h) / 2)

            -- Arrange windows in clean, precise grid
            for i, win in ipairs(ws_windows) do
                local row = math.floor((i - 1) / cols)
                local col = (i - 1) % cols

                -- Calculate precise position with no randomization for clean look
                local win_x = math.floor(area.x + margin + grid_offset_x + col * (win_w + gap))
                local win_y = math.floor(area.y + margin + grid_offset_y + row * (win_h + gap))

                -- Float and move/resize with smooth batch operations
                table.insert(grid_commands, string.format("dispatch focuswindow address:%s", win.address))
                if not win.floating then
                    table.insert(grid_commands, string.format("dispatch togglefloat address:%s", win.address))
                end

                table.insert(grid_commands, string.format("dispatch moveactive exact %d %d", win_x, win_y))
                table.insert(grid_commands, string.format("dispatch resizeactive exact %d %d", win_w, win_h))
            end
        end
    end
    table.insert(grid_commands, string.format("dispatch focuswindow address:%s", active_window.address))
    hyprland.exec_hyprctl_batch(table.unpack(grid_commands))

    local function restore_options()
        local opt_commands = {}
        for _, opt in ipairs(orig_options) do
            local val = opt.int and opt.int
                or opt.float and opt.float
                or opt.custom and utils.fix_color_hex(opt.custom)

            table.insert(opt_commands, string.format("keyword %s %s", opt.option, val))
        end
        hyprland.exec_hyprctl_batch(table.unpack(opt_commands))
    end

    local function restore_windows(activewin_addr)
        local commands = {}
        local clients = hyprland.get_clients()
        for _, new in pairs(clients) do
            local addr = new.address
            local old = orig_windows[addr]
            if old then
                table.insert(commands, string.format("dispatch focuswindow address:%s", addr))
                if old.floating ~= new.floating then
                    table.insert(commands, string.format("dispatch togglefloat address:%s", addr))
                end
                table.insert(commands, string.format("dispatch moveactive exact %d %d", old.at[1], old.at[2]))
                table.insert(commands, string.format("dispatch resizeactive exact %d %d", old.size[1], old.size[2]))
            end
        end

        if activewin_addr then
            table.insert(commands, string.format("dispatch focuswindow address:%s", activewin_addr))
        end

        hyprland.exec_hyprctl_batch(table.unpack(commands))
    end

    local function cleanup_and_exit(activewin_addr)
        restore_options()
        restore_windows(activewin_addr)

        if listenfd then
            posix.close(listenfd)
            os.remove(socket_path)
        end
        if hyprsock then
            posix.close(hyprsock)
        end
        os.exit(0)
    end

    local interrupted = false
    local function signal_handler()
        interrupted = true
        cleanup_and_exit()
    end

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    print("Overview mode active. Waiting for focus change or toggle...")

    local done = false
    while not done and not interrupted do
        -- uncomment to exit overview mode on window focus
        --
        -- local hypr_ready = poll.rpoll(hyprsock, 50)
        -- if hypr_ready and hypr_ready > 0 then
        --     local data = posix.recv(hyprsock, 4096)
        --     for eventline in data:gmatch("[^\r\n]+") do
        --         local addr = eventline:match("^activewindowv2>>(.+)$")
        --         if addr then
        --             cleanup_and_exit("0x" .. addr)
        --             done = true
        --             break
        --         end
        --     end
        -- end

        local control_ready = poll.rpoll(listenfd, 0)
        if not done and control_ready and control_ready > 0 then
            local conn = posix.accept(listenfd)
            if conn then
                local msg = posix.recv(conn, 1024)
                posix.close(conn)
                if msg and msg:match("toggle") then
                    print("Received toggle message, exiting overview mode.")
                    cleanup_and_exit()
                    done = true
                end
            end
        end
    end

    print("Exiting overview mode.")
    cleanup_and_exit()
end
