--- table_mode.lua
--- Table mode is the primary "outer" mode — analogous to Neovim's Normal mode.
--- It is active while navigating and structurally editing a table
--- (adding/removing rows and columns, aligning, etc.).
---
--- ┌─────────────────────────────────────────────────────────────────┐
--- │  Key         │  Action                                          │
--- ├─────────────────────────────────────────────────────────────────┤
--- │  h / ←       │  Move left one cell                              │
--- │  l / →       │  Move right one cell                             │
--- │  k / ↑       │  Move up one row                                 │
--- │  j / ↓       │  Move down one row                               │
--- │  Tab         │  Move right one cell (wraps to next row)         │
--- │  S-Tab       │  Move left one cell                              │
--- │  i / Enter   │  Enter Cell mode (edit current cell)             │
--- │  o           │  Insert row below current row                    │
--- │  O           │  Insert row above current row                    │
--- │  D           │  Delete current row                              │
--- │  A           │  Append column after current column              │
--- │  I           │  Insert column before current column             │
--- │  X           │  Delete current column                           │
--- │  =           │  Re-align / format the whole table               │
--- │  q / Esc     │  Exit Table mode                                 │
--- └─────────────────────────────────────────────────────────────────┘

local parser    = require("ascii_table.parser")
local renderer  = require("ascii_table.renderer")
local state     = require("ascii_table.state")
local cell_mode = require("ascii_table.cell_mode")

local M  = {}
local NS = vim.api.nvim_create_namespace("ascii_table")

-- Internal utilities 

--- Move cursor to the given cell and update the highlight.
local function go_to_cell(bufnr, st, row, col)
  st.row = math.max(1, math.min(st.tbl.nrows, row))
  st.col = math.max(1, math.min(st.tbl.ncols, col))

  local bl, bc = renderer.cell_cursor_pos(st.tbl, st.row, st.col)
  vim.api.nvim_win_set_cursor(0, { bl, bc - 1 })  -- nvim uses 0-indexed col

  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  vim.api.nvim_buf_add_highlight(
    bufnr, NS, "Visual",
    bl - 1, bc - 1, bc - 1 + st.tbl.col_widths[st.col]
  )
end

--- After modifying tbl.rows / tbl.col_widths, re-render and re-parse.
local function flush(bufnr, st)
  renderer.recalc_widths(st.tbl)
  renderer.write(bufnr, st.tbl)
  local fresh = parser.parse(bufnr, st.tbl.start_line, st.tbl.end_line)
  if fresh then st.tbl = fresh end
  -- Clamp current position
  st.row = math.min(st.row, st.tbl.nrows)
  st.col = math.min(st.col, st.tbl.ncols)
  go_to_cell(bufnr, st, st.row, st.col)
end

-- Navigation 

local function nav(bufnr, drow, dcol)
  local st = state.get(bufnr)
  if not st or st.mode ~= "table" then return end
  go_to_cell(bufnr, st, st.row + drow, st.col + dcol)
end

--- Tab wraps: at the last column, move to col 1 of the next row.
local function tab_next(bufnr)
  local st = state.get(bufnr)
  if not st or st.mode ~= "table" then return end
  if st.col == st.tbl.ncols then
    go_to_cell(bufnr, st, st.row + 1, 1)
  else
    go_to_cell(bufnr, st, st.row, st.col + 1)
  end
end

local function tab_prev(bufnr)
  local st = state.get(bufnr)
  if not st or st.mode ~= "table" then return end
  if st.col == 1 then
    go_to_cell(bufnr, st, st.row - 1, st.tbl.ncols)
  else
    go_to_cell(bufnr, st, st.row, st.col - 1)
  end
end

-- Row operations 

local function insert_row(bufnr, offset)
  local st = state.get(bufnr)
  if not st or st.mode ~= "table" then return end
  local empty = {}
  for _ = 1, st.tbl.ncols do table.insert(empty, "") end
  local pos = st.row + offset          -- offset: 0 = above, 1 = below
  table.insert(st.tbl.rows, pos, empty)
  st.tbl.nrows = st.tbl.nrows + 1
  st.row = pos
  flush(bufnr, st)
end

local function delete_row(bufnr)
  local st = state.get(bufnr)
  if not st or st.mode ~= "table" then return end
  if st.tbl.nrows <= 1 then
    vim.notify("[ascii_table] Cannot delete the only row.", vim.log.levels.WARN)
    return
  end
  table.remove(st.tbl.rows, st.row)
  st.tbl.nrows = st.tbl.nrows - 1
  flush(bufnr, st)
end

-- Column operations 

local function insert_col(bufnr, offset)
  local st = state.get(bufnr)
  if not st or st.mode ~= "table" then return end
  local pos = st.col + offset          -- offset: 0 = before, 1 = after
  for _, row in ipairs(st.tbl.rows) do
    table.insert(row, pos, "")
  end
  table.insert(st.tbl.col_widths, pos, 1)
  st.tbl.ncols = st.tbl.ncols + 1
  st.col = pos
  flush(bufnr, st)
end

local function delete_col(bufnr)
  local st = state.get(bufnr)
  if not st or st.mode ~= "table" then return end
  if st.tbl.ncols <= 1 then
    vim.notify("[ascii_table] Cannot delete the only column.", vim.log.levels.WARN)
    return
  end
  for _, row in ipairs(st.tbl.rows) do
    table.remove(row, st.col)
  end
  table.remove(st.tbl.col_widths, st.col)
  st.tbl.ncols = st.tbl.ncols - 1
  flush(bufnr, st)
