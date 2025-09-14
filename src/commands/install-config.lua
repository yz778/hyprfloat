return function(args)
    local config = require('lib.config')



    local f = io.open(config.user_config_file, "r")
    if f then
        f:close()
        print("Configuration file already exists at: " .. config.user_config_file)
        print("Please remove it first if you want to overwrite.")
        os.exit(1)
    end

    local in_file = io.open(config.default_config_file, "r")
    if not in_file then
        print("Error: Default configuration file not found at " .. config.default_config_file)
        os.exit(1)
    end

    os.execute("mkdir -p " .. config.user_config_root)

    local out_file = io.open(config.user_config_file, "w")
    if not out_file then
        print("Error: Could not write to " .. config.user_config_file)
        os.exit(1)
    end

    out_file:write(in_file:read("*a"))
    in_file:close()
    out_file:close()

    print("Default configuration installed at: " .. config.user_config_file)
end
