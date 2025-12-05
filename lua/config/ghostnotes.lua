local M = {}

local fn = vim.fn
local api = vim.api

-- Configurazione Default
local notes_root = fn.expand(vim.g.ghostnotes_root or "~/.notes/code-notes")

-- Namespace
local ns_virtual = api.nvim_create_namespace("GhostNotesVirt")
local ns_links = api.nvim_create_namespace("GhostNotesLinks")

-- Variabili di stato
local note_focus = { win = nil, buf = nil, overlay = nil }
local ghost = { win = nil, buf = nil, file = nil, line = nil }
local ghost_timer = nil

-- Strutture Dati
M.index = {}          
M.notes_by_id = {}    
M.backlinks = {}      
M._project_root = nil
M.config = { 
  show_virtual_text = false 
}

-- ==============================
-- 1. Helpers Generici
-- ==============================

local function get_project_root()
  local git_root = fn.systemlist("git rev-parse --show-toplevel")[1]
  if git_root and git_root ~= "" then return git_root end
  return fn.getcwd()
end

local function get_project_name(root)
  return fn.fnamemodify(root, ":t")
end

local function ensure_dir(path)
  if fn.isdirectory(path) == 0 then fn.mkdir(path, "p") end
end

local function get_main_editor_win()
  local wins = api.nvim_list_wins()
  for _, w in ipairs(wins) do
    local config = api.nvim_win_get_config(w)
    if config.relative == "" then 
       local b = api.nvim_win_get_buf(w)
       local ft = api.nvim_buf_get_option(b, "filetype")
       if ft ~= "neo-tree" and ft ~= "NvimTree" and ft ~= "qf" and ft ~= "Trouble" and ft ~= "lazy" then
          return w
       end
    end
  end
  return 0 
end

local function read_frontmatter(path)
  local ok, lines = pcall(fn.readfile, path)
  if not ok or not lines or #lines == 0 then return nil, lines or {} end
  if lines[1] ~= "---" then return nil, lines end
  
  local meta = {}
  local i = 2
  while i <= #lines do
    local line = lines[i]
    if line == "---" then break end
    local key, value = line:match("^%s*([%w_]+):%s*(.+)%s*$")
    if key and value then meta[key] = value end
    i = i + 1
  end
  
  local body = {}
  for j = i + 1, #lines do body[#body + 1] = lines[j] end
  return meta, body
end

local function format_preview_lines(body, max_lines)
  local lines = {}
  if not body or #body == 0 then return { "(empty note)" } end
  max_lines = max_lines or 8
  local count = 0
  for _, l in ipairs(body) do
    if l:match("%S") then
      if not l:match("^#%s*Note%s*$") then
        local line = l
        local hashes, title = line:match("^(#+)%s*(.+)")
        if hashes and title then
          local level = #hashes
          local icon = (level == 1) and "󰉿 " or "󰧮 "
          line = icon .. title
        end
        line = line:gsub("%[ %]", ""):gsub("%[x%]", "")
        table.insert(lines, line)
        count = count + 1
        if count >= max_lines then break end
      end
    end
  end
  if #lines == 0 then lines = { "(empty note)" } end
  return lines
end

-- === Helper UI Picker (CON PREVIEW) ===
local function pick_note_with_ui(prompt, items, on_choice)
  local ok, pickers = pcall(require, "telescope.pickers")
  if ok then
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new({}, {
      prompt_title = prompt,
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return {
            value = item,
            display = item.display,
            ordinal = item.ordinal or item.display,
            path = item.path, 
            lnum = item.line or 1, 
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}), 
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection and selection.value then
            on_choice(selection.value)
          end
        end)
        return true
      end,
    }):find()
  else
    vim.ui.select(items, {
      prompt = prompt,
      format_item = function(item) return item.display end,
    }, function(choice) 
        if choice then on_choice(choice) end
    end)
  end
end

-- ==============================
-- 2. Gestione Indice
-- ==============================

