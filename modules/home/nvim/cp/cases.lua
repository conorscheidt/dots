-- Local testcases beside a solution, in competitest's layout
-- (testcases/<stem>_input<N>.txt, _output<N>.txt): an add/edit dialog
-- (<leader>ja/je) and `U` in leetcode.nvim's result window to keep a remote
-- case locally.

local M = {}
local active_editor
local ns = vim.api.nvim_create_namespace("local_case_editor")

local function text(value)
  return vim.trim(value or "")
end

local function location(path)
  return vim.fn.fnamemodify(path, ":h") .. "/testcases", vim.fn.fnamemodify(path, ":t:r")
end

function M.read(path)
  local dir, stem = location(path)
  local cases = {}
  for _, file in ipairs(vim.fn.glob(dir .. "/" .. stem .. "_*.txt", false, true)) do
    local kind, id = file:match("_(%a+)(%d+)%.txt$")
    if kind == "input" or kind == "output" then
      id = tonumber(id)
      cases[id] = cases[id] or {}
      cases[id][kind] = text(table.concat(vim.fn.readfile(file), "\n"))
    end
  end
  return cases
end

function M.store(path, input, output, id)
  input, output = text(input), output and text(output) or nil
  if input == "" then
    error("Testcase input is empty")
  end
  local cases = M.read(path)
  local last = 0
  for number, case in pairs(cases) do
    last = math.max(last, number)
    if not id and case.input == input and (output == nil or case.output == output) then
      return number, false
    end
  end
  id = id or last + 1
  local dir, stem = location(path)
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile(vim.split(input, "\n", { plain = true }), ("%s/%s_input%d.txt"):format(dir, stem, id))
  local expected_path = ("%s/%s_output%d.txt"):format(dir, stem, id)
  if output and output ~= "" then
    vim.fn.writefile(vim.split(output, "\n", { plain = true }), expected_path)
  elseif vim.fn.filereadable(expected_path) == 1 then
    vim.fn.delete(expected_path)
  end
  return id, true
end

local function question_for(buf)
  for _, q in ipairs((_G._Lc_state or {}).questions or {}) do
    local console = q.console
    if
      q.bufnr == buf
      or (q.description and q.description.bufnr == buf)
      or (console and (console.result.bufnr == buf or console.testcase.bufnr == buf))
    then
      return q
    end
  end
end

local function context()
  local current = vim.api.nvim_get_current_buf()
  local q = question_for(current)
  local buf = q and q.bufnr or current
  if vim.bo[buf].filetype ~= "cpp" then
    vim.notify("Open a C++ solution to manage its local cases", vim.log.levels.WARN)
    return
  end
  return buf, q
end

local function expected(output, q)
  if text(output) == "" then
    return nil
  end
  return require("cp.leetgen").format_expected(text(output), q and q.q.content)
end

local function append_remote(q, input)
  if not q then
    return
  end
  local meta = q.q.meta_data
  local n = (meta.classname or meta.methods) and 2 or #(meta.params or {})
  local lines = vim.split(q.console.testcase:content(), "\n", { plain = true })
  if n > 0 then
    for i = 1, #lines, n do
      if text(table.concat(vim.list_slice(lines, i, i + n - 1), "\n")) == text(input) then
        return
      end
    end
  end
  q.console.testcase:append(input)
end

