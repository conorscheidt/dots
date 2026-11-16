# dots

My Apple Silicon macOS setup, managed with nix-darwin and Home Manager.
Determinate Nix runs the daemon; Nix owns CLI tools and most apps. Declarative
Homebrew casks provide vendor-updated Brave, Slack, ChatGPT and a few other apps.
The shell and editor use fish, tmux, Ghostty and Nixvim,
with Gruvbox Material throughout.
The wallpaper is `modules/home/wallpaper.png`; a launchd agent sets it at login.

```sh
nix flake check
nix build .#darwinConfigurations.viator.system --no-link
nh darwin switch
```

The host is in `hosts/viator`; shared configuration lives in `modules`.
Skim opens every PDF and is VimTeX's viewer; `pkgs/default.nix` bumps it and
keeps Apple's signature. Pages render in their true colours, because Skim's
dark-mode inversion applies to the whole app, LaTeX output included. Skim reloads
any PDF that changes on disk and opens new ones as tabs. Activation makes
Brave the default browser; macOS asks once to confirm the change. Project
toolchains belong in their own dev shells.

`modules/home/mpv` holds mpv's configuration, scripts and shaders. Finder and
Terminal use the same wrapped package. The Finder bundle has a distinct ID so
LaunchServices can distinguish it from the bare nixpkgs app. uosc, thumbfast
and autoload come from nixpkgs, with local patches for the custom controls and
Dolby Vision thumbnails. `~/.config/mpv/user.conf` holds local OpenSubtitles
credentials. Watch history, resume positions and title preferences also live
outside the Nix store.

T3 Code nightly is a vendor-updated cask; Codex and Claude Code CLIs follow the
flake. New models can need a Claude Code newer than nixpkgs, so
`pkgs/default.nix` may pin it ahead; evaluation warns once nixpkgs catches up.
`modules/darwin/t3code.nix` supplies supported policy defaults for their paths, Claude idle compaction and T3-only desktop-tool overrides. Login, history
and UI preferences remain mutable. ChatGPT stays installed for its desktop tools.
See [project AI integrations](docs/ai-projects.md) for opt-in recipes.

Spotify is the vendor build patched twice: SpotX blocks ads and self-updates,
then Spicetify adds Gruvbox Material colours, true shuffle, Vim-style keys,
hidden podcasts and a full-screen view. A new release needs both to support it;
bump its version and hash in `modules/home/apps.nix`. The pinned DMG stays in
the system closure, so nixpkgs updates can rebuild the app in the meantime.

Brave's cask owns the app and its updates; Home Manager's `package = null`
manages settings without installing a second binary. Exported extension settings
are available in `~/.config/brave/extension-settings`; import them through each
extension's settings page. See [the import notes](modules/home/brave-settings/README.md).

Home Manager copies its app bundles into `~/Applications/Home Manager Apps`
for Spotlight and the Dock. Each switch synchronizes those copies with the flake;
vendor updates belong to cask-managed apps in `/Applications`.
GUI apps added through `nix profile` are separate from Home Manager's app copies.

This is a personal configuration. Change the username, paths and Git identity
before using it; SSH hosts live in an untracked `~/.ssh/config.local`. Activation changes macOS defaults and removes
undeclared Homebrew packages and App Store apps.

Use `nix develop` for the Nix language tools, `nix fmt .` to format, and
`nix build .#nvim` to build the editor separately.

Keys follow one rule per modifier, listed on one page in [KEYS.md](KEYS.md)
(`keys` in a terminal, Cmd-/ anywhere). Cmd drives the workspace through
tmux: Cmd-K picks a project, which opens in Neovim with its last session;
Cmd-J shows or hides a shell under the editor; Cmd-W, Cmd-G and Cmd-F close,
open lazygit and search in whatever is in front, Neovim or a shell.
Ctrl-h/j/k/l move through Neovim splits and tmux panes; Alt-h/j/k/l resize
them. Navigation stops at outer edges. Neovim shows tab pages only when
there are several; use H/L or `<leader>,` for buffers. The explorer is 28
columns wide, with a single search row.

