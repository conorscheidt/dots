# Neovim via Nixvim: one wrapped, byte-compiled build with every tool from
# nixpkgs. Project toolchains (devShells, node_modules) take precedence over
# the fallbacks shipped here.
{inputs, ...}: {
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./options.nix
    ./ui.nix
    ./editing.nix
    ./completion.nix
    ./lsp.nix
    ./format.nix
    ./debug.nix
    ./ai.nix
    ./cp.nix
  ];

  programs.nixvim = {
    enable = true;
    # One nixpkgs for the whole system (and its allowUnfree: jupytext.nvim
    # ships without a license).
    nixpkgs.useGlobalPackages = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # The config lives in the wrapper, never on disk, and impureRtp = false
    # keeps ~/.config/nvim and ~/.local/share/nvim/site off the runtimepath.
    # The default app name is kept on purpose: shada, undo, sessions and the
    # LeetCode login in ~/.cache/nvim carry over from LazyVim.
    wrapRc = true;
    impureRtp = false;

    withNodeJs = false;
    withPerl = false;
    withPython3 = false;
    withRuby = false;

    luaLoader.enable = true;
    performance = {
      byteCompileLua = {
        enable = true;
        plugins = true;
        nvimRuntime = true;
        luaLib = true;
      };
      combinePlugins = {
        enable = true;
        # blink.cmp only finds snippets in a plugin's own snippets/ dir;
        # snacks ships queries/markdown/injections.scm, which collides with
        # the markdown grammar's own (both must stay on the runtimepath);
        # conform and blink both ship doc/recipes.md.
        standalonePlugins = ["friendly-snippets" "snacks.nvim" "conform.nvim"];
      };
    };

    plugins.lz-n.enable = true;

    extraFiles."lua/core.lua".source = ./lua/core.lua;
  };
}
