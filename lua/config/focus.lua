
---------------------------------------------------------------------------
-- Floating focus mode con overlay "sfocato"
---------------------------------------------------------------------------

local focus_state = {
  win = nil,
  buf = nil,
  overlay = nil,
}

local function close_floating_focus()
  if focus_state.win and vim.api.nvim_win_is_valid(focus_state.win) then
    vim.api.nvim_win_close(focus_state.win, true)
  end
  if focus_state.overlay and vim.api.nvim_win_is_valid(focus_state.overlay) then
    vim.api.nvim_win_close(focus_state.overlay, true)
  end
  focus_state.win = nil
  focus_state.buf = nil
  focus_state.overlay = nil
end

local function open_floating_focus()
  if focus_state.win ~= nil then
    return -- già aperto
  end

  local current_buf = vim.api.nvim_get_current_buf()

  -- dimensioni floating "focus"
  local width = math.floor(vim.o.columns * 0.90)
  local height = math.floor(vim.o.lines * 0.85)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- 1) overlay scuro a tutto schermo
  local overlay_buf = vim.api.nvim_create_buf(false, true) -- no file, no swap
  local overlay_opts = {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
    style = "minimal",
    border = "none",
  }

  local overlay_win = vim.api.nvim_open_win(overlay_buf, false, overlay_opts)

  -- evidenziatore per lo sfondo (colori in stile catppuccin)
  vim.api.nvim_set_hl(0, "FocusDim", { bg = "#000000", default = false })
  vim.api.nvim_win_set_option(overlay_win, "winhighlight", "Normal:FocusDim")
  -- un po' di trasparenza (se il terminale la supporta)
  pcall(vim.api.nvim_win_set_option, overlay_win, "winblend", 40)

  -- 2) finestra flottante centrale con il buffer corrente
  local focus_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }

  -- se Neovim supporta zindex (0.10+), mettilo sopra all'overlay
  if vim.fn.has("nvim-0.10") == 1 then
    focus_opts.zindex = 150
    overlay_opts.zindex = 100
  end

  local focus_win = vim.api.nvim_open_win(current_buf, true, focus_opts)

  -- highlight della floating (puoi cambiare il bg per abbinarlo meglio al tema)
  vim.api.nvim_set_hl(0, "FocusFloat", { bg = "#1e1e2e", default = false })
  vim.api.nvim_win_set_option(focus_win, "winhighlight", "Normal:FocusFloat,FloatBorder:FloatBorder")

  -- ESC per chiudere SOLO la modalità focus
  vim.keymap.set("n", "<Esc>", function()
    close_floating_focus()
  end, { buffer = current_buf, silent = true })

  focus_state.win = focus_win
  focus_state.buf = current_buf
  focus_state.overlay = overlay_win
end

local function toggle_floating_focus()
  if focus_state.win ~= nil then
    close_floating_focus()
  else
    open_floating_focus()
  end
end

vim.keymap.set("n", "<leader>M", toggle_floating_focus, { desc = "󱂬 Floating focus mode (with overlay)" })

