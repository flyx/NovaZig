# Zig Language Support for Nova

This repository contains the Zig language extension for the [Nova][1] editor.

This readme is developer documentation, refer to [REDAME-user.md](/README-user.md) for user documentation.
Users should install this extension from the Nova extension gallery (yet to be released).

## Building & Testing

This extension uses [tree-sitter-zig][2] and thus must compile the C code implementing the syntax.
It uses [Nix Flakes][2] as build system, you'll also need the Xcode command line tools.
To build the extension, do

    nix build --impure

We use `--impure` because the clang provided by Nixpkgs currently cannot build fat binaries.
Therefore, we use the system-provided clang (hence the Xcode command line tools), which requires `--impure`.

Afterwards, you should have a `result` symlink containing a folder `Zig.novaextension`.
Open this folder in a new window to test the extension.
In the new window, select `Extensions->Activate Project as Extension` from the menu.

Mind that rebuilding the extension will create a *different* folder, not update the previous one.
This is how Nix works.
To test the new version, deactivate the previous version, close that window, then open the new folder.
Nova might not update the `result` symlink on `nix build` so I usually issue a `rm result` first.

## Tree Sitter Integration

`Queries/highlights.scm` is a modified version based on the one from `tree-sitter-zig`.
Changes concern mostly the tags Nova expects from the queries.

## License

[MIT](/License.md)

 [1]: https://nova.app/
 [2]: https://nixos.wiki/wiki/Flakes