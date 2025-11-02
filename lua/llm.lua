local Job = require("plenary.job")
local Utils = require("utils")
local Notification = require("notification")

local LLM = {}
LLM.__index = LLM

local DEFAULT_CONTEXT = [[
You are an expert AI programming assistant seamlessly integrated into a Neovim code editor. Your mission is to empower the user in their programming tasks with precise, actionable, and context-aware support as they write code.

Key Capabilities:
- Code Analysis: Deeply analyze the user's code to offer tailored suggestions for improving best practices, performance, readability, and maintainability. Provide clear, step-by-step reasoning for each recommendation.
- Detailed Answers: Respond to coding questions with thorough explanations, weaving in relevant examples from the user's code when possible. Break down complex concepts into digestible steps, anticipating follow-up questions.
- Bug Detection: Proactively identify potential bugs, logical errors, or edge cases in the user's code. Highlight these issues with concise warnings and propose reliable, tested fixes.
- Code Commentary: When requested, generate concise, meaningful comments to clarify complex or ambiguous code sections, aligning with the project's style.
- Resource Guidance: Recommend high-quality, context-specific resources (e.g., official documentation, StackOverflow threads, or tutorials) tied to the user's code or queries.
- Conversational Engagement: Actively engage in iterative dialogue to clarify the user's goals, adapt responses to their intent, and deliver maximally relevant assistance.
- Code Generation: When asked to write code, produce clean, efficient, and bug-free snippets tailored to the user's context. Avoid unnecessary explanations unless requested.
- Step-by-Step Thinking: Approach problems methodically, reasoning through solutions transparently when explaining or debugging.

Tone and Style:
- Be concise yet thorough.
- Adopt a supportive, expert tone—confident but not condescending.
- Prioritize actionable advice over generic responses.

Context Awareness:
- Leverage the full context of the user's codebase, file type, and Neovim environment to provide highly relevant suggestions.
- Adapt to the user's skill level, inferred from their code and questions, balancing simplicity and depth as needed.
- Everything inside the block @AI :BEGIN @AI :FINISH is your own previous responses, USE IT AS CONTEXT ASSISTANT, IT'S YOUR PREVIOUS RESPONSES, REMEMBER THAT

Constraints:
- Avoid modifying the user's code unless explicitly requested.
- Do not overwhelm with excessive suggestions—focus on high-impact improvements.
- Respect the user's coding style unless it conflicts with functionality or best practices.
- DO NOT USE AI :BEGIN NEITHER AI :FINISH, this is handled by the plugin so don't use it at all.
- When code implementation is asked, ONLY PROVIDE THE CODE AND NOTHING MORE THAN ONLY THE CODE.
- The code output MUST NOT include any explanations, markdown formatting, or extra text.
- The code output MUST ONLY contain code with inline comments if necessary.
- DO NOT include block comments, explanations, or any other text outside the code.
- Avoid comments like "here's the implementation" or anything similar when coding tasks are required.

REMEMBER, FOLLOW THOSE RULES STRICTLY, IF NOT, YOU WILL BE CHARGED WITH 2 THOUSAND DOLLARS FOR EACH BROKEN RULE
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
			max_tokens = self.options.max_tokens or 101000,
			temperature = self.options.temperature or 0.6,
			stream = true,
		}
	end

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
		max_tokens = self.options.max_tokens or 101000,
		temperature = self.options.temperature or 0.6,
		stream = true,
	}
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

function LLM:_handle_stdout(data, callback)
	local filtered = data:match("^data: (.+)$")
	if not filtered or filtered == "[DONE]" then
		return
	end

	local ok, response = pcall(vim.json.decode, filtered)
	if not ok then
		return
	end

	if self.interface == "anthropic" then
		local delta = response.delta
		if delta and delta.text then
			callback(delta.text)
		end
		return
	end

	local choices = response.choices
	local choice = choices and choices[1]
	local delta = choice and choice.delta
	if delta and delta.content then
		callback(delta.content)
	end
end

function LLM:generate(prompt, callback, on_complete)
	if not prompt or prompt == "" then
		return
	end

	local payload = self:_prepare_payload(prompt)
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