local function open_editor(buf, q, initial, id, from_remote)
  if active_editor then
    active_editor:unmount()
  end
  local Popup, Layout = require("nui.popup"), require("nui.layout")
  local restore = q and q.winid or vim.api.nvim_get_current_win()
  local path = vim.api.nvim_buf_get_name(buf)
  local problem = vim.fn.fnamemodify(path, ":t:r"):match("^%d+") or ""
  local function pane(title, hint)
    return Popup({
      enter = false,
      border = {
        style = "rounded",
        padding = { top = 1, bottom = 1, left = 2, right = 2 },
        text = { top = " " .. title .. " ", top_align = "left", bottom = " " .. hint .. " ", bottom_align = "left" },
      },
      buf_options = { filetype = "json", buftype = "nofile", swapfile = false },
      win_options = { number = false, relativenumber = false, wrap = true, linebreak = true, signcolumn = "no" },
    })
  end
  local input = pane((id and "Edit" or "New") .. " local case " .. problem .. " / Input", "Tab: switch pane")
  local output = pane("Expected output", "Ctrl-S: save   Ctrl-C: cancel")
  local layout = Layout({
    relative = "editor",
    position = "50%",
    size = { width = math.min(120, vim.o.columns - 6), height = math.min(22, math.floor(vim.o.lines * 0.55)) },
  }, Layout.Box({ Layout.Box(input, { size = "50%" }), Layout.Box(output, { size = "50%" }) }, { dir = "row" }))
  active_editor = layout
  local function close()
    vim.cmd.stopinsert()
    layout:unmount()
    active_editor = nil
    if restore and vim.api.nvim_win_is_valid(restore) then
      vim.api.nvim_set_current_win(restore)
    end
  end
  local function contents(popup)
    return text(table.concat(vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false), "\n"))
  end
  local function save()
    local ins, outs = contents(input), contents(output)
    local meta = q and q.q.meta_data
    local count = meta and ((meta.classname or meta.methods) and 2 or #(meta.params or {}))
    if ins == "" then
      return vim.notify("Enter testcase input first", vim.log.levels.WARN)
    end
    if count and count > 0 and #vim.split(ins, "\n", { plain = true }) ~= count then
      return vim.notify(("Use one line per argument (%d lines for this problem)"):format(count), vim.log.levels.WARN)
    end
    local result = expected(outs, q)
    if result and (initial.output or ""):match("^!unordered\n") and not result:match("^!unordered\n") then
      result = "!unordered\n" .. result
    end
    local number, added = M.store(path, ins, result, id)
    if from_remote then
      append_remote(q, ins)
    end
    close()
    vim.notify((added and "Saved local case " or "Already saved as local case ") .. number, vim.log.levels.INFO)
  end
  layout:mount()
  vim.api.nvim_buf_set_name(input.bufnr, "local-case://input")
  vim.api.nvim_buf_set_name(output.bufnr, "local-case://expected")
  vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, false, vim.split(initial.input or "", "\n", { plain = true }))
  vim.api.nvim_buf_set_lines(
    output.bufnr,
    0,
    -1,
    false,
    vim.split((initial.output or ""):gsub("^!unordered\n", ""), "\n", { plain = true })
  )
  local params = q and q.q.meta_data.params or {}
  local function input_hints()
    vim.api.nvim_buf_clear_namespace(input.bufnr, ns, 0, -1)
    for i, param in ipairs(params) do
      if i <= vim.api.nvim_buf_line_count(input.bufnr) then
        vim.api.nvim_buf_set_extmark(input.bufnr, ns, i - 1, 0, {
          virt_text = { { "  " .. param.name .. " : " .. param.type, "Comment" } },
        })
      end
    end
  end
  input_hints()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, { buffer = input.bufnr, callback = input_hints })
  if text(initial.output) == "" then
    vim.api.nvim_buf_set_extmark(output.bufnr, ns, 0, 0, {
      virt_text = { { "Optional: blank runs without a verdict", "Comment" } },
      virt_text_pos = "eol",
    })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      buffer = output.bufnr,
      once = true,
      callback = function()
        vim.api.nvim_buf_clear_namespace(output.bufnr, ns, 0, -1)
      end,
    })
  end
  for _, p in ipairs({ input, output }) do
    local options = { buffer = p.bufnr, noremap = true, silent = true }
    vim.keymap.set({ "n", "i" }, "<C-s>", save, options)
    vim.keymap.set("n", "q", close, options)
    vim.keymap.set("n", "<Esc>", close, options)
    vim.keymap.set({ "n", "i" }, "<C-c>", close, options)
    for _, key in ipairs({ "<Tab>", "<S-Tab>" }) do
      vim.keymap.set({ "n", "i" }, key, function()
        vim.api.nvim_set_current_win(p == input and output.winid or input.winid)
      end, options)
    end
  end
  vim.api.nvim_set_current_win(from_remote and output.winid or input.winid)
  vim.cmd.startinsert()
