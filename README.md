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
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/yz778/hyprfloat/main/install.sh)"
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

- `hyprfloat alttab <next|prev> [sameclass]`: Switches between windows.
  - **next**: Switches to the next window in the MRU list.
  - **prev**: Switches to the previous window in the MRU list.
  - **sameclass**: (Optional) Only switches between windows of the same class.
- `hyprfloat center <scale>`: Centers the active window and optionally scales it.
- `hyprfloat events`: Prints Hyprland events.
- `hyprfloat install-config`: Installs the default configuration.
- `hyprfloat movemon <direction>`: Moves the active window to another monitor.
- `hyprfloat overview`: Shows the workspace overview.
- `hyprfloat snap <x0> <x1> <y0> <y1>`: Snaps the active window to a fractional portion of the screen.
- `hyprfloat togglefloat [mode]`: Toggles floating mode for all windows.
  - **on**: (Optional) Set all windows to floating
  - **off**: (Optional) Set all windows to tiling
  - **(default)**: Toggles between floating and tiling
- `hyprfloat version`: Prints the version of hyprfloat.
- `hyprfloat workspacegroup <next|prev|status>`: Move between groups of workspaces or print current status.
  - **next**: Switch to the next workspace group.
  - **prev**: Switch to the previous workspace group.
  - **status**: Print the workspace group status, e.g. [for using in Waybar](#tips-and-tricks)

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