function M.reload_index()
  M.index = {}
  M.notes_by_id = {}
  M.backlinks = {}
  M._project_root = get_project_root()
  
  local proj_name = get_project_name(M._project_root)
  local dir = notes_root .. "/" .. proj_name
  if fn.isdirectory(dir) == 0 then return end

  local glob = fn.glob(dir .. "/*.md", false, true)
  for _, path in ipairs(glob) do
    local meta, body = read_frontmatter(path)
    if meta and meta.file and meta.line then
      local file = meta.file
      local line = tonumber(meta.line)
      if file and line then
        M.index[file] = M.index[file] or {}

        local preview = nil
        if body and #body > 0 then
          for _, l in ipairs(body) do
            if l:match("%S") then preview = l; break end
          end
        end
        preview = preview or "(empty note)"

        local title = nil
        if body then
            for _, l in ipairs(body) do
                local h = l:match("^#%s*(.+)")
                if h then title = h; break end
            end
        end

        local note_id = fn.fnamemodify(path, ":t:r")
        local note_type = meta.type or "note"

        M.index[file][line] = {
          path = path, preview = preview, title = title or preview,
          id = note_id, type = note_type
        }
        
        M.notes_by_id[note_id] = {
          id = note_id, 
          path = path, 
          title = title or preview,
          file = file, 
          line = line,
          type = note_type 
        }

        local function reg_bl(src, tgt)
             if not src or not tgt then return end
             local s = M.notes_by_id[src]
             if not s then return end
             M.backlinks[tgt] = M.backlinks[tgt] or {}
             table.insert(M.backlinks[tgt], {
                 id = s.id, path = s.path, title = s.title,
                 file = s.file, line = s.line
             })
        end
        if body then
            for _, l in ipairs(body) do
                for t in l:gmatch("%[%[note:([^%]|]+)|([^%]]+)%]") do reg_bl(note_id, t) end
                for t in l:gmatch("%[%[note:([^%]|%]]+)%]") do reg_bl(note_id, t) end
            end
        end
      end
    end
  end
end

local function ensure_index()
  if not next(M.index) then M.reload_index() end
end

-- ==============================
-- 3. Visualizzazione
-- ==============================

local function update_virtual_text_for_buffer(buf)
  api.nvim_buf_clear_namespace(buf, ns_virtual, 0, -1)
  if not M.config.show_virtual_text then return end
  
  local file = api.nvim_buf_get_name(buf)
  if file == "" then return end
  ensure_index()
  
  local notes = M.index[file]
  if not notes then return end

  local line_count = api.nvim_buf_line_count(buf)

  for ln, data in pairs(notes) do
    if ln <= line_count then
        local label = data.title or data.preview or "note"
        if #label > 40 then label = label:sub(1, 37) .. "…" end
        local icon = (data.type == "link") and " " or " "
        
        pcall(api.nvim_buf_set_extmark, buf, ns_virtual, ln - 1, -1, {
          virt_text = { { "  " .. icon .. label, "GhostNotesVirtualText" } },
          virt_text_pos = "eol",
        })
    end
  end
end

local function update_signs_for_buffer(buf)
  local file = api.nvim_buf_get_name(buf)
  if file == "" then return end
  ensure_index()
  
  pcall(vim.fn.sign_unplace, "GhostNotesSigns", { buffer = buf })
  
  local notes = M.index[file]
  if not notes then return end

  local line_count = api.nvim_buf_line_count(buf)

  for ln, data in pairs(notes) do
    if ln <= line_count then
        local sign_name = (data.type == "link") and "GhostNoteLinkSign" or "GhostNoteSign"
        pcall(vim.fn.sign_place, 0, "GhostNotesSigns", sign_name, buf, {
          lnum = tonumber(ln),
          priority = 10,
        })
    end
  end
end

function M.highlight_links_in_buffer(buf)
  api.nvim_buf_clear_namespace(buf, ns_links, 0, -1)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    local row = i - 1
    local s = 1
    while true do
      local start_, finish_ = line:find("%[%[note:([^%]|]+)|([^%]]+)%]%]", s)
      if not start_ then break end
      api.nvim_buf_add_highlight(buf, ns_links, "GhostNotesLink", row, start_ - 1, finish_)
      s = finish_ + 1
    end
    s = 1
    while true do
      local start_, finish_ = line:find("%[%[note:([^%]|%]]+)%]%]", s)
      if not start_ then break end
      api.nvim_buf_add_highlight(buf, ns_links, "GhostNotesLink", row, start_ - 1, finish_)
      s = finish_ + 1
    end
  end
end

-- ==============================
-- 4. Creazione, Link e Gestione Note
-- ==============================

local function get_or_create_note_for_current_pos()
  ensure_index()
  local buf = api.nvim_get_current_buf()
  local file = api.nvim_buf_get_name(buf)
  if file == "" then vim.notify("Buffer senza nome!", vim.log.levels.WARN); return nil end
  local pos = api.nvim_win_get_cursor(0)
  local line = pos[1]

  if M.index[file] and M.index[file][line] then
    return M.index[file][line].path, line, file
  end

  local proj_root = get_project_root()
  local proj_name = get_project_name(proj_root)
  local dir = notes_root .. "/" .. proj_name
  ensure_dir(dir)

  local base = fn.fnamemodify(file, ":t")
  local ts = os.date("!%Y%m%dT%H%M%SZ")
  local filename = string.format("%s_L%d_%s.md", base, line, ts)
  local path = dir .. "/" .. filename

  local lines = {
    "---",
    "type: code_note",
    "project: " .. proj_root,
    "project_name: " .. proj_name,
    "file: " .. file,
    "line: " .. tostring(line),
    "created: " .. ts,
    "---",
    "",
    "# Note",
    "",
    "",
  }
  fn.writefile(lines, path)
  
  M.index[file] = M.index[file] or {}
  M.index[file][line] = { path = path, preview = "(empty note)", title = "Note", type = "code_note" }
  
  update_signs_for_buffer(buf)
  if M.config.show_virtual_text then update_virtual_text_for_buffer(buf) end

  return path, line, file
