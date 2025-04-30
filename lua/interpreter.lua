local Interpreter = {}
Interpreter.__index = Interpreter

function Interpreter:new()
	local instance = {
		tag_handlers = {},
		current_tags = {},
		buffer = "",
	}
	return setmetatable(instance, self)
end

function Interpreter:register_handler(tag_name, handler)
	self.tag_handlers[tag_name] = handler
end

function Interpreter:process(text, context)
	if text == nil or text == "" then
		return text
	end

	local result = text
	local pos = 1
	local tag_start, tag_end

	if self.buffer ~= "" then
		result = self.buffer .. result
		self.buffer = ""
	end

	while pos <= #result do
		tag_start = result:find("<", pos)
		if not tag_start then
			break
		end

		local next_char = result:sub(tag_start + 1, tag_start + 1)
		local is_valid_tag_start = next_char:match("[%a/]")

		if not is_valid_tag_start then
			pos = tag_start + 1
			goto continue
		end

		tag_end = result:find(">", tag_start)
		if not tag_end then
			pos = tag_start + 1
			goto continue
		end

		local tag_content = result:sub(tag_start + 1, tag_end - 1)
		local is_closing = tag_content:sub(1, 1) == "/"
		local tag_name = is_closing and tag_content:sub(2) or tag_content

		if not tag_name:match("^[%a%d_]+$") then
			pos = tag_start + 1
			goto continue
		end

		if not self.tag_handlers[tag_name] then
			pos = tag_start + 1
			goto continue
		end

		if vim.g.schadenfreude_debug then
			vim.schedule(function()
				print("Tag found: " .. (is_closing and "closing " or "opening ") .. tag_name)
			end)
		end

		local handler = self.tag_handlers[tag_name]

		if is_closing then
			if #self.current_tags > 0 and self.current_tags[#self.current_tags].name == tag_name then
				local tag_info = table.remove(self.current_tags)
				local content = result:sub(tag_info.content_start, tag_start - 1)

				local replacement = handler:on_tag_end(content, context)

				local prefix = result:sub(1, tag_info.start - 1)
				local suffix = result:sub(tag_end + 1)

				result = prefix .. (replacement or "") .. suffix
				pos = #prefix + (replacement and #replacement or 0) + 1
			else
				result = result:sub(1, tag_start - 1) .. result:sub(tag_end + 1)
				pos = tag_start
			end
		else
			table.insert(self.current_tags, {
				name = tag_name,
				start = tag_start,
				content_start = tag_end + 1,
			})

			local replacement = handler:on_tag_start(context)

			if replacement then
				result = result:sub(1, tag_start - 1) .. replacement .. result:sub(tag_end + 1)
				pos = tag_start + #replacement
			else
				result = result:sub(1, tag_start - 1) .. result:sub(tag_end + 1)
				pos = tag_start
			end
		end

		::continue::
	end

	if #self.current_tags > 0 then
		local active_tag = self.current_tags[#self.current_tags]
		local handler = self.tag_handlers[active_tag.name]

		if handler and handler.on_content then
			return handler:on_content(result, context) or ""
		else
			return ""
		end
	end

	return result
end

function Interpreter:reset()
	self.current_tags = {}
	self.buffer = ""
end

return Interpreter
