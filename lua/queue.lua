local Queue = {}

function Queue:new()
	local instance = {
		buffer = {},
	}

	setmetatable(instance, self)
	self.__index = self

	return instance
end

function Queue:enqueue(text)
	if not text then
		return
	end

	self.buffer = self.buffer or {}
	table.insert(self.buffer, text)
end

function Queue:dequeue()
	local result = nil
	if self.buffer and self:is_filled() then
		result = table.remove(self.buffer, 1)
	end

	return result
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
