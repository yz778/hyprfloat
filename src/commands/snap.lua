return {
    run = function(args)
        local hyprland = require("lib.hyprland")
        local utils = require("lib.utils")

        utils.check_args(#args ~= 4, "Usage: hyprfloat snap <x0_frac> <x1_frac> <y0_frac> <y1_frac>")

        local x0_frac = tonumber(args[1])
        local x1_frac = tonumber(args[2])
        local y0_frac = tonumber(args[3])
        local y1_frac = tonumber(args[4])

        utils.check_args(not (x0_frac and x1_frac and y0_frac and y1_frac), "All arguments must be numbers")

        local ctx = hyprland.get_active_context()
        utils.check_args(not ctx, "No active window/monitor context")

        if not ctx.window.floating then
            utils.debug("Ignoring snap for tiling window")
            return
        end

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
    end,
    help = {
        short = "Snaps the active window to a fraction of the screen.",
        usage = "snap <x0> <x1> <y0> <y1>",
        long = [[
Snaps the active window to a fractional portion of the screen.

**Arguments:**
- `<x0>` Required. Left position as a fraction of screen width (e.g., 0.0).
- `<x1>` Required. Right position as a fraction of screen width (e.g., 0.5 for half width).
- `<y0>` Required. Top position as a fraction of screen height (e.g., 0.0).
- `<y1>` Required. Bottom position as a fraction of screen height (e.g., 1.0 for full height).
]]
    }
}
