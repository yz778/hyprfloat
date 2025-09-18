local manifest = require('lib.manifest')

return {
    run = function(args)
        print(string.format("hyprfloat %s (https://github.com/yz778/hyprfloat)", manifest.version))
    end,
    help = {
        short = "Prints the hyprfloat version",
        usage = "version",
        long = "Prints the current version of hyprfloat."
    }
}
