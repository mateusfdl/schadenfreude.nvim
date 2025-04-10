local ReplaceHandler = {}
ReplaceHandler.__index = ReplaceHandler

function ReplaceHandler:new()
	local instance = {
		content = "",
	}
	return setmetatable(instance, self)
end

function ReplaceHandler:on_tag_start(context)
	context._replace_pos = vim.api.nvim_win_get_cursor(0)
	context._replace_content = ""
	return ""
end

function ReplaceHandler:on_content(content, context)
	context._replace_content = (context._replace_content or "") .. content
	return ""
end

function ReplaceHandler:on_tag_end(content, context)
	if context._replace_content then
		if not context._operations then
			context._operations = {}
		end

		-- Add the replace operation
		local replace_op = {
			type = "replace",
			content = context._replace_content,
			applied = false,
		}

		table.insert(context._operations, replace_op)

		-- Try to pair with the most recent search
		local paired = false

		-- If we have a _last_search reference, use that
		if context._last_search then
			for i, op in ipairs(context._operations) do
				if op.type == "search" and op.idx == context._last_search and not op.paired then
					-- Pair the operations
					op.paired = true
					replace_op.search_content = op.content
					replace_op.paired_with = i

					-- Apply the search/replace operation to the target buffer with visual feedback
					if context._target_buffer and vim.api.nvim_buf_is_valid(context._target_buffer) then
						local lines = vim.api.nvim_buf_get_lines(context._target_buffer, 0, -1, false)
						local buffer_content = table.concat(lines, "\n")
						local search_text = op.content
						local replace_text = replace_op.content

						-- Find where the match occurs
						local start_idx, end_idx = buffer_content:find(search_text, 1, true)
						if start_idx and end_idx then
							-- Count lines up to start position to find line number
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

							-- Count lines up to end position
							local line_end = line_start
							local col_end = col_start
							local current_count = char_count

							-- Handle multiline content
							local search_lines = vim.split(search_text, "\n", true)
							if #search_lines > 1 then
								line_end = line_start + #search_lines - 1
								-- Calculate end column based on the last line of search text
								col_end = #search_lines[#search_lines]
							else
								-- Single line - end column is start + length of search text
								col_end = col_start + #search_text
							end

							-- Visual feedback: jump to position and highlight
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

							-- Jump to the match position
							vim.api.nvim_set_current_win(target_win)
							vim.api.nvim_win_set_cursor(target_win, { line_start + 1, col_start })

							-- Prepare split lines for replacement
							local replace_lines = vim.split(replace_text, "\n", true)

							-- Replace the content with the new text
							vim.api.nvim_buf_set_text(
								context._target_buffer,
								line_start,
								col_start,
								line_end,
								col_end,
								replace_lines
							)

							-- Return focus to chat buffer
							vim.api.nvim_set_current_win(prev_win)
							vim.api.nvim_win_set_buf(prev_win, prev_buf)

							vim.api.nvim_echo(
								{ { "Applied search/replace operation to target file", "Normal" } },
								true,
								{}
							)
							op.applied = true
							replace_op.applied = true
						end
					end

					paired = true
					context._last_search = nil
					break
				end
			end
		end

		-- If not paired by _last_search, try to find any unpaired search
		if not paired then
			for i = #context._operations - 1, 1, -1 do
				local op = context._operations[i]
				if op.type == "search" and not op.paired then
					-- Pair the operations
					op.paired = true
					replace_op.search_content = op.content
					replace_op.paired_with = i

					-- Apply the search/replace operation to the target buffer with visual feedback
					if context._target_buffer and vim.api.nvim_buf_is_valid(context._target_buffer) then
						local lines = vim.api.nvim_buf_get_lines(context._target_buffer, 0, -1, false)
						local buffer_content = table.concat(lines, "\n")
						local search_text = op.content
						local replace_text = replace_op.content

						-- Find where the match occurs
						local start_idx, end_idx = buffer_content:find(search_text, 1, true)
						if start_idx and end_idx then
							-- Count lines up to start position to find line number
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

							-- Count lines up to end position
							local line_end = line_start
							local col_end = col_start
							local current_count = char_count

							-- Handle multiline content
							local search_lines = vim.split(search_text, "\n", true)
							if #search_lines > 1 then
								line_end = line_start + #search_lines - 1
								-- Calculate end column based on the last line of search text
								col_end = #search_lines[#search_lines]
							else
								-- Single line - end column is start + length of search text
								col_end = col_start + #search_text
							end

							-- Visual feedback: jump to position and highlight
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

							-- Jump to the match position
							vim.api.nvim_set_current_win(target_win)
							vim.api.nvim_win_set_cursor(target_win, { line_start + 1, col_start })

							-- Prepare split lines for replacement
							local replace_lines = vim.split(replace_text, "\n", true)

							-- Replace the content with the new text
							vim.api.nvim_buf_set_text(
								context._target_buffer,
								line_start,
								col_start,
								line_end,
								col_end,
								replace_lines
							)

							-- Return focus to chat buffer
							vim.api.nvim_set_current_win(prev_win)
							vim.api.nvim_win_set_buf(prev_win, prev_buf)

							vim.api.nvim_echo(
								{ { "Applied search/replace operation to target file", "Normal" } },
								true,
								{}
							)
							op.applied = true
							replace_op.applied = true
						end
					end

					paired = true
					break
				end
			end
		end

		context._replace_content = nil
	end
	return ""
end

return ReplaceHandler
