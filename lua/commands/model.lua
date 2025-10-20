local ModelHandler = {}
ModelHandler.__index = ModelHandler

function ModelHandler:new()
	return setmetatable({}, self)
end

function ModelHandler:parse_model_commands(prompt)
	local model_commands = {}
	local remaining_prompt = prompt
	
	-- Pattern to match @model:name "command" or @model:name 'command'
	local pattern = '@model:([%w%-_]+)%s*["\']([^"\']*)["\']'
	
	for model_name, command in prompt:gmatch(pattern) do
		table.insert(model_commands, {
			model = model_name,
			prompt = command,
		})
	end
	
	-- Remove model commands from the original prompt
	remaining_prompt = remaining_prompt:gsub(pattern, "")
	
	-- Clean up extra whitespace
	remaining_prompt = remaining_prompt:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	
	return model_commands, remaining_prompt
end

function ModelHandler:has_model_commands(prompt)
	return prompt:match('@model:([%w%-_]+)%s*["\']([^"\']*)["\']') ~= nil
end

function ModelHandler:validate_model_exists(model_name, available_models)
	for _, model_info in ipairs(available_models) do
		if model_info.name == model_name then
			return true, model_info.llm
		end
	end
	return false, nil
end

function ModelHandler:create_model_prompt(base_context, user_command, history)
	-- Combine the user command with any base context
	local full_prompt = user_command
	if base_context and base_context ~= "" then
		full_prompt = base_context .. "\n\n" .. user_command
	end
	
	return full_prompt
end

return ModelHandler