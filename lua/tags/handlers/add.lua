local AddHandler = {}
AddHandler.__index = AddHandler

function AddHandler:new()
	local instance = {
		content = "",
	}
	return setmetatable(instance, self)
end

function AddHandler:on_tag_start(context)
	context._add_pos = vim.api.nvim_win_get_cursor(0)
	context._add_content = ""
	context._add_operation_idx = #(context._operations or {}) + 1
	return ""
end

function AddHandler:on_content(content, context)
	context._add_content = (context._add_content or "") .. content
	return ""
end

function AddHandler:on_tag_end(content, context)
	if context._add_content then
		if not context._operations then
			context._operations = {}
		end

		-- Handle inline add tag (for one-liners)
		if content ~= "" then
			context._add_content = content
		end

		-- Create the add operation
		local add_op = {
			type = "add",
			content = context._add_content,
			line = nil, -- Will be populated by AT_LINE tag if present
			idx = context._add_operation_idx,
			applied = false,
		}

		table.insert(context._operations, add_op)

		-- Look ahead for AT_LINE tag
		context._waiting_for_line = true
		context._add_index = context._add_operation_idx

		-- If line number is present in an inline tag
		if content and content:match("<|AT_LINE|>%s*(%d+)%s*</|AT_LINE|>") then
			add_op.line = tonumber(content:match("<|AT_LINE|>%s*(%d+)%s*</|AT_LINE|>"))
		end

		-- If we have a target buffer, apply the add operation with visual feedback
		if context._target_buffer and vim.api.nvim_buf_is_valid(context._target_buffer) then
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

			-- Determine where to add the content
			local line_pos

			if add_op.line then
				line_pos = add_op.line
				-- Convert to 0-indexed
				if line_pos > 0 then
					line_pos = line_pos - 1
				end
			else
				-- If no line number specified, add to end of file
				line_pos = vim.api.nvim_buf_line_count(context._target_buffer)
			end

			-- Ensure valid position
			if line_pos > vim.api.nvim_buf_line_count(context._target_buffer) then
				line_pos = vim.api.nvim_buf_line_count(context._target_buffer)
			end

			-- Prepare the lines to add
			local add_lines = vim.split(add_op.content, "\n", true)

			-- Jump to the position before adding
			vim.api.nvim_set_current_win(target_win)
			vim.api.nvim_win_set_cursor(target_win, { line_pos + 1, 0 })

			-- Add the content
			vim.api.nvim_buf_set_lines(context._target_buffer, line_pos, line_pos, false, add_lines)

			-- Return focus to chat buffer
			vim.api.nvim_set_current_win(prev_win)
			vim.api.nvim_win_set_buf(prev_win, prev_buf)

			vim.api.nvim_echo({ { "Added new content at line " .. (line_pos + 1), "Normal" } }, true, {})
			add_op.applied = true
		end

		-- Cleanup
		context._add_content = nil
		context._add_operation_idx = nil
	end
	return ""
end

return AddHandler
