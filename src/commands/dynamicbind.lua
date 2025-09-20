return {
    run = function(args)
        local hyprland = require("lib.hyprland")
        local config = require("lib.config")
        local utils = require("lib.utils")
        local cfg = config.dynamic_bind

        utils.check_args(#args ~= 1, "Usage: hyprfloat dynamic_bind <command>")

        local win = hyprland.get_activewindow()
        utils.check_args(not win, "No active window")

        local mode = win.floating and "floating" or "tiling"
        local bind = args[1]
        local cmd = cfg[mode][bind]
        if cmd then
            utils.debug(cmd)
            hyprland.hyprctl(cmd)
        end
    end,
    help = {
        short = "Run different command based on floating status of window.",
        usage = "hyprfloat dynamicbind <binding>",
        long = [[
Runs a command as defined in `dynamic_bind` configuration, choosing the appropriate one for the current window mode (floating or tiling).

**Arguments:**
- `<binding>` (required): The binding name as defined in your `dynamic_bind` configuration.
]]
    }
}
