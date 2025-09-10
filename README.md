# hyprfloat

`hyprfloat` is a Lua script that provides enhanced window management features for Hyprland, including a GNOME-style overview, easy window snapping, and a global floating mode.

![demo gif](demo/demo.gif)

## Getting Started

### Prerequisites

- Hyprland
- Lua >= 5.1
- [lua-posix](https://github.com/luaposix/luaposix)
- [lua-cjson](https://github.com/mpx/lua-cjson/)

### Installation (Arch Linux)

1.  Install the required dependencies using `pacman`:
    ```sh
    sudo pacman -S lua lua-posix lua-cjson
    ```

2.  Place the `hyprfloat` script somewhere in your `$PATH`. For example:
    ```sh
    cd ~/.local/bin
    curl -O https://raw.githubusercontent.com/yz778/hyprfloat/refs/heads/main/src/hyprfloat
    chmod +x hyprfloat
    ```

3.  Copy and customize the sample configuration:
    ```sh
    mkdir -p ~/.config/hypr
    cd ~/.config/hypr
    curl -O https://raw.githubusercontent.com/yz778/hyprfloat/refs/heads/main/config/hyprfloat.conf.lua
    ```

4.  Add keybindings to your ` ~/.config/hypr/hyprland.conf` ([see below](#bindings))

## Features

- **Workspace Overview**: Arranges all windows into a grid, similar to GNOME's overview.
- **Float Mode**: Toggles all windows between tiling and floating, with customizable Hyprland settings for each mode.
- **Window Snapping**: Snaps the active window to fractional portions of the screen.
- **Window Centering**: Centers the active window, with an option to scale it.
- **Multi-monitor Support**: Move windows between monitors while maintaining relative size and position.

## Configuration

`hyprfloat` configuartion is stored in `~/.config/hypr/hyprfloat.conf.lua`. Copy the sample configuration file from the `config/` directory.

There are two sections:

- `overview`: Configures the appearance of the overview mode, including grid layout, spacing, and window aspect ratios.

- `float_mode`: Defines two sets of Hyprland commands (`tiling_commands` and `floating_commands`) that are applied when toggling between tiling and floating modes. This allows you to have different settings for borders, gaps, and keybindings in each mode.

## Bindings

Bind the `hyprfloat` commands to keybindings in your `hyprland.conf`. For example:

```
bind = $mainMod, BACKSLASH,       exec, hyprfloat overview
bind = $mainMod_SHIFT, BACKSLASH, exec, hyprfloat togglefloat
bind = $mainMod, LEFT,            exec, hyprfloat snap 0.0   0.5   0.0   1.0
bind = $mainMod, RIGHT,           exec, hyprfloat snap 0.5   1.0   0.0   1.0
bind = $mainMod, INSERT,          exec, hyprfloat snap 0.0   0.3   0.0   0.5
bind = $mainMod, HOME,            exec, hyprfloat snap 0.0   1.0   0.0   0.5
bind = $mainMod, PAGE_UP,         exec, hyprfloat snap 0.7   1.0   0.0   0.5
bind = $mainMod, DELETE,          exec, hyprfloat snap 0.0   0.3   0.5   0.0
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
