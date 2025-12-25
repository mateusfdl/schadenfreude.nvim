local Job = require("plenary.job")
local Utils = require("utils")
local Notification = require("notification")

local LLM = {}
LLM.__index = LLM

local DEFAULT_CONTEXT = [[
You are an AI programming assistant integrated into Neovim. Provide concise, actionable code assistance.

Rules:
- When generating code, provide ONLY code without explanations or markdown
- DO NOT use @AI :BEGIN or @AI :FINISH markers - these are added automatically
- Adapt to the user's coding style and skill level
- Focus on practical solutions over lengthy explanations
]]

local INTERFACES = {
	anthropic = {
		system_message_context = DEFAULT_CONTEXT,
	},
	openai = {
		system_message_context = DEFAULT_CONTEXT,
	},
}

local function build_options(interface, options)
	if not INTERFACES[interface] then
		error("Unsupported interface: " .. interface)
	end

	local merged = vim.tbl_deep_extend("force", INTERFACES[interface], options or {})

	if not merged.model then
		error("Missing model for interface: " .. interface)
	end

	if not merged.url then
		error("Missing url for interface: " .. interface)
	end

	return merged
end

function LLM:new(interface, provider, api_key, options)
	local instance = {
		provider = provider,
		api_key = api_key,
		interface = interface,
		options = build_options(interface, options),
		notifier = Notification:new(),
	}

	return setmetatable(instance, self)
end

function LLM:_prepare_payload(prompt, messages)
	local base = {
		model = self.options.model,
		max_tokens = self.options.max_tokens or 101000,
		temperature = self.options.temperature or 0.6,
		stream = true,
	}

	messages = messages or {}
	table.insert(messages, { role = "user", content = prompt })

	if self.interface == "anthropic" then
		base.messages = messages
		base.system = self.options.system_message_context
	else
		base.messages = { { role = "system", content = self.options.system_message_context } }
		vim.list_extend(base.messages, messages)
	end

	return base
end

function LLM:_prepare_headers()
	local headers = { "-H", "Content-Type: application/json" }
	
	if self.interface == "anthropic" then
		vim.list_extend(headers, { "-H", "x-api-key: " .. self.api_key, "-H", "anthropic-version: 2023-06-01" })
	else
		vim.list_extend(headers, { "-H", "Authorization: Bearer " .. self.api_key })
	end

	return headers
end

function LLM:_handle_stdout(data, callback)
	local filtered = data:match("^data: (.+)$")
	if not filtered or filtered == "[DONE]" then
		return
	end

	local ok, response = pcall(vim.json.decode, filtered)
	if not ok then
		return
	end

	local content
	if self.interface == "anthropic" then
		content = response.delta and response.delta.text
	else
		content = response.choices and response.choices[1] and response.choices[1].delta and response.choices[1].delta.content
	end

	if content then
		callback(content)
	end
end

function LLM:generate(prompt, callback, on_complete, messages)
	if not prompt or prompt == "" then
		return
	end

	local response_id = tostring(os.time())
	local payload = self:_prepare_payload(prompt, messages)
	local headers = self:_prepare_headers()

	local args = { "-sS", "-N", "-X", "POST" }
	vim.list_extend(args, headers)
	table.insert(args, "-d")
	table.insert(args, vim.json.encode(payload))
	table.insert(args, self.options.url)

	self.notifier:dispatch_cooking_notification(self.provider)
	callback("\n@AI :BEGIN == ID:" .. response_id .. "\n")

	local job = Job:new({
		command = "curl",
		args = args,
		env = self.options.env,
		on_stdout = function(_, data)
			self:_handle_stdout(data, callback)
		end,
		on_stderr = function(_, data)
			if data and data ~= "" then
				callback("\n" .. data .. "\n")
			end
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				callback("\nRequest failed with exit code " .. code .. "\n")
			end
			callback("\n@AI :FINISH\n")
			self.notifier:stop()
			if on_complete then
				on_complete(code)
			end
		end,
	})

	job:start()
	return job
end

return LLM
