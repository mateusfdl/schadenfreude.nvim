local Utils = {}

function Utils.get_lines_until_cursor()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local col = cursor[2]

	local lines = vim.api.nvim_buf_get_lines(0, 0, row + 1, false)

	if #lines > 0 then
		local last_line = lines[#lines]
		lines[#lines] = string.sub(last_line, 1, col)
	end

	return table.concat(lines, "\n")
end

function Utils.get_visual_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	local start_line = start_pos[2]
	local start_col = start_pos[3]
	local end_line = end_pos[2]
	local end_col = end_pos[3]

	if start_line == 0 or end_line == 0 or start_line > end_line then
		return ""
	end

	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	if #lines == 0 then
		return ""
	end

	if #lines == 1 then
		return string.sub(lines[1], start_col, end_col)
	end

	local first_line = string.sub(lines[1], start_col, -1)
	local last_line = string.sub(lines[#lines], 1, end_col)
	local middle = {}

	for i = 2, (#lines - 1) do
		table.insert(middle, lines[i])
	end

	local selection = {}
	table.insert(selection, first_line)
	vim.list_extend(selection, middle)
	table.insert(selection, last_line)

	return table.concat(selection, "\n")
end

function Utils.get_prompt(replace)
	local visual_lines = Utils.get_visual_selection()
	if visual_lines and #visual_lines > 0 then
		if not replace then
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", false, true, true), "nx", false)
		end
		return visual_lines
	end

	return Utils.get_lines_until_cursor()
end

return Utils
