local bit32 = require('bit32')
local posix = require("posix")
local lgi = require('lgi')
local Gtk = lgi.require('Gtk', '3.0')
local Gdk = lgi.require('Gdk', '3.0')
local GdkPixbuf = lgi.require('GdkPixbuf', '2.0')
local GLib = lgi.GLib
local utils = require('lib.utils')
local config = require('lib.config')

local default_config = {
    alttab = {
        -- Milliseconds to wait before checking if the ALT key is held down.
        -- If this is too short, the check may incorrectly report that ALT is held down.
        altkey_wait_ms = 50,

        -- Milliseconds to wait before opening the main selector window.
        mainwindow_wait_ms = 100,

        -- Number of concurrent grim processes to run
        max_concurrent = 8,

        -- Window scale for previews
        preview_scale = 0.15,

        -- Display and monitor
        default_monitor_index = 0,
        screen_width_ratio = 0.6,

        -- Tile dimensions
        base_tile_size = 120,
        selected_tile_size = 140,
        tile_container_size = 160,

        -- Grid spacing
        grid_row_spacing = 5,
        grid_column_spacing = 5,

        -- Window layout
        window_margin_top = 20,
        window_margin_bottom = 20,
        window_margin_left = 20,
        window_margin_right = 20,

        -- Window stylesheet
        stylesheet = [[
            #alttab-window {
                background: rgba(30, 30, 30, .75);
            }
            .tile {
                background-color: transparent;
                border: 1px solid transparent;
                border-radius: 4px;
                padding: 4px;
            }
            .tile.selected {
                background-color: #4A90E2;
                border: 3px solid #2E5C8A;
                border-radius: 8px;
                padding: 4px;
            }
            #label1 {
                color: #ddeeff;
                font-size: 16px;
                font-weight: bold;
            }
            #label2 {
                color: #ddeeff;
                font-size: 16px;
            }
        ]]
    }
}

local tiles = {}
local prev_tile = 0
local curr_tile = 1
local shared = {}
local alttab_ui = {}

local function altkey_down()
    local km = Gdk.Keymap.get_default()
    local state = km:get_modifier_state()
    local down = bit32.band(state, Gdk.ModifierType.MOD1_MASK) ~= 0
    return down
end

local function cleanup()
    utils.debug("Cleaning up")
    utils.exec_cmd("hyprctl dispatch submap reset")
end

function alttab_ui.launch(params)
    shared = params.shared
    local clients = params.clients
    local cfg = utils.deep_merge(default_config, config).alttab
    local app = Gtk.Application({ application_id = 'hyprfloat.alttab' })
    local previews = {}
    local grid, label1, label2, window, outer
    local css_provider, display, monitor, geom, screen_w, max_width, max_cols, cols, rows, window_w, window_h

    function app:on_shutdown()
        cleanup()
    end

    local function parallel_preview_capture(clients)
        local pids = {}
        local temp_files = {}
        for i, client in ipairs(clients) do
            if client.workspace.id > 0 then
                local temp_file = "/tmp/hyprfloat/preview-" .. client.address .. ".png"
                temp_files[i] = temp_file
                local pid = posix.fork()
                if pid == 0 then -- Child
                    -- make sure scaled window isn't smaller than tile size
                    local w = client.size[1] * cfg.preview_scale
                    local h = client.size[2] * cfg.preview_scale
                    local scale = (w < cfg.selected_tile_size or h < cfg.selected_tile_size)
                        and 1.0
                        or cfg.preview_scale

                    -- take screenshot
                    local grim_cmd = string.format("grim -l 0 -s %f -w %s %s",
                        scale,
                        client.address,
                        temp_file
                    )
                    os.execute(grim_cmd)
                    os.exit(0)
                else -- Parent
                    pids[i] = pid
                    if #pids >= cfg.max_concurrent then
                        local waited_pid = posix.wait()
                        for idx, child_pid in pairs(pids) do
                            if child_pid == waited_pid then
                                pids[idx] = nil
                                break
                            end
                        end
                    end
                end
            end
        end
        for _, pid in pairs(pids) do
            posix.wait(pid)
        end
        local results = {}
        for i, temp_file in pairs(temp_files) do
            local file = io.open(temp_file, "rb")
            if file then
                results[i] = file:read("*a")
                file:close()
                os.remove(temp_file)
            end
        end
        return results
    end

    local function get_previews(clients)
        utils.debug("Capturing previews...")
        local sources = {}
        local preview_data = parallel_preview_capture(clients)
        for i, image in pairs(preview_data) do
            local client = clients[i]
            if image then
                utils.debug("Capturing " .. client.address .. " [" .. client.class .. ":" .. client.title .. "]")
                table.insert(sources, { index = i, client = client, image = image })
            end
        end
        utils.debug("Finished capturing " .. #sources .. " previews")
        return sources
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

    local function build_grid()
        utils.debug("Building grid")
        for _, child in ipairs(grid:get_children()) do
            grid:remove(child)
        end
        for k in pairs(tiles) do tiles[k] = nil end

        for r = 0, rows - 1 do
            for c = 0, cols - 1 do
                local idx = r * cols + c + 1
                if idx <= #previews then
                    previews[idx].index = idx
                    local normal_pixbuf = create_scaled_pixbuf(previews[idx], cfg.base_tile_size)
                    local selected_pixbuf = create_scaled_pixbuf(previews[idx], cfg.selected_tile_size)
                    local image = Gtk.Image.new_from_pixbuf(normal_pixbuf)
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

                    tiles[idx] = {
                        image = image,
                        eventbox = eventbox,
                        source = previews[idx],
                        normal_pixbuf = normal_pixbuf,
                        selected_pixbuf = selected_pixbuf,
                    }
                    grid:attach(eventbox, c, r, 1, 1)
                end
            end
        end
        grid:show_all()
        update_tile_display()
    end

    function app:on_activate()
        utils.exec_cmd("hyprctl dispatch submap alttab")

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
            monitor = display:get_monitor(cfg.default_monitor_index)
            geom = monitor:get_geometry()
            screen_w = geom.width
            max_width = math.floor(screen_w * cfg.screen_width_ratio)
            max_cols = math.floor(max_width / cfg.base_tile_size)

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

            outer = Gtk.Box {
                orientation = Gtk.Orientation.VERTICAL, halign = Gtk.Align.CENTER, valign = Gtk.Align.CENTER,
                margin_left = cfg.window_margin_left, margin_right = cfg.window_margin_right,
                margin_top = cfg.window_margin_top, margin_bottom = cfg.window_margin_bottom,
            }
            outer:pack_start(grid, true, true, 0)
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
                end
                return true
            end

            window:show_all()
            label1:set_text("Loading previews...")
            label2:set_text("")

            previews = get_previews(clients)

            cols = math.min(#previews, max_cols)
            if cols < 1 then cols = 1 end
            rows = math.ceil(#previews / cols)
            window_w = cols * cfg.base_tile_size
            window_h = rows * cfg.base_tile_size
            window:set_default_size(window_w, window_h)

            -- Ensure grid is rebuilt and updated after previews load
            build_grid()
            grid:queue_draw() -- force grid redraw
            window:show_all() -- ensure UI is refreshed
            return false      -- only run once
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
