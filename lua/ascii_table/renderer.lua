local M = {}

function split_multi_line(row)
	local res = {}
	local iters = {}
	for _, cell in ipairs(row) do
		table.insert(iters, cell:gmatch("([^\n]-)\n"))
	end
	local val
	local i = 1
	repeat
		for _, iter in ipairs(iters) do
			val = iter()
			if val == nil then
				break
			end
			if res[i] == nil then
				res[i] = { val }
			else
				table.insert(res[i], val)
			end
		end
		i = i + 1
	until val == nil

	return res
end

local function compute_widths(rows)
	local widths = {}

	for _, row in ipairs(rows) do
		for i, cell in ipairs(row) do
			for stripped_cell in cell:gmatch("([^\n]-)\n") do
				widths[i] = math.max(widths[i] or 0, #stripped_cell)
			end
		end
	end

	return widths
end

local function pad(cell, width)
	return cell .. string.rep(" ", width - #cell)
end

function M.render(rows)
	local widths = compute_widths(rows)
	local lines = {}

	local function separator()
		local parts = {}
		for _, w in ipairs(widths) do
			table.insert(parts, string.rep("-", w + 2))
		end
		return "+" .. table.concat(parts, "+") .. "+"
	end

	table.insert(lines, separator())

	--- Split multi-line row in separate lines and convert it to formatted text
	for _, ml_row in ipairs(rows) do
		for _, row in ipairs(split_multi_line(ml_row)) do
			local parts = {}
			for i, cell in ipairs(row) do
				table.insert(parts, " " .. pad(cell, widths[i]) .. " ")
			end
			table.insert(lines, "|" .. table.concat(parts, "|") .. "|")
		end
		table.insert(lines, separator())
	end

	return lines
end

return M