end

function M.link_current_line_to_existing()
  ensure_index()
  local buf = api.nvim_get_current_buf()
  local file = api.nvim_buf_get_name(buf)
  if file == "" then return end
  local pos = api.nvim_win_get_cursor(0)
  local line = pos[1]

  if M.index[file] and M.index[file][line] then
    vim.notify("Nota già presente su questa riga.", vim.log.levels.WARN)
    return
  end

  local items = {}
  for id, data in pairs(M.notes_by_id) do
    local is_link = false
    local m, _ = read_frontmatter(data.path)
    if m and m.type == "link" then is_link = true end
    if not is_link then
        local fname = fn.fnamemodify(data.path, ":t")
        local display = string.format("%s (%s)", data.title or id, fname)
        table.insert(items, { id = id, title = data.title, path = data.path, display = display, line = data.line })
    end
  end

  if #items == 0 then vim.notify("Nessuna nota da linkare.", vim.log.levels.WARN); return end

  pick_note_with_ui("Link Line to Note:", items, function(choice)
    if not choice then return end
    local proj_root = get_project_root()
    local proj_name = get_project_name(proj_root)
    local dir = notes_root .. "/" .. proj_name
    ensure_dir(dir)
    local ts = os.date("!%Y%m%dT%H%M%SZ")
    local filename = string.format("link_%s_%s.md", choice.id, ts)
    local path = dir .. "/" .. filename

    local lines = {
      "---",
      "type: link",
      "target_id: " .. choice.id,
      "project: " .. proj_root,
      "file: " .. file,
      "line: " .. tostring(line),
      "created: " .. ts,
      "---",
      "",
      "#  Link -> " .. (choice.title or choice.id),
      "",
      "[[note:" .. choice.id .. "]]",
      "",
      "_Satellite file._"
    }
    fn.writefile(lines, path)
    M.reload_index()
    update_signs_for_buffer(buf)
    vim.notify("Link creato!", vim.log.levels.INFO)
  end)
end

function M.delete_note_under_cursor()
  ensure_index()
  local buf = api.nvim_get_current_buf()
  local file = api.nvim_buf_get_name(buf)
  if file == "" then return end
  local pos = api.nvim_win_get_cursor(0)
  local line = pos[1]

  local notes = M.index[file]
  local note = notes and notes[line] or nil
  if not note then vim.notify("Nessuna nota qui.", vim.log.levels.WARN); return end

  vim.ui.select({ "No, cancel", "Yes, delete note" }, {
    prompt = "Delete note: " .. (note.title or note.id) .. "?",
  }, function(choice)
    if choice == "Yes, delete note" then
      
      local deleted_links = 0
      if note.id and M.backlinks[note.id] then
          for _, bl in ipairs(M.backlinks[note.id]) do
              local ref_note = M.notes_by_id[bl.id]
              if ref_note and ref_note.type == "link" then
                  os.remove(ref_note.path)
                  if M.index[ref_note.file] then M.index[ref_note.file][ref_note.line] = nil end
                  M.notes_by_id[ref_note.id] = nil
                  deleted_links = deleted_links + 1
              end
          end
      end

      os.remove(note.path)
      M.index[file][line] = nil
      if vim.tbl_isempty(M.index[file]) then M.index[file] = nil end
      if note.id then M.notes_by_id[note.id] = nil end
      
      update_signs_for_buffer(buf)
      update_virtual_text_for_buffer(buf)
      
      if deleted_links > 0 then
          vim.notify(string.format("Nota eliminata (rimossi %d link).", deleted_links), vim.log.levels.INFO)
      else
          vim.notify("Nota eliminata.", vim.log.levels.INFO)
      end
    end
  end)
end

function M.list_notes_for_current_file()
  ensure_index()
  local file = api.nvim_buf_get_name(0)
  if file == "" then return end
  local notes = M.index[file]
  if not notes or vim.tbl_isempty(notes) then vim.notify("Nessuna nota in questo file.", vim.log.levels.INFO); return end

  local items = {}
  for ln, data in pairs(notes) do
    local icon = (data.type == "link") and " " or " "
    local label = data.title or data.preview or "note"
    local display = string.format("%s L%-4d %s", icon, ln, label)
    table.insert(items, { 
        display = display, 
        ordinal = display,
        path = data.path,  -- Per il preview
        line = 1, 
        code_line = ln     -- Per il jump
    })
  end
  table.sort(items, function(a, b) return a.code_line < b.code_line end)

  pick_note_with_ui("Notes in current file", items, function(choice)
    if not choice then return end
    local target = choice.code_line or choice.lnum or choice.line
    api.nvim_win_set_cursor(0, { target, 0 })
    vim.cmd("normal! zz")
  end)
