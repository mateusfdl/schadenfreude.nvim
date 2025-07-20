local Queue = {}

function Queue:new()
	local instance = {
		buffer = {},
		is_locked = false,
	}

	setmetatable(instance, self)
	self.__index = self

	return instance
end

function Queue:enqueue(text)
	if not text then
		return
	end

	self:wait_until_unlocked()
	self:_lock()

	self.buffer = self.buffer or {}

	table.insert(self.buffer, text)

	self:_unlock()
end

function Queue:dequeue()
	self:wait_until_unlocked()

	self:_lock()
	local result = nil
	if self.buffer and self:is_filled() then
		result = table.remove(self.buffer, 1)
	end
	self:_unlock()

	return result
end

function Queue:_lock()
	self.is_locked = true
end

function Queue:_unlock()
	self.is_locked = false
end

function Queue:wait_until_unlocked()
	local count = 0
	while self.is_locked and count < 1000 do
		count = count + 1
	end
end

function Queue:is_filled()
	return #self.buffer > 0
end

function Queue:process_until_empty(callback)
	while self:is_filled() do
		local text = self:dequeue()
		if not text then
			break
		end
		callback(text)
	end
end

return Queue
