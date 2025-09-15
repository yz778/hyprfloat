local hyprland = require("lib.hyprland")
local event_loop = require("lib.event_loop")
local posix = require("posix")

return function(args)
    local hyprsock = hyprland.get_hyprsocket('socket2')
    local loop = event_loop.create()

    print("\nListening for Hyprland events, press CTRL-C to exit...\n")
    local event_count = 0

    event_loop.add_source(loop, hyprsock, function(fd)
        local data, err = posix.recv(fd, 4096)

        if not data then
            if err then
                print("Error reading from socket: " .. err)
            end
            return false
        end

        for line in data:gmatch("[^\r\n]+") do
            event_count = event_count + 1
            print(string.format("%d: %s", event_count, line))
        end

        return true
    end)

    event_loop.set_cleanup(loop, function()
        print("\nExiting")
        posix.close(hyprsock)
    end)

    event_loop.run(loop)
end
