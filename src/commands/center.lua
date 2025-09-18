return {
    run = function(args)
        local hyprland = require("lib.hyprland")
        local utils = require("lib.utils")

        utils.check_args(#args ~= 1, "Usage: hyprfloat center <scale>")

        local scale = tonumber(args[1])
        utils.check_args(not scale, "Scale must be a number")

        local ctx = hyprland.get_active_context()
        utils.check_args(not ctx, "No active window/monitor context")

        local min_scale = 0.25
        local win = ctx.window
        local screen = ctx.screen
        local effective_area = ctx.effective_area

        local new_w = math.floor(math.min(math.max(win.size[1] * scale, effective_area.w * min_scale), effective_area.w))
        local new_h = math.floor(math.min(math.max(win.size[2] * scale, effective_area.h * min_scale), effective_area.h))
        local new_x = screen.x + math.floor((screen.w - new_w) / 2)
        local new_y = screen.y + math.floor((screen.h - new_h) / 2)

        hyprland.hyprctl_batch(
            "dispatch fullscreenstate 0",
            string.format("dispatch moveactive exact %d %d", new_x, new_y),
            string.format("dispatch resizeactive exact %d %d", new_w, new_h),
            "dispatch alterzorder top"
        )
    end,
    help = {
        short = "Centers the active window.",
        usage = "center <scale>",
        long = [[
Centers the active window in the middle of the screen and applies a scaling factor.

**Arguments:**
- `<scale>` Required. A number to scale the window size (e.g., 1.0 for original size, 1.2 to enlarge, 0.8 to shrink).
]]
    }
}
