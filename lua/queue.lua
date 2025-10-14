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

return Queue
