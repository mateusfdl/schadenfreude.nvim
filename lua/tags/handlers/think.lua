local ThinkHandler = {}
ThinkHandler.__index = ThinkHandler

function ThinkHandler:new()
	local instance = {
		timer = nil,
		frame = 1,
		frames = {
			"🌑",
			"🌒",
			"🌓",
			"🌔",
			"🌕",
			"🌖",
			"🌗",
			"🌘",
		},
	}
	return setmetatable(instance, self)
end

local function valid_buffer(bufnr)
	return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

function ThinkHandler:on_tag_start(context)
	if not context or not valid_buffer(context.buffer) then
		return ""
	end

	local buffer = context.buffer
	local line_count = vim.api.nvim_buf_line_count(buffer)
	if line_count == 0 then
		vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "" })
		line_count = 1
	end

	local row = line_count - 1
	local line = vim.api.nvim_buf_get_lines(buffer, row, row + 1, false)[1] or ""
	local indicator = self.frames[1]
	local new_line = line .. indicator

	vim.api.nvim_buf_set_lines(buffer, row, row + 1, false, { new_line })

	context._think_buffer = buffer
	context._think_pos = { row, #line }

	if context.window and vim.api.nvim_win_is_valid(context.window) then
		pcall(vim.api.nvim_win_set_cursor, context.window, { row + 1, #new_line })
	end

	if not self.timer then
		self.timer = vim.loop.new_timer()
		self.timer:start(0, 150, vim.schedule_wrap(function()
			self:animate(context)
		end))
	end

	return ""
end

function ThinkHandler:on_content(_, _)
	return ""
end

function ThinkHandler:on_tag_end(_, context)
	if context and valid_buffer(context._think_buffer) and context._think_pos then
		local row, col = context._think_pos[1], context._think_pos[2]
		local line = vim.api.nvim_buf_get_lines(context._think_buffer, row, row + 1, false)[1] or ""
		local prefix = col > 0 and line:sub(1, col) or ""
		local new_line = prefix .. "🌑"
		vim.api.nvim_buf_set_lines(context._think_buffer, row, row + 1, false, { new_line })
	end

	if self.timer then
		self.timer:stop()
		self.timer:close()
		self.timer = nil
	end
end

function ThinkHandler:animate(context)
	if not context or not valid_buffer(context._think_buffer) or not context._think_pos then
		return
	end

	local row, col = context._think_pos[1], context._think_pos[2]
	local line = vim.api.nvim_buf_get_lines(context._think_buffer, row, row + 1, false)[1] or ""
	if #line < col then
		return
	end

	self.frame = (self.frame % #self.frames) + 1
	local frame_char = self.frames[self.frame]
	local prefix = col > 0 and line:sub(1, col) or ""
	local new_line = prefix .. frame_char

	vim.api.nvim_buf_set_lines(context._think_buffer, row, row + 1, false, { new_line })

	if context.window and vim.api.nvim_win_is_valid(context.window) then
		pcall(vim.api.nvim_win_set_cursor, context.window, { row + 1, #new_line })
	end
end

return ThinkHandler
