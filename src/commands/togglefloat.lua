return {
    run = function(args)
        local hyprland = require("lib.hyprland")
        local config = require("lib.config")
        local utils = require("lib.utils")

        if utils.file_exists(utils.runtime_path("/overview.sock")) then
            utils.debug("Overview mode detected, will not toggle floating")
            return
        end

        local cfg = config.float_mode
        local mode = args[1]
        -- 保存当前活跃工作区ID和聚焦窗口
        local original_active_ws = hyprland.get_activeworkspace().id
        local original_focused_win = nil
        local clients = hyprland.get_clients()
        for _, win in ipairs(clients) do
            if win.focused then
                original_focused_win = win
                break
            end
        end

        -- 获取所有工作区
        local all_workspaces = hyprland.get_workspaces()
        
        -- 存储所有工作区的操作命令，最后统一执行
        local all_commands = {}
        
        -- 先切换到每个工作区处理，然后返回原工作区
        for _, workspace in ipairs(all_workspaces) do
            local current_ws_id = workspace.id
            
            -- 切换到当前处理的工作区
            table.insert(all_commands, string.format("dispatch workspace %d", current_ws_id))
            
            -- 获取当前工作区的所有窗口
            local windows = {}
            for _, win in ipairs(hyprland.get_clients()) do
                if win.workspace.id == current_ws_id then
                    table.insert(windows, win)
                end
            end

            -- 确定当前工作区的浮动状态
            local is_floating = (
                mode == "on" and false
                or mode == "off" and true
                or hyprland.has_floating(windows)
            )

            -- 保存窗口几何信息
            local saved_geometry = {}
            if not is_floating then
                for _, win in ipairs(windows) do
                    saved_geometry[win.address] = { 
                        at = win.at, 
                        size = win.size,
                        floating = win.floating
                    }
                end
            end

            -- 构建切换命令
            local ws_identifier = string.format("workspace:%d", current_ws_id)
            
            if is_floating then
                table.insert(all_commands, string.format('keyword windowrule unset,%s', ws_identifier))
                table.insert(all_commands, string.format('keyword windowrule unset,class:.*'))
            else
                table.insert(all_commands, string.format('keyword windowrule float,%s', ws_identifier))
                table.insert(all_commands, string.format('keyword windowrule float,class:.*'))
            end

            -- 添加模式特定命令
            local mode_commands = is_floating and cfg.tiling_commands or cfg.floating_commands
            for _, cmd in ipairs(mode_commands) do
                table.insert(all_commands, cmd)
            end

            -- 切换窗口浮动状态并设置置顶
            for _, win in ipairs(windows) do
                if is_floating == win.floating then
                    -- 切换浮动状态
                    table.insert(all_commands, string.format("dispatch togglefloating address:%s", win.address))
                    -- 新增：将窗口置顶
                    table.insert(all_commands, string.format("dispatch alterzorder top,address:%s", win.address))
                end
            end

            -- 恢复窗口几何信息（仅在当前工作区上下文内）
            if not is_floating then
                for _, win in ipairs(windows) do
                    if saved_geometry[win.address] then
                        local geo = saved_geometry[win.address]
                        local x, y = geo.at[1], geo.at[2]
                        local w, h = geo.size[1], geo.size[2]
                        
                        -- 直接操作当前工作区的窗口，无需指定工作区
                        table.insert(all_commands, string.format(
                            "dispatch resizewindow address:%s exact %d %d",
                            win.address, w, h
                        ))
                        table.insert(all_commands, string.format(
                            "dispatch movewindow address:%s exact %d %d",
                            win.address, x, y
                        ))
                    end
                end
            end
        end
        
        -- 最后切回原始工作区
        table.insert(all_commands, string.format("dispatch workspace %d", original_active_ws))
        
        -- 恢复原始焦点窗口并置顶
        if original_focused_win then
            table.insert(all_commands, string.format("dispatch focuswindow address:%s", original_focused_win.address))
            table.insert(all_commands, string.format("dispatch alterzorder top,address:%s", original_focused_win.address))
        end

        -- 执行所有命令
        hyprland.hyprctl_batch(table.unpack(all_commands))

        -- 执行全局配置命令
        for _, cmd in ipairs(cfg.commands) do
            utils.exec_cmd(cmd)
        end
    end,
    help = {
        short = "Toggles floating mode for all workspaces with strict workspace isolation.",
        usage = "togglefloat [on|off]",
        long = [[
Switches all windows in all workspaces between floating and tiling layouts with strict workspace isolation.
Windows will remain in their original workspaces after toggle.

**Arguments:**
- `[on|off]` Optional. Explicitly set all windows to floating ('on') or tiling ('off'). 
  If omitted, it toggles the current state.
]]
    }
}
