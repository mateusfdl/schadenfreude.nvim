local Job = require("plenary.job")

-- Initialize random seed
math.randomseed(os.time())

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
- Be concise yet thorough, using markdown for clarity (e.g., bullet points, code blocks).
- Adopt a supportive, expert tone—confident but not condescending.
- Prioritize actionable advice over generic responses.

Context Awareness:
- Leverage the full context of the user's codebase, file type, and Neovim environment to provide highly relevant suggestions.
- Adapt to the user's skill level, inferred from their code and questions, balancing simplicity and depth as needed.
- Everthing inside the block @AI :BEGIN @AI :FINISH is your own previous responses, USE IT AS CONTEXT ASSISTANT, ITS YOUR PREVIOUS RESPONSES, REMEMBER THAT

Constraints:
- Avoid modifying the user's code unless explicitly requested.
- Do not overwhelm with excessive suggestions—focus on high-impact improvements.
- Respect the user's coding style unless it conflicts with functionality or best practices.
]]
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
		debug = options and options.debug or false,
		debug_log_file = options and options.debug_log_file or vim.fn.stdpath("data") .. "/schadenfreude_debug.log",
	}
	return setmetatable(instance, self)
end

function LLM:_prepare_payload(prompt)
	local messages = {}

	table.insert(messages, {
		role = "user",
		content = prompt,
	})

	if self.interface == "anthropic" then
		return {
			model = self.options.model,
			messages = messages,
			system = self.options.system_message_context,
			max_tokens = 2048,
			temperature = 0.6,
			stream = true,
		}
	else
		table.insert(messages, {
			role = "system",
			content = self.options.system_message_context,
		})

		return {
			model = self.options.model,
			messages = messages,
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

	if self.debug then
		local log_content = "Model: " .. self.provider .. " (" .. self.interface .. ")\n"
		log_content = log_content .. "System context:\n" .. self.options.system_message_context .. "\n\n"
		log_content = log_content .. "User prompt:\n" .. prompt .. "\n\n"
		log_content = log_content .. "Full payload:\n" .. vim.inspect(payload)

		local success = log_to_file(log_content, self.debug_log_file)
		if success then
			vim.api.nvim_echo({ { "Debug: Logged request to " .. self.debug_log_file, "Comment" } }, true, {})
		end
	end

	local args = vim.list_extend({ "-N", "-X", "POST" }, headers)

	table.insert(args, "-d")
	table.insert(args, vim.json.encode(payload))
	table.insert(args, self.options.url)

	local names = {"jhonny", "pascal", "haskell", "pneumonia", "rust", "erlang", "ruby", "lisp", "lua"}
	local name = names[math.random(1, #names)]
	local uid = ""
	for i = 1, 10 do
		uid = uid .. math.random(0, 9)
	end
	local response_id = name .. "-" .. uid
	callback("\n@AI :BEGIN == ID:" .. response_id .. "\n")
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
		on_stderr = function(err, data)
			vim.schedule(function()
				print("Error: " .. vim.inspect(err, data))
			end)
		end,
		on_exit = function(j, return_val)
			callback("\n@AI :FINISH\n")
		end,
	}):start()
end

function LLM:clone()
	local cloned_options = vim.tbl_deep_extend("force", {}, self.options)
	cloned_options.debug = self.debug
	cloned_options.debug_log_file = self.debug_log_file

	return LLM:new(self.interface, self.provider, self.api_key, cloned_options)
end

function LLM:set_new_context(context)
	self.options.system_message_context = context
end

return LLM
