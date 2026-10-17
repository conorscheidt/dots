-- Keep ordinary buffers out of LeetCode-owned windows.
--
-- leetcode.nvim pins its question, description and console windows
-- ('winfixbuf') and owns their buffers. Without routing, `:bnext`, a picker
-- or a buffer delete either fails (E1513) or replaces the solution in its
-- window. Installed only once leetcode.nvim loads: until then nothing here is
-- active, and every hook below defers to the original when no LeetCode
-- buffer is involved.

local M = {}
local installed = false
local routing = false

local function questions()
  return (_G._Lc_state or {}).questions or {}
end

---The leetcode.nvim question owning `buf` (solution, description, info or console).
local function owner(buf)
  for _, q in ipairs(questions()) do
    if
      q.bufnr == buf
      or (q.description and q.description.bufnr == buf)
      or (q.info and q.info.bufnr == buf)
      or (q.console and (q.console.result.bufnr == buf or q.console.testcase.bufnr == buf))
    then
      return q
    end
  end
end

---Show `buf` in a window that may hold it: its question's own window for a
---solution, otherwise a new tab when the current window is pinned or owned.
local function editable_window(buf)
  local q = owner(buf)
  if q and q.bufnr == buf and vim.api.nvim_win_is_valid(q.winid) then
    return vim.api.nvim_set_current_win(q.winid)
  end
  if vim.wo.winfixbuf or owner(vim.api.nvim_get_current_buf()) then
    vim.cmd.tabnew()
    vim.wo.winfixbuf = false
  end
  vim.api.nvim_win_set_buf(0, buf)
end

local function approved(buf, force)
  if not vim.bo[buf].modified or force then
    return true
  end
  local choice = vim.fn.confirm(("Save changes to %q?"):format(vim.api.nvim_buf_get_name(buf)), "&Yes\n&No\n&Cancel")
  if choice == 1 then
    vim.api.nvim_buf_call(buf, vim.cmd.write)
    return true
  end
  return choice == 2
end

---Cycle listed file buffers, never inside a pinned or LeetCode-owned window.
---@param direction 1|-1
function M.navigate(direction)
  local current = vim.api.nvim_get_current_buf()
  local q = owner(current)
  current = q and q.bufnr or current
  local buffers = vim.tbl_filter(function(buf)
    return vim.bo[buf].buflisted and vim.bo[buf].buftype == ""
  end, vim.api.nvim_list_bufs())
  table.sort(buffers)
  if #buffers < 2 then
    return
  end
  local at = 1
  for i, buf in ipairs(buffers) do
    if buf == current then
      at = i
      break
    end
  end
  editable_window(buffers[(at - 1 + direction * vim.v.count1) % #buffers + 1])
end

---question_enter: unpin the solution window (routing keeps it safe), make
---closing the solution tear down its panes, and give the pinned description
---pane working buffer-cycling keys.
---@param q table
function M.attach(q)
  if q._local_buffers_attached == q.bufnr then
    return
  end
  q._local_buffers_attached = q.bufnr
  vim.wo[q.winid].winfixbuf = false
  q._unmount = function(self)
    if self._local_cleanup_scheduled or vim.v.dying ~= 0 then
      return
    end
    self._local_cleanup_scheduled = true
    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(self.winid) and #vim.api.nvim_list_tabpages() == 1 then
        vim.cmd.tabnew()
        vim.wo.winfixbuf = false
      end
      for _, component in ipairs({ self.info, self.console, self.description }) do
        component:unmount()
      end
      local buf = self.bufnr
      if vim.api.nvim_buf_is_valid(buf) and (self._local_delete or not vim.bo[buf].modified) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      _Lc_state.questions = vim.tbl_filter(function(question)
        return question ~= self
      end, questions())
    end)
  end
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    buffer = q.bufnr,
    callback = function(args)
      if args.buf == q.bufnr and not q._local_cleanup_scheduled then
        q:_unmount()
      end
    end,
  })
  local desc = q.description and q.description.bufnr
  if desc and vim.api.nvim_buf_is_valid(desc) then
    for key, dir in pairs({ H = -1, L = 1, ["[b"] = -1, ["]b"] = 1 }) do
      vim.keymap.set("n", key, function()
        M.navigate(dir)
      end, { buffer = desc, desc = dir < 0 and "Prev Buffer" or "Next Buffer" })
    end
  end
end

