return {
    run = function(args)
        local hyprland = require("lib.hyprland")
        local utils = require("lib.utils")

        utils.check_args(#args ~= 1, "Usage: hyprfloat movefocus [u|d|l|r]")

        local direction = args[1]:lower()

        utils.check_args(not direction:match("^[udlr]$"), "Direction must be u)p, d)own, l)eft, or r)ight")

        local ctx = hyprland.get_active_context()
        if not ctx or not ctx.window then
            utils.check_args(true, "No active window/monitor context")
            return
        end

        local current_window = ctx.window
        local current_workspace_id = hyprland.get_activeworkspace().id

        local floating_windows = {}
        for _, client in ipairs(hyprland.get_clients()) do
            if client.floating and client.workspace.id == current_workspace_id then
                table.insert(floating_windows, client)
            end
        end

        utils.check_args(#floating_windows <= 1, "No other floating windows to focus")

        local current_x = current_window.at[1] + current_window.size[1] * 0.5
        local current_y = current_window.at[2] + current_window.size[2] * 0.5
        local current_addr = current_window.address

        local best_window = nil

        if direction == "l" or direction == "r" then
            table.sort(floating_windows, function(a, b)
                local a_y = a.at[2] + a.size[2] * 0.5
                local b_y = b.at[2] + b.size[2] * 0.5
                if math.abs(a_y - b_y) > 10 then
                    return a_y < b_y
                end
                return a.at[1] + a.size[1] * 0.5 < b.at[1] + b.size[1] * 0.5
            end)
        else
            table.sort(floating_windows, function(a, b)
                local a_x = a.at[1] + a.size[1] * 0.5
                local b_x = b.at[1] + b.size[1] * 0.5
                if math.abs(a_x - b_x) > 10 then
                    return a_x < b_x
                end
                return a.at[2] + a.size[2] * 0.5 < b.at[2] + b.size[2] * 0.5
            end)
        end

        local current_idx = 1
        for i, win in ipairs(floating_windows) do
            if win.address == current_addr then
                current_idx = i
                break
            end
        end

        local target_idx
        if direction == "r" or direction == "d" then
            target_idx = current_idx % #floating_windows + 1
        else
            target_idx = current_idx == 1 and #floating_windows or current_idx - 1
        end
        best_window = floating_windows[target_idx]

        if best_window then
            hyprland.hyprctl_batch(
                string.format("dispatch focuswindow address:%s", best_window.address),
                "dispatch alterzorder top"
            )
        end
    end,
    help = {
        short = "Move floating window focus by proximity with wrapping.",
        usage = "movefocus <direction>",
        long = [[
Move floating window focus by proximity in a given direction with wrapping support.

The algorithm treats floating windows as positioned in a 2D matrix and finds the nearest window in the specified direction. If no window exists in that direction, it wraps around to the opposite side.

**Arguments:**
- `<direction>` Required. Direction to move focus:
  - `u` - Focus nearest window above (wraps to bottom)
  - `d` - Focus nearest window below (wraps to top)
  - `l` - Focus nearest window to the left (wraps to right)
  - `r` - Focus nearest window to the right (wraps to left)

**Behavior:**
- Only considers floating windows on the current workspace
- Uses window center points for distance calculations
- Prioritizes windows in the target direction, then falls back to wrapping
- Secondary sorting by distance for tie-breaking
]]
    }
}
