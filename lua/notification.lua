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
		id = nil,
	}
	return setmetatable(instance, self)
end

function Notification:dispatch_cooking_notification(model_name)
	if self.active then
		return
	end

	self.frames = {
		"(╯°□°╯）┻━┻ " .. model_name .. " is cooking",
		"(╯'□')╯︵ ┻━┻ " .. model_name .. " is cooking",
	}
	self.frame_index = 1

	local ui = vim.api.nvim_list_uis()
	local has_ui = ui and ui[1] ~= nil

	self.active = true

	if not has_ui then
		return
	end

	self.buffer = vim.api.nvim_create_buf(false, true)
	vim.bo[self.buffer].modifiable = false

	local max_width = math.max(vim.api.nvim_strwidth(self.frames[1]), vim.api.nvim_strwidth(self.frames[2]))
	self.window = vim.api.nvim_open_win(self.buffer, false, {
		relative = "editor",
		anchor = "SE",
		row = ui[1].height - 2,
		col = ui[1].width,
		width = max_width + 2,
		height = 1,
		style = "minimal",
		border = "none",
		focusable = false,
	})

	vim.wo[self.window].winhl = "Normal:Normal"

	vim.bo[self.buffer].modifiable = true
	vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, { self.frames[1] })
	vim.bo[self.buffer].modifiable = false

	self.timer = vim.loop.new_timer()
	self.timer:start(0, self.interval, vim.schedule_wrap(function()
		if not self.active or not self.window or not vim.api.nvim_win_is_valid(self.window) then
			return
		end

		local message = self.frames[self.frame_index]
		self.frame_index = (self.frame_index % #self.frames) + 1

		if self.buffer and vim.api.nvim_buf_is_valid(self.buffer) then
			vim.bo[self.buffer].modifiable = true
			vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, { message })
			vim.bo[self.buffer].modifiable = false
		end
	end))
end

function Notification:stop()
	if not self.active then
		return
	end

	self.active = false

	if self.timer then
		self.timer:stop()
		self.timer:close()
		self.timer = nil
	end

	vim.schedule(function()
		if self.window and vim.api.nvim_win_is_valid(self.window) then
			vim.api.nvim_win_close(self.window, true)
		end

		if self.buffer and vim.api.nvim_buf_is_valid(self.buffer) then
			vim.api.nvim_buf_delete(self.buffer, { force = true })
		end

		self.window = nil
		self.buffer = nil
	end)
end

return Notification
