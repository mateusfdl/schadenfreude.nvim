
local Chat = {}
Chat.__index = Chat

function Chat:new()
	return setmetatable({
		buffer = nil,
		window = nil,
	}, self)
end

function Chat:find_buffer()
	return vim.fn.bufnr("LLM")
end

function Chat:find_window(bufnr)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == bufnr then
			return win
		end
	end

	return nil
end

function Chat:create_buffer(window_id)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(window_id, buf)

	vim.diagnostic.enable(false, { bufnr = buf })
	vim.bo[buf].filetype = "markdown"
	vim.api.nvim_set_option_value("conceallevel", 2, { win = window_id })
	vim.api.nvim_buf_set_name(buf, "LLM")

	if vim.api.nvim_buf_line_count(buf) == 0 then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
	end

	self.buffer = buf
	self.window = window_id

	return buf
end

function Chat:_get_or_create_buffer()
	local bufnr = self:find_buffer()
	if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
		local win = vim.api.nvim_get_current_win()
		bufnr = self:create_buffer(win)
		vim.cmd("runtime! syntax/markdown.vim")
		return bufnr
	end
	
	self.buffer = bufnr
	return bufnr
end

function Chat:_focus_buffer(bufnr)
	local win = self:find_window(bufnr)
	if win then
		vim.api.nvim_set_current_win(win)
		self.window = win
	else
		local current_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(current_win, bufnr)
		self.window = current_win
	end
end

function Chat:start()
	local bufnr = self:_get_or_create_buffer()
	self:_focus_buffer(bufnr)
	return bufnr
end

function Chat:focus()
	local bufnr = self.buffer and vim.api.nvim_buf_is_valid(self.buffer) and self.buffer or self:_get_or_create_buffer()
	self:_focus_buffer(bufnr)
	return bufnr
end

function Chat:_ensure_buffer()
	return self.buffer and vim.api.nvim_buf_is_valid(self.buffer) and self.buffer or self:_get_or_create_buffer()
end

function Chat:_append_processed_text(text)
	if not text or text == "" or not self.buffer or not vim.api.nvim_buf_is_valid(self.buffer) then
		return
	end

	local lines = vim.split(text, "\n", { plain = true })
	if #lines == 0 then return end

	local last_line_nr = vim.api.nvim_buf_line_count(self.buffer)
	local current_line = vim.api.nvim_buf_get_lines(self.buffer, last_line_nr - 1, last_line_nr, false)[1] or ""
	
	lines[1] = current_line .. lines[1]
	vim.api.nvim_buf_set_lines(self.buffer, last_line_nr - 1, last_line_nr, false, lines)

	local win = self:find_window(self.buffer)
	if win and vim.api.nvim_win_is_valid(win) then
		local new_line_count = vim.api.nvim_buf_line_count(self.buffer)
		local last_line = vim.api.nvim_buf_get_lines(self.buffer, -2, -1, false)[1] or ""
		pcall(vim.api.nvim_win_set_cursor, win, { new_line_count, #last_line })
	end
end

function Chat:append_text(text)
	if not text or text == "" then
		return
	end

	if vim.in_fast_event() then
		vim.schedule(function()
			self:append_text(text)
		end)
		return
	end

	local bufnr = self:_ensure_buffer()
	if not bufnr then
		return
	end

	self:_append_processed_text(text)
end

return Chat
