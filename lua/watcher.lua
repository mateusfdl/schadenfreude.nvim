local Watcher = {}

function Watcher:new(queue, opts)
	opts = opts or {}
	local instance = {
		queue = queue,
		interval = opts.interval or 100,
		running = false,
		callback = opts.callback,
		timer = nil,
	}

	setmetatable(instance, Watcher)
	self.__index = Watcher
	return instance
end

function Watcher:start()
	if self.running then
		return
	end

	self.running = true
	self.timer = vim.loop.new_timer()

	self.timer:start(
		0,
		self.interval,
		vim.schedule_wrap(function()
			if not self.running then
				return
			end
			if self.callback then
				self.queue:process_until_empty(self.callback)
			end
		end)
	)
end

function Watcher:stop()
	self.running = false
	if self.timer then
		self.timer:stop()
		self.timer:close()
		self.timer = nil
	end
end

return Watcher
