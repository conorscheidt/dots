# Project AI integrations

Keep toolchains in the project's dev shell and credentials outside Git. T3 uses
the provider CLIs' configuration; enabling a plugin does not guarantee that every
provider frontend exposes its tools. Check the provider's loaded tools in T3.
The shared competitive-programming guard remains in place.

## Cloudflare

For a trusted Cloudflare project, add to `.codex/config.toml`:

```toml
[mcp_servers.cloudflare]
url = "https://mcp.cloudflare.com/mcp"
```

Run `codex mcp login cloudflare` from that repository. For Claude Code, run:

```sh
claude mcp add --transport http cloudflare --scope project https://mcp.cloudflare.com/mcp
```

This writes project `.mcp.json`; authentication stays outside the repository.
The endpoint uses [Code Mode](https://github.com/cloudflare/mcp), keeping API
discovery and execution behind a small tool interface. Avoid adding the same
server if the current provider already exposes it through the Cloudflare plugin.
`codex mcp add` writes user configuration, so use the project file above instead.

## Documentation and code navigation

Use the existing Context7 integration for framework documentation. An OpenAI
project can opt into the [official documentation MCP](https://developers.openai.com/learn/docs-mcp):

```toml
[mcp_servers.openaiDocs]
url = "https://developers.openai.com/mcp"
```

For Claude, the equivalent is
`claude mcp add --transport http openaiDocs --scope project https://developers.openai.com/mcp`.

Claude's [code-intelligence plugins](https://code.claude.com/docs/en/plugins/code-intelligence)
require their language-server binaries on the provider's PATH. Install only the
relevant project plugin, if it is not already enabled:

```sh
claude plugin install rust-analyzer-lsp@claude-plugins-official --scope project
claude plugin install clangd-lsp@claude-plugins-official --scope project
claude plugin install typescript-lsp@claude-plugins-official --scope project
```

Rust projects should use their pinned `rust-analyzer`; C++ projects should supply
`clangd` and `compile_commands.json`. For the TypeScript plugin, add
`pkgs.typescript-language-server` and the project's compatible TypeScript and
Node versions to its dev shell. Neovim's vtsls is a different executable.
Start the provider from that environment and verify the server actually loaded.

Use `rg` for text, `ast-grep` for syntax and LSP for resolved symbols. Keep checks
project-native; another global semantic MCP adds no demonstrated benefit here.

[Codex project configuration](https://learn.chatgpt.com/docs/config-file/config-basic)
loads only in trusted projects. [Claude MCP scopes](https://code.claude.com/docs/en/mcp)
keep repository integrations separate from user configuration.
