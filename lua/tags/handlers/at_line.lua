local AtLineHandler = {}
AtLineHandler.__index = AtLineHandler

function AtLineHandler:new()
	local instance = {
		content = "",
	}
	return setmetatable(instance, self)
end

function AtLineHandler:on_tag_start(context)
	context._at_line_pos = vim.api.nvim_win_get_cursor(0)
	context._at_line_content = ""
	return ""
end

function AtLineHandler:on_content(content, context)
	context._at_line_content = (context._at_line_content or "") .. content
	return ""
end

function AtLineHandler:on_tag_end(content, context)
	if context._at_line_content then
		if not context._operations then
			context._operations = {}
		end

		-- Handle inline at_line tag (for one-liners)
		if content ~= "" then
			context._at_line_content = content
		end

		-- Try to convert to a line number
		local line_number = tonumber(context._at_line_content)
		if not line_number then
			return ""
		end

		local at_line_op = {
			type = "at_line",
			line = line_number,
			applied = false,
		}

		table.insert(context._operations, at_line_op)

		-- If we have a waiting add operation, update its line number and apply it
		if context._waiting_for_line and context._add_index then
			local found = false

			for i, op in ipairs(context._operations) do
				if op.type == "add" and op.idx == context._add_index and not op.applied then
					-- Update the line number
					op.line = line_number
					at_line_op.add_index = i
					found = true

					-- Apply the add operation to the target buffer if not already applied
					if
						not op.applied
						and context._target_buffer
						and vim.api.nvim_buf_is_valid(context._target_buffer)
					then
						-- Save current state to restore later
						local prev_buf = vim.api.nvim_get_current_buf()
						local prev_win = vim.api.nvim_get_current_win()

						-- Find window for the target buffer
						local target_win = nil
						for _, win in ipairs(vim.api.nvim_list_wins()) do
							if vim.api.nvim_win_get_buf(win) == context._target_buffer then
								target_win = win
								break
							end
						end

						-- If no existing window, open a split with the target buffer
						if not target_win then
							vim.cmd("vsplit")
							target_win = vim.api.nvim_get_current_win()
							vim.api.nvim_win_set_buf(target_win, context._target_buffer)
						end

						-- Adjust line position
						local line_pos = line_number
						if line_pos > 0 then
							line_pos = line_pos - 1 -- Convert to 0-indexed
						end

						-- Ensure valid position
						if line_pos > vim.api.nvim_buf_line_count(context._target_buffer) then
							line_pos = vim.api.nvim_buf_line_count(context._target_buffer)
						end

						-- Jump to the position
						vim.api.nvim_set_current_win(target_win)
						vim.api.nvim_win_set_cursor(target_win, { line_pos + 1, 0 })

						-- Add the content
						local add_lines = vim.split(op.content, "\n", true)
						vim.api.nvim_buf_set_lines(context._target_buffer, line_pos, line_pos, false, add_lines)

						-- Return focus to chat buffer
						vim.api.nvim_set_current_win(prev_win)
						vim.api.nvim_win_set_buf(prev_win, prev_buf)

						vim.api.nvim_echo({ { "Added new content at line " .. (line_pos + 1), "Normal" } }, true, {})
						op.applied = true
						at_line_op.applied = true
					end

					break
				end
			end

			if found then
				context._waiting_for_line = nil
				context._add_index = nil
			end
		end

		context._at_line_content = nil
	end
	return ""
end

return AtLineHandler