local function close_question(q, opts)
  if not approved(q.bufnr, opts.force) then
    return
  end
  if #vim.api.nvim_list_tabpages() == 1 then
    vim.cmd.tabnew()
    vim.wo.winfixbuf = false
  end
  q._local_delete = true
  if vim.api.nvim_win_is_valid(q.winid) then
    q:unmount()
  else
    q:_unmount()
  end
end

---Picker confirm: from a pinned or LeetCode-owned window, open files in a tab
---(or jump to the solution's own window) instead of failing on 'winfixbuf'.
function M.picker_confirm(picker, item, action, jump)
  action = vim.tbl_extend("force", {}, action or {})
  if not action.cmd or action.cmd == "edit" then
    if
      vim.api.nvim_win_is_valid(picker.main)
      and (vim.wo[picker.main].winfixbuf or owner(vim.api.nvim_win_get_buf(picker.main)))
    then
      local selected = picker:selected({ fallback = true })[1]
      local buf = selected and (selected.buf or vim.fn.bufnr(selected.file or ""))
      local q = buf and owner(buf)
      action.cmd = q and q.bufnr == buf and "drop" or "tab"
    end
  end
  return jump(picker, item, action)
end

---Wrap Snacks.bufdelete: deleting a LeetCode buffer closes its question or
---hides its pane; other buffers are deleted normally, even from pinned windows.
local function wrap_bufdelete()
  local deletion = Snacks.bufdelete.delete
  Snacks.bufdelete.delete = function(opts)
    opts = type(opts) == "number" and { buf = opts } or opts or {}
    if type(opts) == "function" or opts.filter then
      return deletion(opts) -- iterates and calls back into this wrapper per buffer
    end
    local buf = opts.file and vim.fn.bufnr(opts.file) or opts.buf or 0
    buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local q = owner(buf)
    if q and q.bufnr == buf then
      return close_question(q, opts)
    elseif q and q.description and q.description.bufnr == buf then
      return q.description:hide()
    elseif q and q.info and q.info.bufnr == buf then
      return q.info:hide()
    elseif q then
      return q.console:hide()
    end
    if buf == vim.api.nvim_get_current_buf() and not vim.bo[buf].buflisted then
      local close = vim.fn.maparg("q", "n", false, true)
      if type(close.callback) == "function" then
        return close.callback()
      end
    end
    local pinned = {}
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if vim.wo[win].winfixbuf then
        pinned[#pinned + 1] = win
        vim.wo[win].winfixbuf = false
      end
    end
    local ok, err = xpcall(deletion, debug.traceback, opts)
    for _, win in ipairs(pinned) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        vim.wo[win].winfixbuf = true
      end
    end
    if not ok then
      error(err)
    end
  end
end

---Called once leetcode.nvim has loaded.
function M.install()
  if installed then
    return
  end
  if vim.v.vim_did_enter == 0 then
    -- `lc` loads leetcode.nvim before the other plugins are set up.
    vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = M.install })
    return
  end
  installed = true

  -- A buffer entering a question's window is moved out: the solution goes
  -- back, the newcomer opens in an editable window.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("cp_buffer_routing", { clear = true }),
    callback = function(args)
      if routing then
        return
      end
      local win = vim.api.nvim_get_current_win()
      for _, q in ipairs(questions()) do
        if q.winid == win and q.bufnr ~= args.buf and not q._local_cleanup_scheduled then
          local target = args.buf
          vim.schedule(function()
            if
              not vim.api.nvim_win_is_valid(win)
              or not vim.api.nvim_buf_is_valid(q.bufnr)
              or not vim.api.nvim_buf_is_valid(target)
              or q._local_cleanup_scheduled
              or vim.api.nvim_win_get_buf(win) ~= target
            then
              return
            end
            local cursor = vim.api.nvim_win_get_cursor(win)
            routing = true
            local ok, err = xpcall(function()
              vim.api.nvim_set_current_win(win)
              vim.api.nvim_win_set_buf(win, q.bufnr)
              editable_window(target)
              vim.api.nvim_win_set_cursor(0, cursor)
            end, debug.traceback)
            routing = false
            if not ok then
              error(err)
            end
          end)
          break
        end
      end
    end,
  })

  if _G.Snacks then
    wrap_bufdelete()
    local ok, actions = pcall(require, "snacks.picker.actions")
    if ok then
      local jump = actions.jump
      actions.confirm = function(picker, item, action)
        return M.picker_confirm(picker, item, action, jump)
      end
    end
  end
end

return M
