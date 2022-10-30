{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-22.05;
    tree-sitter-zig = {
      url = github:maxxnino/tree-sitter-zig;
      flake = false;
    };
    utils.url = github:numtide/flake-utils;
    nova = {
      url = "https://download.panic.com/nova/Nova%2010.zip";
      flake = false;
    };
  };
  outputs = {
    self, nixpkgs, tree-sitter-zig, utils, nova
  }: utils.lib.eachSystem [
    utils.lib.system.x86_64-darwin
    utils.lib.system.aarch64-darwin
  ] (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    syntax-lib = pkgs.stdenvNoCC.mkDerivation {
      name = "tree-sitter-zig-dylib";
      src = tree-sitter-zig;
      buildPhase = ''
        FRAMEWORKS_PATH="${nova}/Contents/Frameworks/"
        BUILD_FLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=11.0 -Isrc -Wall -Wextra"
        LDFLAGS="$BUILD_FLAGS -F$FRAMEWORKS_PATH -framework SyntaxKit -rpath @loader_path/../Frameworks"
        LINKSHARED="-dynamiclib -Wl,-install_name,libtree-sitter-zig.dylib,-rpath,@executable_path/../Frameworks"
        /usr/bin/clang -c $BUILD_FLAGS -o parser.o src/parser.c
        echo "linking"
        /usr/bin/clang $LDFLAGS $LINKSHARED parser.o -o libtree-sitter-zig.dylib
      '';
      installPhase = ''
        cp libtree-sitter-zig.dylib $out
      '';
    };
    
    version = "0.1.0";
    meta = {
      description = "Zig language support";
      homepage = "https://github.com/flyx";
      license = nixpkgs.lib.licenses.mit;
      maintainers = [ "Felix Krause" ];
    };
  in {
    defaultPackage = pkgs.stdenv.mkDerivation {
      pname = "Zig.novaextension";
      version = "0.1.0";
      src = self;
      JSON = builtins.toJSON {
        identifier = "org.flyx.Zig";
        name = "zig";
        organization = "Felix Krause";
        description = meta.description;
        inherit version;
        categories = [ "languages" ];
      };
      buildInputs = [ pkgs.gnused ];
    installPhase = ''
      mkdir -p $out/Zig.novaextension/Queries
      cp -r -t $out/Zig.novaextension Completions Syntaxes Images Queries CHANGELOG.md
      cp README-user.md $out/Zig.novaextension/README.md
      cp ${syntax-lib} $out/Zig.novaextension/Syntaxes/libtree-sitter-zig.dylib
      printenv JSON >$out/Zig.novaextension/extension.json
      ${pkgs.gnused}/bin/sed 's/@fold/@subtree/g' ${tree-sitter-zig}/queries/folds.scm >$out/Zig.novaextension/Queries/folds.scm
    '';
    };
  });
}