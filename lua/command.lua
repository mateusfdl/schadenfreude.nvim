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
	if self:_has_commands_references(prompt) then
		for _, file_handler in pairs(self.handlers) do
			prompt = file_handler:handle(prompt)
		end
	end

	return prompt
end

function CommandHandler:_has_commands_references(prompt)
	return prompt:match("@([^%s]+)") ~= nil
end

return CommandHandler
