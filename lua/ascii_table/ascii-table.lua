--- plugin/ascii_table.lua
--- Bootstrap file loaded automatically by Neovim's plugin system.
--- Registers user commands; does NOT call setup() — the user controls that.

if vim.g.loaded_ascii_table then
	return
end
vim.g.loaded_ascii_table = true

vim.api.nvim_create_user_command("AsciiTable", function()
	require("ascii_table").enter()
end, { desc = "Enter ASCII Table mode at cursor" })

vim.api.nvim_create_user_command("AsciiTableExit", function()
	require("ascii_table").exit()
end, { desc = "Exit ASCII Table mode" })

vim.api.nvim_create_user_command("AsciiTableNew", function(args)
	local parts = vim.split(args.args, "%s+", { trimempty = true })
	local rows = tonumber(parts[1]) or 3
	local cols = tonumber(parts[2]) or 3
	require("ascii_table").create_table(rows, cols)
end, {
	nargs = "*",
	desc = "Create a new ASCII table  :AsciiTableNew [rows] [cols]",
})
