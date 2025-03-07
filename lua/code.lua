local LLM = require("llm")
require("utils")

local Code = {}
Code.__index = Code

local active_job = nil

function Code:new(llm)
	if not llm then
		error("Missing LLM instance")
	end

	local cloned_llm = llm:clone()

	local system_prompt = [[
You are an AI programming assistant integrated into a code editor. Your purpose is to help the user with programming tasks as they write code.
Key capabilities:
- Thoroughly analyze the user's code and provide insightful suggestions for improvements related to best practices, performance, readability, and maintainability. Explain your reasoning.
- Answer coding questions in detail, using examples from the user's own code when relevant. Break down complex topics step- Spot potential bugs and logical errors. Alert the user and suggest fixes.
- Upon request, add helpful comments explaining complex or unclear code.
- Suggest relevant documentation, StackOverflow answers, and other resources related to the user's code and questions.
- Engage in back-and-forth conversations to understand the user's intent and provide the most helpful information.
- Keep concise and use markdown.
- When asked to create code, only generate the code. No bugs.
- Think step by step
]]
	cloned_llm:set_new_context(system_prompt)

	local instance = {
		llm = cloned_llm,
	}
	return setmetatable(instance, self)
end

function Code:refactor_code()
	if not self.llm then
		error("Please setup the plugin first with a provider and API key")
	end

	local selected_code = get_visual_selection()
	if not selected_code or selected_code == "" then
		print("No code selected for refactoring.")
		return
	end
	vim.api.nvim_command("normal! d")
	vim.api.nvim_command("normal! k")

	local prompt = string.format(
		"Refactor the following code: ",
		selected_code,
		"\ntalk in comments only. do NOT use markdown. remember TALK IN COMMENTS ONLY"
	)

	if active_job then
		active_job:shutdown()
	end

	local lines = vim.split(prompt, "\n")
	vim.api.nvim_put(lines, "l", false, true)
	vim.api.nvim_put(vim.split(vim.inspect(self.llm), "\n"), "", false, true)
	-- active_job = self.llm:generate(prompt, function(response)
	-- 	if response and response ~= "" then
	-- 		vim.schedule(function()
	-- 			local lines = vim.split(response, "\n")
	-- 		end)
	-- 	end
	-- end)
end

return Code
