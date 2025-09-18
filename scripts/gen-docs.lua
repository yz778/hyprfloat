function get_script_root()
    local p = debug.getinfo(1, "S").source:sub(2)
    local h = io.popen("readlink -f " .. p)
    local r = h:read("*l")
    h:close()
    return r:match("(.*/)") or "./"
end

local script_dir = get_script_root()
package.path = script_dir .. "../src/?.lua;" .. script_dir .. "../src/?/init.lua;" .. package.path

local utils = require("lib.utils")
local manifest = require("lib.manifest")

local function get_commands()
    local commands = {}
    for _, name in ipairs(manifest.commands) do
        local ok, cmd = pcall(require, "commands." .. name)
        if ok and cmd.help then
            table.insert(commands, { name = name, help = cmd.help })
        else
            io.stderr:write("Error loading command: " .. name .. "\n")
        end
    end
    table.sort(commands, function(a, b) return a.name < b.name end)
    return commands
end

local function render_docs(commands)
    local out = {}
    for _, cmd in ipairs(commands) do
        table.insert(out, string.format("\n#### `%s`\n", cmd.help.usage))
        table.insert(out, "<blockquote>\n")
        table.insert(out, cmd.help.long .. "\n")
        table.insert(out, "</blockquote>\n")
    end
    return table.concat(out)
end

local function read_all(path)
    local f, err = io.open(path, "r")
    if not f then return nil, err end
    local s = f:read("*all")
    f:close()
    return s
end

local function write_all(path, content)
    local f, err = io.open(path, "w")
    if not f then return nil, err end
    f:write(content)
    f:close()
    return true
end

local function update_readme(readme_path, new_block)
    local start_marker = "<!-- GENERATED-COMMANDS-START -->"
    local end_marker   = "<!-- GENERATED-COMMANDS-END -->"

    local content, err = read_all(readme_path)
    if not content then
        return nil, ("Failed to read README: %s"):format(err)
    end

    -- Escape magic chars for patterns
    local function esc(s) return (s:gsub("(%W)", "%%%1")) end

    local pattern = esc(start_marker) .. "(.-)" .. esc(end_marker)
    local replacement = start_marker .. "\n" .. new_block .. "\n" .. end_marker

    local replaced, n = content:gsub(pattern, replacement)
    if n == 0 then
        -- Markers not present: append them at end
        replaced = content
            .. "\n\n"
            .. replacement
            .. "\n"
    end

    -- Atomic-ish write using a temp file then rename (best-effort)
    local tmp = readme_path .. ".tmp"
    local okw, werr = write_all(tmp, replaced)
    if not okw then
        return nil, ("Failed to write temp README: %s"):format(werr)
    end

    -- On POSIX, os.rename is atomic within same filesystem
    local okr, rerr = os.rename(tmp, readme_path)
    if not okr then
        -- Fallback: try direct write if rename fails
        local okw2, werr2 = write_all(readme_path, replaced)
        if not okw2 then
            return nil, ("Failed to update README: %s / %s"):format(rerr or "rename failed", werr2)
        end
    end

    return true
end

local function main()
    local cmds = get_commands()
    local block = render_docs(cmds)
    local ok, err = update_readme("README.md", block)
    if not ok then
        io.stderr:write(err .. "\n")
        os.exit(1)
    end
    print("✅ README.md updated")
end

main()
