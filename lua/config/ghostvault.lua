local M = {}
local api = vim.api
local fn = vim.fn

-- Configurazione interna
local VAULT_DIR = ".ghost"
local STATE_FILE = "state.vim"
local IDENTITY_FILE = "identity.json"
local LOCAL_CONFIG = "local.lua"
local SCRATCHPAD_FILE = "scratchpad.md"
local REGISTRY_FILE = fn.stdpath("data") .. "/ghost_registry.json"

M.current_project = nil
M.project_root = nil

-- ============================================================
-- 1. Helper e Utils
-- ============================================================

local function read_json(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.fn.json_decode, content)
  return ok and data or nil
end

local function write_json(path, data)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(vim.fn.json_encode(data))
  f:close()
  return true
end

local function find_project_root()
  local current = fn.getcwd()
  local root = fn.finddir(VAULT_DIR, current .. ";")
  if root and root ~= "" then
    return fn.fnamemodify(root, ":p:h:h")
  end
  return nil
end

local function update_registry(name, path)
  local registry = read_json(REGISTRY_FILE) or {}
  registry[name] = path
  for pname, ppath in pairs(registry) do
    if fn.isdirectory(ppath) == 0 then registry[pname] = nil end
  end
  write_json(REGISTRY_FILE, registry)
end

