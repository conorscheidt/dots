-- Async compile-and-run for single-file solutions (<leader>r*).
-- Reads input.txt, streams output into a split, and caches binaries and PCHs.
-- LeakSanitizer is unavailable on macOS arm64; ASan and UBSan still run.

local M = {}

local BIN_DIR = vim.fn.stdpath("cache") .. "/cprun"
local PCH_DIR = BIN_DIR .. "/pch"

---@type integer? reusable output buffer
local out_buf = nil
---@type vim.SystemObj? currently running process
local running = nil

---Open (or reuse) the output split; focus stays in the source window.
local function ensure_window()
  if not (out_buf and vim.api.nvim_buf_is_valid(out_buf)) then
    out_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[out_buf].bufhidden = "hide"
    vim.api.nvim_buf_set_name(out_buf, "[run]")
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = out_buf, nowait = true })
  end
  if vim.fn.bufwinid(out_buf) == -1 then
    local win = vim.api.nvim_open_win(out_buf, false, {
      split = "below",
      win = -1,
      height = math.floor(vim.o.lines * 0.35),
    })
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].wrap = true
    vim.wo[win].winfixheight = true
  end
end

---@param lines string[]
local function set_lines(lines)
  if out_buf and vim.api.nvim_buf_is_valid(out_buf) then
    vim.bo[out_buf].modifiable = true
    vim.api.nvim_buf_set_lines(out_buf, 0, -1, false, lines)
    vim.bo[out_buf].modifiable = false
  end
end

---Append text and keep the view pinned to the bottom.
---@param chunk string
local function append(chunk)
  if not (out_buf and vim.api.nvim_buf_is_valid(out_buf)) then
    return
  end
  local lines = vim.split(chunk:gsub("\r\n", "\n"), "\n", { plain = true })
  vim.bo[out_buf].modifiable = true
  vim.api.nvim_buf_set_lines(out_buf, -1, -1, false, lines)
  vim.bo[out_buf].modifiable = false
  local win = vim.fn.bufwinid(out_buf)
  if win ~= -1 then
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(out_buf), 0 })
  end
end

---Run a command, streaming into the output split.
---The full command line is printed only on failure: the sanitized C++ line
---is ~300 characters that would bury the program output.
---@param cmd string[]
---@param opts { cwd: string, stdin?: string, label: string, on_exit?: fun(code: integer, output: string) }
local function spawn(cmd, opts)
  local start = vim.uv.hrtime()
  local output = {}
  if opts.stdin then
    append("  stdin < input.txt\n")
  end
  local function stream(_, data)
    if data then
      output[#output + 1] = data
      vim.schedule(function()
        append((data:gsub("\n$", "")))
      end)
    end
  end
  running = vim.system(cmd, { cwd = opts.cwd, stdin = opts.stdin, stdout = stream, stderr = stream, text = true }, function(res)
    running = nil
    local ms = math.floor((vim.uv.hrtime() - start) / 1e6)
    vim.schedule(function()
      local ok = res.code == 0 and (res.signal or 0) == 0
      if ok then
        append(("\n✓ %s in %dms"):format(opts.label, ms))
      else
        local signal = (res.signal or 0) ~= 0 and (" (signal %d)"):format(res.signal) or ""
        append(("\n✗ %s: exit %d%s in %dms"):format(opts.label, res.code, signal, ms))
        append("  $ " .. table.concat(cmd, " "))
      end
      if opts.on_exit then
        opts.on_exit(res.code, table.concat(output))
      end
    end)
  end)
end

-- Precompiled headers --------------------------------------------------------
--
-- The precompiled header is a one-line stub, so `#include <bits/stdc++.h>`
-- resolves to the shim on macOS and to the real libstdc++ header on Linux.
-- PCHs are keyed by the include dir they were built against: a PCH whose
-- header moved (another root, a rebuilt Nix shim) is rejected by clang.

local PRELUDE = PCH_DIR .. "/prelude.hpp"

---@param dirs { include: string, leetgen: string }
---@param sanitize boolean
---@return string
function M.pch_path(dirs, sanitize)
  local key = vim.fn.sha256(dirs.include):sub(1, 12)
  return ("%s/%s/stdc++-%s.pch"):format(PCH_DIR, key, sanitize and "asan" or "plain")
end

---Usable when present and newer than both the compiler and the shim.
---@param dirs { include: string }
---@param pch string
---@return boolean
function M.pch_is_fresh(dirs, pch)
  local p = vim.uv.fs_stat(pch)
  if not p then
    return false
  end
  for _, dep in ipairs({ vim.fn.exepath("clang++"), dirs.include .. "/bits/stdc++.h" }) do
    local s = dep ~= "" and vim.uv.fs_stat(dep)
    if s and s.mtime.sec > p.mtime.sec then
      return false
    end
  end
  return true
end

---Build both profiles on <leader>rP or the first C++ run.
---@param dirs? table from require("cp").paths()
---@param cb? fun()
function M.pch_build(dirs, cb)
  dirs = dirs or require("cp").paths()
  vim.fn.mkdir(PCH_DIR, "p")
  if not vim.uv.fs_stat(PRELUDE) then
    vim.fn.writefile({ "#include <bits/stdc++.h>" }, PRELUDE)
  end
  local pending = 2
  vim.notify("Building precompiled headers...", vim.log.levels.INFO)
  for _, sanitize in ipairs({ true, false }) do
    local pch = M.pch_path(dirs, sanitize)
    vim.fn.mkdir(vim.fs.dirname(pch), "p")
    local cmd = vim.list_extend({ "clang++" }, require("cp.sys").cxx_flags(dirs, sanitize))
    vim.list_extend(cmd, { "-x", "c++-header", PRELUDE, "-o", pch })
    vim.system(cmd, { text = true }, function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          vim.notify("PCH build failed:\n" .. (res.stderr or ""), vim.log.levels.ERROR)
        end
        pending = pending - 1
        if pending == 0 then
          vim.notify("Precompiled headers ready", vim.log.levels.INFO)
          if cb then
            cb()
          end
        end
      end)
    end)
  end
