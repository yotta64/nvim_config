vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.plugins")
require("config.ghostnotes").setup({ show_virtual_text = true})
require("config.ghostvault").setup()
require("config.focus")
require("config.keymaps")


vim.filetype.add({
  extension = {
    jinja = "jinja",
    jinja2 = "jinja",
    j2 = "jinja",
  },
  pattern = {
    -- Se il file finisce per .html, controlla se dentro c'è sintassi Jinja
    ["*.html"] = function(path, buf)
      local content = vim.api.nvim_buf_get_lines(buf, 0, 15, false) -- Legge le prime 15 righe
      for _, line in ipairs(content) do
        if line:match("{{") or line:match("{%%") then
          return "htmldjango" -- htmldjango offre il miglior mix di HTML + Jinja colors
        end
      end
      return "html"
    end,
  },
})
