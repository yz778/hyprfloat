-- Generic event loop module with signal handling
local signal = require("posix.signal")
local poll = require("posix.poll")

local event_loop = {}

function event_loop.create()
    local loop = {
        sources = {},
        cleanup_fn = nil,
        interrupted = false
    }

    -- Set up signal handlers
    local function signal_handler(signum)
        loop.interrupted = true
    end

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    return loop
end

function event_loop.add_source(loop, fd, callback)
    table.insert(loop.sources, {
        fd = fd,
        callback = callback
    })
end

function event_loop.set_cleanup(loop, cleanup_fn)
    loop.cleanup_fn = cleanup_fn
end

function event_loop.run(loop, timeout_ms)
    timeout_ms = timeout_ms or 50

    while not loop.interrupted do
        for _, source in ipairs(loop.sources) do
            local ready = poll.rpoll(source.fd, timeout_ms)
            if ready and ready > 0 then
                local should_continue = source.callback(source.fd)
                if should_continue == false then
                    loop.interrupted = true
                    break
                end
            end
        end
    end

    if loop.cleanup_fn then
        loop.cleanup_fn()
    end
end

return event_loop
