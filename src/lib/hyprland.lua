local cjson = require("cjson")
local posix = require("posix")
local xdg_runtime_dir = os.getenv("XDG_RUNTIME_DIR")
local hyprland_sig = os.getenv("HYPRLAND_INSTANCE_SIGNATURE")

local hyprland = {}

function hyprland.get_hyprsocket(sockname)
    local sock_path = string.format("%s/hypr/%s/.%s.sock", xdg_runtime_dir, hyprland_sig, sockname)

    local sock = posix.socket(posix.AF_UNIX, posix.SOCK_STREAM, 0)
    if not sock then
        error("Failed to create socket")
    end

    local addr = { family = posix.AF_UNIX, path = sock_path }
    local ok, err = posix.connect(sock, addr)
    if not ok then
        posix.close(sock)
        error("Failed to connect to socket: " .. (err or "unknown error"))
    end

    return sock
end

function hyprland.hyprctl(command)
    local sock = hyprland.get_hyprsocket('socket')

    -- Send command
    local ok, err = posix.send(sock, command)
    if not ok then
        posix.close(sock)
        error("Failed to send command: " .. (err or "unknown error"))
    end

    -- Read response
    local response = ""
    while true do
        local data, _ = posix.recv(sock, 4096)
        if not data or data == "" then
            break
        end
        response = response .. data
    end

    posix.close(sock)
    return response
end

function hyprland.hyprctl_json(command)
    local json_command = "-j/" .. command
    local response = hyprland.hyprctl(json_command)
    return cjson.decode(response)
end

function hyprland.hyprctl_batch(...)
    local commands = table.concat({ ... }, ";")
    local batch_command = "[[BATCH]] " .. commands
    hyprland.hyprctl(batch_command)
end

function hyprland.get_activewindow()
    return hyprland.hyprctl_json("activewindow")
end

function hyprland.get_activeworkspace()
    return hyprland.hyprctl_json("activeworkspace")
end

function hyprland.get_monitors()
    return hyprland.hyprctl_json("monitors")
end

function hyprland.get_clients()
    return hyprland.hyprctl_json("clients")
end

function hyprland.get_workspaces()
    return hyprland.hyprctl_json("workspaces")
end

function hyprland.parse_gaps(gaps_str)
    if not gaps_str then return { top = 0, right = 0, bottom = 0, left = 0 } end

    local values = {}
    for value in gaps_str:gmatch("%S+") do
        table.insert(values, tonumber(value) or 0)
    end

    local count = #values
    return count == 1 and { top = values[1], right = values[1], bottom = values[1], left = values[1] }
        or count == 2 and { top = values[1], right = values[2], bottom = values[1], left = values[2] }
        or count == 4 and { top = values[1], right = values[2], bottom = values[3], left = values[4] }
        or { top = 0, right = 0, bottom = 0, left = 0 }
end

function hyprland.get_border_gap_config()
    local config = {
        border_size = 0,
        gaps_in = { top = 0, right = 0, bottom = 0, left = 0 },
        gaps_out = { top = 0, right = 0, bottom = 0, left = 0 }
    }

    local border_data = hyprland.hyprctl_json("getoption general:border_size")
    config.border_size = border_data.int or 0

    local gaps_in_data = hyprland.hyprctl_json("getoption general:gaps_in")
    if gaps_in_data.custom then
        config.gaps_in = hyprland.parse_gaps(gaps_in_data.custom)
    elseif gaps_in_data.int then
        local val = gaps_in_data.int
        config.gaps_in = { top = val, right = val, bottom = val, left = val }
    end

    local gaps_out_data = hyprland.hyprctl_json("getoption general:gaps_out")
    if gaps_out_data.custom then
        config.gaps_out = hyprland.parse_gaps(gaps_out_data.custom)
    elseif gaps_out_data.int then
        local val = gaps_out_data.int
        config.gaps_out = { top = val, right = val, bottom = val, left = val }
    end

    return config
end

function hyprland.calculate_effective_area(monitor, border_gap)
    local screen_x = monitor.x + monitor.reserved[3]
    local screen_y = monitor.y + monitor.reserved[2]
    local screen_w = monitor.width - monitor.reserved[3] - monitor.reserved[4]
    local screen_h = monitor.height - monitor.reserved[1] - monitor.reserved[2]

    local left_gap = border_gap.gaps_out.left + border_gap.gaps_in.left
    local right_gap = border_gap.gaps_out.right + border_gap.gaps_in.right
    local top_gap = border_gap.gaps_out.top + border_gap.gaps_in.top
    local bottom_gap = border_gap.gaps_out.bottom + border_gap.gaps_in.bottom
    local border_adjustment = border_gap.border_size * 2

    return {
        x = screen_x + left_gap + border_gap.border_size,
        y = screen_y + top_gap + border_gap.border_size,
        w = screen_w - left_gap - right_gap - border_adjustment,
        h = screen_h - top_gap - bottom_gap - border_adjustment,
        screen = { x = screen_x, y = screen_y, w = screen_w, h = screen_h }
    }
end

function hyprland.clamp_window_to_area(win_x, win_y, win_w, win_h, effective_area)
    local new_w = math.min(win_w, effective_area.w)
    local new_h = math.min(win_h, effective_area.h)
    local new_x = math.max(effective_area.x, math.min(win_x, effective_area.x + effective_area.w - new_w))
    local new_y = math.max(effective_area.y, math.min(win_y, effective_area.y + effective_area.h - new_h))

    return new_x, new_y, new_w, new_h
end

function hyprland.get_active_context()
    local activewindow = hyprland.get_activewindow()
    if not activewindow then return nil end

    local monitors = hyprland.get_monitors()

    local monitor
    for _, m in ipairs(monitors) do
        if m.id == activewindow.monitor then
            monitor = m
            break
        end
    end
    if not monitor then return nil end

    local border_gap = hyprland.get_border_gap_config()
    local effective_area = hyprland.calculate_effective_area(monitor, border_gap)

    return {
        window = activewindow,
        screen = effective_area.screen,
        effective_area = effective_area,
        border_gap = border_gap
    }
end

function hyprland.has_floating(windows)
    for _, win in ipairs(windows) do
        if win.floating then
            return true
        end
    end
    return false
end

return hyprland
