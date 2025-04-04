local ThinkHandler = {}
ThinkHandler.__index = ThinkHandler

function ThinkHandler:new()
	local instance = {
		thinking_indicator = "*",
		completion_indicator = "+",
		indicators = {},
		timer = nil,
		frame = 1,
		frames = { "-", "\\", "|", "/" },
	}
	return setmetatable(instance, self)
end

function ThinkHandler:on_tag_start(context)
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

	return self.thinking_indicator
end

function ThinkHandler:on_content(content, context)
	return ""
end

function ThinkHandler:on_tag_end(content, context)
	if #self.indicators == 0 and self.timer then
		self.timer:stop()
		self.timer:close()
		self.timer = nil
	end

	return self.completion_indicator
end

function ThinkHandler:animate(context)
	if not context.buffer or not vim.api.nvim_buf_is_valid(context.buffer) then
		return
	end

	self.frame = (self.frame % #self.frames) + 1
	local frame_char = self.frames[self.frame]

	local lines = vim.api.nvim_buf_get_lines(context.buffer, 0, -1, false)
	self.indicators = {}

	local current_buf = vim.api.nvim_get_current_buf()
	if current_buf ~= context.buffer then
		return
	end

	for i, line in ipairs(lines) do
		local start_pos = 1
		local found_pos = line:find(self.thinking_indicator, start_pos, true)

		while found_pos do
			vim.api.nvim_buf_set_text(context.buffer, i - 1, found_pos - 1, i - 1, found_pos, { frame_char })

			start_pos = found_pos + 1
			found_pos = line:find(self.thinking_indicator, start_pos, true)
		end
	end
end

return ThinkHandler

