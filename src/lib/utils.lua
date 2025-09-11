-- Common utility functions
local cjson = require("cjson")
local config = require("lib.config")

local utils = {}

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
    if config.debug then print("---------\n[execute] " .. cmd) end

    local handle = io.popen(cmd)
    local result = handle and handle:read("*a") or ""
    if handle then handle:close() end

    if config.debug then print("[result ] " .. result) end

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

function utils.check_argcount(argcount, required, usage)
    if argcount ~= required then
        print(usage)
        os.exit(1)
    end
end

function utils.dump(obj)
    print(cjson.encode(obj))
    os.exit(0)
end

return utils
