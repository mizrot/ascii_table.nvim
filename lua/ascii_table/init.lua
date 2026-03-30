--- init.lua
--- Public API for ascii_table.nvim.
---
--- Quickstart in your Neovim config:
---   require("ascii_table").setup()
---
--- Or with options:
---   require("ascii_table").setup({
---     enter_key = "<leader>tt",   -- keymap to enter Table mode
---   })
---
--- User commands:
---   :AsciiTable              – enter Table mode at cursor
---   :AsciiTableNew [R] [C]   – create an R×C table and enter Table mode
---   :AsciiTableExit          – exit Table mode

local M = {}

M.config = {
	enter_key = "<leader>T",
}

local function get_table_mode()
	return require("ascii_table.table_mode")
end

-- Setup

function M.setup(opts)

	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Global keymap: enter Table mode
	vim.keymap.set("n", M.config.enter_key, function()
		local bufnr = vim.api.nvim_get_current_buf()
		get_table_mode().enter(bufnr)
	end, { desc = "[ascii_table] Enter Table mode" })
end

-- Public API 

--- Enter Table mode for the current buffer.
function M.enter()
	local bufnr = vim.api.nvim_get_current_buf()
	get_table_mode().enter(bufnr)
end

--- Exit Table mode for the current buffer.
function M.exit()
	local bufnr = vim.api.nvim_get_current_buf()
	get_table_mode().exit(bufnr)
end

--- Insert a new ASCII table at the current cursor position.
--- @param nrows  number  Total rows including header (default 3)
--- @param ncols  number  Number of columns (default 3)
function M.create_table(nrows, ncols)
	nrows = nrows or 3
	ncols = ncols or 3

	local renderer = require("ascii_table.renderer")

	-- Build a skeleton table with header names and empty body
	local rows = {}
	for r = 1, nrows do
		local row = {}
		for c = 1, ncols do
			row[c] = (r == 1) and ("Col " .. c) or ""
		end
		table.insert(rows, row)
	end

	-- Initial column widths from content
	local col_widths = {}
	for c = 1, ncols do
		col_widths[c] = #("Col " .. c) -- "Col 1" = 5 chars, "Col 10" = 6, etc.
	end

	local tbl = {
		rows = rows,
		nrows = nrows,
		ncols = ncols,
		col_widths = col_widths,
	}

	-- Render the new table into a list of lines
	local lines = renderer.to_lines(tbl)

	-- Insert below the current cursor line
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	vim.api.nvim_buf_set_lines(bufnr, cursor[1], cursor[1], false, lines)

	-- Position cursor on the first line of the new table and enter Table mode
	vim.api.nvim_win_set_cursor(0, { cursor[1] + 1, 0 })
	get_table_mode().enter(bufnr)
end

return M
