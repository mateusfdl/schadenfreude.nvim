--- @module vim.utils

--- @class vim
--- @field api vim.api
--- @field fn vim.fn
--- @field cmd vim.cmd
--- @field feedkeys vim.api.nvim_feedkeys
--- @field termcodes vim.api.nvim_replace_termcodes

local api = vim.api
local fn = vim.fn
local cmd = vim.cmd
local feedkeys = api.nvim_feedkeys
local termcodes = api.nvim_replace_termcodes

--- @return string # A single string containing all lines (truncated at the cursor) joined by "\n".
function get_lines_until_cursor()
	local cursor = api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local col = cursor[2]

	local lines = api.nvim_buf_get_lines(0, 0, row + 1, false)

	if #lines > 0 then
		local last_line = lines[#lines]
		lines[#lines] = string.sub(last_line, 1, col)
	end

	return table.concat(lines, "\n")
end

--- @return string # The text of the visual selection, or an empty string if no selection is found.
function get_visual_selection()
	local start_pos = fn.getpos("'<")
	local end_pos = fn.getpos("'>")

	local start_line = start_pos[2]
	local start_col = start_pos[3]
	local end_line = end_pos[2]
	local end_col = end_pos[3]

	if start_line == 0 or end_line == 0 or start_line > end_line then
		return ""
	end

	local lines = api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	if #lines == 0 then
		return ""
	end

	if #lines == 1 then
		return string.sub(lines[1], start_col, end_col)
	end

	local first_line = string.sub(lines[1], start_col, -1)
	local last_line = string.sub(lines[#lines], 1, end_col)
	local middle = {}

	for i = 2, (#lines - 1) do
		table.insert(middle, lines[i])
	end

	local selection = {}
	table.insert(selection, first_line)
	vim.list_extend(selection, middle)
	table.insert(selection, last_line)

	return table.concat(selection, "\n")
end

--- @param replace boolean # Whether to replace the visual selection with the returned text.
--- @return string # The determined prompt text (either visual selection or lines until cursor).
function get_prompt(replace)
	local visual_lines = get_visual_selection()
	if visual_lines and #visual_lines > 0 then
		if not replace then
			feedkeys(termcodes("<Esc>", false, true, true), "nx", false)
		end
		return table.concat(vim.split(visual_lines, "\n"), "\n")
	end

	return get_lines_until_cursor()
end

--- @param str string|nil # The string to stream into the "Chat" buffer. If nil, nothing happens.
function stream_string_to_chat_buffer(str)
	if not str then
		return
	end

	vim.schedule(function()
		local chat_bufnr = fn.bufnr("Chat")
		if chat_bufnr == -1 then
			-- Create a new buffer named "Chat" if it doesn't exist
			chat_bufnr = api.nvim_create_buf(true, true)
			api.nvim_buf_set_name(chat_bufnr, "Chat")
			api.nvim_set_current_buf(chat_bufnr)
		else
			-- Otherwise, just switch to the existing "Chat" buffer
			api.nvim_set_current_buf(chat_bufnr)
		end

		local lines = vim.split(str, "\n", { plain = true })
		cmd("undojoin")
		api.nvim_put(lines, "c", true, true)
	end)
end

--- @param str string|nil # The string to handle and potentially send to "Chat".
function handle_chat_or_buffer(str)
	local current_buf = api.nvim_get_current_buf()
	if api.nvim_buf_get_name(current_buf) == "Chat" then
		stream_string_to_chat_buffer(str)
	else
		stream_string_to_chat_buffer("")
		stream_string_to_chat_buffer(str)
	end
end

--- @param str string|nil # The file path to read from.
--- @return string # The file content or an error message if the file could not be opened.
function read_file_content(filepath)
	local cwd = vim.fn.getcwd()
	local full_path

	if filepath:sub(1, 1) == "/" then
		full_path = filepath
	elseif filepath:sub(1, 2) == "~/" then
		full_path = os.getenv("HOME") .. filepath:sub(2)
	elseif filepath:sub(1, 2) == "./" then
		full_path = cwd .. filepath:sub(2)
	else
		full_path = cwd .. "/" .. filepath
	end
	local f = io.open(full_path, "r")
	if not f then
		return ("[Error: Could not open file '%s']"):format(filepath)
	end

	local content = f:read("*all")
	f:close()
	return content
end

--- @param filepath string|nil # The filepath to extract the extension from.
--- @return string # The file extension or an empty string if no extension is found.
function get_file_extension(filepath)
	return filepath:match("%.([^%.]+)$") or ""
end

--- Prepends file contents to the prompt with enhanced context for better AI understanding
--- @param prompt string # The original prompt text provided by the user
--- @return string # The modified prompt with file contents prepended and contextual instructions
function prepend_file_contents(prompt)
	local file_snippets = {}
	local files_found = {}

	prompt:gsub("!([^%s]+)", function(file_path)
		table.insert(files_found, file_path)
		return ""
	end)

	if #files_found > 0 then
		table.insert(file_snippets, "\n===== FILE CONTEXT BEGINS =====")
		table.insert(file_snippets, "# The following files are provided as context for your response.")
		table.insert(file_snippets, "# Use these contents to inform your answer, focusing on the user's prompt below.")
		table.insert(file_snippets, "# Each file is marked with its path and content type for clarity.")
	end

	local cleaned_prompt = prompt:gsub("!([^%s]+)", function(file_path)
		local content = read_file_content(file_path)
		local ext = get_file_extension(file_path) or ""

		table.insert(file_snippets, "\n--- File: " .. file_path .. " ---")
		table.insert(file_snippets, "# Filetype: " .. (ext ~= "" and ext or "unknown"))

		if ext ~= "" then
			table.insert(file_snippets, string.format("```%s\n%s\n```", ext, content))
		else
			table.insert(file_snippets, string.format("```\n%s\n```", content))
		end

		table.insert(file_snippets, "--- End of " .. file_path .. " ---")
		return ""
	end)

	if #file_snippets > 0 then
		table.insert(file_snippets, "\n===== FILE CONTEXT ENDS =====")
		table.insert(file_snippets, "# User Prompt Begins Below - Apply the file context as needed:")
	end

	return table.concat(file_snippets, "\n") .. "\n" .. cleaned_prompt
end

--- @param prompt string # The prompt text to check for file references
--- @return boolean # Returns true if the prompt contains file references (starting with !), false otherwise
function has_file_references(prompt)
	return prompt:match("!([^%s]+)") ~= nil
end
