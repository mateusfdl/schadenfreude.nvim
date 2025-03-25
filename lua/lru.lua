local LRU = {}
LRU.__index = LRU

function LRU.new(max_tokens)
	return setmetatable({
		max_tokens = max_tokens,
		current_tokens = 0,
		cache = {},
		head = nil,
		tail = nil,
	}, LRU)
end

function LRU:put(key, tokens, count_tokens)
	while self.current_tokens + count_tokens > self.max_tokens do
		self:evict()
	end
	local node = { key = key, tokens = tokens, count_tokens = count_tokens, previous = nil, next = nil }

	self.cache[key] = { node = node, content = tokens, count_tokens = count_tokens }

	if self.head == nil then
		self.head = node
		self.tail = node
	else
		node.next = self.head
		self.head.previous = node
		self.head = node
	end

	self.current_tokens = self.current_tokens + count_tokens
end

function LRU:get(key)
	cached_entry = self.cache[key]

	if cached_entry == nil then
		return nil
	end

	local node = cached_entry.node
	if node ~= self.head then
		if node == self.tail then
			self.tail = node.prev
		end
		if node.prev then
			node.prev.next = node.next
		end
		if node.next then
			node.next.prev = node.prev
		end
		node.next = self.head
		node.prev = nil
		self.head.prev = node
		self.head = node
	end

	return cached_entry.content
end

function LRU:evict()
	if not self.tail then
		return
	end
	local key = self.tail.key
	self.current_tokens = self.current_tokens - self.cache[key].count_tokens
	self.cache[key] = nil

	if self.tail.previous then
		self.tail.previous.next = nil
		self.tail = self.tail.previous
	else
		self.head = nil
		self.tail = nil
	end
end

return LRU
