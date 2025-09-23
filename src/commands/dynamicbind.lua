local hyprland = require("lib.hyprland")
local utils = require("lib.utils")

local function run_cmd(cmd)
    utils.debug(cmd)

    local delim1_start, delim1_end = string.find(cmd, ":")
    if not delim1_start then
        hyprland.hyprctl(cmd)
    else
        local cmdline = string.sub(cmd, delim1_end + 1)
        local delimc1_start, delimc1_end = string.find(cmdline, " ")
        local command_name = ""
        local args = {}
        if not delim1_start then
            command_name = cmdline
        else
            command_name = string.sub(cmdline, 1, delimc1_start - 1)
            args = utils.explode("%S+", string.sub(cmdline, delimc1_end + 1))
        end

        local ok, command = pcall(require, "commands." .. command_name)
        command.run(args)
    end
end

return {
    run = function(args)
        local config = require("lib.config")
        local cfg = config.dynamic_bind

        utils.check_args(#args ~= 1, "Usage: hyprfloat dynamic_bind <command>")

        local win = hyprland.get_activewindow()
        utils.check_args(not win, "No active window")

        local bind = args[1]
        local mode = utils.file_exists(utils.runtime_path("/overview.sock")) and "overview"
            or win.floating and "floating"
            or "tiling"
        local cmd = cfg[mode][bind]

        if cmd then
            run_cmd(cmd)
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