-- === TELESCOPE PICKER ===
local function pick_project_telescope(items, on_select)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.ui.select(items, { 
      prompt = "Switch GhostProject", 
      format_item = function(item) return item.name end 
    }, on_select)
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "👻 Switch Ghost Project",
    finder = finders.new_table({
      results = items,
      entry_maker = function(entry)
        return {
          value = entry,
          display = "📦 " .. entry.name,
          ordinal = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and selection.value then
          on_select(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

-- ============================================================
-- 2. Gestione Colori
-- ============================================================

local function apply_project_color()
  local default_color = api.nvim_get_hl(0, { name = "Function" }).fg
  local hex_color = default_color and string.format("#%06x", default_color) or "#ffffff"
  local color = vim.g.ghost_color or hex_color
  api.nvim_set_hl(0, "GhostAccent", { fg = color, bold = true })
end

-- ============================================================
-- 3. Sessione
-- ============================================================

local function close_ui_plugins()
  local wins = api.nvim_list_wins()
  for _, win in ipairs(wins) do
    local buf = api.nvim_win_get_buf(win)
    local ft = api.nvim_buf_get_option(buf, "filetype")
    if ft == "neo-tree" or ft == "Trouble" or ft == "qf" or ft == "lazy" or ft == "toggleterm" then
      api.nvim_win_close(win, true)
    end
  end
end

function M.save_session()
  if not M.current_project or not M.project_root then return end
  local vault = M.project_root .. "/" .. VAULT_DIR
  if fn.isdirectory(vault) == 0 then return end
  
  update_registry(M.current_project.name, M.project_root)
  
  -- HOOK: Pre-Save (Utile per salvare stato di plugin esterni come Harpoon o Bufferline)
  api.nvim_exec_autocmds("User", { pattern = "GhostSavePre" })

  vim.opt.sessionoptions = "buffers,curdir,tabpages,winsize,help,globals,skiprtp,resize,blank,folds,terminal,localoptions"
  close_ui_plugins()

  local tmp_file = vault .. "/state.tmp"
  vim.cmd("mksession! " .. tmp_file)

  local f_in = io.open(tmp_file, "r")
  if not f_in then return end
  local content = f_in:read("*a")
  f_in:close()

  -- Sanitizzazione Percorsi
  local root = M.project_root
  local escaped_root = root:gsub("([%-%^%$%(%)%%%.%[%]%*%+%?])", "%%%1")
  
  -- 1. Rimuovi path assoluto del progetto (rende relativi i buffer)
  local sanitized = content:gsub(escaped_root .. "[/\\]", "")
  -- 2. Rimuovi TUTTI i comandi cd/lcd/tcd per evitare lock su cartelle vecchie
  sanitized = sanitized:gsub("\n%w*cd .-\n", "\n")

  local final_file = vault .. "/" .. STATE_FILE
  local f_out = io.open(final_file, "w")
  if f_out then f_out:write(sanitized) f_out:close() end
  os.remove(tmp_file)
end

function M.restore_session()
  if not M.project_root then return end
  local session_path = M.project_root .. "/" .. VAULT_DIR .. "/" .. STATE_FILE
  
  if fn.filereadable(session_path) == 1 then
    api.nvim_set_current_dir(M.project_root)
    
    -- HOOK: Pre-Load
    api.nvim_exec_autocmds("User", { pattern = "GhostLoadPre" })

    -- Tolto 'silent!' per debugging se serve, rimettilo se ti dà fastidio
    local ok, err = pcall(vim.cmd, "source " .. session_path)
    if not ok then
       vim.notify("Errore caricamento sessione: " .. err, vim.log.levels.WARN)
    end

    -- HOOK: Post-Load (Utile per riordinare buffer o riaprire sidebar)
    api.nvim_exec_autocmds("User", { pattern = "GhostLoadPost" })
  end
end

-- ============================================================
-- 4. Core Load
-- ============================================================

local function configure_gitignore(root_path)
  local gitignore = root_path .. "/.gitignore"
  if fn.filereadable(gitignore) == 0 then return end
  local f = io.open(gitignore, "r")
  local content = f:read("*a") or ""
  f:close()
  if content:find(VAULT_DIR) then return end

  vim.schedule(function()
    vim.ui.select(
      { "🔒 Personale", "🤝 Collaborativo", "Ignora per ora" },
      { prompt = "Gitignore rilevato. Gestione GhostVault?" },
      function(choice)
        if not choice or choice == "Ignora per ora" then return end
        local f_app = io.open(gitignore, "a+")
        if not f_app then return end
        if content ~= "" and content:sub(-1) ~= "\n" then f_app:write("\n") end
        f_app:write("# GhostVault\n")
        if choice:find("Personale") then f_app:write(VAULT_DIR .. "/\n")
        else 
          f_app:write(VAULT_DIR .. "/" .. STATE_FILE .. "\n")
        end
        f_app:close()
        pcall(vim.cmd, "Neotree git_status")
      end
    )
  end)
end

local function load_project_core(root_path)
  local identity_path = root_path .. "/" .. VAULT_DIR .. "/" .. IDENTITY_FILE
  if fn.filereadable(identity_path) == 0 then return end
  local id_data = read_json(identity_path)
  if not id_data then return end

  M.project_root = root_path
  M.current_project = id_data
  
  vim.g.ghost_current_notes_root = root_path .. "/" .. VAULT_DIR .. "/notes"

  update_registry(id_data.name, root_path)
  
  vim.g.ghost_run_cmd = nil
  vim.g.ghost_startup_cmds = nil
  vim.g.ghost_color = nil

  local local_lua = root_path .. "/" .. VAULT_DIR .. "/" .. LOCAL_CONFIG
  if fn.filereadable(local_lua) == 1 then dofile(local_lua) end
  apply_project_color()

  vim.schedule(function()
    M.restore_session()
    local cmds = vim.g.ghost_startup_cmds
    if cmds and type(cmds) == "table" then
      for _, cmd in ipairs(cmds) do vim.cmd(cmd) end
    end
  end)

  configure_gitignore(root_path)
end

-- ============================================================
-- 5. API Pubbliche
-- ============================================================

function M.get_project_name()
  if M.current_project then return "👻 " .. M.current_project.name end
  return nil
end

function M.run_project()
  local cmd = vim.g.ghost_run_cmd
  if not cmd or cmd == "" then
    vim.notify("Nessun comando in vim.g.ghost_run_cmd", vim.log.levels.WARN)
    return
  end
  local has_tt = pcall(require, "toggleterm")
  if has_tt then
    vim.cmd(string.format('TermExec cmd="%s" go_back=0 direction=horizontal name="GhostRun"', cmd))
  else
    vim.cmd("split | term " .. cmd)
  end
end

function M.open_scratchpad()
  if not M.current_project or not M.project_root then
    vim.notify("Nessun progetto GhostVault attivo.", vim.log.levels.WARN)
    return
  end
  local path = M.project_root .. "/" .. VAULT_DIR .. "/" .. SCRATCHPAD_FILE
  if fn.filereadable(path) == 0 then
    local f = io.open(path, "w")
    if f then
      f:write("# 📝 Lavagna: " .. M.current_project.name .. "\n\n")
      f:write("Status: [ ] In corso\n\n")
      f:write("## TODO\n- [ ] \n\n")
      f:write("## Appunti\n")
      f:close()
    end
  end
  local ok, gn = pcall(require, "ghostnotes")
  if not ok then ok, gn = pcall(require, "config.ghostnotes") end
  if ok and gn and gn.open_note_floating then
    gn.open_note_floating(path)
  else
    vim.cmd("e " .. path)
  end
end

function M.init_here()
  local root = fn.getcwd()
  local vault = root .. "/" .. VAULT_DIR
  if fn.isdirectory(vault) == 1 then vim.notify("Già inizializzato!", vim.log.levels.WARN) return end
  vim.ui.input({ prompt = "Nome Progetto: " }, function(name)
    if not name or name == "" then return end
    fn.mkdir(vault, "p")
    fn.mkdir(vault .. "/notes", "p")
    write_json(vault .. "/" .. IDENTITY_FILE, { id = tostring(os.time()), name = name })
    local f = io.open(vault .. "/" .. LOCAL_CONFIG, "w")
    if f then
      f:write("-- Config " .. name .. "\n")
      f:write('vim.g.ghost_run_cmd = "echo Ciao ' .. name .. '"\n')
      f:close()
    end
    vim.notify("GhostVault creato!", vim.log.levels.INFO)
    local function step3() load_project_core(root) end
    if fn.isdirectory(root .. "/.git") == 0 then
      vim.ui.select({"Sì, Git init", "No"}, { prompt = "Init Git?" }, function(c)
        if c == "Sì, Git init" then fn.system("git init " .. root) end
        step3()
      end)
    else step3() end
  end)
end

function M.switch_project()
  local registry = read_json(REGISTRY_FILE) or {}
  local items = {}
  for name, path in pairs(registry) do table.insert(items, { name = name, path = path }) end
  if #items == 0 then return end

  pick_project_telescope(items, function(c)
    if not c then return end
    if M.current_project then M.save_session() end
    vim.cmd("%bwipeout!")
    api.nvim_set_current_dir(c.path)
    load_project_core(c.path)
  end)
end

function M.delete_project()
  local registry = read_json(REGISTRY_FILE) or {}
  local items = {}
  for name, path in pairs(registry) do table.insert(items, { name = name, path = path }) end
  if #items == 0 then vim.notify("Nessun progetto.", vim.log.levels.WARN) return end

  vim.ui.select(items, { prompt = "DELETE GhostProject:", format_item = function(i) return i.name end }, function(c)
    if not c then return end
    vim.ui.select({"No", "Yes, DELETE"}, { prompt = "Delete '" .. c.name .. "' config?" }, function(confirm)
      if confirm == "Yes, DELETE" then
        local reg = read_json(REGISTRY_FILE) or {}
        reg[c.name] = nil
        write_json(REGISTRY_FILE, reg)
        local vault_path = c.path .. "/" .. VAULT_DIR
        if fn.isdirectory(vault_path) == 1 then fn.delete(vault_path, "rf") end
        -- pulizia gitignore...
        if M.current_project and M.current_project.name == c.name then
          M.current_project = nil
          M.project_root = nil
        end
        vim.notify("Progetto eliminato.", vim.log.levels.INFO)
      end
    end)
  end)
end

function M.setup()
  local r = find_project_root()
  if r then load_project_core(r)
  else api.nvim_create_autocmd("VimEnter", { callback = function() if not M.current_project then local x=find_project_root() if x then load_project_core(x) end end end }) end
  api.nvim_create_autocmd("VimLeavePre", { callback = function() if M.current_project then M.save_session() end end })
  
  api.nvim_create_user_command("GhostInit", M.init_here, {})
  api.nvim_create_user_command("GhostSwitch", M.switch_project, {})
  api.nvim_create_user_command("GhostRun", M.run_project, {})
  api.nvim_create_user_command("GhostDelete", M.delete_project, {})
  api.nvim_create_user_command("GhostNote", M.open_scratchpad, {})
end

return M
