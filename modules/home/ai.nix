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

  home.activation.agentInstructions = lib.hm.dag.entryAfter ["writeBoundary"] ''
    for f in .claude/CLAUDE.md .codex/AGENTS.md; do
      run install -Dm644 ${./agents.md} "$HOME/$f"
    done
  '';
}
