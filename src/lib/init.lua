local lib = {}
local manifest = require("lib.manifest")

local function print_help()
    print("Usage: hyprfloat <command> [args...]")
    print("\nCommands:\n")

    local commands = {}
    for _, name in ipairs(manifest.commands) do
        local ok, cmd = pcall(require, "commands." .. name)
        if ok and cmd.help then
            table.insert(commands, { name = name, help = cmd.help })
        end
    end

    table.sort(commands, function(a, b) return a.name < b.name end)

    for _, cmd in ipairs(commands) do
        print(string.format("  %s\n  - %s\n", cmd.help.usage, cmd.help.short))
    end
end

function lib.run(args)
    if #args < 1 then
        print_help()
        return
    end

    local utils = require('lib.utils')
    local command_name = table.remove(args, 1)

    if command_name == "--help" then
        print_help()
        return
    end

    local command_found = false
    for _, name in ipairs(manifest.commands) do
        local ok, _ = pcall(require, "commands." .. name)
        if ok then
            command_found = true
            break
        end
    end

    if not command_found then
        print("Invalid command: " .. command_name)
        return
    end

    local ok, command = pcall(require, "commands." .. command_name)

    if not ok then
        utils.debug(command)
        if string.match(command, "module 'commands%." .. command_name .. "' not found") then
            print("Invalid command: " .. command_name)
        else
            print(command)
        end
        os.exit(1)
    end

    if #args > 0 and args[1] == "--help" then
        print(command.help.long)
        return
    end

    utils.debug(string.format("Run: %s %s", command_name, table.concat(args, " ")))
    command.run(args)
end

return lib
