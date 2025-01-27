local M = {}

local chat_window_id = nil

local function lookup_for_chat_buffer()
	return vim.fn.bufnr("Chat")
end

local function create_attached_buffer(window_id)
	local buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_win_set_buf(window_id, buf)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	vim.api.nvim_buf_set_name(buf, "Chat")
	vim.api.nvim_command("au! * <buffer>")

	vim.diagnostic.disable(buf)

	return buf
end

function M.start(window_id_to_attach)
	local existing_chat_buffer = lookup_for_chat_buffer()
	if existing_chat_buffer ~= -1 then
		if window_id_to_attach then
			local _, ok = pcall(vim.api.nvim_win_set_buf, chat_window_id, existing_chat_buffer)
			if ok then
				return existing_chat_buffer
			end
		end

		chat_window_id = vim.api.nvim_get_current_win()

		vim.api.nvim_win_set_buf(chat_window_id, lookup_for_chat_buffer())

		return existing_chat_buffer
	end

	chat_window_id = window_id_to_attach

	return create_attached_buffer(window_id_to_attach)
end

return M
