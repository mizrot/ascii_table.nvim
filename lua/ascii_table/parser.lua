--- parser.lua
--- Responsible for detecting ASCII tables in a buffer and parsing them into
--- an in-memory table struct that the rest of the plugin operates on.
---
--- Table format this plugin works with:
---   +--------+-----+------+
---   | Header | Age | City |   <- row 1 (header)
---   +--------+-----+------+
---   | Alice  | 30  | NYC  |   <- row 2
---   | Bob    | 25  | LA   |   <- row 3
---   +--------+-----+------+

local M = {}

-- Pattern matching 

local SEP_PAT  = "^%+[%-%+]+%+%s*$"   -- +---+---+
local DATA_PAT = "^|.+|%s*$"           -- | foo | bar |

function M.is_separator(line)
  return line ~= nil and line:match(SEP_PAT) ~= nil
end

function M.is_data_row(line)
  return line ~= nil and line:match(DATA_PAT) ~= nil
end

function M.is_table_line(line)
  return M.is_separator(line) or M.is_data_row(line)
end

-- Cell splitting 

--- Split a data line into trimmed cell strings.
--- "| foo | bar | baz |" → { "foo", "bar", "baz" }
function M.split_cells(line)
  local inner = line:match("^|(.+)|%s*$")
  if not inner then return nil end
  local cells = {}
  -- Append sentinel so the last field is captured
  for cell in (inner .. "|"):gmatch("([^|]*)|") do
    table.insert(cells, cell:match("^%s*(.-)%s*$"))
  end
  return cells
end

-- Boundary detection 

--- Find the top and bottom line numbers (1-indexed) of the table that contains
--- buf_line. Returns (top, bot) or nil if buf_line is not inside a table.
function M.find_bounds(bufnr, buf_line)
  local total = vim.api.nvim_buf_line_count(bufnr)

  local function get(n)
    if n < 1 or n > total then return nil end
    return vim.api.nvim_buf_get_lines(bufnr, n - 1, n, false)[1]
  end

  if not M.is_table_line(get(buf_line)) then return nil end

  local top = buf_line
  while top > 1 and M.is_table_line(get(top - 1)) do
    top = top - 1
  end

  local bot = buf_line
  while bot < total and M.is_table_line(get(bot + 1)) do
    bot = bot + 1
  end

  return top, bot
end

-- Parsing 

--- Parse buffer lines [start_line, end_line] (1-indexed) into a table struct.
---
--- Returns:
---   {
---     rows         = { {"cell", ...}, ... },   -- 1-indexed
---     nrows        = number,
---     ncols        = number,
---     col_widths   = { number, ... },           -- content widths (no padding)
---     start_line   = number,                    -- buf line of first table line
---     end_line     = number,                    -- buf line of last table line
---     row_to_line  = { [row_idx] = rel_line },  -- relative line index (1-based)
---   }
function M.parse(bufnr, start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  local rows        = {}
  local row_to_line = {}  -- row index → relative line index within `lines`

  for i, line in ipairs(lines) do
    if M.is_data_row(line) then
      local cells = M.split_cells(line)
      if cells then
        table.insert(rows, cells)
        row_to_line[#rows] = i
      end
    end
  end

  if #rows == 0 then return nil end

  -- Uniform column count (take the maximum; pad shorter rows)
  local ncols = 0
  for _, row in ipairs(rows) do
    if #row > ncols then ncols = #row end
  end
  for _, row in ipairs(rows) do
    while #row < ncols do table.insert(row, "") end
  end

  -- Column widths = maximum content length per column
  local col_widths = {}
  for c = 1, ncols do col_widths[c] = 1 end  -- minimum width = 1
  for _, row in ipairs(rows) do
    for c = 1, ncols do
      local w = #(row[c] or "")
      if w > col_widths[c] then col_widths[c] = w end
    end
  end

  return {
    rows        = rows,
    nrows       = #rows,
    ncols       = ncols,
    col_widths  = col_widths,
    start_line  = start_line,
    end_line    = end_line,
    row_to_line = row_to_line,
  }
end

-- Cursor → cell mapping 

--- Given a buffer position (buf_line, buf_col both 1-indexed), return the
--- (row_idx, col_idx) of the cell under the cursor, or (nil, nil) if on a
--- separator or outside the table.
function M.cell_at(tbl, buf_line, buf_col)
  local rel = buf_line - tbl.start_line + 1

  -- Find the data row at this relative line
  local data_row = nil
  for r, li in pairs(tbl.row_to_line) do
    if li == rel then data_row = r; break end
  end
  if not data_row then return nil, nil end

  -- Count '|' characters up to and including buf_col to determine column
  local line = vim.api.nvim_buf_get_lines(0, buf_line - 1, buf_line, false)[1] or ""
  local pipes = 0
  for i = 1, math.min(buf_col, #line) do
    if line:sub(i, i) == "|" then pipes = pipes + 1 end
  end
  -- After the nth '|' we are in column n (first '|' = left border)
  local col_idx = math.max(1, math.min(pipes, tbl.ncols))

  return data_row, col_idx
end

return M
