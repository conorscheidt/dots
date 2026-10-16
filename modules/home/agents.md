# Environment

macOS on an M4 MacBook Pro, configured by nix-darwin + Home Manager (flake at `~/dev/dots`); fish, tmux, Ghostty, Neovim (Nixvim).
Tools come from Nix. Never suggest `brew install`, global `npm`/`bun`/`cargo install`, or curl-pipe installers: propose the Nix change (a `home.packages` entry or a project devShell), or use `nix shell nixpkgs#tool` for a one-off.
Projects pin their own toolchains (direnv devShells, `rust-toolchain.toml`, `package.json`, `mise.toml`); use those rather than the global fallbacks.
Shell output may be compacted by RTK; `rtk proxy <cmd>` gives raw output.

# Output

- No preamble or postamble. Don't restate the request or summarize what you just did.
- Prose over bullets unless structure genuinely earns it.
- Disagree when I'm wrong. I want pushback and tradeoffs, not agreement.

# Search

- `rg` for text: literals, comments, config values.
- `ast-grep run -l <lang> -p '<pattern>'` for structure: impls, call sites, signatures. Use metavariables (`$X`, `$$$ARGS`). An empty result can mean a wrong pattern (e.g. a missing `pub`), so validate the pattern against a known match before trusting it.
- The language server for anything needing type resolution: definitions, references, which impl satisfies a bound, macro expansion.
