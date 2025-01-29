local api = api
local fn = vim.fn
local cmd = vim.cmd
local feedkeys = api.nvim_feedkeys
local termcodes = api.nvim_replace_termcodes

function get_lines_until_cursor()
	local buf = api.nvim_get_current_buf()
	local win = api.nvim_get_current_win()
	local row = api.nvim_win_get_cursor(win)[1]
	return table.concat(api.nvim_buf_get_lines(buf, 0, row, true), "\n")
end

function get_visual_selection()
	local mode = fn.visualmode()
	local srow, scol = unpack(fn.getpos("v"), 2, 3)
	local erow, ecol = unpack(fn.getpos("."), 2, 3)

	if srow > erow then
		srow, erow = erow, srow
	end

	if mode == "V" then
		cmd("normal! gv_d")
		return api.nvim_buf_get_lines(0, srow - 1, erow, true)
	elseif mode == "v" then
		local lines = api.nvim_buf_get_lines(0, srow - 1, erow, true)
		lines[1] = lines[1]:sub(scol)
		lines[#lines] = lines[#lines]:sub(1, ecol)
		cmd("normal! gv\nd")
		return lines
	elseif mode == "\22" then
		local lines = {}
		for i = srow - 1, erow - 1 do
			local text =
				api.nvim_buf_get_text(0, i, math.min(scol - 1, ecol - 1), i, math.max(scol - 1, ecol - 1) + 1, {})
			table.insert(lines, text[1])
		end
		cmd("normal! gv\nd")
		return lines
	end
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
