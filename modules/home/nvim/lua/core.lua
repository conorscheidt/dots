-- Project detection shared by keymaps, LSP and formatting. Everything here
-- reads the project's own files; nothing names a project or a path.
local M = {}

local function read_json(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local ok, data = pcall(vim.json.decode, fd:read("*a"))
  fd:close()
  return ok and type(data) == "table" and data or nil
end

local function bufpath(buf)
  local name = vim.api.nvim_buf_get_name(buf == 0 and vim.api.nvim_get_current_buf() or buf)
  return name ~= "" and name or vim.uv.cwd() or ""
end

-- Workspace root, in LazyVim's order: attached LSP root, then git, then cwd.
function M.root(buf)
  buf = buf or 0
  local path = bufpath(buf)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    local dir = client.root_dir
    if dir and vim.startswith(path, dir) then
      return dir
    end
  end
  return vim.fs.root(buf, ".git") or vim.uv.cwd()
end

function M.git_root(buf)
  return vim.fs.root(buf or 0, ".git") or vim.uv.cwd()
end

-- JS/TS project root: nearest lockfile (or git), skipping Deno projects.
function M.js_root(buf)
  local locks = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }
  local root = vim.fs.root(buf, { locks, { "package.json" }, { ".git" } })
  local deno = vim.fs.root(buf, { "deno.json", "deno.jsonc", "deno.lock" })
  if deno and (not root or #deno >= #root) then
    return nil
  end
  return root or vim.uv.cwd()
end

local ts_cache = {}

-- TypeScript major version: the installed copy wins, else the declared range.
function M.ts_major(root)
  if ts_cache[root] == nil then
    local installed = read_json(vim.fs.joinpath(root, "node_modules/typescript/package.json"))
    local version = installed and installed.version
    if not version then
      local pkg = read_json(vim.fs.joinpath(root, "package.json")) or {}
      version = (pkg.devDependencies or {}).typescript or (pkg.dependencies or {}).typescript
    end
    ts_cache[root] = tonumber(tostring(version or ""):match("(%d+)")) or 0
  end
  return ts_cache[root]
end

-- TypeScript 7 ships the native `tsc --lsp`; older projects keep tsserver.
function M.ts_native(root)
  return M.ts_major(root) >= 7
end

-- Nearest directory that configures Tailwind (config file or dependency).
function M.tailwind_root(buf)
  return vim.fs.root(buf, function(name, path)
    if name:match("^tailwind%.config%.") then
      return true
    end
    if name == "package.json" then
      local pkg = read_json(vim.fs.joinpath(path, name)) or {}
      return ((pkg.dependencies or {}).tailwindcss or (pkg.devDependencies or {}).tailwindcss) ~= nil
    end
    return false
  end)
end

-- Config markers for tools that must only run where a project opted in.
M.markers = {
  biome = { "biome.json", "biome.jsonc", ".biome.json", ".biome.jsonc" },
  oxlint = { ".oxlintrc.json", ".oxlintrc.jsonc", "oxlint.config.ts" },
}

function M.oxfmt_root(path)
  return vim.fs.root(path, function(name)
    return name:match("^%.oxfmtrc") ~= nil or name:match("^oxfmt%.config%.") ~= nil
  end)
end

-- Prettier only runs where the project configured it.
local prettier_files = {
  ".prettierrc",
  ".prettierrc.json",
  ".prettierrc.json5",
  ".prettierrc.yaml",
  ".prettierrc.yml",
  ".prettierrc.toml",
  ".prettierrc.js",
  ".prettierrc.cjs",
  ".prettierrc.mjs",
  ".prettierrc.ts",
  ".prettierrc.cts",
  ".prettierrc.mts",
  "prettier.config.js",
  "prettier.config.cjs",
  "prettier.config.mjs",
  "prettier.config.ts",
  "prettier.config.cts",
  "prettier.config.mts",
}

function M.prettier_root(path)
  return vim.fs.root(path, function(name, dir)
    if vim.list_contains(prettier_files, name) then
      return true
    end
    return name == "package.json" and (read_json(vim.fs.joinpath(dir, name)) or {}).prettier ~= nil
  end)
end

-- A tool from the nearest node_modules/.bin, or nil.
function M.node_bin(path, name)
  local root = vim.fs.root(path, function(n, dir)
    return n == "node_modules" and vim.uv.fs_stat(vim.fs.joinpath(dir, n, ".bin", name)) ~= nil
  end)
  return root and vim.fs.joinpath(root, "node_modules/.bin", name) or nil
end

-- What Biome formats; Astro, Svelte, Vue and HTML fully only when the
-- project's config opts in, otherwise their script blocks.
local biome_fts = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  json = true,
  jsonc = true,
  css = true,
  graphql = true,
  html = true,
  astro = true,
  svelte = true,
  vue = true,
}

-- Exactly one formatter per web file, and only the one the project chose:
-- oxfmt, then Biome, then Prettier (from the project's node_modules, so its
-- plugins resolve). A project that configures Prettier without installing it
-- is left alone rather than reformatted by an LSP in a different style.
-- Unconfigured files fall back to the language server's formatter.
function M.web_formatters(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then
    return {}
  end
  if M.oxfmt_root(path) then
    return { "oxfmt" }
  end
  if biome_fts[vim.bo[buf].filetype] and vim.fs.root(path, M.markers.biome) then
    return { "biome-check" }
  end
  if M.prettier_root(path) then
    if M.node_bin(path, "prettier") then
      return { "prettier" }
    end
    vim.notify_once("Prettier is configured but not installed here; run the package manager's install.", vim.log.levels.WARN)
    return { lsp_format = "never" }
  end
  return {}
end

-- The project's virtualenv interpreter (uv and venv both create .venv),
-- else an activated one.
function M.venv_python(path)
  local root = path and vim.fs.root(path, ".venv")
  local python = root and vim.fs.joinpath(root, ".venv/bin/python")
  if python and vim.uv.fs_stat(python) then
    return python
  end
  local venv = vim.env.VIRTUAL_ENV
  return venv and vim.fs.joinpath(venv, "bin/python") or nil
end

-- clangd that matches the compiler builds use. Inside a devShell the shell's
-- clangd wins; otherwise Apple's /usr/bin/clangd, which matches the
-- /usr/bin/clang++ that builds use (nixpkgs clangd mixes its own libc++
-- headers with the macOS SDK and reports spurious errors).
function M.clangd()
  if vim.env.IN_NIX_SHELL and vim.fn.exepath("clangd") ~= "" then
    return vim.fn.exepath("clangd")
  end
  if vim.fn.executable("/usr/bin/clangd") == 1 then
    return "/usr/bin/clangd"
  end
  return "clangd"
end

-- A CP session (lc/nvt launchers, leetcode.nvim or competitest) is AI-free.
function M.cp_session()
  return (vim.env.NVIM_CP or "") ~= "" or vim.g.cp_session == true
end

return M
