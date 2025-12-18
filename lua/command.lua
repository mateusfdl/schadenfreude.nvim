local FileHandler = require("commands.file")
local ModelHandler = require("commands.model")

local CommandHandler = {}
CommandHandler.__index = CommandHandler

function CommandHandler:new()
	local instance = {
		handlers = { FileHandler:new() },
		model_handler = ModelHandler:new(),
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

function CommandHandler:parse_model_commands(prompt)
	return self.model_handler:parse_model_commands(prompt)
end

function CommandHandler:has_model_commands(prompt)
	return self.model_handler:has_model_commands(prompt)
end

function CommandHandler:_has_commands(prompt)
	if type(prompt) ~= "string" then
		return false
	end

	local has_file_commands = false
	for match in prompt:gmatch("@([^%s]+)") do
		if not match:match("^model:") then
			has_file_commands = true
			break
		end
	end
	return has_file_commands
end

return CommandHandler
