local BufferParser = {}
BufferParser.__index = BufferParser

function BufferParser:new()
	return setmetatable({
		history = {},
	}, self)
end

function BufferParser:parse_buffer_content(content)
	local messages = {}
	local current_message = nil
	local lines = vim.split(content, "\n")
	local i = 1

	while i <= #lines do
		local line = lines[i]

		local ai_begin_match = line:match("^@AI :BEGIN == ID:([^%s]+)")
		if ai_begin_match then
			if current_message and current_message.role == "user" then
				table.insert(messages, current_message)
				current_message = nil
			end

			current_message = {
				role = "assistant",
				content = "",
				id = ai_begin_match,
			}
			i = i + 1

			while i <= #lines do
				local ai_line = lines[i]
				if ai_line:match("^@AI :FINISH$") then
					break
				end

				if current_message.content == "" then
					current_message.content = ai_line
				else
					current_message.content = current_message.content .. "\n" .. ai_line
				end
				i = i + 1
			end

			if current_message then
				table.insert(messages, current_message)
				current_message = nil
			end
		else
			if not current_message or current_message.role ~= "user" then
				current_message = {
					role = "user",
					content = line,
				}
			else
				if current_message.content == "" then
					current_message.content = line
				else
					current_message.content = current_message.content .. "\n" .. line
				end
			end
		end

		i = i + 1
	end

	if current_message and current_message.role == "user" and current_message.content ~= "" then
		table.insert(messages, current_message)
	end

	return messages
end

function BufferParser:get_messages_from_buffer(buffer)
	if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
		return {}
	end

	local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
	local content = table.concat(lines, "\n")

	return self:parse_buffer_content(content)
end

function BufferParser:extract_new_user_message(buffer)
	local messages = self:get_messages_from_buffer(buffer)

	if #messages > 0 and messages[#messages].role == "user" then
		return messages[#messages].content
	end

	return nil
end

function BufferParser:get_conversation_history(buffer, exclude_last_user_message)
	local messages = self:get_messages_from_buffer(buffer)

	if exclude_last_user_message and #messages > 0 and messages[#messages].role == "user" then
		table.remove(messages)
	end

	return messages
end

function BufferParser:format_messages_for_api(messages, _)
	local formatted = {}

	for _, message in ipairs(messages) do
		table.insert(formatted, {
			role = message.role,
			content = message.content,
		})
	end

	return formatted
end

return BufferParser

