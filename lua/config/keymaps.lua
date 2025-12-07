-- lua/config/keymaps.lua

local map = vim.keymap.set

-- salvataggio / uscita / buffer
map("n", "<c-s>", "<cmd>w<CR>", { desc = " Save" })
map("n", "<c-q>", "<cmd>wqa<CR>", { desc = " Quit window" })
map("n", "<leader>-", "<cmd>split<CR>", { desc = " split horizontally" })
map("n", "<leader>_", "<cmd>vsplit<CR>", { desc = " split vertically" })
map("n", "<leader>k", "<Cmd>wincmd k<CR>", { desc = "⬅ move to the left" })
map("n", "<leader>j", "<Cmd>wincmd j<CR>", { desc = "⬇ move to the bottom" })
map("n", "<leader>h", "<Cmd>wincmd h<CR>", { desc = "⬆ move to the top" })
map("n", "<leader>l", "<Cmd>wincmd l<CR>", { desc = "➡ move to the right" })
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "  Increase Window Height" })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = " Decrease Window Height" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = " Increase Window Width" })
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "󰞘 Decrease Window Width" })

-- toggle diagnostics ON/OFF
map("n", "<leader>o", function()
	local cfg = vim.diagnostic.config()
	local enabled = not cfg.virtual_text
	vim.diagnostic.config({
		virtual_text = enabled,
		signs = enabled,
	})
	print("Diagnostics: " .. (enabled and "ON" or "OFF"))
end, { desc = "Toggle diagnostics" })

-- format con conform.nvim
map("n", "<leader>F", function()
	local ok, conform = pcall(require, "conform")
	if ok then
		conform.format({ async = true, lsp_fallback = true })
	else
		vim.lsp.buf.format({ async = true })
	end
end, { desc = "󰉿 Format buffer" })

---------------------------------------------------------------------------
-- Project notes (Telekasten-style, ma in markdown liscio)
---------------------------------------------------------------------------

local function open_project_note()
	-- prova a prendere la root git, altrimenti cwd
	local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
	if git_root == nil or git_root == "" then
		git_root = vim.fn.getcwd()
	end

	local project_name = vim.fn.fnamemodify(git_root, ":t")
	local home = vim.fn.expand("~/notes/projects")
	vim.fn.mkdir(home, "p")
	local note_path = home .. "/" .. project_name .. ".md"

	if vim.fn.filereadable(note_path) == 0 then
		local template = {
			"# " .. project_name,
			"",
			"## Description",
			"",
			"## Status",
			"- [ ] ",
			"",
			"## Tasks",
			"- [ ] ",
			"",
			"## Ideas",
			"- ",
			"",
			"## Log",
			"- " .. os.date("%Y-%m-%d") .. ": ",
			"",
		}
		vim.fn.writefile(template, note_path)
	end

	vim.cmd("edit " .. note_path)
end

--------------
---Lazy

vim.keymap.set("n", "<leader>L", "<Cmd>Lazy<CR>", { desc = "💤 Lazy manager" })

----------------
-- NeoTree
--------------

vim.keymap.set("n", "<leader>ee", "<cmd>Neotree toggle filesystem<CR>", { desc = " Neo-tree filesystem" })
vim.keymap.set("n", "<leader>eb", "<cmd>Neotree buffers<CR>", { desc = "󰏋 Neo-tree buffers" })
vim.keymap.set("n", "<leader>eg", "<cmd>Neotree git_status<CR>", { desc = " Neo-tree git status" })

----------
---bufferline

vim.keymap.set("n", "<S-Tab>", "<Cmd>BufferPrevious<CR>", { desc = "󰒮 Go to previous tab" })
vim.keymap.set("n", "<Tab>", "<Cmd>BufferNext<CR>", { desc = "󰒭 Go to next tab" })
vim.keymap.set("n", "<A-l>", "<Cmd>BufferMoveNext<CR>", { desc = "󰞘 Move buffer to the right" })
vim.keymap.set("n", "<A-h>", "<Cmd>BufferMovePrevious<CR>", { desc = "󰞗 Move buffer to the left" })
vim.keymap.set("n", "<A-w>", "<Cmd>BufferClose<CR>", { desc = " Close tab" })

