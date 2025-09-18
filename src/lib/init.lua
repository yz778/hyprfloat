local lib = {}

local function print_help()
    print("Usage: hyprfloat <command> [args...]\n")
    print("  alttab <next|prev> [sameclass]")
    print("  center <scale>")
    print("  events")
    print("  install-config")
    print("  movemon <direction>")
    print("  overview")
    print("  snap <x0> <x1> <y0> <y1>")
    print("  togglefloat <mode>")
    print("  version")
    print("  workspacegroup <next|prev|status|move>")
end

function lib.run(args)
    if #args < 1 then
        print_help()
        os.exit(1)
    end

    local utils = require('lib.utils')
    local command = table.remove(args, 1)

    local ok, handler_or_error = pcall(require, "commands." .. command)
    if not ok then
        utils.debug(handler_or_error)
        if string.match(handler_or_error, "module 'commands%." .. command .. "' not found") then
            print("Invalid command: " .. command)
        else
            print(handler_or_error)
        end
        os.exit(1)
    end

    utils.debug(string.format("Run: %s %s", command, table.concat(args, " ")))
    handler_or_error(args)
end

return lib
