local ModelBlockManager = {}
ModelBlockManager.__index = ModelBlockManager

function ModelBlockManager:new()
	return setmetatable({
		active_blocks = {},
		temp_buffers = {},
		block_order = {},
		main_chat_buffer = nil,
		chat_instance = nil,
	}, self)
end

function ModelBlockManager:create_model_block(model_name, block_id, prompt)
	local temp_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(temp_buf, "filetype", "markdown")

	local block = {
		id = block_id,
		model_name = model_name,
		prompt = prompt,
		temp_buffer = temp_buf,
		content = "",
		is_complete = false,
		start_line = nil,
		end_line = nil,
	}

	self.active_blocks[block_id] = block
	self.temp_buffers[block_id] = temp_buf
	table.insert(self.block_order, block_id)

	if self.main_chat_buffer and vim.api.nvim_buf_is_valid(self.main_chat_buffer) then
		vim.schedule(function()
			local block_start_marker = "@AI :BEGIN == ID:" .. block_id .. " == MODEL:" .. model_name
			local last_line = vim.api.nvim_buf_line_count(self.main_chat_buffer)
			vim.api.nvim_buf_set_lines(self.main_chat_buffer, last_line, last_line, false, { "", block_start_marker })
		end)
	end

	return block
end

function ModelBlockManager:append_to_block(block_id, text)
	local block = self.active_blocks[block_id]
	if not block then
		return
	end

	block.content = block.content .. text

	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(block.temp_buffer) then
			local lines = vim.split(block.content, "\n")
			vim.api.nvim_buf_set_lines(block.temp_buffer, 0, -1, false, lines)
		end

		if self.main_chat_buffer and vim.api.nvim_buf_is_valid(self.main_chat_buffer) then
			self:render_block_in_main_buffer(block)

			self:move_cursor_to_block_end(block)
		end
	end)
end

function ModelBlockManager:complete_block(block_id)
	local block = self.active_blocks[block_id]
	if not block then
		return
	end

	block.is_complete = true

	vim.schedule(function()
		if self.main_chat_buffer and vim.api.nvim_buf_is_valid(self.main_chat_buffer) then
			self:render_block_in_main_buffer(block)
		end
	end)
end

function ModelBlockManager:render_block_in_main_buffer(block)
	if not self.main_chat_buffer or not vim.api.nvim_buf_is_valid(self.main_chat_buffer) then
		return
	end

	local main_lines = vim.api.nvim_buf_get_lines(self.main_chat_buffer, 0, -1, false)
	local start_line_idx = nil

	for i, line in ipairs(main_lines) do
		if line:match("^@AI :BEGIN == ID:" .. block.id .. " == MODEL:") then
			start_line_idx = i -- 1-based index
			break
		end
	end

	if not start_line_idx then
		return
	end

	local content_start = start_line_idx + 1 -- Line after the start marker
	local content_end = content_start

	for i = content_start, #main_lines do
		if main_lines[i]:match("^@AI :BEGIN") or main_lines[i]:match("^@AI :FINISH") then
			content_end = i - 1
			break
		end
		content_end = i
	end

	local content_lines = vim.split(block.content, "\n")
	if block.is_complete then
		table.insert(content_lines, "@AI :FINISH")
		table.insert(content_lines, "")
	end

	vim.api.nvim_buf_set_lines(self.main_chat_buffer, content_start - 1, content_end, false, content_lines)

	block.start_line = start_line_idx
	block.end_line = start_line_idx + #content_lines
end

function ModelBlockManager:set_main_chat_buffer(buffer)
	self.main_chat_buffer = buffer
end

function ModelBlockManager:set_chat_instance(chat_instance)
	self.chat_instance = chat_instance
end

function ModelBlockManager:move_cursor_to_block_end(block)
	if not self.main_chat_buffer or not vim.api.nvim_buf_is_valid(self.main_chat_buffer) then
		return
	end

	local win = vim.fn.bufwinid(self.main_chat_buffer)
	if win == -1 then
		return
	end

	local block_start_marker = "@AI :BEGIN == ID:" .. block.id .. " == MODEL:" .. block.model_name
	local main_lines = vim.api.nvim_buf_get_lines(self.main_chat_buffer, 0, -1, false)

	for i, line in ipairs(main_lines) do
		if line:match("^@AI :BEGIN == ID:" .. block.id .. " == MODEL:") then
			local content_lines = vim.split(block.content, "\n")
			local end_line = i + #content_lines
			local buffer_line_count = vim.api.nvim_buf_line_count(self.main_chat_buffer)

			if end_line <= buffer_line_count then
				local last_line_content = content_lines[#content_lines] or ""
				pcall(vim.api.nvim_win_set_cursor, win, { end_line, #last_line_content })
			end
			break
		end
	end
end

function ModelBlockManager:get_block(block_id)
	return self.active_blocks[block_id]
end

function ModelBlockManager:cleanup_completed_blocks()
	for block_id, block in pairs(self.active_blocks) do
		if block.is_complete then
			if vim.api.nvim_buf_is_valid(block.temp_buffer) then
				vim.api.nvim_buf_delete(block.temp_buffer, { force = true })
			end

			self.active_blocks[block_id] = nil
			self.temp_buffers[block_id] = nil

			for i, id in ipairs(self.block_order) do
				if id == block_id then
					table.remove(self.block_order, i)
					break
				end
			end
		end
	end
end

function ModelBlockManager:get_active_blocks()
	return self.active_blocks
end

function ModelBlockManager:is_any_block_active()
	for _, block in pairs(self.active_blocks) do
		if not block.is_complete then
			return true
		end
	end
	return false
end

return ModelBlockManager

