local DeleteHandler = {}
DeleteHandler.__index = DeleteHandler

function DeleteHandler:new()
	local instance = {
		content = "",
	}
	return setmetatable(instance, self)
end

function DeleteHandler:on_tag_start(context)
	context._delete_pos = vim.api.nvim_win_get_cursor(0)
	context._delete_content = ""
	context._delete_operation_idx = #(context._operations or {}) + 1
	return ""
end

function DeleteHandler:on_content(content, context)
	context._delete_content = (context._delete_content or "") .. content
	return ""
end

function DeleteHandler:on_tag_end(content, context)
	if context._delete_content then
		if not context._operations then
			context._operations = {}
		end

		-- Handle content from tag end if available
		if content ~= "" then
			context._delete_content = content
		end

		-- Create the delete operation
		local delete_op = {
			type = "delete",
			content = context._delete_content,
			idx = context._delete_operation_idx,
			applied = false,
		}

		table.insert(context._operations, delete_op)

		-- Apply the delete operation directly to the target buffer with visual feedback
		if context._target_buffer and vim.api.nvim_buf_is_valid(context._target_buffer) then
			local lines = vim.api.nvim_buf_get_lines(context._target_buffer, 0, -1, false)
			local buffer_content = table.concat(lines, "\n")

			-- Find the position of the content to delete
			local start_idx, end_idx = buffer_content:find(context._delete_content, 1, true)
			if start_idx and end_idx then
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

				-- Count lines up to start position
				local line_start = 0
				local char_count = 0
				local col_start = 0

				for i, line in ipairs(lines) do
					if char_count + #line + 1 > start_idx then
						line_start = i - 1
						col_start = start_idx - char_count
						break
					end
					char_count = char_count + #line + 1
				end

				-- Calculate end position
				local delete_lines = vim.split(context._delete_content, "\n", true)
				local line_end = line_start
				local col_end = col_start

				if #delete_lines > 1 then
					line_end = line_start + #delete_lines - 1
					col_end = #delete_lines[#delete_lines]
				else
					col_end = col_start + #context._delete_content
				end

				-- Jump to the position before deleting
				vim.api.nvim_set_current_win(target_win)
				vim.api.nvim_win_set_cursor(target_win, { line_start + 1, col_start })

				-- Visually highlight the content to be deleted (briefly)
				-- Use vim API to delete the content from the buffer
				vim.api.nvim_buf_set_text(
					context._target_buffer,
					line_start,
					col_start,
					line_end,
					col_end,
					{} -- Empty replacement
				)

				-- Return focus to chat buffer
				vim.api.nvim_set_current_win(prev_win)
				vim.api.nvim_win_set_buf(prev_win, prev_buf)

				vim.api.nvim_echo({ { "Deleted content from target file", "Normal" } }, true, {})
				delete_op.applied = true
			else
				vim.api.nvim_echo({ { "Could not find content to delete in target file", "WarningMsg" } }, true, {})
			end
		end

		-- Cleanup
		context._delete_content = nil
		context._delete_operation_idx = nil
	end
	return ""
end

return DeleteHandler
