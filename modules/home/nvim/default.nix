# Wrapped Neovim; project toolchains take precedence over bundled fallbacks.
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
    nixpkgs.useGlobalPackages = true;
    nixpkgs.source = inputs.nixpkgs;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Keep ~/.config/nvim off runtimepath, while retaining normal state/cache paths.
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
