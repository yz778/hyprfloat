{
  description = "Hyprfloat flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} ({ self, ... }: {
    systems = [ "x86_64-linux" "aarch64-linux" ];
    perSystem = { pkgs, lib, self', ... }:
    let
      luaEnv = pkgs.lua53Packages.lua.withPackages (ps: [ ps.luaposix ps.cjson ps.lgi ps.bit32 ]);

      gObjectDeps = with pkgs; [
        glib gobject-introspection gtk3 pango atk gdk-pixbuf cairo
      ];
    in
    {
      packages.default = self'.packages.hyprfloat;
      packages.hyprfloat = pkgs.stdenv.mkDerivation {
        pname = "hyprfloat";
        version = "2.5.1";
        src = ./src;

        nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.makeWrapper ];
        buildInputs = gObjectDeps;

        installPhase = ''
          runHook preInstall

          install -d $out/bin $out/share/hyprfloat
          cp -r . $out/share/hyprfloat/

          makeWrapper ${lib.getExe luaEnv} $out/bin/hyprfloat \
            --add-flags $out/share/hyprfloat/hyprfloat \
            --prefix PATH : "${luaEnv}/bin" \
            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath gObjectDeps}"

          runHook postInstall
        '';

        meta = {
          mainProgram = "hyprfloat";
          description = "Hyprland floating window manager utility";
          homepage = "https://github.com/yz778/hyprfloat";
          license = lib.licenses.mit;
          platforms = lib.platforms.linux;
        };
      };
      devShells.default = pkgs.mkShell {
        packages = [
          luaEnv
          pkgs.git
        ] ++ gObjectDeps;

        shellHook = ''
          export GI_TYPELIB_PATH="${pkgs.lib.makeSearchPath "lib/girepository-1.0" gObjectDeps}:\$GI_TYPELIB_PATH"
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath gObjectDeps}:\$LD_LIBRARY_PATH"
          export XDG_DATA_DIRS="${pkgs.gtk3}/share:\$XDG_DATA_DIRS"
        '';
      };
    };
    flake.nixosModules.default = { config, lib, pkgs, ... }: {
      options.programs.hyprfloat.enable = lib.mkEnableOption "hyprfloat";

      config = lib.mkIf config.programs.hyprfloat.enable {
        environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.hyprfloat ];
      };
    };
  });
}