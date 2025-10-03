{
  description = "Hyprfloat flake with wrapGAppsHook for GObject dependencies";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          lua = pkgs.lua53Packages.lua;
          luaposix = pkgs.lua53Packages.luaposix;
          luacjson = pkgs.lua53Packages.cjson;
          lualgi = pkgs.lua53Packages.lgi;
          
          gObjectDeps = with pkgs; [
            glib gobject-introspection gtk3 pango atk gdk-pixbuf cairo
          ];

          luaPath = pkgs.lib.concatStringsSep ":" [
            "${luaposix}/share/lua/5.3/?.lua"
            "${luaposix}/share/lua/5.3/?/init.lua"
            "${luacjson}/share/lua/5.3/?.lua"
            "${luacjson}/share/lua/5.3/?/init.lua"
            "${lualgi}/share/lua/5.3/?.lua"
            "${lualgi}/share/lua/5.3/?/init.lua"
            "$LUA_PATH"
          ];
          luaCPath = pkgs.lib.concatStringsSep ":" [
            "${luaposix}/lib/lua/5.3/?.so"
            "${luacjson}/lib/lua/5.3/?.so"
            "${lualgi}/lib/lua/5.3/?.so"
            "$LUA_CPATH"
          ];
        in
        {
          default = pkgs.stdenv.mkDerivation {
            name = "hyprfloat";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [ pkgs.wrapGAppsHook ];
            buildInputs = [ lua luaposix luacjson lualgi ] ++ gObjectDeps;

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin $out/share/hyprfloat
              cp -r src/* $out/share/hyprfloat/
              
              cat > $out/bin/hyprfloat << EOF
              #!/${pkgs.bash}/bin/bash
              exec ${lua}/bin/lua $out/share/hyprfloat/hyprfloat "\$@"
              EOF
              chmod +x $out/bin/hyprfloat

              mkdir -p $out/share/applications
              cat > $out/share/applications/hyprfloat.desktop << EOF
              [Desktop Entry]
              Name=Hyprfloat
              Comment=Hyprland window management utility
              Exec=$out/bin/hyprfloat
              Type=Application
              Categories=Utility;System;
              Keywords=hyprland;window;float;
              EOF

              runHook postInstall
            '';

            preFixup = ''
              wrapProgram $out/bin/hyprfloat \
                --set LUA_PATH "${luaPath}" \
                --set LUA_CPATH "${luaCPath}" \
                --prefix GI_TYPELIB_PATH : "${pkgs.lib.makeSearchPath "lib/girepository-1.0" gObjectDeps}" \
                --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath gObjectDeps}" \
                --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share"
            '';

            checkPhase = ''
              echo "Verifying core module loading capability..."
              ${lua}/bin/lua -e '
                local required = { "posix", "cjson", "lgi.GLib" }
                for _, mod in ipairs(required) do
                  local ok, err = pcall(require, mod)
                  if not ok then
                    error("Module loading failed: " .. mod .. " (" .. err .. ")")
                  end
                end
                print("All core modules verified successfully")
              '
            '';

            passthru = {
              apps = {
                hyprfloat = {
                  type = "desktop";
                  program = "$out/bin/hyprfloat";
                };
              };
            };
            meta = {
              mainProgram = "hyprfloat";
              platforms = systems;
              description = "Hyprland floating window manager utility";
            };
          };
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          lua = pkgs.lua53Packages.lua;
          luaposix = pkgs.lua53Packages.luaposix;
          luacjson = pkgs.lua53Packages.cjson;
          lualgi = pkgs.lua53Packages.lgi;
          
          gObjectDeps = with pkgs; [
            glib gobject-introspection gtk3 pango atk gdk-pixbuf cairo
          ];
        in
        {
          default = pkgs.mkShell {
            packages = [
              lua
              luaposix
              luacjson
              lualgi
              pkgs.wrapGAppsHook
              pkgs.git
              pkgs.gtk3
            ] ++ gObjectDeps;

            shellHook = ''
              export GI_TYPELIB_PATH="${pkgs.lib.makeSearchPath "lib/girepository-1.0" gObjectDeps}:\$GI_TYPELIB_PATH"
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath gObjectDeps}:\$LD_LIBRARY_PATH"
              export XDG_DATA_DIRS="${pkgs.gtk3}/share:\$XDG_DATA_DIRS"
              export LUA_PATH="${luaposix}/share/lua/5.3/?.lua:${luaposix}/share/lua/5.3/?/init.lua:${luacjson}/share/lua/5.3/?.lua:${luacjson}/share/lua/5.3/?/init.lua:${lualgi}/share/lua/5.3/?.lua:${lualgi}/share/lua/5.3/?/init.lua:\$LUA_PATH"
              export LUA_CPATH="${luaposix}/lib/lua/5.3/?.so:${luacjson}/lib/lua/5.3/?.so:${lualgi}/lib/lua/5.3/?.so:\$LUA_CPATH"

              echo "Verifying modules in development environment..."
              lua -e '
                local ok, lgi = pcall(require, "lgi")
                if ok then
                  print("lgi loaded successfully (version: " .. lgi.version .. ")")
                  print("GLib version: " .. lgi.GLib.MAJOR_VERSION .. "." .. lgi.GLib.MINOR_VERSION)
                else
                  print("Warning: lgi loading failed - " .. lgi)
                end
              '
            '';
          };
        }
      );

      nixosModules.default = { config, pkgs, ... }: {
        options.programs.hyprfloat = {
          enable = pkgs.lib.mkEnableOption "Enable hyprfloat";
        };

        config = pkgs.lib.mkIf config.programs.hyprfloat.enable {
          environment.systemPackages = [ self.packages.${pkgs.system}.default ];
          environment.variables.GDK_PIXBUF_MODULE_FILE = 
            "${pkgs.gdk-pixbuf.out}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
        };
      };
    };
}
    