vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.plugins")
require("config.ghostnotes").setup({ show_virtual_text = true})
require("config.ghostvault").setup()
require("config.focus")
require("config.keymaps")
