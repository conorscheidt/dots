# Global fallbacks only: projects pin their own toolchains through direnv
# devShells, rust-toolchain.toml, mise or package.json, which take precedence.
{
  config,
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    (inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system}.latest.withComponents [
      "cargo"
      "clippy"
      "rust-analyzer"
      "rust-src"
      "rustc"
      "rustfmt"
    ])
    cargo-nextest
    cargo-edit
    nodejs_latest
    bun
    pnpm
    wrangler
    uv
    python3 # global fallback; projects use their uv-managed .venv
    ast-grep
    typescript-language-server # Claude/Codex typescript-lsp plugins
    typescript
  ];

  home.sessionVariables.RUST_BACKTRACE = "1";

  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/dev/dots";
  };
}