end

function M.toggle_virtual_text()
  M.config.show_virtual_text = not M.config.show_virtual_text
  local buf = api.nvim_get_current_buf()
  if not M.config.show_virtual_text then
    api.nvim_buf_clear_namespace(buf, ns_virtual, 0, -1)
    vim.notify("GhostNotes: VT OFF", vim.log.levels.INFO)
  else
    update_virtual_text_for_buffer(buf)
    vim.notify("GhostNotes: VT ON", vim.log.levels.INFO)
  end
end

local function get_sorted_note_lines_for_file(file)
  if not next(M.index) then M.reload_index() end
  local notes = M.index[file]
  if not notes or vim.tbl_isempty(notes) then return {} end
  local lines = {}
  for ln, _ in pairs(notes) do table.insert(lines, ln) end
  table.sort(lines)
  return lines
end

function M.goto_next_note()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then return end
  local lines = get_sorted_note_lines_for_file(file)
  if #lines == 0 then return end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local target = nil
  for _, ln in ipairs(lines) do if ln > cur then target = ln; break end end
  if not target then target = lines[1] end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

function M.goto_prev_note()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then return end
  local lines = get_sorted_note_lines_for_file(file)
  if #lines == 0 then return end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local target = nil
  for i = #lines, 1, -1 do local ln = lines[i]; if ln < cur then target = ln; break end end
  if not target then target = lines[#lines] end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

-- ==============================
-- 5. Task Manager & Backlinks (PARSER INTELLIGENTE)
-- ==============================

local function parse_tasks_from_file(path)
  local f = io.open(path, "r")
  if not f then return {} end
  local lines = {}
  for l in f:lines() do table.insert(lines, l) end
  f:close()

  local found_groups = {}
  local filename = fn.fnamemodify(path, ":t")
  if filename == "scratchpad.md" then filename = "LAVAGNA" end
  
  local current_group = {
    title = nil, 
    file = filename, 
    path = path,
    line = 1,
    total = 0, 
    done = 0,
    items = {} 
  }
  
  local group_pushed = false

  for i, line in ipairs(lines) do
    -- 1. TRIGGER TODO:
    local todo_content = line:match("TODO:%s*(.*)$")

    if todo_content then
      local trigger_line = i
      local title = vim.trim(todo_content)
      
      -- 2. LISTA SOTTOSTANTE
      local list_items = {}
      local j = i + 1
      while j <= #lines do
        local next_line = lines[j]
        local is_item = next_line:match("^%s*[-*]%s*%[[^]]*%]")
        
        if is_item then
           local is_done = next_line:match("^%s*[-*]%s*%[[xX]%]")
           local text = next_line:match("^%s*[-*]%s*%[[^]]*%]%s*(.*)") or "Item"
           table.insert(list_items, { text = text, done = (is_done ~= nil), line = j })
        elseif next_line:match("^%s*$") then
           -- skip empty
        else
           break
        end
        j = j + 1
      end

      -- 3. DECISIONE PRIORITÀ
      local has_title = (title ~= "")
      local has_list = (#list_items > 0)

      if has_title then
         -- CASO A/B: Titolo Presente -> Blocco (con o senza lista)
         local done_count = 0
         for _, it in ipairs(list_items) do if it.done then done_count = done_count + 1 end end
         
         table.insert(found_groups, {
            type = "block",
            title = title,
            total = #list_items,
            done = done_count,
            line = trigger_line, 
            path = path,
            file = filename
         })
      elseif has_list then
         -- CASO C: Solo Lista -> Task Singoli
         for _, it in ipairs(list_items) do
            table.insert(found_groups, {
               type = "single",
               title = it.text,
               done = it.done,
               line = it.line,
               path = path,
               file = filename
            })
         end
      end
      
      i = j - 1
    end
    i = i + 1
  end
  return found_groups
end

local function scan_todo_blocks()
  local tasks = {}
  local proj_root = get_project_root()
  
  local proj_name = get_project_name(proj_root)
  local dir = notes_root .. "/" .. proj_name
  if fn.isdirectory(dir) == 1 then
    local glob = fn.glob(dir .. "/*.md", false, true)
    for _, path in ipairs(glob) do
      local file_tasks = parse_tasks_from_file(path)
      for _, t in ipairs(file_tasks) do table.insert(tasks, t) end
    end
  end

  local scratchpad = proj_root .. "/.ghost/scratchpad.md"
  if fn.filereadable(scratchpad) == 0 then scratchpad = proj_root .. "/.ghost/scratchpad.md" end
  if fn.filereadable(scratchpad) == 1 then
      local scratch_tasks = parse_tasks_from_file(scratchpad)
      for _, t in ipairs(scratch_tasks) do table.insert(tasks, t) end
  end

  return tasks
end

function M.list_project_tasks()
  local tasks = scan_todo_blocks()
  if #tasks == 0 then vim.notify("Nessun task trovato.", vim.log.levels.INFO); return end

  table.sort(tasks, function(a, b)
    local a_done = false
    if a.type == "block" then a_done = (a.total > 0 and a.done == a.total) else a_done = a.done end
    local b_done = false
    if b.type == "block" then b_done = (b.total > 0 and b.done == b.total) else b_done = b.done end

    if a_done ~= b_done then return not a_done end
    local af = a.file or ""
    local bf = b.file or ""
    return af < bf
  end)

  local items = {}
  for _, t in ipairs(tasks) do
    local display = ""
    
    if t.type == "block" then
        if t.total == 0 then
            local icon = "🎯" 
            display = string.format("%s %s (%s)", icon, t.title, t.file)
            table.insert(items, { display = display, path = t.path, line = t.line, ordinal = display })
        else
            local percent = math.floor((t.done / t.total) * 100)
            local icon = "📝"
            if t.done == t.total then icon = "✅"
            elseif percent < 30 then icon = "🔴"
            elseif percent < 70 then icon = "🟡"
            else icon = "🟢"
            end
            display = string.format("%s [%d/%d] %s (%s)", icon, t.done, t.total, t.title, t.file)
            table.insert(items, { display = display, path = t.path, line = t.line, ordinal = display })
        end
    else
        local icon = t.done and "✅" or " "
        display = string.format("%s %s (%s)", icon, t.title, t.file)
        table.insert(items, { display = display, path = t.path, line = t.line, ordinal = display })
    end
  end

  pick_note_with_ui("Ghost Tasks", items, function(choice)
    if not choice then return end
    M.open_note_floating(choice.path)
    vim.defer_fn(function()
       if note_focus.win and api.nvim_win_is_valid(note_focus.win) then
          api.nvim_win_set_cursor(note_focus.win, { choice.line, 0 })
          vim.cmd("normal! zz")
       end
    end, 100)
  end)
end

-- ==============================
-- [RESTO DEL FILE INVARIATO]
-- (Funzioni insert_note_link, follow, show_backlinks, float navigation, setup)
-- Assicurati di copiare le funzioni sotto da qui in poi per completezza
-- ==============================

function M.insert_note_link_via_picker()
  if not next(M.notes_by_id) then M.reload_index() end
  local target_buf = api.nvim_get_current_buf()
  local target_win = api.nvim_get_current_win()
  local current_path = api.nvim_buf_get_name(target_buf)
  local current_id = fn.fnamemodify(current_path, ":t:r")

  local items = {}
  for id, data in pairs(M.notes_by_id) do
    if id ~= current_id then
      local fname = fn.fnamemodify(data.file or data.path, ":t")
      local display = string.format("%s:%d  %s", fname, data.line or 0, data.title or id)
      table.insert(items, { id = id, title = data.title, path = data.path, display = display })
    end
  end

  pick_note_with_ui("Link to note", items, function(choice)
    if not choice then return end
    if api.nvim_win_is_valid(target_win) then api.nvim_set_current_win(target_win) end
    local pos = api.nvim_win_get_cursor(target_win)
    local line = api.nvim_get_current_line()
    local link = string.format("[[note:%s|%s]]", choice.id, choice.title or choice.id)
    local before = line:sub(1, pos[2])
    local after = line:sub(pos[2] + 1)
    api.nvim_set_current_line(before .. link .. after)
    api.nvim_win_set_cursor(target_win, {pos[1], pos[2] + #link})
    M.highlight_links_in_buffer(target_buf)
  end)
end

function M.follow_link_under_cursor()
  M.reload_index()
  local buf = api.nvim_get_current_buf()
  local pos = api.nvim_win_get_cursor(0)
  local line = api.nvim_buf_get_lines(buf, pos[1]-1, pos[1], false)[1] or ""
  local col = pos[2]
  local target_id = nil
  
  local s = 1
  while true do
    local st, en, id = line:find("%[%[note:([^%]|]+)|[^%]]+%]%]", s)
    if not st then break end
    if col+1 >= st and col+1 <= en then target_id = id; break end
    s = en + 1
  end
  if not target_id then
    s = 1
    while true do
      local st, en, id = line:find("%[%[note:([^%]|%]]+)%]%]", s)
      if not st then break end
      if col+1 >= st and col+1 <= en then target_id = id; break end
      s = en + 1
    end
  end

  if target_id then
    local target = M.notes_by_id[vim.trim(target_id)]
    if target then M.open_note_floating(target.path) else vim.notify("Nota non trovata: "..target_id, vim.log.levels.ERROR) end
  else
    vim.notify("Nessun link trovato.", vim.log.levels.WARN)
  end
end

function M.show_backlinks_for_current_note()
  if not next(M.notes_by_id) then M.reload_index() end
  local current_path = api.nvim_buf_get_name(0)
  local current_id = fn.fnamemodify(current_path, ":t:r")
  local backs = M.backlinks[current_id]
  if not backs or #backs == 0 then vim.notify("Nessun backlink.", vim.log.levels.INFO); return end
  local items = {}
  for _, b in ipairs(backs) do
    local fname = fn.fnamemodify(b.file or b.path, ":t")
    local display = string.format("%s:%d  %s", fname, b.line or 0, b.title or b.id)
    table.insert(items, { id = b.id, path = b.path, display = display })
  end
  pick_note_with_ui("Backlinks", items, function(c) if c then M.open_note_floating(c.path) end end)
end

-- ==============================
-- 6. Floating Editor & Navigation
-- ==============================

local function close_note_floating()
  if note_focus.win and api.nvim_win_is_valid(note_focus.win) then api.nvim_win_close(note_focus.win, true) end
  if note_focus.overlay and api.nvim_win_is_valid(note_focus.overlay) then api.nvim_win_close(note_focus.overlay, true) end
  note_focus.win = nil
  note_focus.overlay = nil
  note_focus.buf = nil
end

local function setup_note_protection(buf, win)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local end_row = 0
  for i, line in ipairs(lines) do if i > 1 and line == "---" then end_row = i; break end end
  if end_row == 0 then return end 

  if win and api.nvim_win_is_valid(win) then
      api.nvim_win_set_option(win, "foldmethod", "manual")
      api.nvim_win_set_option(win, "foldenable", true)
  end
  
  -- FIX CRASH: Usa win_call al posto di buf_call
  if win and api.nvim_win_is_valid(win) then
      api.nvim_win_call(win, function()
          pcall(function()
              vim.cmd("normal! zE")
              vim.cmd(string.format("1,%dfold", end_row))
          end)
      end)
  end

  api.nvim_create_autocmd("InsertEnter", {
    buffer = buf,
    callback = function()
      local cursor = api.nvim_win_get_cursor(0)
      if cursor[1] <= end_row then
        local key = api.nvim_replace_termcodes("<Esc>", true, false, true)
        api.nvim_feedkeys(key, "n", false)
        local safe = end_row + 1
        if lines[safe] == "" then safe = safe + 1 end
        if safe > #lines then api.nvim_buf_set_lines(buf, end_row, end_row, false, { "" }) end
        api.nvim_win_set_cursor(0, { safe, 0 })
        vim.notify("🔒 Metadati protetti.", vim.log.levels.WARN)
      end
    end,
  })
end

function M.jump_to_code_context()
  local buf = api.nvim_get_current_buf()
  local lines = api.nvim_buf_get_lines(buf, 0, 15, false) 
  local target_file, target_line
  for _, line in ipairs(lines) do
    if not target_file then target_file = line:match("^file:%s*(.+)$") end
    if not target_line then target_line = line:match("^line:%s*(%d+)$") end
    if target_file and target_line then break end
  end

  if not target_file or not target_line then vim.notify("Nota non ancorata.", vim.log.levels.WARN); return end

  if M.close_and_save_internal then M.close_and_save_internal() else vim.cmd("close") end

  vim.schedule(function()
    if vim.fn.filereadable(target_file) == 0 then vim.notify("File non trovato.", vim.log.levels.ERROR); return end
    
    local main_win = get_main_editor_win()
    if main_win ~= 0 then api.nvim_set_current_win(main_win) end
    
    vim.cmd("e " .. target_file)
    pcall(api.nvim_win_set_cursor, 0, { tonumber(target_line), 0 })
    vim.cmd("normal! zz")
    local cl = api.nvim_win_get_cursor(0)[1]
    api.nvim_buf_add_highlight(0, -1, "IncSearch", cl - 1, 0, -1)
    vim.defer_fn(function() api.nvim_buf_clear_namespace(0, -1, cl - 1, cl) end, 300)
  end)
end

function M.open_note_floating(path, no_redirect)
  if not no_redirect then
      local meta, _ = read_frontmatter(path)
      if meta and meta.type == "link" and meta.target_id then
          if not next(M.notes_by_id) then M.reload_index() end
          local target = M.notes_by_id[meta.target_id]
          if target then return M.open_note_floating(target.path) end
      end
  end

  close_note_floating()
  local buf = fn.bufadd(path)
  fn.bufload(buf)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "" 
  local ok, ts = pcall(require, "vim.treesitter")
  if ok and ts.start then ts.start(buf, "markdown") end

  local cols, lines = vim.o.columns, vim.o.lines
  local overlay_win = api.nvim_open_win(api.nvim_create_buf(false, true), false, {
    relative="editor", width=cols, height=lines, row=0, col=0, style="minimal", border="none", zindex=(fn.has("nvim-0.10")==1 and 30 or nil)
  })
  api.nvim_set_hl(0, "GhostNotesDim", { bg = "#000000", default = false })
  api.nvim_win_set_option(overlay_win, "winhighlight", "Normal:GhostNotesDim")
  pcall(api.nvim_win_set_option, overlay_win, "winblend", 40)

  local width = math.floor(cols * 0.9)
  local height = math.floor(lines * 0.85)
  local win = api.nvim_open_win(buf, true, {
    relative="editor", width=width, height=height, row=math.floor((lines-height)/2), col=math.floor((cols-width)/2),
    style="minimal", border="rounded", zindex=(fn.has("nvim-0.10")==1 and 31 or nil)
  })
  
  api.nvim_win_set_option(win, "winhighlight", "Normal:GhostNotesFloat,FloatBorder:FloatBorder")
  api.nvim_win_set_option(win, "conceallevel", 2)
  api.nvim_win_set_option(win, "concealcursor", "nc")
  api.nvim_win_set_option(win, "wrap", false) 
  api.nvim_win_set_option(win, "signcolumn", "yes:1") 
  api.nvim_win_set_option(win, "foldtext", "'🔒 Metadata (read-only)'")
  api.nvim_win_set_option(win, "foldcolumn", "0") 
  api.nvim_win_set_option(win, "fillchars", "fold: ")

  setup_note_protection(buf, win)

  local function close_and_save()
    if api.nvim_buf_is_valid(buf) and api.nvim_buf_get_option(buf, 'modified') then
       vim.api.nvim_buf_call(buf, function() vim.cmd("silent! write") end)
    end
    close_note_floating()
    M.reload_index()
  end
  M.close_and_save_internal = close_and_save

  -- FIX: Guardiano per evitare apertura file nel float
  api.nvim_create_autocmd("BufEnter", {
    buffer = nil, 
    callback = function(args)
      if api.nvim_get_current_win() ~= win then return end
      if args.buf == buf then return end
      local ft = api.nvim_buf_get_option(args.buf, "filetype")
      if ft == "TelescopePrompt" or ft == "neo-tree" or ft == "lazy" then return end

      local new_buf = args.buf
      close_note_floating()

      local target_win = get_main_editor_win()
      if target_win == 0 then
         vim.cmd("split")
         target_win = api.nvim_get_current_win()
      end
      
      api.nvim_set_current_win(target_win)
      api.nvim_win_set_buf(target_win, new_buf)
    end
  })

  vim.keymap.set("n", "q", close_and_save, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", close_and_save, { buffer = buf, silent = true })
  vim.keymap.set("n", "<leader>ax", function() M.insert_note_link_via_picker() end, { buffer = buf, silent = true })
  vim.keymap.set("n", "af", function() M.follow_link_under_cursor() end, { buffer = buf, silent = true })
  vim.keymap.set("n", "gd", M.jump_to_code_context, { buffer = buf, silent = true })

  note_focus.win = win; note_focus.buf = buf; note_focus.overlay = overlay_win
  M.highlight_links_in_buffer(buf)
  api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, { buffer = buf, callback = function(a) M.highlight_links_in_buffer(a.buf) end })
end

function M.add_or_edit_note_here()
  local path = get_or_create_note_for_current_pos()
  if path then M.open_note_floating(path) end
end

-- ==============================
-- 7. Ghost Popup Preview
-- ==============================

local function close_ghost()
  if ghost.win and api.nvim_win_is_valid(ghost.win) then api.nvim_win_close(ghost.win, true) end
  ghost.win = nil; ghost.buf = nil; ghost.file = nil; ghost.line = nil
end

function M.show_ghost_under_cursor()
  ensure_index()
  local buf = api.nvim_get_current_buf()
  local file = api.nvim_buf_get_name(buf)
  if file == "" then close_ghost(); return end
  local pos = api.nvim_win_get_cursor(0)
  local line = pos[1]
  local notes = M.index[file]
  local note = notes and notes[line] or nil
  
  if not note then close_ghost(); return end
  if ghost.file == file and ghost.line == line and ghost.win and api.nvim_win_is_valid(ghost.win) then return end
  close_ghost()

  local _, body = read_frontmatter(note.path)
  local lines = format_preview_lines(body, 8)
  ghost.buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(ghost.buf, 0, -1, false, lines)

  for i, l in ipairs(lines) do
    if l:match("^󰉿 ") or l:match("^󰧮 ") then api.nvim_buf_add_highlight(ghost.buf, -1, "GhostNotesPreviewTitle", i-1, 0, -1)
    elseif l:match("") or l:match("") then api.nvim_buf_add_highlight(ghost.buf, -1, "GhostNotesPreviewTodo", i-1, 0, -1)
    end
  end

  local maxlen = 0
  for _, l in ipairs(lines) do local w = fn.strdisplaywidth(l); if w > maxlen then maxlen = w end end
  
  ghost.win = api.nvim_open_win(ghost.buf, false, {
    relative="cursor", row=1, col=1, width=math.min(math.max(maxlen+2, 20), vim.o.columns-4),
    height=math.min(#lines, 10), style="minimal", border="rounded", zindex=(fn.has("nvim-0.10")==1 and 25 or nil)
  })
  api.nvim_win_set_option(ghost.win, "winhighlight", "Normal:GhostNotesPreview,FloatBorder:FloatBorder")
  ghost.file = file; ghost.line = line
end

-- ==============================
-- 8. Ricerca Globale (The Brain)
-- ==============================

function M.search_in_notes()
  local proj_root = get_project_root()
  local proj_name = get_project_name(proj_root)
  local dir = notes_root .. "/" .. proj_name
  
  if fn.isdirectory(dir) == 0 then 
      vim.notify("Nessuna nota trovata per questo progetto.", vim.log.levels.WARN)
      return 
  end

  -- Usiamo il live_grep di Telescope limitato alla cartella delle note
  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then 
      vim.notify("Questa funzione richiede Telescope.", vim.log.levels.ERROR)
      return 
  end

  builtin.live_grep({
    prompt_title = "🔍 Cerca nel Cervello (" .. proj_name .. ")",
    cwd = dir,
    -- Opzionale: argomenti extra per ripgrep per ignorare i file di sistema o metadati se vuoi
    -- additional_args = function() return { "--hidden" } end 
  })
end

-- ==============================
-- 9. Setup & Mappings
-- ==============================

function M.setup(opts)
  opts = opts or {}
  if opts.show_virtual_text ~= nil then
     M.config.show_virtual_text = opts.show_virtual_text
  end

  local group = api.nvim_create_augroup("GhostNotes", { clear = true })
  
  -- Highlights
  vim.api.nvim_set_hl(0, "GhostNotesPreview", { bg = "#11111b", default = false })
  vim.api.nvim_set_hl(0, "GhostNotesPreviewTitle", { fg = "#f9e2af", bold = true, default = false })
  vim.api.nvim_set_hl(0, "GhostNotesPreviewTodo", { fg = "#a6e3a1", default = false })
  vim.api.nvim_set_hl(0, "GhostNotesSign", { fg = "#f9e2af", default = false })
  vim.api.nvim_set_hl(0, "GhostNotesLinkSign", { fg = "#89b4fa", bold = true, default = false }) 
  vim.api.nvim_set_hl(0, "GhostNotesVirtualText", { fg = "#6c7086", italic = true, default = false })
  vim.api.nvim_set_hl(0, "Folded", { fg = "#6c7086", bg = "#1e1e2e", italic = true, force = true })

  vim.fn.sign_define("GhostNoteSign", { text = "", texthl = "GhostNotesSign" })
  vim.fn.sign_define("GhostNoteLinkSign", { text = "", texthl = "GhostNotesLinkSign" })

  -- Autocmds
  api.nvim_create_autocmd({ "CursorMoved" }, {
    group = group,
    callback = function()
      if ghost_timer then vim.uv.timer_stop(ghost_timer); ghost_timer = nil end
      close_ghost()
      local bt = vim.bo.buftype
      if bt ~= "" then return end
      if api.nvim_win_get_config(0).relative ~= "" then return end
      
      ghost_timer = vim.uv.new_timer()
      ghost_timer:start(250, 0, vim.schedule_wrap(function()
        if api.nvim_buf_is_valid(0) then M.show_ghost_under_cursor() end
        ghost_timer = nil
      end))
    end,
  })

  api.nvim_create_autocmd({ "CmdlineEnter", "BufLeave", "WinLeave", "InsertEnter" }, {
    group = group, callback = function() close_ghost() end
  })

  api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = group,
    callback = function(args)
      local bt = vim.bo[args.buf].buftype
      if bt ~= "" then return end
      update_signs_for_buffer(args.buf)
      if M.config.show_virtual_text then update_virtual_text_for_buffer(args.buf) end
    end,
  })

  -- Keymappings
  vim.keymap.set("n", "<leader>an", M.add_or_edit_note_here, { desc = "Add/edit code note" })
  vim.keymap.set("n", "<leader>ak", M.link_current_line_to_existing, { desc = "Link existing note" })
  vim.keymap.set("n", "<leader>ad", M.delete_note_under_cursor, { desc = "Delete note" })
  vim.keymap.set("n", "<leader>al", M.list_notes_for_current_file, { desc = "List notes file" })
  vim.keymap.set("n", "<leader>av", M.toggle_virtual_text, { desc = "Toggle virtual text" })
  vim.keymap.set("n", "<leader>at", M.list_project_tasks, { desc = "Ghost Tasks (TODO)" })
  vim.keymap.set("n", "<leader>ab", M.show_backlinks_for_current_note, { desc = "Ghost Backlinks" })
  vim.keymap.set("n", "<leader>as", M.search_in_notes, { desc = "Search text in GhostNotes" })
  vim.keymap.set("n", "]n", M.goto_next_note, { desc = "Next note" })
  vim.keymap.set("n", "[n", M.goto_prev_note, { desc = "Prev note" })
end

return M
