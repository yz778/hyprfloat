local lib = {}

local function print_help()
    print("Usage: hyprfloat <command> [args...]\n")
    print("Commands:\n")
    print("  alttab <next|prev> [sameclass]     - Switches between windows.")
    print("  center <scale>                     - Centers the active window and optionally scales it.")
    print("  events                             - (Debugging) Prints all Hyprland events.")
    print("  movemon <direction>                - Moves the active window to another monitor.")
    print("  overview                           - Shows the workspace overview.")
    print("  snap <x0> <x1> <y0> <y1>           - Snaps the active window to a fractional portion of the screen.")
    print("  togglefloat [mode]                 - Toggles floating mode for all windows.")
    print("  version                            - Prints the version of hyprfloat.")
end

function lib.run(args)
    if #args < 1 then
        print_help()
        os.exit(1)
    end

    local posix = require("posix")
    local utils = require('lib.utils')
    local command = table.remove(args, 1)

    local ok, handler_or_error = pcall(require, "commands." .. command)
    if not ok then
        utils.debug(handler_or_error)
        print("Invalid command: " .. command)
        os.exit(1)
    end

    utils.debug(string.format("Run: %s %s", command, table.concat(args, " ")))
    posix.mkdir("/tmp/hyprfloat")
    handler_or_error(args)
end

return lib
