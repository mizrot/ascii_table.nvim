--- cell_mode.lua
--- Cell mode lets the user edit a single cell's content in an isolated
--- floating window, avoiding the complexity of in-place buffer editing.
---
--- Entering Cell mode:
---   - A bordered floating window opens at the cursor, pre-filled with the
---     current cell's content.
---   - The user types freely; the window is just a scratch buffer.
---
--- Exiting Cell mode (all paths call commit()):
---   <Tab>     commit -> move right one column
---   <S-Tab>   commit -> move left one column
---   <CR>      commit -> move down one row
---   <Esc>     commit -> stay on the same cell

local state = require("ascii_table.state")
local renderer = require("ascii_table.renderer")
local parser = require("ascii_table.parser")

local M = {}

-- ─── Highlight namespace (shared with table_mode) ────────────────────────────
local NS = vim.api.nvim_create_namespace("ascii_table")

-- ─── Internal helpers ─────────────────────────────────────────────────────────

--- Re-highlight the active cell after returning to Table mode.
local function rehighlight(bufnr, st)
	vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
	local bl, bc = renderer.cell_cursor_pos(st.tbl, st.row, st.col)
	vim.api.nvim_win_set_cursor(0, { bl, bc - 1 })
	vim.api.nvim_buf_add_highlight(bufnr, NS, "Visual", bl - 1, bc - 1, bc - 1 + st.tbl.col_widths[st.col])
end

--- Close the floating window, update the cell value, re-render the table,
--- then move the logical cursor by (drow, dcol).
local function commit(float_win, float_buf, bufnr, drow, dcol)
	-- Read content from scratch buffer (single line)
	local lines = vim.api.nvim_buf_get_lines(float_buf, 0, 2, false)
	local new_content = (lines[1] or ""):match("^%s*(.-)%s*$") -- trim

	-- Close the float (switch focus back to main window first)
	if vim.api.nvim_win_is_valid(float_win) then
		vim.api.nvim_win_close(float_win, true)
	end
	---  vim.api.nvim_buf_delete(float_buf, { force = true })

	local st = state.get(bufnr)
	if not st then
		return
	end

	-- Update cell value
	st.tbl.rows[st.row][st.col] = new_content

	-- Recompute column widths (content may have grown or shrunk)
	renderer.recalc_widths(st.tbl)

	-- Re-render and re-parse to keep tbl in sync with buffer
	renderer.write(bufnr, st.tbl)
	local new_tbl = parser.parse(bufnr, st.tbl.start_line, st.tbl.end_line)
	if new_tbl then
		st.tbl = new_tbl
	end

	-- Move logical cursor (clamped to valid range)
	st.row = math.max(1, math.min(st.tbl.nrows, st.row + drow))
	st.col = math.max(1, math.min(st.tbl.ncols, st.col + dcol))
	st.mode = "table"

	-- Return visual focus and highlight
	rehighlight(bufnr, st)
end

-- Public API

--- Enter Cell mode: open a floating editor for the current cell.
function M.enter(bufnr)
	local st = state.get(bufnr)
	if not st or st.mode ~= "table" then
		return
	end

	st.mode = "cell"

	local row_idx = st.row
	local col_idx = st.col
	local content = st.tbl.rows[row_idx][col_idx]

	-- Minimum float width: wider of current col width vs 20 chars
	local float_w = math.max(st.tbl.col_widths[col_idx], 20)

	-- Anchor the float to the cell's position in the buffer
	local bl, bc = renderer.cell_cursor_pos(st.tbl, row_idx, col_idx)

	-- Create scratch buffer
	local fbuf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, { content })
	vim.bo[fbuf].bufhidden = "wipe"
	vim.bo[fbuf].filetype = "ascii_table_cell"

	-- Open floating window
	local fwin = vim.api.nvim_open_win(fbuf, true, {
		relative = "win",
		bufpos = { bl - 1, bc - 1 }, -- 0-indexed
		width = float_w,
		height = 1,
		style = "minimal",
		border = "rounded",
		title = string.format(" [%d,%d] ", row_idx, col_idx),
		title_pos = "center",
		zindex = 50,
	})

	-- Start in insert mode, cursor at end of existing content
	vim.cmd("startinsert!")

	-- Keymaps inside the floating buffer
	local opts = { buffer = fbuf, nowait = true, silent = true }

	-- Tab -> commit and move right
	vim.keymap.set("i", "<Tab>", function()
		commit(fwin, fbuf, bufnr, 0, 1)
	end, opts)

	-- S-Tab -> commit and move left
	vim.keymap.set("i", "<S-Tab>", function()
		commit(fwin, fbuf, bufnr, 0, -1)
	end, opts)

	-- Enter -> commit and move down
	vim.keymap.set("i", "<CR>", function()
		commit(fwin, fbuf, bufnr, 1, 0)
	end, opts)

	-- Esc -> commit and stay (also works from normal mode in the float)
	vim.keymap.set({ "i", "n" }, "<Esc>", function()
		commit(fwin, fbuf, bufnr, 0, 0)
	end, opts)

	-- Guard: if the float is closed by other means (e.g. :q), clean up state
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(fwin),
		once = true,
		callback = function()
			local s = state.get(bufnr)
			if s and s.mode == "cell" then
				s.mode = "table"
				vim.cmd("stopinsert")
			end
		end,
	})
end

return M
