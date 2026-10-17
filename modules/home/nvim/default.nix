{
  inputs,
  ...
}:
{
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
  ];

  programs.nixvim = {
    enable = true;
    nixpkgs.useGlobalPackages = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    wrapRc = true;
    impureRtp = false;
    withNodeJs = false;
    withPerl = false;
    withPython3 = false;
    withRuby = false;
    # Skip 0.12's blocking terminal-background query (~10 ms per launch);
    # 'background' stays dark, which Ghostty always is.
    env.NVIM_NOTTYFAST = "1";
    # Byte compilation already covers what vim.loader would cache (it measured
    # 2-4 ms slower on top), so it stays off and leaves no growing luac cache.
    performance = {
      byteCompileLua = {
        enable = true;
        plugins = true;
        nvimRuntime = true;
        luaLib = true;
      };
      combinePlugins = {
        enable = true;
        standalonePlugins = [
          "friendly-snippets"
          "snacks.nvim"
          "conform.nvim"
          "nvim-dap"
          "neotest"
          "inc-rename.nvim"
        ];
      };
    };
    plugins.lz-n.enable = true;
    extraFiles."lua/core.lua".source = ./lua/core.lua;
  };
}
