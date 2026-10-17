# sidekick.nvim: the Claude Code and Codex CLIs in a split, and Copilot's next
# edit suggestions. Both are off in competitive-programming sessions, and the
# suggestions also stay out of practice repositories (a CP root's markers),
# where the CLI remains available for coaching.
{ config, ... }:
let
  inherit (config.lib.nixvim) mkRaw;

  guarded =
    body:
    mkRaw ''
      function()
        if require("core").cp_session() then
          vim.notify("AI is off in competitive-programming sessions.", vim.log.levels.WARN, { title = "sidekick" })
          return
        end
        ${body}
      end
    '';

  key = mode: lhs: body: desc: {
    inherit mode;
    key = lhs;
    action = guarded body;
    options.desc = desc;
  };
  cli = call: ''require("sidekick.cli").${call}'';
  # A CP session, or a buffer under a CP root (see cp/init.lua).
  practice =
    buf: ''(require("core").cp_session() or vim.fs.root(${buf}, { ".leetgen", ".include" }) ~= nil)'';
in
{
  programs.nixvim = {
    plugins.sidekick = {
      enable = true;
      # After the first screen: suggestions hook buffer events, not a command.
      lazyLoad.settings.event = "DeferredUIEnter";
      settings = {
        nes.enabled = mkRaw ''
          function(buf)
            return not ${practice "buf"} and vim.g.sidekick_nes ~= false and vim.b[buf].sidekick_nes ~= false
          end
        '';
        # CLI sessions live in tmux, so they outlast the Neovim that opened them.
        cli.mux = {
          enabled = true;
          backend = "tmux";
        };
      };
    };

    # Next edit suggestions come from Copilot's server. Sign in once with
    # `:LspCopilotSignIn`, which exists in buffers the server is attached to.
    lsp.servers.copilot = {
      enable = true;
      packageFallback = true;
      config.root_dir = mkRaw ''
        function(bufnr, on_dir)
          if not ${practice "bufnr"} then on_dir(vim.fs.root(bufnr, ".git")) end
        end
      '';
    };

    keymaps = [
      {
        mode = "n";
        key = "<Tab>";
        action = mkRaw ''
          function()
            local ok, sidekick = pcall(require, "sidekick")
            if not (ok and sidekick.nes_jump_or_apply()) then return "<Tab>" end
          end
        '';
        options = {
          expr = true;
          desc = "Next edit: jump to it, then apply";
        };
      }
      (key [ "n" "t" "i" "x" ] "<C-.>" (cli "focus()") "Focus AI CLI")
      (key "n" "<leader>aa" (cli "toggle()") "Toggle AI CLI")
      (key "n" "<leader>ac" (cli ''toggle({ name = "claude", focus = true })'') "Toggle Claude")
      (key "n" "<leader>ax" (cli ''toggle({ name = "codex", focus = true })'') "Toggle Codex")
      (key "n" "<leader>as" (cli "select({ filter = { installed = true } })") "Select AI CLI")
      (key "n" "<leader>ad" (cli "close()") "Detach AI CLI")
      (key [ "n" "x" ] "<leader>at" (cli ''send({ msg = "{this}" })'') "Send This")
      (key "n" "<leader>af" (cli ''send({ msg = "{file}" })'') "Send File")
      (key "x" "<leader>av" (cli ''send({ msg = "{selection}" })'') "Send Selection")
      (key [ "n" "x" ] "<leader>ap" (cli "prompt()") "Pick Prompt")
    ];
  };
}
