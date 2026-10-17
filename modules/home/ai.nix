# The Claude and ChatGPT/Codex desktop apps own their settings files (they
# rewrite them), so Nix only supplies binaries and the shared global
# instructions. The instructions are installed as real files because Claude's
# desktop app ignores a symlinked ~/.claude/CLAUDE.md.
{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    claude-code
    rtk # Claude Code PreToolUse hook: compacts verbose command output
  ];

  home.sessionVariables.DISABLE_AUTOUPDATER = "1"; # claude-code updates with the flake

  # Edits made through the apps are kept as <file>.hm-backup before replacing.
  home.activation.agentInstructions = lib.hm.dag.entryAfter ["writeBoundary"] ''
    for f in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"; do
      if ! cmp -s ${./agents.md} "$f"; then
        if [ -e "$f" ]; then run cp "$f" "$f.hm-backup"; fi
        run install -Dm644 ${./agents.md} "$f"
      fi
    done
  '';
}
