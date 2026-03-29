--- renderer.lua
--- Converts the in-memory table struct back into properly-aligned ASCII lines
--- and writes them into the buffer, replacing the original table region.
---
--- Rendered format:
---   +--------+-----+------+
---   | Header | Age | City |
---   +--------+-----+------+
---   | Alice  | 30  | NYC  |
---   | Bob    | 25  | LA   |
---   +--------+-----+------+

local M = {}

-- ─── Line builders ────────────────────────────────────────────────────────────

--- "+--------+-----+------+"
local function make_sep(col_widths)
  local parts = {}
  for _, w in ipairs(col_widths) do
    table.insert(parts, string.rep("-", w + 2))  -- " " + content + " "
  end
  return "+" .. table.concat(parts, "+") .. "+"
end

--- "| foo    | bar | baz  |"
local function make_row(cells, col_widths)
  local parts = {}
  for c, w in ipairs(col_widths) do
    local cell = cells[c] or ""
    -- Left-align: content + trailing spaces to fill width
    parts[c] = " " .. cell .. string.rep(" ", w - #cell) .. " "
  end
  return "|" .. table.concat(parts, "|") .. "|"
end

-- ─── Public API ───────────────────────────────────────────────────────────────

--- Convert a table struct to a list of buffer lines.
--- Layout: sep / header / sep / body-rows... / sep
function M.to_lines(tbl)
  local sep   = make_sep(tbl.col_widths)
  local lines = { sep }

  for r, row in ipairs(tbl.rows) do
    table.insert(lines, make_row(row, tbl.col_widths))
    -- Separator after header and after last row only
    if r == 1 or r == tbl.nrows then
      table.insert(lines, sep)
    end
  end

  return lines
end

--- Write the table into the buffer, replacing [start_line, end_line].
--- Updates tbl.end_line to reflect the new line range in the buffer.
function M.write(bufnr, tbl)
  local lines = M.to_lines(tbl)
  vim.api.nvim_buf_set_lines(bufnr, tbl.start_line - 1, tbl.end_line, false, lines)
  tbl.end_line = tbl.start_line + #lines - 1
end

-- ─── Cursor positioning ───────────────────────────────────────────────────────

--- Return (buf_line, buf_col) — both 1-indexed — for the first character of
--- the content of cell (row_idx, col_idx) after a fresh render.
---
--- Rendered line layout for col_widths = {w1, w2, w3}:
---   pos 1   : |
---   pos 2   : <space>
---   pos 3   : first char of col 1 content   ← col 1 starts here
---   pos 3+w1: <space>
---   pos 4+w1: |
---   pos 5+w1: <space>
---   pos 6+w1: first char of col 2 content   ← col 2 starts here
---   ...
---
--- General formula for col c:  start = 3 + Σ_{i=1}^{c-1}(col_widths[i] + 3)
function M.cell_cursor_pos(tbl, row_idx, col_idx)
  -- Relative line within the rendered table (1-based)
  -- Layout: sep(1), header(2), sep(3), row2(4), row3(5), ..., rowN(N+2), sep(N+3)
  local rel_line
  if row_idx == 1 then
    rel_line = 2
  else
    rel_line = row_idx + 2
  end
  local buf_line = tbl.start_line + rel_line - 1

  -- Column offset inside the line (1-indexed)
  local buf_col = 3
  for c = 1, col_idx - 1 do
    buf_col = buf_col + tbl.col_widths[c] + 3
  end

  return buf_line, buf_col
end

--- Recompute col_widths in-place after a cell value has changed.
function M.recalc_widths(tbl)
  for c = 1, tbl.ncols do tbl.col_widths[c] = 1 end
  for _, row in ipairs(tbl.rows) do
    for c = 1, tbl.ncols do
      local w = #(row[c] or "")
      if w > tbl.col_widths[c] then tbl.col_widths[c] = w end
    end
  end
end

return M
