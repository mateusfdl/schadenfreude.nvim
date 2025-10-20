local Notification = {}
Notification.__index = Notification

-- Global registry to track all active notifications
local active_notifications = {}
local notification_counter = 0

function Notification:new()
	local instance = {
		timer = nil,
		window = nil,
		buffer = nil,
		interval = 500,
		frame_index = 1,
		active = false,
		frames = {},
		id = nil,
	}
	setmetatable(instance, self)
	return instance
end

function Notification:dispatch_cooking_notification(model_name)
	if self.active then
		return
	end

	self.active = true
	notification_counter = notification_counter + 1
	self.id = "notification_" .. notification_counter

	-- Add this notification to the global registry
	active_notifications[self.id] = self

	-- Create dynamic frames with the model name
	self.frames = {
		"(╯°□°╯）┻━┻ " .. model_name .. " is cooking",
		"(╯'□')╯︵ ┻━┻ " .. model_name .. " is cooking",
	}

	-- Create buffer
	self.buffer = vim.api.nvim_create_buf(false, true)
	vim.bo[self.buffer].modifiable = false

	-- Get screen dimensions and calculate position based on active notifications
	local ui = vim.api.nvim_list_uis()[1]
	local max_width = math.max(vim.api.nvim_strwidth(self.frames[1]), vim.api.nvim_strwidth(self.frames[2]))
	
	-- Calculate row position based on number of active notifications
	local active_count = 0
	for _ in pairs(active_notifications) do
		active_count = active_count + 1
	end
	local row_offset = (active_count - 1) * 2  -- 2 lines per notification (1 for content + 1 for spacing)
	
	-- Create window at bottom right, stacked vertically
	self.window = vim.api.nvim_open_win(self.buffer, false, {
		relative = 'editor',
		anchor = 'SE',
		row = ui.height - 2 - row_offset,
		col = ui.width,
		width = max_width + 2,
		height = 1,
		style = 'minimal',
		border = 'none',
		focusable = false,
	})

	-- Set window highlight
	vim.wo[self.window].winhl = 'Normal:Normal'
	
	-- Start animation timer
	self.timer = vim.loop.new_timer()
	self.timer:start(0, self.interval, vim.schedule_wrap(function()
		if not self.active then
			return
		end

		local message = self.frames[self.frame_index]
		self.frame_index = (self.frame_index % #self.frames) + 1

		-- Update buffer content
		vim.bo[self.buffer].modifiable = true
		vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, { message })
		vim.bo[self.buffer].modifiable = false
	end))
end

function Notification:stop()
	self.active = false
	
	-- Remove from global registry
	if self.id then
		active_notifications[self.id] = nil
	end
	
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
		
		-- Reposition remaining notifications
		self:_reposition_notifications()
	end)
end

function Notification:_reposition_notifications()
	local ui = vim.api.nvim_list_uis()[1]
	local notifications = {}
	
	-- Collect all active notifications
	for _, notification in pairs(active_notifications) do
		table.insert(notifications, notification)
	end
	
	-- Reposition each notification
	for i, notification in ipairs(notifications) do
		if notification.window and vim.api.nvim_win_is_valid(notification.window) then
			local row_offset = (i - 1) * 2
			vim.api.nvim_win_set_config(notification.window, {
				relative = 'editor',
				anchor = 'SE',
				row = ui.height - 2 - row_offset,
				col = ui.width,
			})
		end
	end
end

return Notification