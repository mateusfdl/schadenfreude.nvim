local Notification = {}
Notification.__index = Notification

function Notification:new()
	local instance = {
		timer = nil,
		window = nil,
		buffer = nil,
		interval = 500,
		frame_index = 1,
		active = false,
		frames = {},
	}
	setmetatable(instance, self)
	return instance
end

function Notification:dispatch_cooking_notification(model_name)
	if self.active then
		return
	end

	self.active = true

	-- Create dynamic frames with the model name
	self.frames = {
		"(╯°□°╯）┻━┻ " .. model_name .. " is cooking",
		"(╯'□')╯︵ ┻━┻ " .. model_name .. " is cooking",
	}

	-- Create buffer
	self.buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(self.buffer, 'modifiable', false)

	-- Get screen dimensions
	local ui = vim.api.nvim_list_uis()[1]
	local max_width = math.max(vim.api.nvim_strwidth(self.frames[1]), vim.api.nvim_strwidth(self.frames[2]))
	
	-- Create window at bottom right, slightly above bottom
	self.window = vim.api.nvim_open_win(self.buffer, false, {
		relative = 'editor',
		anchor = 'SE',
		row = ui.height - 2,
		col = ui.width,
		width = max_width + 2,
		height = 1,
		style = 'minimal',
		border = 'none',
		focusable = false,
	})
	
	-- Set window highlight
	vim.api.nvim_win_set_option(self.window, 'winhl', 'Normal:Normal')
	
	-- Start animation timer
	self.timer = vim.loop.new_timer()
	self.timer:start(0, self.interval, vim.schedule_wrap(function()
		if not self.active then
			return
		end

		local message = self.frames[self.frame_index]
		self.frame_index = (self.frame_index % #self.frames) + 1
		
		-- Update buffer content
		vim.api.nvim_buf_set_option(self.buffer, 'modifiable', true)
		vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, { message })
		vim.api.nvim_buf_set_option(self.buffer, 'modifiable', false)
	end))
end

function Notification:stop()
	self.active = false
	
	if self.timer then
		self.timer:stop()
		self.timer:close()
		self.timer = nil
	end
	
	vim.schedule(function()
		if self.window and vim.api.nvim_win_is_valid(self.window) then
			vim.api.nvim_win_close(self.window, true)
			self.window = nil
		end
		
		if self.buffer and vim.api.nvim_buf_is_valid(self.buffer) then
			vim.api.nvim_buf_delete(self.buffer, { force = true })
			self.buffer = nil
		end
	end)
end

return Notification