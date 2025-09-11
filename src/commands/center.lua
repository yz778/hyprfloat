local hyprland = require("lib.hyprland")
local utils = require("lib.utils")

return function(args)
    utils.check_argcount(#args, 1, "Usage: hyprfloat center <scale>")

    local scale = tonumber(args[1])
    if not scale then
        error("Scale must be a number")
    end

    local ctx = hyprland.get_active_context()
    if not ctx then error("No active window/monitor context") end

    local min_scale = 0.25
    local win = ctx.window
    local screen = ctx.screen
    local effective_area = ctx.effective_area

    local new_w = math.floor(math.min(math.max(win.size[1] * scale, effective_area.w * min_scale), effective_area.w))
    local new_h = math.floor(math.min(math.max(win.size[2] * scale, effective_area.h * min_scale), effective_area.h))
    local new_x = screen.x + math.floor((screen.w - new_w) / 2)
    local new_y = screen.y + math.floor((screen.h - new_h) / 2)

    hyprland.exec_hyprctl_batch(
        "dispatch fullscreenstate 0",
        string.format("dispatch moveactive exact %d %d", new_x, new_y),
        string.format("dispatch resizeactive exact %d %d", new_w, new_h),
        "dispatch alterzorder top"
    )
end
