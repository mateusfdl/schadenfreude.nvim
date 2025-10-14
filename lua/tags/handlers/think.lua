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

function ThinkHandler:on_tag_start(context)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	context._think_pos = { row - 1, col }
	context.buffer = vim.api.nvim_get_current_buf()

	local line = vim.api.nvim_buf_get_lines(context.buffer, row - 1, row, false)[1] or ""
	local indicator = self.frames[1]
	local new_line = line:sub(1, col) .. indicator

	if vim.api.nvim_buf_is_valid(context.buffer) then
		vim.api.nvim_buf_set_lines(context.buffer, row - 1, row, false, { new_line })
	end

	if not self.timer then
		self.timer = vim.loop.new_timer()
		self.timer:start(
			0,
			150,
			vim.schedule_wrap(function()
				self:animate(context)
			end)
		)
	end

	return indicator
end

function ThinkHandler:on_content(_, _)
	return ""
end

function ThinkHandler:on_tag_end(_, context)
	if context._think_pos and context.buffer and vim.api.nvim_buf_is_valid(context.buffer) then
		local row, col = unpack(context._think_pos)
		local line = vim.api.nvim_buf_get_lines(context.buffer, row, row + 1, false)[1] or ""
		local completion_indicator = "🌑"
		local new_line = line:sub(1, col) .. completion_indicator

		vim.api.nvim_buf_set_lines(context.buffer, row, row + 1, false, { new_line })
	end

	if self.timer then
		self.timer:stop()
		self.timer:close()
		self.timer = nil
	end
end

function ThinkHandler:animate(context)
	if not context.buffer or not vim.api.nvim_buf_is_valid(context.buffer) or not context._think_pos then
		return
	end

	local row, col = unpack(context._think_pos)
	local line = vim.api.nvim_buf_get_lines(context.buffer, row, row + 1, false)[1] or ""
	if #line < col then
		return
	end

	self.frame = (self.frame % #self.frames) + 1
	local frame_char = self.frames[self.frame]

	local new_line = line:sub(1, col) .. frame_char

	vim.api.nvim_buf_set_lines(context.buffer, row, row + 1, false, { new_line })
end

return ThinkHandler
