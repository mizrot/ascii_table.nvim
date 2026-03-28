local M = {}

local function compute_widths(rows)
    local widths = {}

    for _, row in ipairs(rows) do
        for i, cell in ipairs(row) do
            widths[i] = math.max(widths[i] or 0, #cell)
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

    for _, row in ipairs(rows) do
        local parts = {}
        for i, cell in ipairs(row) do
            table.insert(parts, " " .. pad(cell, widths[i]) .. " ")
        end
        table.insert(lines, "|" .. table.concat(parts, "|") .. "|")
        table.insert(lines, separator())
    end

    return lines
end

return M
