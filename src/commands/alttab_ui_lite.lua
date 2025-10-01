local lgi = require('lgi')
local Gtk = lgi.require('Gtk', '3.0')
local Gdk = lgi.require('Gdk', '3.0')
local GLib = lgi.GLib
local bit32 = require('bit32')
local config = require('lib.config')
local utils = require('lib.utils')
local hyprland = require('lib.hyprland')

local alttab_ui = {}

local function altkey_down()
    return bit32.band(Gdk.Keymap.get_default():get_modifier_state(), Gdk.ModifierType.MOD1_MASK) ~= 0
end

function alttab_ui.launch(params)
    local shared = params.shared
    local clients = params.clients
    local cfg = config.alttab

    local app = Gtk.Application({ application_id = 'hyprfloat.alttab' })

    local all_widgets = {}      -- Flat list of client widgets for easy cycling
    local widget_to_client = {} -- Map from widget back to client object
    local current_idx = 1

    function app:on_activate()
        local window = Gtk.ApplicationWindow {
            application = app,
            title = "hyprfloat:alttab"
        }
        window:set_name("alttab-window")
        window:set_decorated(false)

        -- Create a map of monitor IDs to names
        local monitors = hyprland.get_monitors()
        local monitor_map = {}
        for _, mon in ipairs(monitors) do
            monitor_map[mon.id] = mon.name
        end

        local outer_box = Gtk.Box {
            orientation = Gtk.Orientation.VERTICAL,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            spacing = 5
        }
        outer_box:set_name("alttab-outer")
        window:add(outer_box)

        local list_box = Gtk.Box({ orientation = Gtk.Orientation.VERTICAL, spacing = 2 })
        outer_box:pack_start(list_box, true, true, 0)

        -- Add text entry box at the top
        local text_entry = Gtk.Entry()
        text_entry:set_name("alttab-entry")
        text_entry:set_placeholder_text("Filter...")
        outer_box:pack_start(text_entry, false, false, 0)

        local list_box = Gtk.Box({ orientation = Gtk.Orientation.VERTICAL, spacing = 2 })
        outer_box:pack_start(list_box, true, true, 0)

        local active_clients = {}
        for _, client in ipairs(clients) do
            if client.workspace.id > 0 then -- Filter out special workspaces
                table.insert(active_clients, client)
            end
        end

        for _, client in ipairs(active_clients) do
            local mon_name = monitor_map[client.monitor] or "?"

            local grid = Gtk.Grid()
            grid:set_name("client-row")
            grid:set_column_spacing(30)

            local app_label = Gtk.Label({ label = client.class .. ": " .. client.title, xalign = 0 })
            app_label:set_halign(Gtk.Align.START)

            local mon_label = Gtk.Label({ label = "[" .. mon_name .. "]", xalign = 1 })
            mon_label:set_halign(Gtk.Align.END)

            grid:attach(app_label, 0, 0, 1, 1)
            grid:attach(mon_label, 1, 0, 1, 1)
            grid:set_hexpand(true)
            app_label:set_hexpand(true)

            list_box:pack_start(grid, false, false, 0)
            table.insert(all_widgets, grid)
            widget_to_client[grid] = client
        end

        local function update_selection()
            if #all_widgets == 0 then
                shared.selected_address = nil
                return
            end
            for i, widget in ipairs(all_widgets) do
                if i == current_idx then
                    widget:get_style_context():add_class("selected")
                    shared.selected_address = widget_to_client[widget].address
                else
                    widget:get_style_context():remove_class("selected")
                end
            end
        end

        local function move_next()
            if #all_widgets == 0 then return end
            current_idx = current_idx + 1
            if current_idx > #all_widgets then current_idx = 1 end
            update_selection()
        end

        local function move_prev()
            if #all_widgets == 0 then return end
            current_idx = current_idx - 1
            if current_idx < 1 then current_idx = #all_widgets end
            update_selection()
        end

        function window:on_key_press_event(event)
            local keyval = event.keyval
            local handled = true
            if keyval == Gdk.KEY_Escape then
                app:quit()
            elseif keyval == Gdk.KEY_Return then
                shared.activate()
                app:quit()
            elseif keyval == Gdk.KEY_Tab or keyval == Gdk.KEY_Down or keyval == Gdk.KEY_Right or keyval == Gdk.KEY_grave then
                move_next()
            elseif keyval == Gdk.KEY_ISO_Left_Tab or keyval == Gdk.KEY_Up or keyval == Gdk.KEY_Left then
                move_prev()
            else
                handled = false
            end
            return handled
        end

        -- Apply some styling
        local css_provider = Gtk.CssProvider()
        css_provider:load_from_data([[
            #alttab-window {
                background-color: rgba(40, 40, 40, 0.9);
                border-radius: 8px;
                border: 1px solid rgba(100, 100, 100, 0.8);
            }
            #alttab-outer {
                padding: 10px;
                min-width: 300px;
            }
            #client-row {
                padding: 2px 5px;
                border-radius: 4px;
            }
            #client-row.selected {
                background-color: #4A90E2;
            }
            #client-row.selected label {
                color: white;
            }
        ]])
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Display.get_default():get_default_screen(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        -- Set initial selection and show
        if #all_widgets > 0 then
            update_selection()
        else
            -- No windows, show a message and quit soon
            local label = Gtk.Label({ label = "No windows open" })
            outer_box:pack_start(label, true, true, 0)
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, function()
                app:quit()
                return false
            end)
        end

        window:show_all()
        window:grab_focus()

        -- Monitor for Alt key release to activate window
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, cfg.altkey_wait_ms or 100, function()
            if altkey_down() then
                return true -- Continue monitoring
            end
            utils.debug("ALT Key released")
            app:quit()
            if shared.selected_address then
                shared.activate()
            end
            return false -- Stop timer
        end)
    end

    local success, err = pcall(function()
        app:run(nil)
    end)
    if not success then
        utils.debug("Error running alttab_ui: " .. tostring(err))
    end
end

return alttab_ui
