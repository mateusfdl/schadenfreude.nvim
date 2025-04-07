local FileHandler = {}
FileHandler.__index = FileHandler

function FileHandler:new()
	return setmetatable({}, self)
end

function FileHandler:handle(prompt)
	local file_snippets = {}
	local files_found = {}

	prompt:gsub("@file:([^%s]+)", function(file_path)
		table.insert(files_found, file_path)
		return ""
	end)

	if #files_found > 0 then
		table.insert(file_snippets, "\n===== FILE CONTEXT BEGINS =====")
		table.insert(file_snippets, "# The following files are provided as context...")
	end

	local cleaned_prompt = prompt:gsub("@file:([^%s]+)", function(file_path)
		local full_path = vim.fn.expand(file_path)

		if file_path:match("%*") then
			local files = vim.fn.globpath(vim.fn.getcwd(), file_path, true, true)
			local contents = {}

			for _, file in ipairs(files) do
				if file ~= "" then
					local f = io.open(file, "r")
					if f then
						table.insert(contents, "\n--- File: " .. file .. " ---")
						table.insert(contents, "# Filetype: " .. get_file_extension(file) or "unknown")
						table.insert(
							contents,
							string.format("```%s\n%s\n```", get_file_extension(file) or "", f:read("*all"))
						)
						table.insert(contents, "--- End of " .. file .. " ---")
						f:close()
					else
						vim.notify("[Error: Could not open file '" .. file .. "']")
					end
				end
			end

			table.insert(file_snippets, table.concat(contents, "\n"))
		else
			if vim.fn.filereadable(full_path) == 0 then
				return ""
			end

			local content = self:_read_file_content(file_path)
			local ext = self:_get_file_extension(file_path) or ""
			table.insert(file_snippets, "\n--- File: " .. file_path .. " ---")
			table.insert(file_snippets, "# Filetype: " .. (ext ~= "" and ext or "unknown"))
			table.insert(file_snippets, string.format("```%s\n%s\n```", ext, content))
			table.insert(file_snippets, "--- End of " .. file_path .. " ---")
		end

		return ""
	end)

	if #file_snippets > 0 then
		table.insert(file_snippets, "\n===== FILE CONTEXT ENDS =====")
		table.insert(file_snippets, "# User Prompt Begins Below...")
	end

	return table.concat(file_snippets, "\n") .. "\n" .. cleaned_prompt
end

function FileHandler:has_command_call(prompt)
	return prompt:match("@file:([^%s]+)") ~= nil
end

function FileHandler:_read_file_content(filepath)
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

function FileHandler:_get_file_extension(filepath)
	return filepath:match("%.([^%.]+)$") or ""
end

return FileHandler
