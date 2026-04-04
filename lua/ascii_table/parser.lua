local M = {}

function iter_array(t)
	local i = 0
	return function()
		i = i + 1
		return t[i]
	end
end

--- Find the header of the table and match exact width of every collumn
function len_match(lines)
	local widths = {}
	local separator = string.match(lines[1], "%+[%-%+]+%+")
	if separator == nil then
		return false
	end
	for next in separator:gmatch("%+%-+") do
		table.insert(widths, #next - 1)
	end
	-- Remove the header separator, then check widths of the columns
	table.remove(lines, 1)
	for _, line in ipairs(lines) do
		local i = 1
		for next in line:gmatch("%+%-+") do
			if widths[i] ~= (#next - 1) then
				return false
			end
			i = i + 1
		end
		i = 1
		for next in line:gmatch("|[^|]+") do
			if widths[i] ~= (#next - 1) then
				return false
			end
			i = i + 1
		end
	end
	return true
end

-- Split a multi-line row like "| a | b |" into { "a", "b" }
function M.parse_row(row)
	local cells = {}
	local lines = {}
	local res = {}

	--- (I)terate over all lines in a row
	for _, line in ipairs(row) do
		--- Remove trailing characters
		line = line:gsub("[^|]+$", "\n", 1)
		--- Postpone the iteration 
		table.insert(lines, line:gmatch("|([^|]+)"))
	end

	for _, iter in ipairs(lines) do
		local curr = 1
		local line = iter()
		while true do
			if line == nil then
				break
			end
			if cells[curr] == nil then
				cells[curr] = { vim.trim(line) }
			else
				table.insert(cells[curr], vim.trim(line))
			end
			line = iter()
			curr = curr + 1
		end
	end
	for i, cell in ipairs(cells) do
		table.insert(res, table.concat(cell, "\n").."\n")
	end
	return res
end

function M.parse_lines(lines)
	local res = {}
	local iter = iter_array(lines)
	while true do
		local line = iter()
		if line == nil then
			break
		end
		local multi_line = {}
		while line:match("|") do
			table.insert(multi_line, line)
			line = iter()
		end
		if multi_line[1] then
			table.insert(res, M.parse_row(multi_line))
		end
	end
	return res
end

return M
