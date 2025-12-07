local fn = vim.fn

local lazypath = fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = {
		---------------------------------------------------------------------------
		-- Tema / UI base
		---------------------------------------------------------------------------
		{
			"thesimonho/kanagawa-paper.nvim",
			lazy = false,
			priority = 1000,
			init = function()
				vim.cmd.colorscheme("kanagawa-paper-ink")
			end,
			config = function()
				require("kanagawa-paper").setup({
					overrides = function(colors)
						local theme = colors.theme
						local palette = colors.palette

						return {

							-- H1: Rosso/Rosa (Il più importante)
							["@markup.heading.1.markdown"] = { fg = palette.sakuraPink or "#d27e99", bold = true },
							["MarkviewHeading1"] = { link = "@markup.heading.1.markdown" }, -- Link esplicito per Markview

							-- H2: Arancione
							["@markup.heading.2.markdown"] = { fg = palette.surimiOrange or "#ff9e64", bold = true },
							["MarkviewHeading2"] = { link = "@markup.heading.2.markdown" },

							-- H3: Giallo
							["@markup.heading.3.markdown"] = { fg = palette.carpenterYellow or "#e6c384", bold = true },
							["MarkviewHeading3"] = { link = "@markup.heading.3.markdown" },

							-- H4: Verde
							["@markup.heading.4.markdown"] = { fg = palette.springGreen or "#98bb6c", bold = true },
							["MarkviewHeading4"] = { link = "@markup.heading.4.markdown" },

							-- H5: Ciano/Blu
							["@markup.heading.5.markdown"] = { fg = palette.crystalBlue or "#7e9cd8", bold = true },
							["MarkviewHeading5"] = { link = "@markup.heading.5.markdown" },

							-- H6: Viola
							["@markup.heading.6.markdown"] = { fg = palette.oniViolet or "#957fb8", bold = true },
							["MarkviewHeading6"] = { link = "@markup.heading.6.markdown" },

							-- OPZIONALE: Marker del titolo (i caratteri #)
							-- Li facciamo un po' più scuri per far risaltare il testo
							["@markup.heading.marker.markdown"] = { fg = theme.ui.nontext },
						}
					end,
				})
			end,
			opts = {},
		},
		{
			"nvim-lualine/lualine.nvim",
			dependencies = { "nvim-tree/nvim-web-devicons" },
			config = function()
				require("lualine").setup({
					options = {
						theme = "kanagawa-paper-ink",
						icons_enabled = true,
						section_separators = "",
						component_separators = "",
					},
					sections = {
						lualine_a = { "mode" },
						lualine_b = { "branch", "diff", "diagnostics" },
						lualine_c = { "filename" },
						lualine_x = {
							-- componente GhostNotes: sicuro e senza globali
							function()
								local ok, gn = pcall(require, "config.ghostnotes")
								if not ok or not gn or not gn.statusline_component then
									return ""
								end
								return gn.statusline_component()
							end,
							{
								function()
									local ok, gv = pcall(require, "ghostvault")
									if not ok then
										ok, gv = pcall(require, "config.ghostvault")
									end
									if ok and gv and gv.get_project_name then
										return gv.get_project_name() or ""
									end
									return ""
								end,
								color = "GhostAccent",
							},
							"encoding",
							"fileformat",
							"filetype",
						},
						lualine_y = { "progress" },
						lualine_z = { "location" },
					},
				})
			end,
		},

		{
			"romgrk/barbar.nvim",
			dependencies = {
				"lewis6991/gitsigns.nvim",
				"nvim-tree/nvim-web-devicons",
			},
			init = function()
				vim.g.barbar_auto_setup = false
			end,
			opts = {
				-- lazy.nvim will automatically call setup for you. put your options here, anything missing will use the default:
				animation = true,
				insert_at_start = true,
				clickable = true,
				focus_on_close = "left",
				icons = {
					-- Configure the base icons on the bufferline.
					-- Valid options to display the buffer index and -number are `true`, 'superscript' and 'subscript'
					buffer_index = false,
					buffer_number = false,
					button = "",
					-- Enables / disables diagnostic symbols
					diagnostics = {
						[vim.diagnostic.severity.ERROR] = { enabled = true, icon = "E" },
						[vim.diagnostic.severity.WARN] = { enabled = false },
						[vim.diagnostic.severity.INFO] = { enabled = false },
						[vim.diagnostic.severity.HINT] = { enabled = false },
					},
					gitsigns = {
						added = { enabled = true, icon = "+" },
						changed = { enabled = true, icon = "~" },
						deleted = { enabled = true, icon = "-" },
					},
					filetype = {
						-- Sets the icon's highlight group.
						-- If false, will use nvim-web-devicons colors
						custom_colors = false,
						-- Requires `nvim-web-devicons` if `true`
						enabled = true,
					},
					modified = { button = "●" },
					pinned = { button = "", filename = true },
					-- Use a preconfigured buffer appearance— can be 'default', 'powerline', or 'slanted'
					preset = "slanted",

					-- Configure the icons on the bufferline based on the visibility of a buffer.
					-- Supports all the base icon options, plus `modified` and `pinned`.
					alternate = { filetype = { enabled = false } },
					current = { buffer_index = true },
					inactive = { button = "×" },
					visible = { modified = { buffer_number = false } },
				},
				-- If true, new buffers will be inserted at the start/end of the list.
				-- Default is to insert after current buffer.
				insert_at_end = false,
				insert_at_start = false,

				-- Sets the maximum padding width with which to surround each tab
				maximum_padding = 3,

				-- Sets the minimum padding width with which to surround each tab
				minimum_padding = 3,

				-- Sets the maximum buffer name length.
				maximum_length = 30,

				-- Sets the minimum buffer name length.
				minimum_length = 0,

				-- If set, the letters for each buffer in buffer-pick mode will be
				-- assigned based on their name. Otherwise or in case all letters are
				-- already assigned, the behavior is to assign letters in order of
				-- usability (see order below)
				semantic_letters = true,

				-- Set the filetypes which barbar will offset itself for
				sidebar_filetypes = {
					-- Use the default values: {event = 'BufWinLeave', text = '', align = 'left'}
					NvimTree = true,
					-- Or, specify the text used for the offset:
					undotree = {
						text = "undotree",
						align = "center", -- *optionally* specify an alignment (either 'left', 'center', or 'right')
					},
					-- Or, specify the event which the sidebar executes when leaving:
					["neo-tree"] = { event = "BufWipeout" },
					-- Or, specify all three
					Outline = { event = "BufWinLeave", text = "symbols-outline", align = "right" },
				},

				-- New buffer letters are assigned in this order. This order is
				-- optimal for the qwerty keyboard layout but might need adjustment
				-- for other layouts.
				letters = "asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP",

				-- Sets the name of unnamed buffers. By default format is "[Buffer X]"
				-- where X is the buffer number. But only a static string is accepted here.
				no_name_title = nil,

				-- sorting options
				sort = {
					-- tells barbar to ignore case differences while sorting buffers
					ignore_case = true,
				},
			},
		},

		{
			"folke/noice.nvim",
			event = "VeryLazy",
			opts = {
				lsp = {
					-- override markdown rendering so that **cmp** and other plugins use Treesitter
					override = {
						["vim.lsp.util.convert_input_to_markdown_lines"] = true,
						["vim.lsp.util.stylize_markdown"] = true,
						["cmp.entry.get_documentation"] = true,
					},
				},
				presets = {
					bottom_search = true, -- use a classic bottom cmdline for search
					command_palette = true, -- position the cmdline and popupmenu together
					long_message_to_split = true, -- long messages will be sent to a split
					inc_rename = false, -- enables an input dialog for inc-rename.nvim
					lsp_doc_border = false, -- add a border to hover docs and signature help
				},
			},
			dependencies = {
				"MunifTanjim/nui.nvim",
				"rcarriga/nvim-notify",
			},
		},

		{
			"lukas-reineke/indent-blankline.nvim",
			main = "ibl",
			config = function()
				require("ibl").setup()
			end,
		},

		{
			"brenoprata10/nvim-highlight-colors",
			opts = { render = "background" }, -- O "virtual"
		},

		{
			"uga-rosa/ccc.nvim",
			opts = {},
			cmd = { "CccPick", "CccConvert" },
		},

		{
			"ziontee113/icon-picker.nvim",
			dependencies = {
				"stevearc/dressing.nvim", -- Opzionale: rende l'interfaccia molto più bella (stile telescope/vim.ui)
				"nvim-telescope/telescope.nvim", -- Opzionale: se vuoi usare telescope come backend
			},
			config = function()
				require("icon-picker").setup({
					disable_legacy_commands = true,
				})

				local opts = { noremap = true, silent = true }
			end,
		},

		---------------------------------------------------------------------------
		-- File explorer / navigazione / fuzzy finder
		---------------------------------------------------------------------------

		{
			"nvim-neo-tree/neo-tree.nvim",
			branch = "v3.x",
			dependencies = {
				"nvim-lua/plenary.nvim",
				"nvim-tree/nvim-web-devicons",
				"MunifTanjim/nui.nvim",
			},
			config = function()
				require("neo-tree").setup({
					window = { width = 30 },
					filesystem = {
						follow_current_file = { enabled = true },
						filtered_items = { hide_dotfiles = false },
					},
					event_handlers = {
						{
							event = "file_renamed",
							handler = function(args)
								require("ghostnotes").on_file_moved(args.source, args.destination)
							end,
						},
						{
							event = "file_moved",
							handler = function(args)
								require("ghostnotes").on_file_moved(args.source, args.destination)
							end,
						},
					},
				})
			end,
		},

		{
			"nvim-telescope/telescope.nvim",
			dependencies = {
				"nvim-lua/plenary.nvim",
				"nvim-tree/nvim-web-devicons",
			},
			config = function()
				local telescope = require("telescope")
				local previewers = require("telescope.previewers")
				local preview_utils = require("telescope.previewers.utils")

				telescope.setup({
					defaults = {
						layout_config = { prompt_position = "top" },
						sorting_strategy = "ascending",

						-- previewer di base (testo)
						file_previewer = previewers.vim_buffer_cat.new,
						grep_previewer = previewers.vim_buffer_vimgrep.new,
						qflist_previewer = previewers.vim_buffer_qflist.new,
					},

					extensions = {
						-- il tuo file_browser rimane com’è, ad es.:
						file_browser = {
							hijack_netrw = true,
							mappings = {
								["n"] = {
									["<C-u>"] = false,
									["<C-d>"] = false,
								},
							},
						},
						media = { backend = "viu" },
					},
				})
			end,
		},
		{
			"kelly-lin/ranger.nvim",
			config = function()
				local ranger_nvim = require("ranger-nvim")
				ranger_nvim.setup({
					enable_cmds = true, -- crea :Ranger e :RangerCurrentDirectory
					replace_netrw = false, -- lasciamo stare netrw
					ui = {
						border = "rounded",
						height = 0.9,
						width = 0.9,
						x = 0.5,
						y = 0.5,
					},
				})
				vim.keymap.set("n", "<leader>fr", function()
					ranger_nvim.open(true)
				end, { desc = " Open ranger file manager" })

				-- apri ranger in floating, nella dir del file corrente
			end,
		},

		---------------------------------------------------------------------------
		-- Treesitter + webdev helpers
		---------------------------------------------------------------------------

		{
			"nvim-treesitter/nvim-treesitter",
			build = ":TSUpdate",
			config = function()
				require("nvim-treesitter.configs").setup({
					ensure_installed = {
						"lua",
						"python",
						"javascript",
						"typescript",
						"html",
						"jinja",
						"htmldjango",
						"css",
						"json",
						"yaml",
						"c",
						"cpp",
						"markdown",
						"markdown_inline",
					},
					highlight = { enable = true },
					indent = { enable = true },
				})

				vim.treesitter.language.register("markdown", "telekasten")
				vim.treesitter.language.register("htmldjango", "jinja")
				vim.treesitter.language.register("htmldjango", "html")
			end,
		},

		{
			"windwp/nvim-ts-autotag",
			dependencies = { "nvim-treesitter/nvim-treesitter" },
			config = function()
				require("nvim-ts-autotag").setup()
			end,
		},

		---------------------------------------------------------------------------
		-- LSP, mason, nvim-cmp, diagnostics
		---------------------------------------------------------------------------

		{
			"neovim/nvim-lspconfig",
			dependencies = {
				"williamboman/mason.nvim",
				"williamboman/mason-lspconfig.nvim",
				"hrsh7th/nvim-cmp",
				"hrsh7th/cmp-nvim-lsp",
				"hrsh7th/cmp-buffer",
				"hrsh7th/cmp-path",
			},
			config = function()
				-----------------------------
				-- Mason setup
				-----------------------------
				require("mason").setup()
				require("mason-lspconfig").setup({
					ensure_installed = {
						"pyright",
						"ts_ls",
						"html",
						"cssls",
						"jsonls",
						"yamlls",
						"clangd",
						"stylua",
						"lua_ls",
					},
				})

				-----------------------------
				-- CMP
				-----------------------------
				local cmp = require("cmp")
				cmp.setup({
					snippet = { expand = function() end },
					mapping = cmp.mapping.preset.insert({
						["<C-Space>"] = cmp.mapping.complete(),
						["<CR>"] = cmp.mapping.confirm({ select = true }),
						["<C-n>"] = cmp.mapping.select_next_item(),
						["<C-p>"] = cmp.mapping.select_prev_item(),
						["<C-e>"] = cmp.mapping.abort(),
					}),
					sources = {
						{ name = "nvim_lsp" },
						{ name = "buffer" },
						{ name = "path" },
					},
					formatting = {
						format = require("nvim-highlight-colors").format,
					},
				})

				local capabilities = require("cmp_nvim_lsp").default_capabilities()

				local function on_attach(client, bufnr)
					local map = function(lhs, rhs)
						vim.keymap.set("n", lhs, rhs, { buffer = bufnr })
					end
				end

				-----------------------------
				-- Register servers
				-----------------------------
				for _, server in ipairs({
					"pyright",
					"ts_ls",
					"html",
					"cssls",
					"jsonls",
					"yamlls",
					"clangd",
					"stylua",
					"lua_ls",
				}) do
					vim.lsp.config[server] = {
						capabilities = capabilities,
						on_attach = on_attach,
						settings = (server == "lua_ls")
								and {
									Lua = {
										diagnostics = {
											globals = { "vim" },
										},
										format = {
											enable = false, -- <--- FIX DEFINITIVO
										},
									},
								}
							or nil,
					}

					vim.lsp.start(vim.lsp.config[server])
				end

				-----------------------------
				-- Better diagnostics
				-----------------------------
				vim.diagnostic.config({
					virtual_text = false,
					float = { border = "rounded" },
					update_in_insert = false,
					signs = true,
				})
			end,
		},

		---------------------------------------------------------------------------
		-- Formatting
		---------------------------------------------------------------------------

		{
			"stevearc/conform.nvim",
			config = function()
				require("conform").setup({
					formatters_by_ft = {
						python = { "black" },
						javascript = { "biome" },
						typescript = { "biome" },
						javascriptreact = { "prettier" },
						typescriptreact = { "prettier" },
						html = { "djlint" },
						css = { "prettier" },
						json = { "prettier" },
						yaml = { "prettier" },
						lua = { "stylua" },
						c = { "clang_format" },
						cpp = { "clang_format" },
					},
					formatters = {
						djlint = {
							prepend_args = { "--profile", "html", "--reformat", "--indent", "2" },
						},
						prettier = {
							prepend_arg = {
								"--trailing-comma",
								"all",
							},
						},
					},
					-- format_on_save = {
					-- 	timeout_ms = 1500,
					-- 	lsp_format = "never",
					-- },
				})
			end,
		},

		---------------------------------------------------------------------------
		-- Git e terminale
		---------------------------------------------------------------------------

		{
			"lewis6991/gitsigns.nvim",
			config = function()
				require("gitsigns").setup()
			end,
		},

		{
			"kdheepak/lazygit.nvim",
			lazy = true,
			cmd = {
				"LazyGit",
				"LazyGitConfig",
				"LazyGitCurrentFile",
				"LazyGitFilter",
				"LazyGitFilterCurrentFile",
			},
			-- optional for floating window border decoration
			dependencies = {
				"nvim-lua/plenary.nvim",
			},
			-- setting the keybinding for LazyGit with 'keys' is recommended in
			-- order to load the plugin when the command is run for the first time
			keys = {
				{ "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
			},
		},
		-- Terminale avanzato
		{
			"akinsho/toggleterm.nvim",
			version = "*",
			config = function()
				require("toggleterm").setup({
					size = 15, -- Altezza del terminale orizzontale
					open_mapping = [[\]], -- Tasto rapido per aprire/chiudere un terminale generico
					hide_numbers = true,
					shade_filetypes = {},
					shade_terminals = true,
					shading_factor = 2,
					start_in_insert = true,
					insert_mappings = true,
					persist_size = true,
					-- "horizontal" apre sotto, "float" apre al centro, "vertical" a lato
					direction = "horizontal",
					close_on_exit = true,
					shell = vim.o.shell,
					float_opts = {
						border = "curved",
						winblend = 0,
					},
				})

				-- Mappatura per uscire dalla modalità Terminale facilmente (opzionale ma consigliata)
				function _G.set_terminal_keymaps()
					local opts = { buffer = 0 }
					vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
					vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
					vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
					vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
					vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
				end

				vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
			end,
		},
		---------------------------------------------------------------------------
		-- Note system: Telekasten
		---------------------------------------------------------------------------

		{
			"renerocksai/telekasten.nvim",
			dependencies = { "nvim-lua/plenary.nvim" },
			config = function()
				local home = vim.fn.expand("~/.notes")
				require("telekasten").setup({
					home = home,
				})

				local tk = require("telekasten")
				vim.keymap.set("n", "<leader>zz", tk.panel, { desc = "Telekasten panel" })
				vim.keymap.set("n", "<leader>zd", tk.goto_today, { desc = "Telekasten today" })
				vim.keymap.set("n", "<leader>zn", tk.new_note, { desc = "Telekasten new note" })
				vim.keymap.set("n", "<leader>zc", tk.show_calendar, { desc = "Telekasten calendar" })
				vim.keymap.set("n", "<leader>zf", tk.find_notes, { desc = "Telekasten find notes" })
				vim.keymap.set("n", "<leader>zg", tk.search_notes, { desc = "Telekasten search in notes" })
			end,
		},

		---------------------------------------------------------------------------
		-- Markdown prettifier & immagini (kitty)
		---------------------------------------------------------------------------

		{
			"OXY2DEV/markview.nvim",
			lazy = false, -- raccomandato dalla doc
			dependencies = {
				"nvim-treesitter/nvim-treesitter",
				"nvim-tree/nvim-web-devicons",
			},
			config = function()
				require("markview").setup({})
				vim.api.nvim_create_autocmd("FileType", {
					pattern = "markdown",
					callback = function()
						vim.opt_local.conceallevel = 2
						vim.opt_local.concealcursor = "nc" -- Nasconde anche sulla riga del cursore (opzionale)
					end,
				})
			end,
		},

		{
			"3rd/image.nvim",
			build = false, -- usa magick_cli senza build del rock
			opts = {
				backend = "kitty",
				processor = "magick_cli",
				integrations = {
					markdown = {
						enabled = true,
						clear_in_insert_mode = false,
						download_remote_images = true,
						only_render_image_at_cursor = false,
						only_render_image_at_cursor_mode = "popup",
						floating_windows = false,
						filetypes = { "markdown" },
					},
					neorg = {
						enabled = false,
					},
					typst = {
						enabled = true,
						filetypes = { "typst" },
					},
					html = {
						enabled = false,
					},
					css = {
						enabled = false,
					},
				},
				max_width = nil,
				max_height = nil,
				max_width_window_percentage = nil,
				max_height_window_percentage = 50,
				scale_factor = 1.0,
				window_overlap_clear_enabled = false,
				window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs" },
				editor_only_render_when_focused = false,
				tmux_show_only_in_active_window = false,
				hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
			},
		},

		---------------------------------------------
		--- Mini.nvim things
		---------------------------------------------

		{
			"echasnovski/mini.nvim",
			version = false,
			config = function()
				-- 1. ICONS
				require("mini.icons").setup({ style = "glyph" })
				require("mini.icons").mock_nvim_web_devicons()

				-- 2. SURROUND & PAIRS & COMMENT
				require("mini.surround").setup()
				require("mini.pairs").setup() -- Sostituisce nvim-autopairs
				require("mini.comment").setup() -- Sostituisce Comment.nvim

				-- 3. AI (Better Text Objects)
				require("mini.ai").setup()

				-- 4. INDENTSCOPE (Opzionale, sostituisce indent-blankline)
				require("mini.indentscope").setup({
					symbol = "│",
					options = { try_as_border = true },
				})

				-- 5. CLUE (Sostituisce WhichKey)
				local miniclue = require("mini.clue")
				miniclue.setup({
					triggers = {
						-- Leader & Builtin
						{ mode = "n", keys = "<Leader>" },
						{ mode = "x", keys = "<Leader>" },
						{ mode = "i", keys = "<C-x>" },
						{ mode = "n", keys = "<C-w>" },

						-- Registers, Marks, Macros
						{ mode = "n", keys = '"' },
						{ mode = "x", keys = '"' },
						{ mode = "i", keys = "<C-r>" },
						{ mode = "c", keys = "<C-r>" },
						{ mode = "n", keys = "'" },
						{ mode = "n", keys = "`" },

						-- Gitsigns (prev/next hunk)
						{ mode = "n", keys = "]" },
						{ mode = "n", keys = "[" },

						-- Z & G keys (Fold, Spell, GoTo)
						{ mode = "n", keys = "z" },
						{ mode = "x", keys = "z" },
						{ mode = "n", keys = "g" },
						{ mode = "x", keys = "g" },

						-- Mini.Surround (s)
						{ mode = "n", keys = "s" },
						{ mode = "x", keys = "s" },

						-- Mini.AI & Operators (d, c, y, v)
						{ mode = "n", keys = "d" },
						{ mode = "n", keys = "c" },
						{ mode = "n", keys = "y" },
						{ mode = "x", keys = "a" },
						{ mode = "x", keys = "i" },
						{ mode = "o", keys = "a" },
						{ mode = "o", keys = "i" },
					},

					clues = {
						miniclue.gen_clues.builtin_completion(),
						miniclue.gen_clues.registers(),
						miniclue.gen_clues.windows(),
						miniclue.gen_clues.z(),
						miniclue.gen_clues.g(),
						miniclue.gen_clues.marks(),

						-- Custom Clues
						{ mode = "n", keys = "sa", desc = "Add Surround" },
						{ mode = "n", keys = "sd", desc = "Delete Surround" },
						{ mode = "n", keys = "sr", desc = "Replace Surround" },
						{ mode = "n", keys = "sf", desc = "Find Surround" },

						{ mode = "n", keys = "<Leader>a", desc = "👻 GhostNotes" },
						{ mode = "n", keys = "<Leader>p", desc = "👻 GhostVault" },
						{ mode = "n", keys = "<Leader>f", desc = "📂 Find/Files" },
						{ mode = "n", keys = "<Leader>z", desc = "󱘒 Telekasten" },
						{ mode = "n", keys = "<Leader>g", desc = " Git" },
						{ mode = "n", keys = "<Leader>e", desc = " Neotree" },
						{ mode = "n", keys = "<Leader>m", desc = "󰍔 Markdown" },
						{ mode = "n", keys = "<Leader>q", desc = " Color Picker" },
					},

					window = {
						delay = 300, -- Un po' più reattivo
						config = { width = "auto", border = "rounded" },
					},
				})
			end,
		},
	},

	---------------------------------------------------------------------------
	-- keys helper
	---------------------------------------------------------------------------

	install = {
		colorscheme = { "kanagawa-paper-ink" },
	},

	checker = { enabled = false },
})
