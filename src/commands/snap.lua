local hyprland = require("lib.hyprland")
local utils = require("lib.utils")

return function(args)
    utils.check_args(#args ~= 4, "Usage: hyprfloat snap <x0_frac> <x1_frac> <y0_frac> <y1_frac>")

    local x0_frac = tonumber(args[1])
    local x1_frac = tonumber(args[2])
    local y0_frac = tonumber(args[3])
    local y1_frac = tonumber(args[4])

    utils.check_args(not (x0_frac and x1_frac and y0_frac and y1_frac), "All arguments must be numbers")

    local ctx = hyprland.get_active_context()
    utils.check_args(not ctx, "No active window/monitor context")

    local effective_area = ctx.effective_area

    local new_x = effective_area.x + math.floor(effective_area.w * x0_frac)
    local new_y = effective_area.y + math.floor(effective_area.h * y0_frac)
    local new_w = math.floor(effective_area.w * (x1_frac - x0_frac))
    local new_h = math.floor(effective_area.h * (y1_frac - y0_frac))

    hyprland.hyprctl_batch(
        "dispatch fullscreenstate 0",
        string.format("dispatch moveactive exact %d %d", new_x, new_y),
        string.format("dispatch resizeactive exact %d %d", new_w, new_h),
        "dispatch alterzorder top"
    )
end
