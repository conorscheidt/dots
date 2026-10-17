-- Assist-free timed mode (`nvt`, NVIM_CP=timed) for interview reps.
--
-- No LSP client, no completion of any kind (blink, built-in keyword, omni),
-- no diagnostics, no autopairs, no AI. A statusline clock shows elapsed
-- time; <leader>rr still compiles and runs, because verifying an answer is
-- not assistance. :TimerReset restarts the clock.

local M = {}

local start = os.time()

---@return string
function M.elapsed()
  local secs = os.difftime(os.time(), start)
  return ("%02d:%02d"):format(math.floor(secs / 60), secs % 60)
end

-- Put the clock in lualine when it is in use, else in a plain statusline.
local function show_clock()
  if package.loaded.lualine then
    local lualine = require("lualine")
    local cfg = lualine.get_config()
    cfg.sections = cfg.sections or {}
    local x = cfg.sections.lualine_x or {}
    if not vim.tbl_contains(x, M.component) then
      table.insert(x, 1, M.component)
      cfg.sections.lualine_x = x
      lualine.setup(cfg)
    end
  else
    vim.o.laststatus = 3
    vim.o.statusline = "%f %m%r%= 󱎫 %{v:lua.require'cp.timed'.elapsed()}  %y  %l:%c "
  end
end

M.component = function()
  return "󱎫 " .. M.elapsed()
end

function M.setup()
  -- Clients are never started (vim.lsp.enable and plugins all go through
  -- vim.lsp.start); anything that slips through is stopped on attach.
  vim.lsp.start = function()
    return nil
  end
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("cp_timed", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        client:stop(true)
      end
    end,
  })
  vim.diagnostic.enable(false)

  vim.g.minipairs_disable = true
  vim.o.complete = ""
  vim.o.completeopt = ""
  vim.o.autocomplete = false
  for _, key in ipairs({ "<C-n>", "<C-p>", "<C-x><C-o>", "<C-x><C-n>", "<C-x><C-p>" }) do
    vim.keymap.set("i", key, "<Nop>")
  end
  -- Bundled ftplugins set omnifunc per buffer; blink honours vim.b.completion.
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
    group = "cp_timed",
    callback = function(args)
      vim.b[args.buf].completion = false
      vim.bo[args.buf].omnifunc = ""
      vim.bo[args.buf].completefunc = ""
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = "cp_timed",
    once = true,
    callback = vim.schedule_wrap(show_clock),
  })
  vim.api.nvim_create_autocmd("User", {
    group = "cp_timed",
    pattern = "DeferredPlugin",
    callback = function(args)
      if args.data == "lualine.nvim" then
        vim.schedule(show_clock)
      end
    end,
  })
  vim.uv.new_timer():start(1000, 1000, vim.schedule_wrap(function()
    vim.cmd.redrawstatus()
  end))

  vim.api.nvim_create_user_command("TimerReset", function()
    start = os.time()
    vim.notify("Timer reset")
  end, { desc = "Reset the session timer" })
end

return M
