local Interpreter = require("interpreter")
local ThinkHandler = require("tags.handlers.think")
local Queue = require("queue")

local Chat = {}
Chat.__index = Chat

function Chat:new()
	local instance = {
		buffer = nil,
		window = nil,
		interpreter = Interpreter:new(),
		queue = Queue:new(),
		is_typing = false,
	}

	instance.interpreter:register_handler("think", ThinkHandler:new())

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
	vim.bo[buf].conceallevel = 2
	vim.api.nvim_buf_set_name(buf, "LLM")
	self.buffer = buf
	return buf
end

function Chat:start()
	local chat_bufnr = self:find_buffer()

	if chat_bufnr == -1 then
		self.window = vim.api.nvim_get_current_win()
		local buf = self:create_buffer(self.window)
		vim.cmd("runtime! syntax/markdown.vim")
		return buf
	else
		local existing_win = self:find_window(chat_bufnr)
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
	local chat_bufnr = self:find_buffer()

	if chat_bufnr == -1 then
		return self:start()
	else
		local chat_win = self:find_window(chat_bufnr)
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

	self.queue:enqueue(text)

	if not self.is_typing then
		self:_process_queue()
	end
end

function Chat:_process_queue()
	vim.schedule(function()
		if self.is_typing or not self.buffer or not vim.api.nvim_buf_is_valid(self.buffer) then
			return
		end

		local text = self.queue:dequeue()
		if not text then
			return
		end

		self.is_typing = true

		local context = {
			buffer = self.buffer,
			window = self.window,
		}

		local processed_text = self.interpreter:process(text, context)
		if not processed_text or processed_text == "" then
			self.is_typing = false
			self:_process_queue()
			return
		end

		local chars = vim.fn.split(processed_text, "\\zs")
		local line_idx = vim.api.nvim_buf_line_count(self.buffer) - 1
		local current_line = vim.api.nvim_buf_get_lines(self.buffer, line_idx, line_idx + 1, false)[1] or ""
		local char_idx = 1

		local function type_char()
			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(self.buffer) then
					self.is_typing = false
					return
				end

				if char_idx > #chars then
					self.is_typing = false
					self:_process_queue()
					return
				end

				local char = chars[char_idx]

				if char == "\n" then
					vim.api.nvim_buf_set_lines(self.buffer, line_idx, line_idx + 1, false, { current_line })
					current_line = ""
					line_idx = line_idx + 1

					if line_idx >= vim.api.nvim_buf_line_count(self.buffer) then
						vim.api.nvim_buf_set_lines(self.buffer, -1, -1, false, { "" })
					end
				else
					current_line = current_line .. char
					vim.api.nvim_buf_set_lines(self.buffer, line_idx, line_idx + 1, false, { current_line })
				end

				pcall(vim.api.nvim_win_set_cursor, 0, { line_idx + 1, #current_line })

				char_idx = char_idx + 1
				vim.defer_fn(type_char, 10)
			end)
		end

		type_char()
	end)
end

return Chat
