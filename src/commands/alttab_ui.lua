local bit32 = require('bit32')
local posix = require("posix")
local lgi = require('lgi')
local Gtk = lgi.require('Gtk', '3.0')
local Gdk = lgi.require('Gdk', '3.0')
local GdkPixbuf = lgi.require('GdkPixbuf', '2.0')
local GLib = lgi.GLib
local config = require('lib.config')
local hyprland = require('lib.hyprland')
local utils = require('lib.utils')

local alt_release_timer = nil
local alttab_ui = {}
local search_entry = nil
local search_mode = false
local shared = {}
local tiles = {}
local prev_tile = 0
local curr_tile = 1
local all_clients = {}     -- Array of all client records and metadata
local visible_clients = {} -- Array of indices into all_clients

local function altkey_down()
    return bit32.band(Gdk.Keymap.get_default():get_modifier_state(), Gdk.ModifierType.MOD1_MASK) ~= 0
end

local function cleanup()
    utils.debug("Cleaning up")
    hyprland.hyprctl("dispatch submap reset")
end

function alttab_ui.launch(params)
    shared = params.shared
    local clients = params.clients

    -- Initialize client data
    all_clients = {}
    for i, client in ipairs(clients) do
        all_clients[i] = {
            client = client,
            image_data = nil,
            normal_pixbuf = nil,
            selected_pixbuf = nil,
        }
    end

    -- Initially all clients are visible (use filter_clients to ensure consistency)
    local cfg = config.alttab
    local app = Gtk.Application({ application_id = 'hyprfloat.alttab' })

    -- UI elements that need to be accessible by timer functions
    local grid, label1, label2, window, outer, scrolled_window
    local css_provider, display, monitor, max_cols, cols, rows, window_w, window_h
    local visible_rows = nil

    function app:on_shutdown()
        cleanup()
    end

    local function filter_clients(query)
        visible_clients = {}

        if not query then
            -- No filter - all clients are visible
            for i = 1, #all_clients do
                table.insert(visible_clients, i)
            end
        else
            -- Filter by query
            local query_lower = query:lower()
            for index, client_record in ipairs(all_clients) do
                local client = client_record.client
                local class_lower = client.class:lower()
                local title_lower = client.title:lower()

                if class_lower:find(query_lower, 1, true) or title_lower:find(query_lower, 1, true) then
                    table.insert(visible_clients, index)
                end
            end
        end

        utils.debug("Filtered to " .. #visible_clients .. " visible clients")
    end

    local function ensure_tile_visible(tile_index)
        if not scrolled_window then return end

        local row = math.ceil(tile_index / cols) - 1 -- 0-indexed row
        local tile_top = row * cfg.tile_container_size
        local tile_bottom = tile_top + cfg.tile_container_size

        local vadj = scrolled_window:get_vadjustment()
        if not vadj then return end

        local visible_top = vadj:get_value()
        local visible_bottom = visible_top + vadj:get_page_size()

        if tile_top < visible_top then
            vadj:set_value(tile_top)
        elseif tile_bottom > visible_bottom then
            vadj:set_value(tile_bottom - vadj:get_page_size())
        end
    end

    local function update_tile_display()
        if prev_tile > 0 then
            local prev_client_record = all_clients[visible_clients[prev_tile]]
            local prev_tile_obj = tiles[prev_tile]
            if prev_client_record.normal_pixbuf then
                prev_tile_obj.image:set_from_pixbuf(prev_client_record.normal_pixbuf)
            end
            prev_tile_obj.eventbox:get_style_context():remove_class("selected")
        end

        if #tiles > 0 then
            local curr_client_record = all_clients[visible_clients[curr_tile]]
            local curr_tile_obj = tiles[curr_tile]
            if curr_client_record.selected_pixbuf then
                curr_tile_obj.image:set_from_pixbuf(curr_client_record.selected_pixbuf)
            end
            curr_tile_obj.eventbox:get_style_context():add_class("selected")
            local client = curr_client_record.client
            label1:set_text(client.class)
            label2:set_text(client.title)
            shared.selected_address = client.address
            ensure_tile_visible(curr_tile)
        elseif #tiles == 0 then
            label1:set_text("No results")
            label2:set_text("")
            shared.selected_address = nil
        end

        prev_tile = curr_tile
    end

    local function update_grid_and_window_size()
        cols = math.min(#visible_clients, max_cols)
        if cols < 1 then cols = 1 end
        local total_rows = math.ceil(#visible_clients / cols)
        visible_rows = math.min(total_rows, max_rows)
        rows = total_rows

        window_w = cols * cfg.tile_container_size + cfg.window_margin_left + cfg.window_margin_right
        window_h = visible_rows * cfg.tile_container_size + cfg.window_margin_top + cfg.window_margin_bottom

        if scrolled_window then
            scrolled_window:set_size_request(cols * cfg.tile_container_size, visible_rows * cfg.tile_container_size)
        end

        window:resize(window_w, window_h)
    end

    local function create_placeholder_pixbuf(size)
        local pixbuf = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, true, 8, size, size)
        pixbuf:fill(0x40404040) -- Dark gray placeholder
        return pixbuf
    end

    local function async_preview_capture(on_preview_ready)
        local active_count = 0

        -- Simple function to capture one client in its own thread
        local function capture_client(index, client)
            -- Calculate scale
            local w = client.size[1] * cfg.preview_scale
            local h = client.size[2] * cfg.preview_scale
            local scale = (w < cfg.selected_tile_size or h < cfg.selected_tile_size)
                and 1.0
                or cfg.preview_scale

            -- Build grim command
            local grim_cmd = string.format("grim -l 0 -s %f -w %s -", scale, client.address)

            utils.debug("Starting capture for " .. client.address .. " with cmd: " .. grim_cmd)

            -- Execute grim and read all output at once
            local file = io.popen(grim_cmd, "r")
            if not file then
                utils.debug("ERROR: Failed to start grim for " .. client.address)
                return
            end

            local image_data = file:read("*a")
            local exit_code = file:close()

            utils.debug(string.format("Capture result for %s: %d bytes, exit_code: %s",
                client.address,
                image_data and #image_data or 0,
                tostring(exit_code)))

            -- Deliver result back to main thread
            active_count = active_count - 1
            GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
                if image_data and #image_data > 0 and (exit_code == 0 or exit_code == true) then
                    on_preview_ready(index, image_data)
                else
                    utils.debug("FAILED capture for " .. client.address .. " - no data or bad exit code")
                end
                return false -- Don't repeat
            end)
        end

        -- Start a thread for each client, respecting max concurrent limit
        for i, client_record in ipairs(all_clients) do
            local client = client_record.client
            if client.workspace.id > 0 then
                -- Wait for available slot
                while active_count >= cfg.max_concurrent do
                    utils.debug("Waiting for slot, active: " .. active_count)
                    GLib.usleep(10000) -- Sleep 10ms
                end

                active_count = active_count + 1
                utils.debug("Starting thread " .. active_count .. " for " .. client.address)

                -- Spawn thread using GLib
                local thread = GLib.Thread.new("grim-" .. client.address, function()
                    capture_client(i, client)
                end)

                -- Don't join - let it run asynchronously
            end
        end
    end

    local function create_pixbuf_from_source(source)
        local loader = GdkPixbuf.PixbufLoader.new()
        local success, err = pcall(function()
            loader:write(source.image)
            loader:close()
        end)
        if success then
            return loader:get_pixbuf()
        else
            utils.debug(string.format("Failed to load pixbuf for %s: %s",
                source.client.address or "unknown",
                err or "unknown"
            ))
            return nil
        end
    end

    local function create_scaled_pixbuf(source, size)
        local pixbuf = create_pixbuf_from_source(source)
        if not pixbuf then
            pixbuf = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, true, 8, size, size)
            pixbuf:fill(0x808080ff)
        end
        local w, h = pixbuf:get_width(), pixbuf:get_height()
        local scale = math.min(size / w, size / h)
        return pixbuf:scale_simple(math.floor(w * scale), math.floor(h * scale), GdkPixbuf.InterpType.BILINEAR)
    end

    local function update_tile_preview(index, image_data)
        local client_record = all_clients[index]
        if not client_record then return end

        -- Store image data in master record
        client_record.image_data = image_data

        -- Create pixbufs and store in master record
        local client = client_record.client
        local source = { client = client, image = image_data }
        client_record.normal_pixbuf = create_scaled_pixbuf(source, cfg.base_tile_size)
        client_record.selected_pixbuf = create_scaled_pixbuf(source, cfg.selected_tile_size)

        -- Update any visible tiles that reference this client
        for tile_index, visible_index in ipairs(visible_clients) do
            if visible_index == index and tiles[tile_index] then
                local tile = tiles[tile_index]
                if tile_index == curr_tile then
                    tile.image:set_from_pixbuf(client_record.selected_pixbuf)
                else
                    tile.image:set_from_pixbuf(client_record.normal_pixbuf)
                end
                break -- Found the tile, no need to continue
            end
        end

        utils.debug(string.format("Updated preview for %s [%s:%s]",
            client.address,
            client.class,
            client.title
        ))
    end

    local function build_grid_with_placeholders()
        utils.debug("Building grid with placeholders for " .. #visible_clients .. " visible clients")

        -- Clear existing grid and tiles
        for _, child in ipairs(grid:get_children()) do
            grid:remove(child)
        end
        for k in pairs(tiles) do tiles[k] = nil end

        -- Create tiles for visible clients only
        local tile_index = 1
        for r = 0, rows - 1 do
            for c = 0, cols - 1 do
                if tile_index <= #visible_clients then
                    local index = visible_clients[tile_index]
                    local client_record = all_clients[index]

                    local image
                    if client_record.normal_pixbuf then
                        -- Use existing pixbuf if available
                        image = Gtk.Image.new_from_pixbuf(client_record.normal_pixbuf)
                    else
                        -- Use placeholder
                        local placeholder = create_placeholder_pixbuf(cfg.base_tile_size)
                        image = Gtk.Image.new_from_pixbuf(placeholder)
                    end

                    local eventbox = Gtk.EventBox()
                    eventbox:get_style_context():add_class("tile")
                    eventbox:add(image)
                    eventbox:set_size_request(cfg.tile_container_size, cfg.tile_container_size)

                    -- Capture tile_index in closure for click handler
                    local current_tile_index = tile_index
                    function eventbox:on_button_press_event(event)
                        if event.button == 1 then
                            curr_tile = current_tile_index
                            update_tile_display()
                            shared.activate()
                            app:quit()
                        end
                        return false
                    end

                    tiles[tile_index] = {
                        image = image,
                        eventbox = eventbox,
                    }

                    grid:attach(eventbox, c, r, 1, 1)
                    tile_index = tile_index + 1
                end
            end
        end

        grid:show_all()
        utils.debug("Grid built with " .. #tiles .. " tiles")
    end

    local function perform_filter()
        local query = search_entry:get_text()
        filter_clients(query)

        update_grid_and_window_size()
        if #visible_clients > 0 then
            curr_tile = 1
        end
        prev_tile = 0 -- Reset prev_tile to avoid stale state after filtering
        build_grid_with_placeholders()
        update_tile_display()
    end

    local function on_search_changed()
        perform_filter()
    end

    local function move_next()
        if #tiles == 0 then return end
        curr_tile = curr_tile + 1
        if curr_tile > #tiles then curr_tile = 1 end
        update_tile_display()
    end

    local function move_prev()
        if #tiles == 0 then return end
        curr_tile = curr_tile - 1
        if curr_tile < 1 then curr_tile = #tiles end
        update_tile_display()
    end

    local function start_alt_release_monitoring()
        alt_release_timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, cfg.altkey_wait_ms, function()
            if altkey_down() then
                return true -- Continue monitoring
            end
            utils.debug("ALT Key released")
            app:quit()
            shared.activate()
            return false -- Stop timer
        end)
    end

    function app:on_activate()
        hyprland.hyprctl("dispatch submap alttab")

        local dummywin = Gtk.ApplicationWindow {
            application = app,
            title = "hyprfloat:dummy"
        }
        dummywin:set_opacity(0.0)
        dummywin:set_default_size(10, 10) -- can't be too small
        dummywin:show_all()

        GLib.timeout_add(GLib.PRIORITY_DEFAULT, cfg.mainwindow_wait_ms, function()
            window = Gtk.ApplicationWindow {
                application = app,
                title = "hyprfloat:alttab"
            }

            -- Setup CSS and window geometry
            css_provider = Gtk.CssProvider()
            css_provider:load_from_data(cfg.stylesheet)

            display = Gdk.Display.get_default()
            Gtk.StyleContext.add_provider_for_screen(
                display:get_default_screen(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            -- Get screen dimensions
            monitor = display:get_monitor(cfg.default_monitor_index)
            local geom = monitor:get_geometry()

            -- Calculate available space for tiles (screen minus window margins)
            local available_width = geom.width - cfg.window_margin_left - cfg.window_margin_right
            local available_height = geom.height - cfg.window_margin_top - cfg.window_margin_bottom

            -- Calculate maximum grid dimensions that fit on screen
            max_cols = math.floor(available_width / cfg.tile_container_size)
            max_rows = math.floor(available_height / cfg.tile_container_size)

            -- Create search entry (initially hidden)
            search_entry = Gtk.SearchEntry()
            search_entry:set_name("search")
            search_entry:set_halign(Gtk.Align.CENTER)
            search_entry:set_size_request(400, -1)
            search_entry:set_can_focus(true)
            search_entry:set_visible(false) -- Start hidden
            search_entry.on_search_changed = on_search_changed

            -- Add key press handler to search entry
            function search_entry:on_key_press_event(event)
                local keyval = event.keyval

                -- Handle ESC here first - always quit app
                if keyval == Gdk.KEY_Escape then
                    app:quit()
                    return true
                end

                -- Let navigation keys bubble up to the window handler
                if keyval == Gdk.KEY_Up or keyval == Gdk.KEY_Down or
                    keyval == Gdk.KEY_Left or keyval == Gdk.KEY_Right or
                    keyval == Gdk.KEY_Tab or keyval == Gdk.KEY_ISO_Left_Tab or
                    keyval == Gdk.KEY_Page_Up or keyval == Gdk.KEY_Page_Down or
                    keyval == Gdk.KEY_Home or keyval == Gdk.KEY_End or
                    keyval == Gdk.KEY_grave or keyval == Gdk.KEY_Return then
                    return false -- Let window handler deal with these
                end

                -- Handle Backspace to allow deletion from the end
                if keyval == Gdk.KEY_BackSpace then
                    local text = search_entry:get_text()
                    if #text > 0 then
                        search_entry:set_text(string.sub(text, 1, -2))
                        search_entry:set_position(-1)
                    end
                    return true -- Event handled
                end

                -- For typing characters, handle them here to avoid ALT key interference
                local char_code = Gdk.keyval_to_unicode(keyval)
                if char_code ~= 0 then
                    local char = string.char(char_code)
                    -- Filter out control characters.
                    if not string.match(char, "%c") then
                        search_entry:set_text(search_entry:get_text() .. char)
                        search_entry:set_position(-1) -- Move cursor to end
                        return true                   -- Event handled
                    end
                end

                -- This ensures typing works even with ALT held down.
                -- Consume other unhandled key presses to prevent unwanted side effects.
                return true
            end

            label1 = Gtk.Label()
            label1:set_name("label1")
            label1:set_halign(Gtk.Align.CENTER)

            label2 = Gtk.Label()
            label2:set_name("label2")
            label2:set_halign(Gtk.Align.CENTER)

            grid = Gtk.Grid {
                halign = Gtk.Align.CENTER, valign = Gtk.Align.CENTER,
                row_spacing = cfg.grid_row_spacing, column_spacing = cfg.grid_column_spacing,
            }

            -- Create scrollable container for the grid
            scrolled_window = Gtk.ScrolledWindow()
            scrolled_window:set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scrolled_window:add(grid)

            outer = Gtk.Box {
                orientation = Gtk.Orientation.VERTICAL, halign = Gtk.Align.CENTER, valign = Gtk.Align.CENTER,
                margin_left = cfg.window_margin_left, margin_right = cfg.window_margin_right,
                margin_top = cfg.window_margin_top, margin_bottom = cfg.window_margin_bottom,
            }
            outer:pack_start(search_entry, false, false, 5)
            outer:pack_start(scrolled_window, true, true, 0)
            outer:pack_start(label1, false, false, 0)
            outer:pack_start(label2, false, false, 0)

            window:set_name("alttab-window")
            window:set_decorated(false)
            window:add(outer)

            local function handle_grid_navigation(keyval, shift_down)
                if #tiles == 0 then return false end

                local handled = true
                if keyval == Gdk.KEY_Left or keyval == Gdk.KEY_ISO_Left_Tab or (shift_down and keyval == Gdk.KEY_grave) then
                    move_prev()
                elseif keyval == Gdk.KEY_Right or keyval == Gdk.KEY_Tab or keyval == Gdk.KEY_grave then
                    move_next()
                elseif keyval == Gdk.KEY_Up then
                    curr_tile = curr_tile - cols
                    if curr_tile < 1 then curr_tile = curr_tile + #tiles end
                    update_tile_display()
                elseif keyval == Gdk.KEY_Down then
                    curr_tile = curr_tile + cols
                    if curr_tile > #tiles then curr_tile = curr_tile - #tiles end
                    update_tile_display()
                elseif keyval == Gdk.KEY_Page_Up then
                    curr_tile = curr_tile - (cols * visible_rows)
                    if curr_tile < 1 then curr_tile = math.max(1, curr_tile + #tiles) end
                    update_tile_display()
                elseif keyval == Gdk.KEY_Page_Down then
                    curr_tile = curr_tile + (cols * visible_rows)
                    if curr_tile > #tiles then curr_tile = math.min(#tiles, curr_tile - #tiles) end
                    update_tile_display()
                elseif keyval == Gdk.KEY_Home then
                    curr_tile = 1
                    update_tile_display()
                elseif keyval == Gdk.KEY_End then
                    curr_tile = #tiles
                    update_tile_display()
                else
                    handled = false
                end
                return handled
            end

            function window:on_key_press_event(event)
                local keyval = event.keyval

                if keyval == Gdk.KEY_Escape then
                    app:quit()
                    return true
                elseif keyval == Gdk.KEY_Return then
                    shared.activate()
                    app:quit()
                    return true
                end

                if handle_grid_navigation(keyval, event.state.SHIFT_MASK) then
                    return true
                end

                -- Check for alphanumeric characters to enable search mode
                local char_code = Gdk.keyval_to_unicode(keyval)
                if not search_mode and char_code ~= 0 then
                    local char = string.char(char_code)
                    if char:match("%w") then
                        if not search_mode then search_mode = true end

                        -- TODO: uncomment to remove ALT check
                        -- if alt_release_timer then
                        --     GLib.source_remove(alt_release_timer)
                        --     alt_release_timer = nil
                        -- end

                        search_entry:set_text(search_entry:get_text() .. char)
                        search_entry:grab_focus()
                        search_entry:set_position(-1) -- Move cursor to end
                        return true
                    end
                end

                -- In search mode, let the search entry handle the event.
                -- Otherwise, consume the event so it doesn't do anything else.
                return search_mode == false
            end

            -- Initialize visible clients to show all initially
            filter_clients("")

            -- Calculate initial grid dimensions and window size
            update_grid_and_window_size()
            window:set_default_size(window_w, window_h)

            window:show_all()
            label1:set_text("Loading previews...")
            label2:set_text("")

            -- Set initial focus to grid (not search entry)
            grid:grab_focus()

            -- Build grid immediately with placeholders
            build_grid_with_placeholders()

            -- Set initial selection if we have tiles
            if #tiles > 0 then
                curr_tile = 1
                update_tile_display()
            end

            -- Start async preview capture
            utils.debug("Starting async preview capture...")
            async_preview_capture(update_tile_preview)

            return false -- only run once
        end)
    end

    --
    -- Main execution
    --

    start_alt_release_monitoring()

    local signals = { 'SIGINT', 'SIGTERM', 'SIGHUP' }
    for _, sig in ipairs(signals) do
        posix.signal(posix[sig], function()
            cleanup()
            app:quit()
        end)
    end

    -- Wrap app:run in pcall to ensure cleanup on any errors
    local success, err = pcall(function()
        app:run(nil)
    end)
    if not success then
        cleanup()
        error(err)
    end

    -- Ensure cleanup runs after app:run completes
    cleanup()
end

return alttab_ui
