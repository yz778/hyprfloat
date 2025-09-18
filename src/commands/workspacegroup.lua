return {
    run = function(args)
        local hyprland = require("lib.hyprland")
        local utils = require("lib.utils")
        local config = require("lib.config")

        local cfg = config.workspacegroup

        local function find_group(groups, workspaceid)
            for i, group in ipairs(groups) do
                for _, v in ipairs(group) do
                    if v == workspaceid then
                        return i
                    end
                end
            end

            return nil
        end

        local function find_workspace(workspaceid, nextgroup, groups)
            -- Find current group and position of my_workspace
            for _, group in ipairs(groups) do
                for i, ws in ipairs(group) do
                    if ws == workspaceid then
                        -- Found position i in current group
                        local next_group = groups[nextgroup]
                        if next_group then
                            return next_group[i]
                        else
                            return nil -- nextgroup invalid
                        end
                    end
                end
            end
            return nil -- my_workspace not found
        end

        local function switch_group(nextgroup, monitor)
            -- switch all workspaces
            local commands = {}
            for _, wsid in ipairs(cfg.groups[nextgroup]) do
                table.insert(commands, "dispatch workspace " .. wsid)
            end
            table.insert(commands, "dispatch focusmonitor " .. monitor)
            hyprland.hyprctl_batch(table.unpack(commands))

            -- run custom commands
            for _, cmd in ipairs(cfg.commands) do
                utils.exec_cmd(cmd)
            end
        end

        local function move_client(client, nextgroup)
            switch_group(nextgroup, client.monitor)
            local next_workspace = find_workspace(client.workspace.id, nextgroup, cfg.groups)
            hyprland.hyprctl(string.format('dispatch movetoworkspace %d, address:%s', next_workspace, client.address))
        end

        local function select_workspaceset_group()
            local lgi = require('lgi')
            local Gtk = lgi.require('Gtk', '3.0')
            local Gdk = lgi.require('Gdk', '3.0')
            local utf8 = require("utf8")

            local client = hyprland.get_activewindow()
            local app = Gtk.Application({ application_id = 'hyprfloat.alttab' })
            local group = find_group(cfg.groups, client.workspace.id)

            function app:on_activate()
                local window = Gtk.ApplicationWindow {
                    application = app,
                    title = "hyprfloat:workspacegroup"
                }

                local vbox = Gtk.Box {
                    orientation = 'VERTICAL',
                    spacing = 6,
                    margin = 10,
                }

                -- label
                local label = Gtk.Label { label = string.format("Move [%s] %s to:", client.class, client.title) }
                label:set_halign(Gtk.Align.CENTER)
                vbox:pack_start(label, false, false, 0)

                -- group options
                local listbox = Gtk.ListBox {}
                local rows = {}
                for i, _ in ipairs(cfg.groups) do
                    local option = "🖥️ Group "
                        .. i
                        .. (i == group and " (Current)" or "")


                    local row_label = Gtk.Label { label = option, xalign = 0 }
                    local row = Gtk.ListBoxRow {}
                    row:add(row_label)
                    rows[i] = row
                    listbox:add(row)
                end
                listbox:select_row(rows[group])
                vbox:pack_start(listbox, false, false, 0)

                window:add(vbox)

                window.on_key_press_event = function(_, event)
                    local keyval = event.keyval
                    local nextgroup = nil

                    if keyval == Gdk.KEY_Escape then
                        app:quit()
                        return true
                    elseif keyval == Gdk.KEY_Return then
                        local row = listbox:get_selected_row()
                        nextgroup = row:get_index() + 1
                    else
                        nextgroup = tonumber(utf8.char(keyval))
                    end

                    print(nextgroup)
                    if nextgroup and nextgroup >= 1 and nextgroup <= #rows then
                        listbox:select_row(rows[nextgroup])
                        move_client(client, nextgroup)
                        app:quit()
                        return true
                    end
                end

                window:show_all()
            end

            app:run(nil)
        end

        utils.check_args(#args < 1, "Usage: hyprfloat workspaceset <next|prev|status|group|move>")
        local action = args[1]
        local valid = { next = true, prev = true, status = true, group = true, move = true }
        utils.check_args(not valid[action], "Invalid first argument")

        local active_workspace = hyprland.get_activeworkspace()

        local groupcount = #cfg.groups
        local group = find_group(cfg.groups, active_workspace.id)
        if not group then
            local err = string.format("Workspace %d not found in config.workspacegroup.groups", active_workspace.id)
            utils.debug(err)
            print(err)
            os.exit(1)
        end

        if action == "status" then
            local workspaces = hyprland.get_workspaces()
            local str = ""
            for i, g in ipairs(cfg.groups) do
                if group == i then
                    str = str .. cfg.icons.active
                else
                    local has_windows = false
                    for _, ws in ipairs(g) do
                        if workspaces[ws].windows > 0 then
                            has_windows = true
                            break
                        end
                    end

                    str = str .. (has_windows and cfg.icons.occupied or cfg.icons.default)
                end
            end
            print(str)
        elseif action == "group" then
            local nextgroup = tonumber(args[2])
            utils.check_args(not nextgroup, "Invalid group number")
            if group ~= nextgroup then
                switch_group(nextgroup, active_workspace.monitor)
            end
        elseif action == "move" then
            select_workspaceset_group()
        else
            local nextgroup = group + (action == "next" and 1 or -1)
            nextgroup = nextgroup > groupcount and groupcount
                or nextgroup < 1 and 1
                or nextgroup

            if group ~= nextgroup then
                switch_group(nextgroup, active_workspace.monitor)
            end
        end
    end,
    help = {
        short = "Manages and cycles through groups of workspaces.",
        usage = "workspacegroup <next|prev|status|group|move>",
        long = [[
Manages groups of workspaces, useful for multi-monitor setups.

**Arguments:**
- `<next|prev>` Switches to the next or previous workspace group.
- `<status>` Prints the status of workspace groups, useful for status bars.
- `<group>` Switches to a specific workspace group by number.
- `<move>` Presents a UI to move the active window to a different workspace group.
]]
    }
}
