local M = {}

local chat_window_id = nil

local function lookup_for_chat_buffer()
	return vim.fn.bufnr("Chat")
end

local function find_window_for_buffer(bufnr)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == bufnr then
			return win
		end
	end
	return nil
end

local function create_and_attach_buffer(window_id)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(window_id, buf)
	vim.api.nvim_buf_set_var(buf, "filetype", "markdown")
	vim.api.nvim_buf_set_name(buf, "Chat")

	if vim.diagnostic and vim.diagnostic.enable() then
		vim.diagnostic.enable(false, { bufnr = buf })
	end

	return buf
end

function M.start()
	local chat_bufnr = lookup_for_chat_buffer()

	if chat_bufnr == -1 then
		chat_window_id = vim.api.nvim_get_current_win()
		return create_and_attach_buffer(chat_window_id)
	else
		local existing_win = find_window_for_buffer(chat_bufnr)
		if existing_win then
			vim.api.nvim_set_current_win(existing_win)
			chat_window_id = existing_win
			return chat_bufnr
		else
			local current_win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(current_win, chat_bufnr)
			chat_window_id = current_win
			return chat_bufnr
		end
	end
end

function M.focus_or_create_chat()
	local chat_bufnr = lookup_for_chat_buffer()

	if chat_bufnr == -1 then
		return M.start()
	else
		local chat_win = find_window_for_buffer(chat_bufnr)
		if chat_win then
			vim.api.nvim_set_current_win(chat_win)
		else
			vim.api.nvim_set_current_buf(chat_bufnr)
		end
		return chat_bufnr
	end
end

return M
