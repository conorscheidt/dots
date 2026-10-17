-- Competitive-programming session state and the CP root.
--
-- The root holds the usual layout: leetcode/ (leetcode.nvim storage),
-- templates/, .include/ (<bits/stdc++.h> shim) and .leetgen/ (harness header).

local M = {}

local MARKERS = { ".leetgen", ".include" }

---vim.g.cp_root or $CP_ROOT (the lc/nvt launchers export the directory they
---start in), else the nearest ancestor of `path` with the CP layout, else the
---git root of cwd, else cwd.
---@param path? string file or directory to resolve from; defaults to the current buffer
---@return string
function M.root(path)
  local explicit = vim.g.cp_root or vim.env.CP_ROOT
  if explicit and explicit ~= "" then
    return (vim.fs.normalize(vim.fn.fnamemodify(explicit, ":p")):gsub("(.)/$", "%1"))
  end
  local cwd = vim.fn.getcwd()
  path = path or vim.api.nvim_buf_get_name(0)
  return vim.fs.root(path ~= "" and path or cwd, MARKERS) or vim.fs.root(cwd, ".git") or cwd
end

---@param root? string
---@return { root: string, include: string, leetgen: string, templates: string, leetcode: string }
function M.paths(root)
  root = root or M.root()
  local include = root .. "/.include"
  if not vim.uv.fs_stat(include .. "/bits/stdc++.h") then
    include = vim.g.cp_shim -- bundled shim, so any directory works as a root
  end
  return {
    root = root,
    include = include,
    leetgen = root .. "/.leetgen",
    templates = root .. "/templates",
    leetcode = root .. "/leetcode",
  }
end

---Mark this Neovim as a CP session. The AI loader refuses to start once set.
function M.session()
  vim.g.cp_session = true
end

---competitest's C++ arguments: the sanitized profile, plus its PCH when one
---is already built (<leader>jr builds it before loading competitest).
---@return string[]
function M.competitest_cpp()
  local dirs = M.paths()
  local args = require("cp.sys").cxx_flags(dirs, true)
  local pch = require("cp.run").pch_path(dirs, true)
  if require("cp.run").pch_is_fresh(dirs, pch) then
    vim.list_extend(args, { "-include-pch", pch })
  end
  return vim.list_extend(args, { "$(FNAME)", "-o", "$(FNOEXT)" })
end

---Per-extension templates for received problems, only those that exist.
---@return table<string, string>|false
function M.templates()
  local dir, found = M.paths().templates, {}
  for _, ext in ipairs({ "cpp", "rs" }) do
    local file = ("%s/solution.%s"):format(dir, ext)
    if vim.uv.fs_stat(file) then
      found[ext] = file
    end
  end
  return next(found) and found or false
end

---leetcode.nvim's question_enter hook.
---@param q table
function M.question_enter(q)
  require("cp.cases").attach(q)
  require("cp.buffers").attach(q)
end

return M
