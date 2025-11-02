local Interpreter = {}
Interpreter.__index = Interpreter

function Interpreter:new()
	local instance = {
		tag_handlers = {},
		active_tag = nil,
		pending = "",
	}
	return setmetatable(instance, self)
end

function Interpreter:register_handler(tag_name, handler)
	self.tag_handlers[tag_name] = handler
end

local function append_to_tag(tag_state, chunk, context)
	if not tag_state then
		return
	end

	tag_state.buffer = tag_state.buffer .. chunk
	local handler = tag_state.handler
	if handler.on_content then
		handler:on_content(chunk, context)
	end
end

function Interpreter:process(text, context)
	if not text or text == "" then
		return ""
	end

	local data = self.pending .. text
	self.pending = ""

	local output = {}
	local pos = 1

	while pos <= #data do
		local tag_start = data:find("<", pos)
		if not tag_start then
			local remainder = data:sub(pos)
			if remainder ~= "" then
				if self.active_tag then
					append_to_tag(self.active_tag, remainder, context)
				else
					table.insert(output, remainder)
				end
			end
			break
		end

		if tag_start > pos then
			local prefix = data:sub(pos, tag_start - 1)
			if self.active_tag then
				append_to_tag(self.active_tag, prefix, context)
			else
				table.insert(output, prefix)
			end
		end

		local tag_end = data:find(">", tag_start + 1)
		if not tag_end then
			self.pending = data:sub(tag_start)
			break
		end

		local tag_content = data:sub(tag_start + 1, tag_end - 1)
		local is_closing = tag_content:sub(1, 1) == "/"
		local tag_name = is_closing and tag_content:sub(2) or tag_content

		if not tag_name:match("^[%w_]+$") then
			local literal = data:sub(tag_start, tag_end)
			if self.active_tag then
				append_to_tag(self.active_tag, literal, context)
			else
				table.insert(output, literal)
			end
			pos = tag_end + 1
			goto continue
		end

		local handler = self.tag_handlers[tag_name]
		if not handler then
			local literal = data:sub(tag_start, tag_end)
			if self.active_tag then
				append_to_tag(self.active_tag, literal, context)
			else
				table.insert(output, literal)
			end
			pos = tag_end + 1
			goto continue
		end

		if is_closing then
			if self.active_tag and self.active_tag.name == tag_name then
				local replacement = handler:on_tag_end(self.active_tag.buffer, context)
				if replacement and replacement ~= "" then
					table.insert(output, replacement)
				end
				self.active_tag = nil
			end
		else
			local replacement = handler:on_tag_start(context)
			if replacement and replacement ~= "" then
				table.insert(output, replacement)
			end
			self.active_tag = {
				name = tag_name,
				handler = handler,
				buffer = "",
			}
		end

		pos = tag_end + 1

		::continue::
	end

	if self.active_tag then
		return table.concat(output)
	end

	return table.concat(output)
end

function Interpreter:reset()
	self.active_tag = nil
	self.pending = ""
end

return Interpreter
