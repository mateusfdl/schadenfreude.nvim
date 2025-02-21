local Chat = {}
Chat.__index = Chat

function Chat:new()
	local instance = {
		buffer = nil,
		window = nil,
		history = {},
		current_job = nil,
	}
	return setmetatable(instance, self)
end

function Chat:_find_buffer()
	return vim.fn.bufnr("Chat")
end

function Chat:_find_window(bufnr)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == bufnr then
			return win
		end
	end
	return nil
end

function Chat:_create_buffer(window_id)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(window_id, buf)

	if vim.diagnostic and vim.diagnostic.enable then
		vim.diagnostic.enable(false, { bufnr = buf })
	end

	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	vim.api.nvim_buf_set_option(buf, "conceallevel", 2)
	vim.api.nvim_buf_set_name(buf, "Chat")
	self.buffer = buf
	return buf
end

function Chat:start()
	local chat_bufnr = self:_find_buffer()

	if chat_bufnr == -1 then
		self.window = vim.api.nvim_get_current_win()
		return self:_create_buffer(self.window)
	else
		local existing_win = self:_find_window(chat_bufnr)
		if existing_win then
			vim.api.nvim_set_current_win(existing_win)
			self.window = existing_win
			self.buffer = chat_bufnr
			return chat_bufnr
		else
			local current_win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(current_win, chat_bufnr)
			self.window = current_win
			self.buffer = chat_bufnr
			return chat_bufnr
		end
	end
end

function Chat:focus()
	local chat_bufnr = self:_find_buffer()

	if chat_bufnr == -1 then
		return self:start()
	else
		local chat_win = self:_find_window(chat_bufnr)
		if chat_win then
			vim.api.nvim_set_current_win(chat_win)
		else
			vim.api.nvim_set_current_buf(chat_bufnr)
		end
		self.buffer = chat_bufnr
		return chat_bufnr
	end
end

function Chat:append_text(text)
	if not text then
		return
	end

	vim.schedule(function()
		if not self.buffer then
			return
		end

		local new_lines = vim.split(text, "\n", true)

		local last_line_idx = vim.api.nvim_buf_line_count(self.buffer) - 1
		local last_line = vim.api.nvim_buf_get_lines(self.buffer, last_line_idx, last_line_idx + 1, false)[1] or ""

		if #new_lines > 0 then
			new_lines[1] = last_line .. new_lines[1]
		end

		vim.api.nvim_buf_set_lines(self.buffer, last_line_idx, last_line_idx + 1, false, new_lines)

		local new_last_line_idx = vim.api.nvim_buf_line_count(self.buffer) - 1
		local new_last_line = vim.api.nvim_buf_get_lines(self.buffer, new_last_line_idx, new_last_line_idx + 1, false)[1]
			or ""
		vim.api.nvim_win_set_cursor(0, { new_last_line_idx + 1, #new_last_line })
	end)
end

return Chat
