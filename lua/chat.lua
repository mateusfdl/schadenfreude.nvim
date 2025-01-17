local M = {}

local active_chat_buffer_id = nil
local active_chat_window_id = nil

local function create_floating_buffer()
	if not active_chat_buffer_id then
		active_chat_buffer_id = vim.api.nvim_create_buf(false, true)
		if not active_chat_buffer_id then
			return nil
		end
	end
	return active_chat_buffer_id
end

local function open_floating_window()
	local buf = create_floating_buffer()
	if not buf then
		return nil
	end

	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")

	local win_width = math.ceil(width * 0.7)
	local win_height = math.ceil(height * 0.7)

	local col = math.ceil((width - win_width) / 2)
	local row = math.ceil((height - win_height) / 2)

	local opts = {
		style = "minimal",
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		border = { "-", "-", "-", "|", "-", "-", "-", "|" },
	}

	local win_id = vim.api.nvim_open_win(buf, true, opts)

	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	vim.api.nvim_command("au! * <buffer>")

	vim.diagnostic.enable(false, { bufnr = buf })

	return buf, win_id
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
	if not window_id_to_attach then
		local buf, _ = open_floating_window()
		return buf
	else
		if active_chat_window_id then
			vim.api.nvim_set_current_win(active_chat_window_id)
			return active_chat_buffer_id
		end

		active_chat_buffer_id = create_attached_buffer(window_id_to_attach)
		active_chat_window_id = window_id_to_attach

		return active_chat_buffer_id
	end
end

return M
