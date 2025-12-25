local FileHandler = require("commands.file")

local CommandHandler = {}
CommandHandler.__index = CommandHandler

function CommandHandler:new()
	return setmetatable({
		file_handler = FileHandler:new(),
	}, self)
end

function CommandHandler:handle(prompt)
	if type(prompt) ~= "string" then
		error("Expected string for prompt, got " .. type(prompt))
	end

	if prompt:match("@file:") then
		return self.file_handler:handle(prompt)
	end

	return prompt
end

return CommandHandler
