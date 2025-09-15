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

local tiles = {}
local prev_tile = 0
local curr_tile = 1
local shared = {}
local alttab_ui = {}
local visible_rows = 0

local function altkey_down()
    local km = Gdk.Keymap.get_default()
    local state = km:get_modifier_state()
    local down = bit32.band(state, Gdk.ModifierType.MOD1_MASK) ~= 0
    return down
end

local function cleanup()
    utils.debug("Cleaning up")
    hyprland.hyprctl("dispatch submap reset")
end

function alttab_ui.launch(params)
    shared = params.shared
    local clients = params.clients
    local cfg = config.alttab
    local app = Gtk.Application({ application_id = 'hyprfloat.alttab' })
    local grid, label1, label2, window, outer, scrolled_window
    local css_provider, display, monitor, max_cols, cols, rows, window_w, window_h

    function app:on_shutdown()
        cleanup()
    end

    local function create_placeholder_pixbuf(size)
        local pixbuf = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, true, 8, size, size)
        pixbuf:fill(0x40404040) -- Dark gray placeholder
        return pixbuf
    end

    local function async_preview_capture(clients, on_preview_ready)
        local pending_captures = {}
        local active_captures = {}
        local completed_files = {}

        -- First pass: generate all grim commands and populate pending_captures queue
        for i, client in ipairs(clients) do
            if client.workspace.id > 0 then
                local temp_file = "/tmp/hyprfloat/preview-" .. client.address .. ".png"
                local temp_file_tmp = temp_file .. ".tmp"

                -- make sure scaled window isn't smaller than tile size
                local w = client.size[1] * cfg.preview_scale
                local h = client.size[2] * cfg.preview_scale
                local scale = (w < cfg.selected_tile_size or h < cfg.selected_tile_size)
                    and 1.0
                    or cfg.preview_scale

                -- prepare grim command to write to .tmp file first, then rename to avoid race condition
                local grim_cmd = string.format("grim -l 0 -s %f -w %s %s && mv %s %s &",
                    scale,
                    client.address,
                    temp_file_tmp,
                    temp_file_tmp,
                    temp_file
                )

                table.insert(pending_captures, {
                    index = i,
                    client = client,
                    temp_file = temp_file,
                    grim_cmd = grim_cmd
                })
            end
        end

        -- Function to process captures up to max concurrent limit
        local function process_captures()
            -- Start new captures if we have capacity and pending items
            local running_count = 0
            for _ in pairs(active_captures) do
                running_count = running_count + 1
            end

            while running_count < cfg.max_concurrent and #pending_captures > 0 do
                local capture_info = table.remove(pending_captures, 1) -- remove from front of queue

                -- Execute the grim command
                os.execute(capture_info.grim_cmd)
                active_captures[capture_info.index] = capture_info
                running_count = running_count + 1
            end

            -- Check for completed captures
            for i, capture_info in pairs(active_captures) do
                local file = io.open(capture_info.temp_file, "rb")
                if file then
                    -- File exists, check if it's complete by trying to read it
                    local image_data = file:read("*a")
                    file:close()

                    if image_data and #image_data > 0 then
                        -- Successfully captured
                        os.remove(capture_info.temp_file)
                        completed_files[i] = true
                        active_captures[i] = nil
                        on_preview_ready(i, capture_info.client, image_data)
                    end
                end
            end

            -- Continue processing if there are still items in queue or active captures
            local still_processing = #pending_captures > 0
            if not still_processing then
                for _ in pairs(active_captures) do
                    still_processing = true
                    break
                end
            end

            return still_processing
        end

        -- Set up polling timer to process captures
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, process_captures)
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

    local function update_tile_preview(tile_index, client, image_data)
        if not tiles[tile_index] then return end

        local tile = tiles[tile_index]
        local source = { index = tile_index, client = client, image = image_data }

        -- Create new pixbufs with actual preview
        local normal_pixbuf = create_scaled_pixbuf(source, cfg.base_tile_size)
        local selected_pixbuf = create_scaled_pixbuf(source, cfg.selected_tile_size)

        -- Update tile data
        tile.source = source
        tile.normal_pixbuf = normal_pixbuf
        tile.selected_pixbuf = selected_pixbuf

        -- Update the displayed image
        if tile_index == curr_tile then
            tile.image:set_from_pixbuf(selected_pixbuf)
        else
            tile.image:set_from_pixbuf(normal_pixbuf)
        end

        utils.debug("Updated preview for " .. client.address .. " [" .. client.class .. ":" .. client.title .. "]")
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
            -- Scroll up to show the tile
            vadj:set_value(tile_top)
        elseif tile_bottom > visible_bottom then
            -- Scroll down to show the tile
            vadj:set_value(tile_bottom - vadj:get_page_size())
        end
    end

    local function update_tile_display()
        if prev_tile > 0 and tiles[prev_tile] then
            local prev_tile_obj = tiles[prev_tile]
            prev_tile_obj.image:set_from_pixbuf(prev_tile_obj.normal_pixbuf)
            prev_tile_obj.eventbox:get_style_context():remove_class("selected")
        end

        if tiles[curr_tile] then
            local curr_tile_obj = tiles[curr_tile]
            curr_tile_obj.image:set_from_pixbuf(curr_tile_obj.selected_pixbuf)
            curr_tile_obj.eventbox:get_style_context():add_class("selected")
            label1:set_text(curr_tile_obj.source.client.class)
            label2:set_text(curr_tile_obj.source.client.title)
            shared.selected_address = curr_tile_obj.source.client.address

            -- Ensure the selected tile is visible
            ensure_tile_visible(curr_tile)
        end

        prev_tile = curr_tile
    end

    local function move_next()
        curr_tile = curr_tile + 1
        if curr_tile > #tiles then curr_tile = 1 end
        update_tile_display()
    end

    local function move_prev()
        curr_tile = curr_tile - 1
        if curr_tile < 1 then curr_tile = #tiles end
        update_tile_display()
    end

    local function build_grid_with_placeholders(clients)
        utils.debug("Building grid with placeholders")
        for _, child in ipairs(grid:get_children()) do
            grid:remove(child)
        end
        for k in pairs(tiles) do tiles[k] = nil end

        for r = 0, rows - 1 do
            for c = 0, cols - 1 do
                local idx = r * cols + c + 1
                if idx <= #clients then
                    local client = clients[idx]

                    -- Create placeholder pixbufs
                    local placeholder_normal = create_placeholder_pixbuf(cfg.base_tile_size)
                    local placeholder_selected = create_placeholder_pixbuf(cfg.selected_tile_size)

                    local image = Gtk.Image.new_from_pixbuf(placeholder_normal)
                    local eventbox = Gtk.EventBox()
                    eventbox:get_style_context():add_class("tile")
                    eventbox:add(image)
                    eventbox:set_size_request(cfg.tile_container_size, cfg.tile_container_size)

                    function eventbox:on_button_press_event(event)
                        if event.button == 1 then
                            curr_tile = idx
                            update_tile_display()
                            shared.activate()
                            app:quit()
                        end
                        return false
                    end

                    -- Create placeholder source data
                    local placeholder_source = {
                        index = idx,
                        client = client,
                        image = nil -- Will be updated when actual preview is ready
                    }

                    tiles[idx] = {
                        image = image,
                        eventbox = eventbox,
                        source = placeholder_source,
                        normal_pixbuf = placeholder_normal,
                        selected_pixbuf = placeholder_selected,
                    }
                    grid:attach(eventbox, c, r, 1, 1)
                end
            end
        end
        grid:show_all()
        update_tile_display()
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
            outer:pack_start(scrolled_window, true, true, 0)
            outer:pack_start(label1, false, false, 0)
            outer:pack_start(label2, false, false, 0)

            window:set_name("alttab-window")
            window:set_decorated(false)
            window:add(outer)

            function window:on_key_press_event(event)
                local keyval = event.keyval
                local shift_down = event.state.SHIFT_MASK

                if keyval == Gdk.KEY_Escape then
                    app:quit()
                elseif keyval == Gdk.KEY_Return then
                    shared.activate()
                elseif keyval == Gdk.KEY_Left or keyval == Gdk.KEY_ISO_Left_Tab or (shift_down and Gdk.KEY_grave) then
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
                    -- Move up by visible rows
                    curr_tile = curr_tile - (cols * visible_rows)
                    if curr_tile < 1 then
                        curr_tile = math.max(1, curr_tile + #tiles)
                    end
                    update_tile_display()
                elseif keyval == Gdk.KEY_Page_Down then
                    -- Move down by visible rows
                    curr_tile = curr_tile + (cols * visible_rows)
                    if curr_tile > #tiles then
                        curr_tile = math.min(#tiles, curr_tile - #tiles)
                    end
                    update_tile_display()
                elseif keyval == Gdk.KEY_Home then
                    curr_tile = 1
                    update_tile_display()
                elseif keyval == Gdk.KEY_End then
                    curr_tile = #tiles
                    update_tile_display()
                end
                return true
            end

            -- Calculate grid dimensions based on clients, not limited by screen space
            cols = math.min(#clients, max_cols)
            if cols < 1 then cols = 1 end
            local total_rows = math.ceil(#clients / cols)
            visible_rows = math.min(total_rows, max_rows)
            rows = total_rows -- Total rows for all clients

            -- Window size based on visible area only
            window_w = cols * cfg.tile_container_size + cfg.window_margin_left + cfg.window_margin_right
            window_h = visible_rows * cfg.tile_container_size + cfg.window_margin_top + cfg.window_margin_bottom +
                100 -- extra space for labels

            -- Set scrolled window size to show only visible rows
            scrolled_window:set_size_request(cols * cfg.tile_container_size, visible_rows * cfg.tile_container_size)
            window:set_default_size(window_w, window_h)

            window:show_all()
            label1:set_text("Loading previews...")
            label2:set_text("")

            -- Build grid immediately with placeholders
            build_grid_with_placeholders(clients)

            -- Start async preview capture
            utils.debug("Starting async preview capture...")
            async_preview_capture(clients, update_tile_preview)

            return false -- only run once
        end)
    end

    --
    -- Main execution
    --

    GLib.timeout_add(GLib.PRIORITY_DEFAULT, cfg.altkey_wait_ms, function()
        if altkey_down() then
            return true
        end
        utils.debug("ALT Key released")
        app:quit()
        shared.activate()
    end)

    local signals = { 'SIGINT', 'SIGTERM', 'SIGHUP' }
    for _, sig in ipairs(signals) do
        posix.signal(posix[sig], function()
            app:quit()
        end)
    end

    app:run(nil)
end

return alttab_ui
