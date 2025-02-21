local Job = require("plenary.job")

local LLM = {}
LLM.__index = LLM

local DEFAULT_CONTEXT = [[You're a programming assistant focused on providing clear, accurate solutions.
- Give direct, practical answers focused on code
- Include complete, working examples when relevant
- Point out potential issues or gotchas
- Ask for clarification if requirements are unclear]]

local INTERFACES = {
	anthropic = {
		system_message_context = DEFAULT_CONTEXT,
	},
	openai = {
		system_message_context = DEFAULT_CONTEXT,
	},
}

function LLM:new(interface, provider, api_key, options)
	if not INTERFACES[interface] then
		error("Unsupported interface: " .. interface)
	end

	local instance = {
		provider = provider,
		api_key = api_key,
		interface = interface,
		options = vim.tbl_deep_extend("force", INTERFACES[interface], options or {}),
	}
	return setmetatable(instance, self)
end

function LLM:_prepare_payload(prompt)
	if self.interface == "anthropic" then
		return {
			model = self.options.model,
			messages = {
				{
					role = "user",
					content = prompt,
				},
			},
			system = self.options.system_message_context,
			max_tokens = 2048,
			temperature = 0.6,
			stream = true,
		}
	else
		return {
			model = self.options.model,
			messages = {
				{
					role = "system",
					content = self.options.system_message_context,
				},
				{
					role = "user",
					content = prompt,
				},
			},
			max_tokens = 2048,
			temperature = 0.6,
			stream = true,
		}
	end
end

function LLM:_prepare_headers()
	local headers = {
		"-H",
		"Content-Type: application/json",
	}

	if self.interface == "anthropic" then
		table.insert(headers, "-H")
		table.insert(headers, "x-api-key: " .. self.api_key)
		table.insert(headers, "-H")
		table.insert(headers, "anthropic-version: 2023-06-01")
	else
		table.insert(headers, "-H")
		table.insert(headers, "Authorization: Bearer " .. self.api_key)
	end

	return headers
end

function LLM:generate(prompt, callback)
	local payload = self:_prepare_payload(prompt)
	local headers = self:_prepare_headers()

	local args = vim.list_extend({ "-N", "-X", "POST" }, headers)

	table.insert(args, "-d")
	table.insert(args, vim.json.encode(payload))
	table.insert(args, self.options.url)

	return Job:new({
		command = "curl",
		args = args,
		on_stdout = function(_, data)
			local filtered_data = data:match("^data: (.+)$")
			if not filtered_data then
				return
			end

			local success, response = pcall(vim.json.decode, filtered_data)
			if not success then
				return
			end

			if self.interface == "anthropic" then
				if response.delta and response.delta.text then
					callback(response.delta.text)
				end
			else
				if response.choices and response.choices[1] and response.choices[1].delta.content then
					callback(response.choices[1].delta.content)
				end
			end
		end,
		on_stderr = function(_, data)
			vim.schedule(function()
				print("Error: " .. vim.inspect(data))
			end)
		end,
	}):start()
end

return LLM
