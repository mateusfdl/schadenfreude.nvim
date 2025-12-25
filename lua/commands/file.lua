local FileHandler = {}
FileHandler.__index = FileHandler

function FileHandler:new()
	return setmetatable({}, self)
end

function FileHandler:handle(prompt)
	local file_snippets = {}
	local cleaned_prompt = prompt:gsub("@file:([^%s]+)", function(file_path)
		local content = self:_read_file_content(file_path)
		local ext = self:_get_file_extension(file_path) or ""
		
		table.insert(file_snippets, string.format("--- File: %s ---", file_path))
		table.insert(file_snippets, string.format("```%s\n%s\n```", ext, content))
		return ""
	end)

	if #file_snippets > 0 then
		return table.concat(file_snippets, "\n") .. "\n" .. cleaned_prompt
	end

	return cleaned_prompt
end

function FileHandler:_read_file_content(filepath)
	local full_path = vim.fn.expand(filepath)
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
