# dots

My Apple Silicon macOS setup, managed with nix-darwin and Home Manager.
Determinate Nix runs the daemon; Nix owns CLI tools and most apps. Homebrew
handles a few casks. The shell and editor use fish, tmux, Ghostty and Nixvim,
with Gruvbox Material throughout.

```sh
nix flake check
nix build .#darwinConfigurations.viator.system --no-link
nh darwin switch
```

The host is in `hosts/viator`; shared configuration lives in `modules`.
`pkgs/zathura` packages the GTK3 reader for native macOS scrolling.
Project toolchains belong in their own dev shells.

This is a personal configuration. Change the username, paths, Git identity
and SSH hosts before using it. Activation changes macOS defaults and removes
undeclared Homebrew packages.

Use `nix develop` for the Nix language tools, `nix fmt .` to format, and
`nix build .#nvim` to build the editor separately.

Serato DJ Lite requires a one-time installer download from Serato. If the
installer is missing from the store, the build prints the download and import
instructions. Build it separately with `nix build .#serato-dj-lite`.
