{
  inputs = {
    nixpkgs.url     = github:NixOS/nixpkgs/nixos-22.05;
    tree-sitter-zig = {
      url   = github:maxxnino/tree-sitter-zig;
      flake = false;
    };
    utils.url = github:numtide/flake-utils;
    nova      = {
      url   = "https://download.panic.com/nova/Nova%2010.zip";
      flake = false;
    };
    logo = {
      url   = github:ziglang/logo;
      flake = false;
    };
  };
  outputs = {
    self, nixpkgs, tree-sitter-zig, utils, nova, logo
  }: utils.lib.eachSystem [
    utils.lib.system.x86_64-darwin
    utils.lib.system.aarch64-darwin
  ] (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    syntax-lib = pkgs.stdenvNoCC.mkDerivation {
      name       = "tree-sitter-zig-dylib";
      src        = tree-sitter-zig;
      buildPhase = ''
        FRAMEWORKS_PATH="${nova}/Contents/Frameworks/"
        BUILD_FLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=11.0 -Isrc -Wall -Wextra"
        LDFLAGS="$BUILD_FLAGS -F$FRAMEWORKS_PATH -framework SyntaxKit -rpath @loader_path/../Frameworks"
        LINKSHARED="-dynamiclib -Wl,-install_name,libtree-sitter-zig.dylib,-rpath,@executable_path/../Frameworks"
        /usr/bin/clang -c $BUILD_FLAGS -o parser.o src/parser.c
        echo "linking"
        /usr/bin/clang $LDFLAGS $LINKSHARED parser.o -o libtree-sitter-zig.dylib
        /usr/bin/codesign -s - libtree-sitter-zig.dylib
      '';
      installPhase = ''
        cp libtree-sitter-zig.dylib $out
      '';
    };
    
    version = "0.1.0";
    meta    = {
      description = "Zig language support";
      homepage    = "https://github.com/flyx";
      license     = nixpkgs.lib.licenses.mit;
      maintainers = [ "Felix Krause" ];
    };
    cfgSection = {basePath, description, items, ...}@args: isWorkspace: {
      children = builtins.map (
        item: {
          key = basePath + "." + item.id + (if isWorkspace then "" else ".default");
        } // (builtins.removeAttrs item [ "id" "default" ]) // (if isWorkspace then {} else {
          inherit (item) default;
        })
      ) items;
      description = if isWorkspace then
        (description + " (if set, overrides default)")
      else (description + " (may be overridden per workspace)");
      type = "section";
    } // (builtins.removeAttrs args [ "basePath" "items" ]);
    configItems = isWorkspace: [
      (cfgSection {
        basePath    = "org.flyx.zig";
        description = "Settings for the Zig compiler";
        items       = [
          {
            id      = "path";
            title   = "Path to the Zig compiler";
            type    = "path";
            default = "zig";
          }
          {
            id      = "fmt";
            title   = "Format on Save";
            type    = "boolean";
            default = false;
          }
        ];
      } isWorkspace)
      (cfgSection {
        basePath    = "org.flyx.zig.zls";
        description = "Settings for the ZLS lanugage server";
        items       = [
          {
            id      = "path";
            title   = "Path to ZLS";
            type    = "path";
            default = "zls";
          }
        ];
      } isWorkspace)
    ];
  in {
    defaultPackage = pkgs.stdenv.mkDerivation {
      pname   = "Zig.novaextension";
      version = "0.1.0";
      src     = self;
      JSON    = builtins.toJSON {
        inherit version;
        identifier       = "org.flyx.Zig";
        name             = "zig";
        organization     = "Felix Krause";
        description      = meta.description;
        categories       = [ "languages" "commands" "completions" ];
        config           = configItems false;
        configWorkspace  = configItems true;
        main             = "main.js";
        bugs             = "https://github.com/flyx/NovaZig/issues";
        repository       = "https://github.com/flyx/NovaZig";
        funding          = "https://github.com/sponsors/flyx";
        license          = "MIT";
        activationEvents = [
          "onLanguage:zig"
          "onWorkspaceContains:*.zig"
        ];
        entitlements = {
          process    = true;
          filesystem = "readonly";
        };
        commands.editor = [
          {
            title    = "Format Zig File";
            command  = "org.flyx.zig.command.fmt";
            when     = "editorHasFocus && editorSyntax == 'zig'";
            shortcut = "opt-shift-F";
          }
        ];
      };
      buildInputs = with pkgs; [ gnused librsvg ];
    installPhase = ''
      mkdir -p $out/Zig.novaextension/Queries
      cp -r -t $out/Zig.novaextension Completions Scripts Syntaxes Queries CHANGELOG.md
      cp README-user.md $out/Zig.novaextension/README.md
      cp ${syntax-lib} $out/Zig.novaextension/Syntaxes/libtree-sitter-zig.dylib
      printenv JSON >$out/Zig.novaextension/extension.json
      ${pkgs.gnused}/bin/sed 's/@fold/@subtree/g' ${tree-sitter-zig}/queries/folds.scm >$out/Zig.novaextension/Queries/folds.scm
      ${pkgs.librsvg}/bin/rsvg-convert -w 16 -h 16 ${logo}/zig-mark.svg -o $out/Zig.novaextension/extension.png
      ${pkgs.librsvg}/bin/rsvg-convert -w 32 -h 32 ${logo}/zig-mark.svg -o $out/Zig.novaextension/extension@2x.png
    '';
    };
  });
}