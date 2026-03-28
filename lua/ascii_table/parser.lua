local M = {}

-- Split a line like "| a | b |" into { "a", "b" }
function M.parse_line(line)
    local cells = {}
    for cell in line:gmatch("|([^|]+)") do
        table.insert(cells, vim.trim(cell))
    end
    return cells
end

function M.parse_lines(lines)
    local result = {}
    for _, line in ipairs(lines) do
        if line:match("|") then
            table.insert(result, M.parse_line(line))
        end
    end
    return result
end

return M
