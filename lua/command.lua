local FileHandler = require("commands.file")

local CommandHandler = {}
CommandHandler.__index = CommandHandler

function CommandHandler:new()
	local instance = {
		handlers = { FileHandler:new() },
	}
	return setmetatable(instance, self)
end

function CommandHandler:handle(prompt)
	if type(prompt) ~= "string" then
		error("Expected string for prompt, got " .. type(prompt))
	end

	if self:_has_commands(prompt) then
		for _, file_handler in pairs(self.handlers) do
			prompt = file_handler:handle(prompt)
		end
	end

	return prompt
end

function CommandHandler:_has_commands(prompt)
	if type(prompt) ~= "string" then
		return false
	end
	return prompt:match("@([^%s]+)") ~= nil
end

return CommandHandler