end

-- Format / align 

local function format_table(bufnr)
  local st = state.get(bufnr)
  if not st or st.mode ~= "table" then return end
  flush(bufnr, st)
  vim.notify("[ascii_table] Table formatted.", vim.log.levels.INFO)
end

-- Keymap registration 

-- Keep track of keys we've set so we can remove them cleanly on exit.
local _registered = {}  -- [bufnr] = list of { mode, lhs }

local function map(bufnr, mode, lhs, fn, desc)
  vim.keymap.set(mode, lhs, fn, {
    buffer  = bufnr,
    nowait  = true,
    silent  = true,
    desc    = "[ascii_table] " .. desc,
  })
  _registered[bufnr] = _registered[bufnr] or {}
  table.insert(_registered[bufnr], { mode, lhs })
end

local function setup_keymaps(bufnr)
  -- Navigation
  map(bufnr, "n", "h",       function() nav(bufnr,  0, -1) end,   "Move left")
  map(bufnr, "n", "l",       function() nav(bufnr,  0,  1) end,   "Move right")
  map(bufnr, "n", "k",       function() nav(bufnr, -1,  0) end,   "Move up")
  map(bufnr, "n", "j",       function() nav(bufnr,  1,  0) end,   "Move down")
  map(bufnr, "n", "<Left>",  function() nav(bufnr,  0, -1) end,   "Move left")
  map(bufnr, "n", "<Right>", function() nav(bufnr,  0,  1) end,   "Move right")
  map(bufnr, "n", "<Up>",    function() nav(bufnr, -1,  0) end,   "Move up")
  map(bufnr, "n", "<Down>",  function() nav(bufnr,  1,  0) end,   "Move down")
  map(bufnr, "n", "<Tab>",   function() tab_next(bufnr) end,      "Next cell (wrap)")
  map(bufnr, "n", "<S-Tab>", function() tab_prev(bufnr) end,      "Prev cell (wrap)")

  -- Enter Cell mode
  map(bufnr, "n", "i",    function() cell_mode.enter(bufnr) end, "Enter Cell mode")
  map(bufnr, "n", "<CR>", function() cell_mode.enter(bufnr) end, "Enter Cell mode")

  -- Row operations
  map(bufnr, "n", "o", function() insert_row(bufnr, 1) end,  "Insert row below")
  map(bufnr, "n", "O", function() insert_row(bufnr, 0) end,  "Insert row above")
  map(bufnr, "n", "D", function() delete_row(bufnr) end,     "Delete current row")

  -- Column operations
  map(bufnr, "n", "A", function() insert_col(bufnr, 1) end,  "Append column right")
  map(bufnr, "n", "I", function() insert_col(bufnr, 0) end,  "Insert column left")
  map(bufnr, "n", "X", function() delete_col(bufnr) end,     "Delete current column")

  -- Format
  map(bufnr, "n", "=", function() format_table(bufnr) end,   "Format/align table")

  -- Exit
  map(bufnr, "n", "q",     function() M.exit(bufnr) end, "Exit Table mode")
  map(bufnr, "n", "<Esc>", function() M.exit(bufnr) end, "Exit Table mode")
end

local function remove_keymaps(bufnr)
  for _, km in ipairs(_registered[bufnr] or {}) do
    pcall(vim.keymap.del, km[1], km[2], { buffer = bufnr })
  end
  _registered[bufnr] = nil
end

-- ─── Public API ───────────────────────────────────────────────────────────────

--- Enter Table mode at the current cursor position.
--- Parses the table under the cursor, aligns it, and sets up keymaps.
function M.enter(bufnr)
  if state.in_mode(bufnr, "table") or state.in_mode(bufnr, "cell") then
    vim.notify("[ascii_table] Already active.", vim.log.levels.WARN)
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_line = cursor[1]
  local cur_col  = cursor[2] + 1  -- convert to 1-indexed

  local top, bot = parser.find_bounds(bufnr, cur_line)
  if not top then
    vim.notify("[ascii_table] No table found at cursor.", vim.log.levels.WARN)
    return false
  end

  local tbl = parser.parse(bufnr, top, bot)
  if not tbl then
    vim.notify("[ascii_table] Failed to parse table.", vim.log.levels.WARN)
    return false
  end

  -- Immediately align the table to canonical format
  renderer.write(bufnr, tbl)
  tbl = parser.parse(bufnr, top, tbl.end_line)

  -- Initialise state
  local st = state.init(bufnr)
  vim.print(st)
  st.mode = "table"
  st.tbl  = tbl

  -- Determine starting cell from cursor position
  local row, col = parser.cell_at(tbl, cur_line, cur_col)
  st.row = row or 1
  st.col = col or 1

  setup_keymaps(bufnr)
  go_to_cell(bufnr, st, st.row, st.col)

  vim.notify("[ascii_table] Table mode  (q / <Esc> to exit)", vim.log.levels.INFO)
  return true
end

--- Exit Table mode, remove keymaps, and clear highlight.
function M.exit(bufnr)
  local st = state.get(bufnr)
  if not st then return end

  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  remove_keymaps(bufnr)
  state.clear(bufnr)

  -- Restore Neovim normal mode (in case something left us in insert)
  vim.cmd("stopinsert")

  vim.notify("[ascii_table] Exited Table mode.", vim.log.levels.INFO)
end

return M
