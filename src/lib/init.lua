local lib = {}

local function print_help()
    print("Usage: hyprfloat <command> [args...]\n")
    print("Commands:\n")
    print("  center [scale]            - Center active window with scaling")
    print("  events                    - Listen to Hyprland socket events (for debugging)")
    print("  movemon [direction]       - Move active window to next monitor")
    print("  overview                  - GNOME-style overview mode")
    print("  snap [x0] [x1] [y0] [y1]  - Snap window to screen fraction")
    print("  togglefloat (mode)        - Toggle floating mode for all windows (on|off|auto)")
    print("  version                   - Print version number")
end

function lib.run(args)
    if #args < 1 then
        print_help()
        os.exit(1)
    end

    local command = table.remove(args, 1)
    local handler = require("commands." .. command)

    if not handler then
        print("Unknown command: " .. command)
        print_help()
        os.exit(1)
    end

    handler(args)
end

return lib
