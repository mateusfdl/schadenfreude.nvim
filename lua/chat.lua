local Interpreter = require("interpreter")
local ThinkHandler = require("tags.handlers.think")

local Chat = {}
Chat.__index = Chat

function Chat:new()
	local interpreter = Interpreter:new()
	interpreter:register_handler("think", ThinkHandler:new())

	local instance = {
		buffer = nil,
		window = nil,
		interpreter = interpreter,
	}

	return setmetatable(instance, self)
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

function Chat:start()
	local chat_bufnr = self:find_buffer()
	if chat_bufnr == -1 or not vim.api.nvim_buf_is_valid(chat_bufnr) then
		local win = vim.api.nvim_get_current_win()
		local buf = self:create_buffer(win)
		vim.cmd("runtime! syntax/markdown.vim")
		return buf
	end

	self.buffer = chat_bufnr
	local existing_win = self:find_window(chat_bufnr)
	if existing_win then
		self.window = existing_win
		vim.api.nvim_set_current_win(existing_win)
	else
		local current_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(current_win, chat_bufnr)
		self.window = current_win
	end

	return chat_bufnr
end

function Chat:focus()
	local bufnr = self.buffer
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		bufnr = self:start()
	end

	local win = self:find_window(bufnr)
	if win then
		vim.api.nvim_set_current_win(win)
		self.window = win
	else
		local current_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(current_win, bufnr)
		self.window = current_win
	end

	return bufnr
end

function Chat:_ensure_buffer()
	local bufnr = self.buffer
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		return bufnr
	end

	return self:start()
end

function Chat:_append_processed_text(text)
	if not text or text == "" then
		return
	end

	local bufnr = self.buffer
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count == 0 then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })
		line_count = 1
	end

	local last_idx = line_count - 1
	local current_line = vim.api.nvim_buf_get_lines(bufnr, last_idx, last_idx + 1, false)[1] or ""

	local segments = vim.split(text, "\n", { plain = true })
	if #segments == 0 then
		return
	end

	segments[1] = current_line .. segments[1]
	vim.api.nvim_buf_set_lines(bufnr, last_idx, last_idx + 1, false, { segments[1] })

	if #segments > 1 then
		local tail = {}
		for i = 2, #segments do
			tail[#tail + 1] = segments[i]
		end
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, tail)
	end

	local win = self:find_window(bufnr)
	if win and vim.api.nvim_win_is_valid(win) then
		self.window = win
		local updated_count = vim.api.nvim_buf_line_count(bufnr)
		local last_line = vim.api.nvim_buf_get_lines(bufnr, updated_count - 1, updated_count, false)[1] or ""
		pcall(vim.api.nvim_win_set_cursor, win, { updated_count, #last_line })
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

	local context = {
		buffer = bufnr,
		window = self:find_window(bufnr),
	}

	local processed = self.interpreter:process(text, context)
	self:_append_processed_text(processed)
end

return Chat
