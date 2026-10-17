-- Async compile-and-run for single-file solutions (<leader>r*).
-- <leader>rr pipes input.txt and streams output into a split; <leader>rt runs
-- every testcase beside the file (testcases/<stem>_input<N>.txt, competitest's
-- layout) and prints a verdict for each. Binaries and PCHs are cached.
-- LeakSanitizer is unavailable on macOS arm64; ASan and UBSan still run.

local M = {}

local BIN_DIR = vim.fn.stdpath("cache") .. "/cprun"
local PCH_DIR = BIN_DIR .. "/pch"

---@type integer? reusable output buffer
local out_buf = nil
---@type vim.SystemObj? currently running process
local running = nil
local generation = 0
---@type { file: string, stdin: string, stdout: string }? the last clean <leader>rr run
local last_run = nil
---@type { file: string, failed: integer[] }? the last <leader>rt run
local last_test = nil

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
  local count = vim.api.nvim_buf_line_count(out_buf)
  local last = vim.api.nvim_buf_get_lines(out_buf, count - 1, count, false)[1]
  local lines = vim.split((last .. chunk):gsub("\r\n", "\n"), "\n", { plain = true })
  vim.bo[out_buf].modifiable = true
  vim.api.nvim_buf_set_lines(out_buf, count - 1, count, false, lines)
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
---@param opts { cwd: string, stdin?: string, label: string, on_exit?: fun(code: integer, output: string, stdout: string) }
local function spawn(cmd, opts)
  local current = generation
  local start = vim.uv.hrtime()
  local output, stdout = {}, {}
  if opts.stdin then
    append("  stdin < input.txt\n")
  end
  local function stream(sink)
    return function(_, data)
      if data then
        output[#output + 1] = data
        if sink then
          sink[#sink + 1] = data
        end
        vim.schedule(function()
          if current == generation then
            append(data)
          end
        end)
      end
    end
  end
  local streams = { cwd = opts.cwd, stdin = opts.stdin, stdout = stream(stdout), stderr = stream(), text = true }
  running = vim.system(cmd, streams, function(res)
    local ms = math.floor((vim.uv.hrtime() - start) / 1e6)
    vim.schedule(function()
      if current ~= generation then
        return
      end
      running = nil
      local ok = res.code == 0 and (res.signal or 0) == 0
      if ok then
        append(("\n✓ %s in %dms\n"):format(opts.label, ms))
      else
        local signal = (res.signal or 0) ~= 0 and (" (signal %d)"):format(res.signal) or ""
        append(("\n✗ %s: exit %d%s in %dms"):format(opts.label, res.code, signal, ms))
        append("\n  $ " .. table.concat(cmd, " ") .. "\n")
      end
      if opts.on_exit then
        opts.on_exit(ok and 0 or (res.code ~= 0 and res.code or 1), table.concat(output), table.concat(stdout))
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

-- Recipes --------------------------------------------------------------------

---@param file string absolute source path
---@param ft string
---@param sanitize boolean
---@return { compile?: string[], exec: string[], pch?: string }|nil spec
---@return string? err
local function build_spec(file, ft, sanitize)
  vim.fn.mkdir(BIN_DIR, "p")
  -- Keyed by the full path: every problem's file may be called `solution`.
  local bin = ("%s/%s-%s"):format(BIN_DIR, vim.fn.fnamemodify(file, ":t:r"), vim.fn.sha256(file):sub(1, 8))

  if ft == "cpp" or ft == "c" then
    local dirs = require("cp").paths(require("cp").root(file))
    local args =
      vim.list_extend({ ft == "cpp" and "clang++" or "clang" }, require("cp.sys").cxx_flags(dirs, sanitize, ft))
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
    local args = { "rustc", "--edition", "2024", "-g", "--crate-name", "solution", "-o", bin }
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

---Compile when the recipe has a compile step, then call `after`.
---@param spec { compile?: string[], exec: string[], pch?: string }
---@param file string
---@param dir string
---@param retried? boolean
---@param again fun() rerun the whole command once after PCH maintenance
---@param after fun()
local function compile(spec, file, dir, retried, again, after)
  if not spec.compile then
    return after()
  end
  spawn(spec.compile, {
    cwd = dir,
    label = "compile",
    on_exit = function(code, output)
      if code == 0 then
        return after()
      end
      -- A stale PCH (compiler update, moved header) fails the build: drop it
      -- and rebuild once without asking.
      local stale = output:find("precompiled header", 1, true) or output:find("PCH file", 1, true)
      if spec.pch and stale and not retried then
        vim.fn.delete(spec.pch)
        append("\n  stale precompiled header; rebuilding")
        M.pch_build(require("cp").paths(require("cp").root(file)), again)
      end
    end,
  })
end

---Compile and run the current buffer.
---@param opts? { sanitize?: boolean, compile_only?: boolean, use_input?: boolean, retried?: boolean, debug?: boolean }
function M.run(opts)
  opts = opts or {}
  local sanitize = opts.sanitize ~= false
  local use_input = opts.use_input ~= false
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("Buffer has no file on disk", vim.log.levels.ERROR)
  end
  local saved, save_error = pcall(vim.cmd.update)
  if not saved then
    return vim.notify("Could not save solution: " .. tostring(save_error), vim.log.levels.ERROR)
  end
  generation = generation + 1
  local current = generation
  if running then
    running:kill("sigterm")
    running = nil
  end
  local ft = vim.bo.filetype
  local buf = vim.api.nvim_get_current_buf()
  -- `retried` = PCH maintenance already attempted once; never loop on it.
  local function again()
    if current == generation and vim.api.nvim_buf_is_valid(buf) then
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
      opts.debug and "debugger" or sanitize and "asan+ubsan" or "no sanitizers",
      use_input and "" or "   no stdin"
    ),
    "  " .. string.rep("─", 40),
    "",
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
    if opts.debug then
      local input = dir .. "/input.txt"
      return require("dap").run({
        type = "codelldb",
        request = "launch",
        name = "Debug " .. vim.fs.basename(file),
        program = spec.exec[1],
        cwd = dir,
        stdio = vim.uv.fs_stat(input) and { input, vim.NIL, vim.NIL } or nil,
      })
    end
    if not opts.compile_only then
      spawn(spec.exec, {
        cwd = dir,
        stdin = stdin,
        label = "run",
        on_exit = function(code, _, stdout)
          last_run = code == 0 and { file = file, stdin = stdin or "", stdout = stdout } or nil
        end,
      })
    end
  end
  compile(spec, file, dir, opts.retried, again, exec)
end

-- Debugging ------------------------------------------------------------------

local PROJECT = { "CMakeLists.txt", "Makefile", "meson.build", "build.ninja", "Cargo.toml" }

---<leader>dc on a single-file program: build it without sanitizers and start
---it under the debugger, on input.txt when there is one.
---@return boolean handled false when a project build owns the file
function M.debug()
  local file, ft = vim.api.nvim_buf_get_name(0), vim.bo.filetype
  if file == "" or not (ft == "c" or ft == "cpp" or ft == "rust") or vim.fs.root(file, PROJECT) then
    return false
  end
  M.run({ sanitize = false, debug = true })
  return true
end

-- Testcases ------------------------------------------------------------------

local SHOWN = 12 -- lines of input, expected or actual output shown per case

---@param label string
---@param value string
---@param shown? integer
local function block(label, value, shown)
  shown = shown or SHOWN
  local lines = vim.split(vim.trim(value), "\n", { plain = true })
  local extra = #lines - shown
  if extra > 0 then
    lines = vim.list_slice(lines, 1, shown)
    lines[#lines + 1] = ("… (+%d lines)"):format(extra)
  end
  local out = {}
  for i, line in ipairs(lines) do
    out[i] = ("      %-9s %s"):format(i == 1 and label or "", line)
  end
  return table.concat(out, "\n") .. "\n"
end

---Compile once, then run every testcase beside the current file and print a
---verdict for each: pass, wrong answer, runtime error, timeout, or (without
---an expected file) just the output.
---@param opts? { sanitize?: boolean, retried?: boolean }
function M.test(opts)
  opts = opts or {}
  local sanitize = opts.sanitize ~= false
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("Buffer has no file on disk", vim.log.levels.ERROR)
  end
  local saved, save_error = pcall(vim.cmd.update)
  if not saved then
    return vim.notify("Could not save solution: " .. tostring(save_error), vim.log.levels.ERROR)
  end
  local cases = require("cp.cases").read(file)
  local ids = vim.tbl_keys(cases)
  table.sort(ids)
  if #ids == 0 then
    return vim.notify("No testcases beside this file. <leader>ra saves input.txt as one.", vim.log.levels.WARN)
  end
  generation = generation + 1
  local current = generation
  if running then
    running:kill("sigterm")
    running = nil
  end
  local ft = vim.bo.filetype
  local buf = vim.api.nvim_get_current_buf()
  local function again()
    if current == generation and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_call(buf, function()
        M.test(vim.tbl_extend("force", opts, { retried = true }))
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
  local timeout = vim.g.cp_timeout_ms or 5000
  local compare = require("cp.compare")
  ensure_window()
  set_lines({
    ("  %s   %s   %d case%s"):format(
      vim.fs.basename(file),
      opts.debug and "debugger" or sanitize and "asan+ubsan" or "no sanitizers",
      #ids,
      #ids == 1 and "" or "s"
    ),
    "  " .. string.rep("─", 40),
    "",
  })

  local passed, failed = 0, {}
  local function finish()
    last_test = { file = file, failed = failed }
    local tail = #failed == 0 and ""
      or ("   failed: %s   (<leader>rf loads the first into input.txt)"):format(table.concat(failed, " "))
    append(("\n  %s %d/%d passed%s\n"):format(#failed == 0 and "✓" or "✗", passed, #ids, tail))
  end
  local function step(i)
    local id = ids[i]
    if not id then
      return finish()
    end
    local case = cases[id]
    local start = vim.uv.hrtime()
    local run = { cwd = dir, stdin = (case.input or "") .. "\n", text = true, timeout = timeout }
    running = vim.system(spec.exec, run, function(res)
      local ms = math.floor((vim.uv.hrtime() - start) / 1e6)
      vim.schedule(function()
        if current ~= generation then
          return
        end
        running = nil
        local out = res.stdout or ""
        local detail = block("input", case.input or "")
        if res.code == 124 then
          failed[#failed + 1] = id
          append(("  ⏱ %-3d timed out after %dms\n%s"):format(id, timeout, detail))
        elseif res.code ~= 0 or (res.signal or 0) ~= 0 then
          failed[#failed + 1] = id
          local signal = (res.signal or 0) ~= 0 and (" (signal %d)"):format(res.signal) or ""
          append(
            ("  ! %-3d exit %d%s in %dms\n%s%s"):format(
              id,
              res.code,
              signal,
              ms,
              detail,
              block("stderr", res.stderr or "", 6)
            )
          )
        elseif not case.output then
          passed = passed + 1
          append(("  ? %-3d %dms, no expected output\n%s%s"):format(id, ms, detail, block("got", out)))
        elseif compare(out, case.output) then
          passed = passed + 1
          append(("  ✓ %-3d %dms\n"):format(id, ms))
        else
          failed[#failed + 1] = id
          local want = case.output:gsub("^!unordered\n", "")
          append(("  ✗ %-3d %dms\n%s%s%s"):format(id, ms, detail, block("expected", want), block("got", out)))
        end
        step(i + 1)
      end)
    end)
  end
  compile(spec, file, dir, opts.retried, again, function()
    append("\n")
    step(1)
  end)
end

---Save input.txt as a testcase. When the last <leader>rr ran this file
---cleanly on the same input, its output becomes the expected output.
function M.pin()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("Buffer has no file on disk", vim.log.levels.ERROR)
  end
  local fd = io.open(vim.fs.dirname(file) .. "/input.txt", "r")
  local input = fd and fd:read("*a") or ""
  if fd then
    fd:close()
  end
  if vim.trim(input) == "" then
    return vim.notify("input.txt is empty: nothing to save as a testcase", vim.log.levels.WARN)
  end
  local verified = last_run and last_run.file == file and last_run.stdin == input and vim.trim(last_run.stdout) ~= ""
  local id, added = require("cp.cases").store(file, input, verified and last_run.stdout or nil)
  if not added then
    return vim.notify("Already saved as testcase " .. id, vim.log.levels.INFO)
  end
  vim.notify(
    verified and ("Saved testcase %d with the last run's output as expected"):format(id)
      or ("Saved testcase %d without an expected output (<leader>re adds one)"):format(id),
    vim.log.levels.INFO
  )
end

---Pick a testcase and open its input and expected files side by side.
function M.edit_cases()
  local file = vim.api.nvim_buf_get_name(0)
  local cases = file ~= "" and require("cp.cases").read(file) or {}
  local ids = vim.tbl_keys(cases)
  table.sort(ids)
  if #ids == 0 then
    return vim.notify("No testcases beside this file. <leader>ra saves input.txt as one.", vim.log.levels.WARN)
  end
  local dir, stem = vim.fs.dirname(file) .. "/testcases", vim.fn.fnamemodify(file, ":t:r")
  vim.ui.select(ids, {
    prompt = "Testcase",
    format_item = function(id)
      local case = cases[id]
      local want = case.output and case.output:gsub("^!unordered\n", ""):gsub("\n", " ") or "(no expected output)"
      return ("%2d  %s  ->  %s"):format(id, (case.input or ""):gsub("\n", " | "):sub(1, 60), want:sub(1, 30))
    end,
  }, function(id)
    if not id then
      return
    end
    local height = math.floor(vim.o.lines * 0.3)
    vim.cmd(("botright %dsplit %s"):format(height, vim.fn.fnameescape(("%s/%s_input%d.txt"):format(dir, stem, id))))
    vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(("%s/%s_output%d.txt"):format(dir, stem, id)))
    vim.cmd.wincmd("p")
  end)
end

---Copy the first testcase that failed the last <leader>rt into input.txt, to
---reproduce it with <leader>rr or under the debugger.
function M.load_failed()
  local file = vim.api.nvim_buf_get_name(0)
  local id = last_test and last_test.file == file and last_test.failed[1]
  if not id then
    return vim.notify("No failing testcase from the last <leader>rt of this file", vim.log.levels.INFO)
  end
  local case = require("cp.cases").read(file)[id]
  local target = vim.fs.dirname(file) .. "/input.txt"
  vim.fn.writefile(vim.split(case.input or "", "\n", { plain = true }), target)
  vim.cmd.checktime()
  vim.notify(("Testcase %d is now input.txt"):format(id), vim.log.levels.INFO)
end

---Open `input.txt` beside the current file in a split.
function M.edit_input()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("Buffer has no file on disk", vim.log.levels.ERROR)
  end
  vim.cmd(
    ("botright %dsplit %s"):format(
      math.floor(vim.o.lines * 0.3),
      vim.fn.fnameescape(vim.fs.dirname(file) .. "/input.txt")
    )
  )
end

---Kill the running process, if any.
function M.stop()
  generation = generation + 1
  if running then
    running:kill("sigterm")
    running = nil
    vim.notify("Killed running process", vim.log.levels.WARN)
  else
    vim.notify("Nothing running", vim.log.levels.INFO)
  end
end

return M