`lc` opens LeetCode in C++; `lc --lang rust` starts in Rust. In an open
problem, `<leader>jL` opens the [plugin's language picker](https://github.com/kawre/leetcode.nvim#-commands)
(`:Leet lang`) to switch languages and keep separate solution files.
`<leader>jR` runs on LeetCode and `<leader>js` submits in either language.
`<leader>jr` runs the samples locally instead: it generates a harness that
reads LeetCode's testcase format (`<leader>jH` regenerates it), saves the
samples as testcases and runs them with `<leader>rt`. It covers C++ and Rust,
including linked lists, trees, in-place and design problems; a Rust `main()`
you wrote yourself is left alone. Codeforces problems sent from the browser
with `<leader>rv` arrive with their testcases in the same place.

In any session, C++, Rust and Python solutions run with `<leader>rr` against
`input.txt` and with `<leader>rt` against every testcase beside the file
(`testcases/<stem>_input<N>.txt` and `_output<N>.txt`, competitest's layout),
with a verdict per case: pass, wrong answer with the diff, crash with the
sanitizer or panic message, or timeout (`vim.g.cp_timeout_ms`, 5 s by
default). `<leader>ra` saves `input.txt` as a new testcase, using the last
clean run's output as the expected output; `<leader>re` opens a testcase's
two files; `<leader>rf` copies the first failing input back to `input.txt`.

Neovim tracks nightly. sidekick.nvim runs the Claude Code and Codex CLIs in
tmux-backed splits (`<leader>a`) and shows Copilot's next edit suggestions,
which Tab jumps to and applies; run `:LspCopilotSignIn` once. Both stay off in
competitive-programming sessions, and the suggestions also stay out of
practice repositories (any directory with the CP layout).

Any `.tex` file compiles with the full TeX Live in the profile: pdfLaTeX by
default, output in `build/`, set in `~/.config/latexmk/latexmkrc`. A document
picks another engine with `% !TeX program = lualatex`, and a project with its
own dev shell and `.latexmkrc` overrides both. Opening a `.tex` file starts
VimTeX's continuous latexmk through the document's direnv, even when Neovim
starts elsewhere (allow the project's `.envrc` once). Each successful compile reloads Skim and
shows the cursor line without raising it; Cmd-Shift-click in Skim jumps back
to the source. Errors open the quickfix list without moving the cursor and
close once fixed, and lualine shows the compile state. `<leader>l` holds
VimTeX's commands (`ll` toggle, `lv` view, `le` errors, `lt` contents, `lc`
clean, `lk` stop), plus `ld` for package docs and `lp` for LanguageTool
proofreading. texlab provides completion, hover, references and ChkTeX.
Badness formats `.tex` and `.bib` on save with one sentence per line; a
`% badness-format off`/`on` pair keeps a table's hand layout, and generated
`gen/` files, `.sty` and `.cls` are skipped. Ghostty runs in its own
fullscreen on the desktop, beside the notch. Cmd-Enter shrinks it to the left
half and uncovers Skim on the right; Cmd-Enter again restores it. macOS asks
once to let the terminal control Skim.

VS Code is for notebooks, with clean embedded Neovim, strict Pylance, Ruff,
and project-local Python environments. Cmd-S formats, fixes and sorts
imports, including notebook-scoped fixes that preserve cross-cell imports.
Delayed autosave writes files but does not run VS Code's notebook save actions.
Select the project's `.venv` kernel; its dependencies (including `ipykernel`)
belong in the project, not the global Python installation.

In `package.json` and `Cargo.toml`, `<leader>p` groups dependency actions:
`pv` lists versions (including prereleases), `pU` upgrades the current
dependency, `pA` upgrades all, and `pr` refreshes annotations. Cargo also
has `pf` for features, `pu`/`pa` for compatible updates, and `pl` to update
its lockfile after saving. For JavaScript, `pN` opens a prerelease-aware
upgrade picker. npm/yarn/pnpm/Bun are detected from the project's lockfile;
bulk npm upgrades preserve range style and run that manager's install.
Bun is available for compatible projects; `bun run --bun <script>` explicitly
selects its runtime. `node`/`npm`/`npx` provide standard Node compatibility,
and dependency actions keep the detected package manager. Bun installs share
its global package cache even when the project runs under Node.
Project dev shells override these fallbacks.
Interactive `rm` expands to `trash`, using the native system Trash and
preserving Put Back information; scripts retain ordinary `rm`. `unrm` opens
the Trash in Finder.
The trash tool accepts `-r`, `-f` and `-i` for compatibility, but `-i` does not
prompt and `-f` does not suppress missing-file errors.

A weekly root job prunes system and user generations, keeping at least three
and everything from the last 14 days. It also drops `result` links older than
14 days but keeps every direnv root, and logs to `/var/log/nh-clean.log`.
Determinate Nixd's automatic garbage collector frees the store. Flake updates
are reviewed before activation.

VS Code and its extensions follow `flake.lock`, except Python Environments,
which nixpkgs lags: its Marketplace version and hash live in
`modules/home/vscode.nix`. Update both together. Automatic app and extension
updates are disabled; the mutable extension directory permits manually
installed extras. Reopen Neovim and reload Ghostty's configuration;
`tmux source-file ~/.config/tmux/tmux.conf` updates the running tmux server
without ending sessions.
New tmux panes attach to the macOS GUI session before starting Fish so Touch ID
works for sudo. Existing panes keep their original session context.

If activation stops at `checkAppManagementPermission`, enable App Management
for the terminal running the switch in System Settings → Privacy & Security,
then rerun it. The system profile and some home files may already be updated,
but `/run/current-system` is created only after activation finishes successfully.
VS Code uses the Nix-pinned Fish executable directly; task shells use `/bin/sh`.

`pkgs/mixxx-bin` and `pkgs/openfader` package the official stable Apple Silicon
apps with pinned checksums. Home Manager installs them; build either separately
with `nix build .#mixxx-bin` or `nix build .#openfader`. Update them with
`nix run nixpkgs#nix-update -- --flake openfader` and
`nix run nixpkgs#nix-update -- --flake mixxx-bin --url https://github.com/mixxxdj/mixxx`.
`pkgs/default.nix` also pins InstantSpaceSwitcher ahead of nixpkgs; evaluation
warns once nixpkgs catches up, and the override can then go.
Serato DJ Lite requires a one-time installer download from Serato. If the
installer is missing from the store, the build prints the download and import
instructions. The package is fixed-output, so nixpkgs updates never rebuild it
and the installer is needed again only for a new version. Build it separately with `nix build .#serato-dj-lite`.
