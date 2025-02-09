local api = vim.api
local fn = vim.fn
local cmd = vim.cmd
local feedkeys = api.nvim_feedkeys
local termcodes = api.nvim_replace_termcodes

function get_lines_until_cursor()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local col = cursor[2]

	local lines = vim.api.nvim_buf_get_lines(0, 0, row, false)

	if #lines > 0 then
		local last_line = lines[#lines]
		lines[#lines] = string.sub(last_line, 1, col)
	end

	return table.concat(lines, "\n")
end

function M.get_visual_selection()
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

function get_prompt(replace)
	local visual_lines = get_visual_selection()
	if visual_lines then
		if not replace then
			feedkeys(termcodes("<Esc>", false, true, true), "nx", false)
		end
		return table.concat(visual_lines, "\n")
	end
	return get_lines_until_cursor()
end

function stream_string_to_chat_buffer(str)
	if not str then
		return
	end
	vim.schedule(function()
		local chat_bufnr = fn.bufnr("Chat")
		if chat_bufnr == -1 then
			chat_bufnr = api.nvim_create_buf(true, true)
			api.nvim_buf_set_name(chat_bufnr, "Chat")
			api.nvim_set_current_buf(chat_bufnr)
		else
			api.nvim_set_current_buf(chat_bufnr)
		end

		local lines = vim.split(str, "\n")
		cmd("undojoin")
		api.nvim_put(lines, "c", true, true)
	end)
end

function handle_chat_or_buffer(str)
	local current_buf = api.nvim_get_current_buf()
	if api.nvim_buf_get_name(current_buf) == "Chat" then
		stream_string_to_chat_buffer(str)
	else
		stream_string_to_chat_buffer("")
		stream_string_to_chat_buffer(str)
	end
end
