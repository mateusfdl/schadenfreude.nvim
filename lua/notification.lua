local Notification = {}
Notification.__index = Notification

function Notification:new()
	return setmetatable({
		active = false,
	}, self)
end

function Notification:dispatch_cooking_notification(model_name)
	if self.active then
		return
	end

	self.active = true
	vim.notify("󱁧 " .. model_name .. " is thinking...", vim.log.levels.INFO)
end

function Notification:stop()
	self.active = false
end

return Notification
