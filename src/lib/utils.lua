local cjson = require("cjson")
local posix = require("posix")
local config = require("lib.config")

local utils = {}
local log_file_path = "/tmp/hyprfloat/debug.log"

function utils.deep_merge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k]) == "table" then
            utils.deep_merge(t1[k], v)
        else
            t1[k] = v
        end
    end
    return t1
end

function utils.exec_cmd(cmd)
    utils.debug("[execute] " .. cmd)

    local handle = io.popen(cmd)
    local result = handle and handle:read("*a") or ""
    if handle then handle:close() end

    utils.debug("[result ] " .. result)

    return result
end

function utils.get_cmd_json(command)
    local output = utils.exec_cmd(command)
    if output == "" then return {} end
    return cjson.decode(output)
end

function utils.fix_color_hex(input)
    -- hyprctl getoption returns colors in legacy format without the leading 0x
    -- but hyprctl keyword doesn't accept that, so we have it back
    return type(input) == "string" and input:gsub('%f[%w](%x%x%x%x%x%x%x%x)%f[%W]', '0x%1') or input
end

function utils.check_args(wrong_args, usage)
    if wrong_args then
        print(usage)
        os.exit(1)
    end
end

function utils.stringify(o, indent)
    indent = indent or 2
    local typ = type(o)
    local str = '(' .. typ .. '):'
    if typ == 'table' then
        str = str .. '{\n'
        for k, v in pairs(o) do
            str = str .. string.rep('  ', indent) .. k .. ' = ' .. utils.stringify(v, indent + 2) .. ',\n'
        end
        str = str .. string.rep('  ', indent - 2) .. '}'
    else
        str = str .. tostring(o)
    end

    return str
end

function utils.dump(o)
    print(utils.stringify(o))
    os.exit(1)
end

function utils.parallel_map(items, func, max_concurrent)
    local results = {}
    local running = 0
    local index = 1
    local itemcount = #items

    local function process_next()
        if index > itemcount then return end

        local current_index = index
        index = index + 1
        running = running + 1

        local success, result = pcall(func, items[current_index])
        if success then
            results[current_index] = result
        else
            results[current_index] = nil
        end

        running = running - 1
        process_next()
    end

    -- Start initial batch of concurrent processes
    for _ = 1, math.min(max_concurrent, itemcount) do
        process_next()
    end

    -- Wait for all processes to complete
    while running > 0 do
        posix.sleep(0.01)
    end

    return results
end

function utils.debug(message)
    if not config.debug then return nil end

    local file = io.open(log_file_path, "a")
    if file then
        file:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), message))
        file:close()
    end
end

return utils