----------
---telescope

vim.keymap.set("n", "<leader>ff", "<cmd> Telescope find_files<CR>", { desc = " Find files" })
vim.keymap.set("n", "<leader>fg", "<cmd> Telescope live_grep<CR>", { desc = "󱎸 search text in files" })
vim.keymap.set("n", "<leader>fb", "<cmd> Telescope buffers<CR>", { desc = "󰏋 search in buffers" })
vim.keymap.set("n", "<leader>fo", "<cmd> Telescope oldfiles<CR>", { desc = " search ild files" })

---cmp

map("n", "gd", vim.lsp.buf.definition)
map("n", "gr", vim.lsp.buf.references)
map("n", "gi", vim.lsp.buf.implementation)
map("n", "K", vim.lsp.buf.hover)
map("n", "<leader>rn", vim.lsp.buf.rename)
map("n", "<leader>ca", vim.lsp.buf.code_action)
map("n", "[d", vim.diagnostic.goto_prev)
map("n", "]d", vim.diagnostic.goto_next)
map("n", "<leader>Od", vim.diagnostic.open_float)

------------
--- git signs
vim.keymap.set("n", "]c", "<cmd>Gitsigns next_hunk<CR>", { desc = "Next hunk" })
vim.keymap.set("n", "[c", "<cmd>Gitsigns prev_hunk<CR>", { desc = "Prev hunk" })
vim.keymap.set("n", "<leader>gs", "<cmd>Gitsigns stage_hunk<CR>", { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>gu", "<cmd>Gitsigns undo_stage_hunk<CR>", { desc = "Undo stage hunk" })
vim.keymap.set("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", { desc = "Preview hunk" })

--------
---Telekasten  (tutti in plugin.lua)
--------

map("n", "<leader>zp", open_project_note, { desc = "Open project note" })

---------------------------------------------------------------------------
-- Markview: preview markdown / split view
---------------------------------------------------------------------------

map("n", "<leader>mv", "<cmd>Markview toggle<CR>", { desc = " Toggle markdown preview (buffer)" })
map("n", "<leader>mV", "<cmd>Markview splitToggle<CR>", { desc = " Toggle markdown splitview" })

-------------------------------------------
--- CCC & icon Picker
-------------------------------------------

vim.keymap.set("n", "<leader>qq", "<cmd>CccPick<cr>", { desc = " Pick color with sliders" })
vim.keymap.set("n", "<leader>qa", "<cmd>CccConvert<cr>", { desc = "󰑤 Convert color under cursor" })
-- Usage:
-- Normal Mode: <leader>i apre il picker
vim.keymap.set("n", "<leader>qi", "<cmd>IconPickerNormal<cr>", { desc = "🦉 Pick Icons/Emojis" })

-- Normal Mode (Yank): copia l'icona nel registro invece di scriverla
vim.keymap.set("n", "<leader>qiy", "<cmd>IconPickerYank<cr>", { desc = " Yank Icon" })

-- Insert Mode: <C-i> apre il picker mentre scrivi
vim.keymap.set("i", "<C-i>", "<cmd>IconPickerInsert<cr>", { desc = " Pick Icon (Insert)" })

-------------------------------------------
---GhostVault

vim.keymap.set("n", "<leader>pi", "<cmd>GhostInit<cr>", { desc = " Init Ghost Project" })
vim.keymap.set("n", "<leader>ps", "<cmd>GhostSwitch<cr>", { desc = "󰑤 Switch Ghost Project" })
vim.keymap.set("n", "<leader>pd", "<cmd>GhostDelete<cr>", { desc = "󰆴 Delete Ghost Project" })
vim.keymap.set("n", "<leader>pr", "<cmd>GhostRun<cr>", { desc = " Run Ghost Project" })
vim.keymap.set("n", "<leader>pn", "<cmd>GhostNote<cr>", { desc = " Ghost Project Scratchpad" })
