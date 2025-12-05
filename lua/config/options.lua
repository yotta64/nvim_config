-- lua/config/options.lua

local opt = vim.opt
local g = vim.g

g.mapleader = " "
g.maplocalleader = " "

opt.number = true
opt.relativenumber = false
opt.cursorline = true

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

opt.wrap = false
opt.scrolloff = 4
opt.sidescrolloff = 8

opt.termguicolors = true
opt.signcolumn = "yes"

opt.splitright = true
opt.splitbelow = true

opt.ignorecase = true
opt.smartcase = true

opt.updatetime = 250
opt.timeoutlen = 400

opt.clipboard = "unnamedplus"

-- better undo
opt.undofile = true

-- disable built-in netrw (userai neo-tree)
g.loaded_netrw = 1
g.loaded_netrwPlugin = 1