end

function M.add()
  local buf, q = context()
  if buf then
    open_editor(buf, q, {})
  end
end

function M.edit()
  local buf, q = context()
  if not buf then
    return
  end
  local cases = M.read(vim.api.nvim_buf_get_name(buf))
  if not next(cases) then
    return M.add()
  end
  local Menu, Line = require("nui.menu"), require("nui.line")
  local numbers = vim.tbl_keys(cases)
  table.sort(numbers)
  local items = {}
  for _, id in ipairs(numbers) do
    local case = cases[id]
    local summary = vim.fn.strcharpart((case.input or ""):gsub("\n", " | "), 0, 55)
    local result = case.output and vim.fn.strcharpart(case.output:gsub("^!unordered\n", ""):gsub("\n", " "), 0, 22)
      or "(inspect output)"
    local label = Line()
    label:append((" %02d  "):format(id), "Comment")
    label:append(summary)
    label:append("  ->  ", "Comment")
    label:append(result, case.output and "Type" or "Comment")
    items[#items + 1] = Menu.item(label, { case_id = id })
  end
  local restore = q and q.winid or vim.api.nvim_get_current_win()
  local menu = Menu({
    relative = "editor",
    position = "50%",
    size = { width = math.min(100, vim.o.columns - 6), height = math.min(#items, 12) },
    border = {
      style = "rounded",
      text = { top = " Local cases ", bottom = " Enter: edit   j/k: move   q: close " },
    },
  }, {
    lines = items,
    keymap = {
      focus_next = { "j", "<Down>", "<Tab>" },
      focus_prev = { "k", "<Up>", "<S-Tab>" },
      close = { "q", "<Esc>", "<C-c>" },
      submit = "<CR>",
    },
    on_close = function()
      if vim.api.nvim_win_is_valid(restore) then
        vim.api.nvim_set_current_win(restore)
      end
    end,
    on_submit = function(item)
      if vim.api.nvim_win_is_valid(restore) then
        vim.api.nvim_set_current_win(restore)
      end
      open_editor(buf, q, cases[item.case_id], item.case_id)
    end,
  })
  menu:mount()
  vim.api.nvim_buf_set_name(menu.bufnr, "local-case://list")
end

local function displayed_case(node)
  if type(node) ~= "table" then
    return
  end
  if node.body then
    return node.body
  end
  if node.cases and node.idx then
    return node.cases[node.idx].body
  end
  for _, child in ipairs(type(node.contents) == "function" and node:contents() or {}) do
    local body = displayed_case(child)
    if body then
      return body
    end
  end
end

function M.import(q)
  local body = displayed_case(q.console.result.renderer)
  local input = body and (body.raw_input or table.concat(body.input or {}, "\n")) or q.console.result.last_testcase
  if not input or text(input) == "" then
    return vim.notify("This result has no testcase to save", vim.log.levels.WARN)
  end
  local output = body and body.expected
  if not output or output == vim.NIL or text(output) == "" then
    return open_editor(q.bufnr, q, { input = input }, nil, true)
  end
  local id, added = M.store(vim.api.nvim_buf_get_name(q.bufnr), input, expected(output, q))
  append_remote(q, input)
  vim.notify((added and "Saved local case " or "Already saved as local case ") .. id, vim.log.levels.INFO)
end

function M.attach(q)
  local console = q.console
  if console._local_cases_attached then
    return
  end
  console._local_cases_attached = true
  console.use_testcase = function()
    M.import(q)
  end
  local function bind(popup)
    popup.border:set_text("bottom", " U: save local case ", "center")
    if not popup._local_cases_attached then
      popup._local_cases_attached = true
      local handle = popup.handle
      popup.handle = function(self, item)
        self.last_testcase = nil
        return handle(self, item)
      end
    end
  end
  local mount = console.mount
  console.mount = function(self, ...)
    mount(self, ...)
    bind(self.result)
  end
  bind(console.result)
end

return M
