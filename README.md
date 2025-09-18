# hyprfloat

`hyprfloat` is a Lua script that provides enhanced window management features for [Hyprland](https://hypr.land), including a GNOME-style overview, floating window snapping, and more.

https://github.com/user-attachments/assets/bf9eaf2c-1d13-4ead-992c-1e2cb2328951

## Getting Started

### Prerequisites

- [Lua](https://lua.org), [lua-cjson](https://github.com/mpx/lua-cjson/), [lua-lgi](https://github.com/lgi-devs/lgi), [lua-posix](https://github.com/luaposix/luaposix)
- [grim-hyprland](https://github.com/eriedaberrie/grim-hyprland)

### Installation

1.  Install the required dependencies. Example using yay in Arch Linux:
    ```sh
    yay -S lua lua-posix lua-lgi lua-cjson grim-hyprland
    ```

2.  Run the install script
    ```sh
    curl -fsSL https://raw.githubusercontent.com/yz778/hyprfloat/main/install.sh | sh
    ```

3.  (Optional) Install and customize the [default configuration](src/config/default.conf.lua) file.
    ```sh
    hyprfloat install-config
    ```
    The configuration will be placed at `~/.config/hypr/hyprfloat.config.lua`.

4.  Add [keybindings](#bindings) to your ` ~/.config/hypr/hyprland.conf`

## Features

- **ALT-Tab Window Switching**: A window switcher with MRU (Most-Recently-Used) focus, search / preview, and an option to switch between windows of the same class. To search through previews, keep holding the ALT key down as you type.

https://github.com/user-attachments/assets/c4d359ad-6b04-4b91-8774-80df4ad27d6c

- **Workspace Overview**: Arranges all windows into a grid, similar to GNOME's overview.

- **Float Mode**: Toggles all windows between tiling and floating, with customizable Hyprland settings for each mode.

- **Window Snapping**: Snaps the active window to fractional portions of the screen.

- **Window Centering**: Centers the active window, with an option to scale it.

- **Multi-monitor Support**: Move windows between monitors while maintaining relative size and position.

- **Workspace Groups**: Group workspaces together and cycle through them. This is useful for multi-monitor setups.

## Commands

<!-- GENERATED-COMMANDS-START -->

#### `alttab <next|prev> [sameclass]`
<blockquote>
Switches focus to the next or previous window in the focus history.

**Arguments:**
- `<next|prev>` Required. Specifies whether to switch to the next or the previous window.
- `[sameclass]` Optional. If provided, the window selection is restricted to windows of the same class as the currently active window.

</blockquote>

#### `center <scale>`
<blockquote>
Centers the active window in the middle of the screen and applies a scaling factor.

**Arguments:**
- `<scale>` Required. A number to scale the window size (e.g., 1.0 for original size, 1.2 to enlarge, 0.8 to shrink).

</blockquote>

#### `events`
<blockquote>
Connects to the Hyprland event socket and prints all incoming events to the console. Useful for debugging.
</blockquote>

#### `install-config`
<blockquote>
Copies the default configuration file to the user's config directory, allowing for user-specific customizations.
</blockquote>

#### `movemon <direction>`
<blockquote>
Moves the active window to a different monitor while maintaining its relative position and size.

**Arguments:**
- `<direction>` Required. A number indicating which monitor to move to (+1 for next, -1 for previous).

</blockquote>

#### `overview`
<blockquote>
Toggles a GNOME-style workspace overview, arranging all windows in a grid. Running the command again will exit overview mode.
</blockquote>

#### `snap <x0> <x1> <y0> <y1>`
<blockquote>
Snaps the active window to a fractional portion of the screen.

**Arguments:**
- `<x0>` Required. Left position as a fraction of screen width (e.g., 0.0).
- `<x1>` Required. Right position as a fraction of screen width (e.g., 0.5 for half width).
- `<y0>` Required. Top position as a fraction of screen height (e.g., 0.0).
- `<y1>` Required. Bottom position as a fraction of screen height (e.g., 1.0 for full height).

</blockquote>

#### `togglefloat [on|off]`
<blockquote>
Switches all windows between floating and tiling layouts.

**Arguments:**
- `[on|off]` Optional. Explicitly set all windows to floating ('on') or tiling ('off'). If omitted, it toggles the current state.

</blockquote>

#### `version`
<blockquote>
Prints the current version of hyprfloat.
</blockquote>

#### `workspacegroup <next|prev|status|group|move>`
<blockquote>
Manages groups of workspaces, useful for multi-monitor setups.

**Arguments:**
- `<next|prev>` Switches to the next or previous workspace group.
- `<status>` Prints the status of workspace groups, useful for status bars.
- `<group>` Switches to a specific workspace group by number.
- `<move>` Presents a UI to move the active window to a different workspace group.

</blockquote>

<!-- GENERATED-COMMANDS-END -->

## Bindings

Add bindings to your `hyprland.conf`, here is a fully configured example:

```ini
# ALT-Tab / SHIFT-ALT-TAB for quick MRU switching, keep ALT held to use window switcher
submap = alttab
bind = SHIFT, SPACE, exec, hyprctl dispatch submap reset
submap = reset

windowrule = float,               title:^(hyprfloat:alttab)$
windowrule = noanim,              title:^(hyprfloat:alttab)$
windowrule = pin,                 title:^(hyprfloat:alttab)$
windowrule = size 0 0,            title:^(hyprfloat:alttab)$
windowrule = stayfocused,         title:^(hyprfloat:alttab)$
windowrule = bordersize 0,        title:^(hyprfloat:dummy)$
windowrule = float,               title:^(hyprfloat:dummy)$
windowrule = noanim,              title:^(hyprfloat:dummy)$
windowrule = size 0 0,            title:^(hyprfloat:dummy)$
bind = ALT, TAB,                  exec, hyprfloat alttab next
bind = ALT_SHIFT, TAB,            exec, hyprfloat alttab prev
bind = ALT, GRAVE,                exec, hyprfloat alttab next sameclass
bind = ALT_SHIFT, GRAVE,          exec, hyprfloat alttab prev sameclass

# Toggle Overview mode
bind = $mainMod, BACKSLASH,       exec, hyprfloat overview

# Toggle Floating or Tiling layout
bind = $mainMod_SHIFT, BACKSLASH, exec, hyprfloat togglefloat

# Snap window to predefined positions (floating mode only)
bind = $mainMod, LEFT,            exec, hyprfloat snap 0.0   0.5   0.0   1.0
bind = $mainMod, RIGHT,           exec, hyprfloat snap 0.5   1.0   0.0   1.0
bind = $mainMod, INSERT,          exec, hyprfloat snap 0.0   0.3   0.0   0.5
bind = $mainMod, HOME,            exec, hyprfloat snap 0.0   1.0   0.0   0.5
bind = $mainMod, PAGE_UP,         exec, hyprfloat snap 0.7   1.0   0.0   0.5
bind = $mainMod, DELETE,          exec, hyprfloat snap 0.0   0.3   0.5   1.0
bind = $mainMod, END,             exec, hyprfloat snap 0.0   1.0   0.5   1.0
bind = $mainMod, PAGE_DOWN,       exec, hyprfloat snap 0.7   1.0   0.5   1.0
bind = $mainMod_SHIFT, INSERT,    exec, hyprfloat snap 0.0   0.7   0.0   1.0
bind = $mainMod_SHIFT, HOME,      exec, hyprfloat snap 0.2   0.8   0.0   1.0
bind = $mainMod_SHIFT, PAGE_UP,   exec, hyprfloat snap 0.7   1.0   0.0   1.0
bind = $mainMod_SHIFT, UP,        exec, hyprfloat snap 0.0   1.0   0.0   1.0

# Move active window between monitors
bind = $mainMod_SHIFT, LEFT,      exec, hyprfloat movemon -1
bind = $mainMod_SHIFT, RIGHT,     exec, hyprfloat movemon +1

# Center and resize the active window (floating mode only)
bind = $mainMod, UP,              exec, hyprfloat center 1.25
bind = $mainMod, DOWN,            exec, hyprfloat center 0.75
bind = $mainMod_SHIFT, DOWN,      exec, hyprfloat center 1.00

# Cycle through workspace groups
bind = $mainMod_CTRL, LEFT,       exec, hyprfloat workspacegroup prev
bind = $mainMod_CTRL, RIGHT,      exec, hyprfloat workspacegroup next
bind = $mainMod_CTRL, M,          exec, hyprfloat workspacegroup move
bind = $mainMod, 1,               exec, hyprfloat workspacegroup group 1
bind = $mainMod, 2,               exec, hyprfloat workspacegroup group 2
bind = $mainMod, 3,               exec, hyprfloat workspacegroup group 3
```

## Tips and Tricks

Here is a sample configuration that shows how I synchronize workspace changes across my three monitors.

~/.config/hypr/hyprland.conf
```ini
monitor=DP-1,1280x1024@75,0x0,1
monitor=DP-3,2560x1440@143,1280x0,1
monitor=HDMI-A-1,1280x1024@75,3840x0,1

# group 1
workspace=1, monitor:DP-1,     persistent:true
workspace=2, monitor:DP-3,     persistent:true
workspace=3, monitor:HDMI-A-1, persistent:true

# group 2
workspace=4, monitor:DP-1,     persistent:true
workspace=5, monitor:DP-3,     persistent:true
workspace=6, monitor:HDMI-A-1, persistent:true

# group 3
workspace=7, monitor:DP-1,     persistent:true
workspace=8, monitor:DP-3,     persistent:true
workspace=9, monitor:HDMI-A-1, persistent:true
```

~/.config/waybar/config.jsonc
```json
"custom/workspacegroup": {
  "exec": "hyprfloat workspacegroup status",
  "interval": "once",
  "format": "{text}",
  "on-click": "hyprfloat workspacegroup next",
  "tooltip": false,
  "signal": 8
}
```

~/.config/hypr/hyprfloat.config.lua
```lua
workspacegroup = {
    icons = {
        active = "  ",
        default = "  ",
    },
    groups = {
        { 1, 2, 3 }, -- monitor 1
        { 4, 5, 6 }, -- monitor 2
        { 7, 8, 9 }, -- monitor 3
    },
    commands = {
        "pkill -RTMIN+8 waybar"
    }
}
```
