local parser = require("ascii_table.parser")
local renderer = require("ascii_table.renderer")

local M = {}

function M.align_table(start_line, end_line)
	local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
	local rows = parser.parse_lines(lines)
	local new_lines = renderer.render(rows)

	vim.api.nvim_buf_set_lines(0, start_line, end_line, false, new_lines)
end

function M.create_table(rows, cols)
	local data = {}

	for _ = 1, rows do
		local row = {}
		for _ = 1, cols do
			table.insert(row, "\n")
		end
		table.insert(data, row)
	end

	return renderer.render(data)
end

function M.insert_collumn(start_line, end_line)
	local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
	local rows = parser.parse_lines(lines)
	new_rows = {}
	for i in pairs(rows) do
		table.insert(rows[i], "")
	end
    local new_lines =  renderer.render(rows)
    vim.api.nvim_buf_set_lines(0, start_line, end_line, false, new_lines)
end

function M.setup(opts)
	package.path = package.path .. "/usr/share/lua/5.1/?.lua"
	package.cpath = package.cpath .. "/usr/lib/lua/5.1/socket/?.so"
	require("mobdebug").start()

	opts = opts or {}

	vim.api.nvim_create_user_command("AsciiAlign", function()
		local start_line = vim.fn.line("'<") - 1
		local end_line = vim.fn.line("'>")
		M.align_table(start_line, end_line)
	end, { range = true })

	vim.api.nvim_create_user_command("AsciiTable", function(opts)
		local args = vim.split(opts.args, " ")
		local rows = tonumber(args[1]) or 2
		local cols = tonumber(args[2]) or 2

		local lines = M.create_table(rows, cols)
		vim.api.nvim_put(lines, "l", true, true)
	end, { nargs = "*" })

	vim.api.nvim_create_user_command("AsciiInsertCollumn", function()
		local start_line = vim.fn.line("'<") - 1
		local end_line = vim.fn.line("'>")
		M.insert_collumn(start_line, end_line)
	end, {range = true})
end

return M
