# The only in-editor AI: claudecode.nvim, loaded by its <leader>a keys and
# never in a competitive-programming session (NVIM_CP or vim.g.cp_session).
# There are deliberately no command triggers, so nothing loads it except
# these guarded keys.
{config, ...}: let
  lua = config.lib.nixvim.mkRaw;

  # Each key re-checks the guard, so a session that turns into CP later stops
  # the server instead of acting.
  claude = mode: key: cmd: desc: {
    inherit mode key;
    action = lua ''
      function()
        if require("core").cp_session() then
          if package.loaded.claudecode then pcall(vim.cmd, "ClaudeCodeStop") end
          vim.notify("AI is off in competitive-programming sessions.", vim.log.levels.WARN, { title = "claudecode" })
          return
        end
        require("lz.n").trigger_load("claudecode.nvim")
        vim.cmd("${cmd}")
      end
    '';
    options.desc = desc;
  };
in {
  programs.nixvim = {
    plugins.claudecode = {
      enable = true;
      lazyLoad.settings.lazy = true;
      settings.terminal = {
        split_side = "right";
        split_width_percentage = 0.35;
      };
    };
    # The CLI comes from home.packages (modules/home/ai.nix).
    dependencies.claude-code.enable = false;

    keymaps = [
      (claude "n" "<leader>ac" "ClaudeCode" "Toggle Claude")
      (claude "n" "<leader>af" "ClaudeCodeFocus" "Focus Claude")
      (claude "n" "<leader>ar" "ClaudeCode --resume" "Resume Claude")
      (claude "n" "<leader>aC" "ClaudeCode --continue" "Continue Claude")
      (claude "n" "<leader>am" "ClaudeCodeSelectModel" "Select Claude Model")
      (claude "n" "<leader>ab" "ClaudeCodeAdd %" "Add Current Buffer")
      (claude "x" "<leader>as" "ClaudeCodeSend" "Send to Claude")
      (claude "n" "<leader>aa" "ClaudeCodeDiffAccept" "Accept Diff")
      (claude "n" "<leader>ad" "ClaudeCodeDiffDeny" "Deny Diff")
    ];

    # Add files from the explorer, as LazyVim does in its tree filetypes.
    autoCmd = [
      {
        event = "FileType";
        group = "core";
        pattern = ["snacks_picker_list" "netrw" "minifiles"];
        callback = lua ''
          function(ev)
            vim.keymap.set("n", "<leader>as", function()
              if require("core").cp_session() then
                vim.notify("AI is off in competitive-programming sessions.", vim.log.levels.WARN, { title = "claudecode" })
                return
              end
              require("lz.n").trigger_load("claudecode.nvim")
              vim.cmd("ClaudeCodeTreeAdd")
            end, { buffer = ev.buf, desc = "Add File" })
          end
        '';
      }
    ];
  };
}
