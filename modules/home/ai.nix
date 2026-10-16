# Provider CLIs and shared instructions; authentication and mutable app state
# stay outside Nix. Real instruction files remain editable by the clients.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The profile path, not the store path: Codex trusts a hook by its hash, so a
  # store path would need re-approval after every rtk update.
  rtk = "${config.home.profileDirectory}/bin/rtk";
  # RTK compacts verbose command output before the agent reads it.
  rtkHook = agent: [
    {
      matcher = "Bash";
      hooks = [
        {
          type = "command";
          command = "${rtk} hook ${agent}";
        }
      ];
    }
  ];
in
{
  home.packages = [ pkgs.rtk ];

  programs.codex = {
    enable = true;
    # Only hooks.json is managed; config.toml stays Codex's own.
    hooks.PreToolUse = rtkHook "codex";
  };

  programs.claude-code = {
    enable = true;
    # Merged into the app-writable settings.json; other keys are left alone.
    mutableSettings = true;
    settings = {
      hooks.PreToolUse = rtkHook "claude";
      # Applied by Claude Code itself, so it holds however it is launched (T3
      # Code too); unlike DISABLE_AUTOUPDATER it also blocks `claude update`
      # and `claude install`.
      env.DISABLE_UPDATES = "1";
    };
  };

  # Edits made through the apps are kept as <file>.hm-backup before replacing.
  home.activation.agentInstructions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for f in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"; do
      if ! cmp -s ${./agents.md} "$f"; then
        if [ -e "$f" ]; then run cp "$f" "$f.hm-backup"; fi
        run install -Dm644 ${./agents.md} "$f"
      fi
    done
  '';
}
