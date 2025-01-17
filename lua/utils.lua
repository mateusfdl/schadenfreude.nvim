function get_lines_until_cursor()
	local current_buffer = vim.api.nvim_get_current_buf()
	local current_window = vim.api.nvim_get_current_win()
	local cursor_position = vim.api.nvim_win_get_cursor(current_window)
	local row = cursor_position[1]

	local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, row, true)

	return table.concat(lines, "\n")
end

function get_visual_selection()
	local srow, scol = unpack(vim.fn.getpos("v"), 2, 3)
	local erow, ecol = unpack(vim.fn.getpos("."), 2, 3)
	local mode = vim.fn.visualmode()

	if srow > erow then
		srow, erow = erow, srow
	end

	if mode == "V" then
		local svrow = unpack(vim.fn.getpos("'<"), 2)
		local evrow = unpack(vim.fn.getpos("'>"), 2)

		return vim.api.nvim_buf_get_lines(0, svrow - 1, evrow, true)
	end

	if mode == "v" then
		local lines = vim.api.nvim_buf_get_lines(0, srow - 1, erow, true)
		lines[1] = string.sub(lines[1], scol)
		lines[#lines] = string.sub(lines[#lines], 1, ecol)
		return lines
	end

	if mode == "\22" then
		local lines = {}
		for i = srow - 1, erow - 1 do
			local text =
				vim.api.nvim_buf_get_text(0, i, math.min(scol - 1, ecol - 1), i, math.max(scol - 1, ecol - 1) + 1, {})
			table.insert(lines, text[1])
		end
		return lines
	end
end

function get_prompt(replace)
	local visual_lines = get_visual_selection()
	local prompt = ""

	if visual_lines then
		prompt = table.concat(visual_lines, "\n")
		if replace then
			vim.api.nvim_command("normal! d")
			vim.api.nvim_command("normal! k")
		else
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", false, true, true), "nx", false)
		end
	else
		prompt = get_lines_until_cursor()
	end

	return prompt
end

function stream_string_to_current_window(str)
	vim.schedule(function()
		local current_window = vim.api.nvim_get_current_win()
		local cursor_position = vim.api.nvim_win_get_cursor(current_window)
		local row, col = cursor_position[1], cursor_position[2]

		if not str then
			return
		end
		local lines = vim.split(str, "\n")

		vim.cmd("undojoin")
		vim.api.nvim_put(lines, "c", true, true)

		local num_lines = #lines
		local last_line_length = #lines[num_lines]
		vim.api.nvim_win_set_cursor(current_window, { row + num_lines - 1, col + last_line_length })
	end)
end