end

---Call `cb` once the profile's PCH is fresh, building it first if needed.
---@param dirs table
---@param sanitize boolean
---@param cb fun()
function M.pch_ensure(dirs, sanitize, cb)
  if M.pch_is_fresh(dirs, M.pch_path(dirs, sanitize)) then
    return cb()
  end
  M.pch_build(dirs, cb)
end

-- Recipes --------------------------------------------------------------------

---@param file string absolute source path
---@param ft string
---@param sanitize boolean
---@return { compile?: string[], exec: string[], pch?: string }|nil spec
---@return string? err
local function build_spec(file, ft, sanitize)
  vim.fn.mkdir(BIN_DIR, "p")
  local bin = BIN_DIR .. "/" .. vim.fn.fnamemodify(file, ":t:r")

  if ft == "cpp" or ft == "c" then
    local dirs = require("cp").paths(require("cp").root(file))
    local args = vim.list_extend({ ft == "cpp" and "clang++" or "clang" }, require("cp.sys").cxx_flags(dirs, sanitize, ft))
    local pch
    if ft == "cpp" then
      pch = M.pch_path(dirs, sanitize)
      if M.pch_is_fresh(dirs, pch) then
        vim.list_extend(args, { "-include-pch", pch })
      else
        pch = nil
      end
    end
    vim.list_extend(args, { file, "-o", bin })
    return { compile = args, exec = { bin }, pch = pch }
  end

  if ft == "rust" then
    if vim.fs.root(file, "Cargo.toml") then
      return { exec = { "cargo", "run", "--quiet" } }
    end
    -- rustc derives the crate name from the file name, and LeetCode's
    -- `1.two-sum.rs` is not a valid one.
    local args = { "rustc", "--edition", "2021", "-g", "--crate-name", "solution", "-o", bin }
    if sanitize then
      vim.list_extend(args, require("cp.sys").rust_sanitizer()) -- needs nightly rustc
    else
      vim.list_extend(args, { "-C", "debug-assertions=on", "-C", "overflow-checks=on" })
    end
    table.insert(args, file)
    return { compile = args, exec = { bin } }
  end

  if ft == "python" then
    return { exec = { "python3", file } }
  end

  return nil, "No run recipe for filetype: " .. (ft == "" and "<none>" or ft)
end

---Compile and run the current buffer.
---@param opts? { sanitize?: boolean, compile_only?: boolean, use_input?: boolean, retried?: boolean }
function M.run(opts)
  opts = opts or {}
  local sanitize = opts.sanitize ~= false
  local use_input = opts.use_input ~= false
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("Buffer has no file on disk", vim.log.levels.ERROR)
  end
  if running then
    running:kill("sigterm")
    running = nil
  end
  vim.cmd("silent! write")

  local ft = vim.bo.filetype
  local buf = vim.api.nvim_get_current_buf()
  -- `retried` = PCH maintenance already attempted once; never loop on it.
  local function again()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_call(buf, function()
        M.run(vim.tbl_extend("force", opts, { retried = true }))
      end)
    end
  end

  if ft == "cpp" and not opts.retried then
    local dirs = require("cp").paths(require("cp").root(file))
    if not M.pch_is_fresh(dirs, M.pch_path(dirs, sanitize)) then
      return M.pch_build(dirs, again)
    end
  end

  local spec, err = build_spec(file, ft, sanitize)
  if not spec then
    return vim.notify(err or "unsupported", vim.log.levels.ERROR)
  end

  local dir = vim.fs.dirname(file)
  ensure_window()
  set_lines({
    ("  %s   %s%s"):format(
      vim.fs.basename(file),
      sanitize and "asan+ubsan" or "no sanitizers",
      use_input and "" or "   no stdin"
    ),
    "  " .. string.rep("─", 40),
  })

  local stdin
  if use_input and not opts.compile_only then
    local fd = io.open(dir .. "/input.txt", "r")
    if fd then
      stdin = fd:read("*a")
      fd:close()
    end
  end

  local function exec()
    if not opts.compile_only then
      spawn(spec.exec, { cwd = dir, stdin = stdin, label = "run" })
    end
  end

  if not spec.compile then
    return exec()
  end
  spawn(spec.compile, {
    cwd = dir,
    label = "compile",
    on_exit = function(code, output)
      if code == 0 then
        return exec()
      end
      -- A stale PCH (compiler update, moved header) fails the build: drop it
      -- and rebuild once without asking.
      local stale = output:find("precompiled header", 1, true) or output:find("PCH file", 1, true)
      if spec.pch and stale and not opts.retried then
        vim.fn.delete(spec.pch)
        append("\n  stale precompiled header; rebuilding")
        M.pch_build(require("cp").paths(require("cp").root(file)), again)
      end
    end,
  })
end

---Open `input.txt` beside the current file in a split.
function M.edit_input()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("Buffer has no file on disk", vim.log.levels.ERROR)
  end
  vim.cmd(("botright %dsplit %s"):format(math.floor(vim.o.lines * 0.3), vim.fn.fnameescape(vim.fs.dirname(file) .. "/input.txt")))
end

---Kill the running process, if any.
function M.stop()
  if running then
    running:kill("sigterm")
    running = nil
    vim.notify("Killed running process", vim.log.levels.WARN)
  else
    vim.notify("Nothing running", vim.log.levels.INFO)
  end
end

return M
