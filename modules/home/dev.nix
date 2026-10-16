{ pkgs, ... }: {
  home.packages = with pkgs; [
    (fenix.latest.withComponents [
      "cargo"
      "clippy"
      "rust-analyzer"
      "rust-src"
      "rustc"
      "rustfmt"
    ])
    uv
    python3
    bun
    nodejs
  ];

  home.sessionVariables.RUST_BACKTRACE = "1";
}
