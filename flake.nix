{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    nova-utils.url = "github:flyx/nova-extension-utils";
    tree-sitter-zig = {
      url = "github:maxxnino/tree-sitter-zig";
      flake = false;
    };
    utils.url = "github:numtide/flake-utils";
    logo = {
      url = "github:ziglang/logo";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, nova-utils, tree-sitter-zig, utils, logo }:
    utils.lib.eachSystem [
      utils.lib.system.x86_64-darwin
      utils.lib.system.aarch64-darwin
    ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nova-utils.overlays.default ];
        };
        syntax-lib = pkgs.buildNovaTreeSitterLib {
          langName = "zig";
          src = tree-sitter-zig;
        };
      in {
        packages.default = pkgs.buildNovaExtension {
          name = "zig";
          version = "0.1.1";
          src = self;
          identifier = "org.flyx.zig";
          organization = "Felix Krause";
          description = "Zig language support";
          categories = [ "languages" "commands" "completions" ];
          license = "MIT";
          activationEvents = [ "onLanguage:zig" "onWorkspaceContains:*.zig" ];
          bugs = "https://github.com/flyx/NovaZig/issues";
          repository = "https://github.com/flyx/NovaZig";
          funding = "https://github.com/sponsors/flyx";
          treeSitterLibs = [ syntax-lib ];
          derivationParams = {
            buildInputs = with pkgs; [ gnused librsvg ];
            postInstall = ''
              ${pkgs.gnused}/bin/sed 's/@fold/@subtree/g' ${tree-sitter-zig}/queries/folds.scm >$extDir/Queries/folds.scm
              ${pkgs.librsvg}/bin/rsvg-convert -w 32 -h 32 ${logo}/zig-mark.svg -o $extDir/extension.png
              ${pkgs.librsvg}/bin/rsvg-convert -w 64 -h 64 ${logo}/zig-mark.svg -o $extDir/extension@2x.png
            '';
          };
          config = [
            {
              name = "compiler";
              title = "Settings for the Zig compiler";
              type = "section";
              children = [
                {
                  name = "path";
                  title = "Path to the Zig compiler";
                  type = "path";
                  default = "zig";
                }
                {
                  name = "formatOnSave";
                  title = "Format on Save";
                  type = "boolean";
                  default = false;
                }
              ];
            }
            {
              name = "langServer";
              title = "Settings for the ZLS lanugage server";
              type = "section";
              children = [
                {
                  name = "path";
                  title = "Path to ZLS";
                  type = "path";
                  default = "zls";
                }
              ];
            }
          ];
          main = "main.js";
          entitlements = {
            process = true;
            filesystem = "readonly";
          };
          commands.editor = [{
            title = "Format Zig File";
            command = "org.flyx.zig.command.fmt";
            when = "editorHasFocus && editorSyntax == 'zig'";
            shortcut = "opt-shift-F";
          }];
        };
      });
}
