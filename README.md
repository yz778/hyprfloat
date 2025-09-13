# hyprfloat

`hyprfloat` is a Lua script that provides enhanced window management features for [Hyprland](https://hypr.land), including a GNOME-style overview, easy window snapping, and a global floating mode.

https://github.com/user-attachments/assets/bf9eaf2c-1d13-4ead-992c-1e2cb2328951

## Getting Started

### Prerequisites

- [Lua](https://lua.org) with [lua-cjson](https://github.com/mpx/lua-cjson/), [lua-lgi](https://github.com/lgi-devs/lgi), [lua-posix](https://github.com/luaposix/luaposix)
- [grim-hyprland](https://github.com/eriedaberrie/grim-hyprland) (for Window switching)

### Installation

1.  Install the required dependencies. Example using yay in Arch Linux:
    ```sh
    yay -S lua lua-posix lua-lgi lua-cjson grim-hyprland
    ```

2.  Run the install script
    ```sh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/yz778/hyprland/main/install.sh)"
    ```

3.  Customize theconfiguration file:
    ```sh
    ~/.config/hypr/hyprfloat.conf.lua
    ```

4.  Add keybindings to your ` ~/.config/hypr/hyprland.conf` ([see below](#bindings))

## Features

- **Workspace Overview**: Arranges all windows into a grid, similar to GNOME's overview.
- **Float Mode**: Toggles all windows between tiling and floating, with customizable Hyprland settings for each mode.
- **Window Snapping**: Snaps the active window to fractional portions of the screen.
- **Window Centering**: Centers the active window, with an option to scale it.
- **Multi-monitor Support**: Move windows between monitors while maintaining relative size and position.

## Configuration

`hyprfloat` configuration is stored in `~/.config/hypr/hyprfloat.conf.lua`. See the [example configuration file](config/hyprfloat.conf.lua) for details on what each setting does.

## Bindings

Bind the `hyprfloat` commands to keybindings in your `hyprland.conf`. For example:


```
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
bind = $mainMod, BACKSLASH,       exec, hyprfloat overview
bind = $mainMod_SHIFT, BACKSLASH, exec, hyprfloat togglefloat
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
bind = $mainMod_SHIFT, LEFT,      exec, hyprfloat movemon -1
bind = $mainMod_SHIFT, RIGHT,     exec, hyprfloat movemon +1
bind = $mainMod, UP,              exec, hyprfloat center 1.25
bind = $mainMod, DOWN,            exec, hyprfloat center 0.75
bind = $mainMod_SHIFT, DOWN,      exec, hyprfloat center 1.00
```
