local hyprland = require("lib.hyprland")
local utils = require("lib.utils")

return function(args)
    utils.check_args(#args ~= 1, "Usage: hyprfloat movemon [direction]")

    local direction = tonumber(args[1])
    utils.check_args(not direction, "Direction must be a number -1 or +1")

    local old = hyprland.get_active_context()
    local monitors = hyprland.get_monitors()
    local moncount = #monitors

    local nextmon = old.window.monitor + direction
    if nextmon < 0 then nextmon = moncount - 1 end
    if nextmon >= moncount then nextmon = 0 end

    utils.exec_cmd(string.format("hyprctl dispatch movewindow mon:%d", nextmon))

    local new = hyprland.get_active_context()
    if not new or new.window.monitor == old.window.monitor then
        return true
    end

    local old_effective = old.effective_area
    local new_effective = new.effective_area

    -- Calculate relative position on old effective screen
    local rel_x = (old.window.at[1] - old_effective.x) / old_effective.w
    local rel_y = (old.window.at[2] - old_effective.y) / old_effective.h

    -- Determine if window is full width/height on old screen (with some tolerance)
    local tolerance = 10
    local is_full_width = math.abs(old.window.size[1] - old_effective.w) <= tolerance
    local is_full_height = math.abs(old.window.size[2] - old_effective.h) <= tolerance

    -- Calculate proportional scaling
    local scale_w = new_effective.w / old_effective.w
    local scale_h = new_effective.h / old_effective.h
    local going_to_smaller = scale_w < 1.0 or scale_h < 1.0
    local going_to_larger = scale_w > 1.0 or scale_h > 1.0

    local new_w, new_h

    if going_to_smaller and old.window.size[1] <= new_effective.w and old.window.size[2] <= new_effective.h then
        new_w = old.window.size[1]
        new_h = old.window.size[2]
    elseif going_to_larger then
        if is_full_width then
            new_w = new_effective.w
        else
            new_w = math.floor(old.window.size[1] * scale_w)
        end

        if is_full_height then
            new_h = new_effective.h
        else
            new_h = math.floor(old.window.size[2] * scale_h)
        end
    else
        new_w = math.floor(old.window.size[1] * scale_w)
        new_h = math.floor(old.window.size[2] * scale_h)
    end

    -- Calculate new position maintaining relative position
    local new_x = new_effective.x + math.floor(rel_x * new_effective.w)
    local new_y = new_effective.y + math.floor(rel_y * new_effective.h)

    new_x, new_y, new_w, new_h = hyprland.clamp_window_to_area(new_x, new_y, new_w, new_h, new_effective)

    hyprland.exec_hyprctl_batch(
        "dispatch fullscreenstate 0",
        string.format("dispatch moveactive exact %d %d", new_x, new_y),
        string.format("dispatch resizeactive exact %d %d", new_w, new_h),
        "dispatch alterzorder top"
    )
end
