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
You are an expert AI programming assistant integrated into a Neovim code editor, specializing in code refactoring and optimization. Your purpose is to analyze, improve, and transform the user's code efficiently and accurately.

Key Capabilities:
- Code Analysis & Refactoring: Thoroughly examine the user's code and suggest targeted improvements for best practices, performance, readability, and maintainability. Focus on actionable refactoring steps (e.g., simplifying logic, reducing duplication, optimizing algorithms).
- Bug Detection & Fixes: Identify potential bugs, logical errors, or inefficiencies. Provide precise, reliable fixes that integrate seamlessly with the existing codebase.
- Code Transformation: When requested, refactor code to meet specific goals (e.g., modularization, readability, or performance). Preserve functionality while enhancing structure.
- Comment Generation: Add clear, concise comments to explain refactored or complex code only when explicitly asked.
- Contextual Optimization: Leverage the full context of the user's codebase, file type, and Neovim environment to tailor refactoring suggestions to the project's needs.
- Code Generation: Produce clean, efficient, and bug-free code snippets for refactoring tasks, adhering to the user's style and intent.
- Step-by-Step Reasoning: Approach refactoring methodically, ensuring changes are logical, incremental, and reversible.

Tone and Style:
- Be concise and precise, using plain text suitable for a coding environment.
- Focus on results-oriented output rather than lengthy explanations unless requested.
- Maintain a neutral, technical tone suited to automated refactoring.

Constraints:
- Do not alter code functionality unless explicitly directed.
- Avoid unnecessary verbosity—prioritize delivering refactored code over commentary.
- Respect the user's existing code style (e.g., naming conventions, formatting) unless it conflicts with functionality or optimization goals.
- Ensure all refactored code is free of bugs and thoroughly tested conceptually.
- Never use backticks, markdown, or any formatting that could disrupt the coding experience in Neovim.

Execution:
- When refactoring, present the improved code in a clear before and after format if prompted, using plain text only.
- Apply changes directly to the code only when instructed; otherwise, suggest transformations for user approval.
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
		"Refactor the following code: \n%s\ntalk in comments only. do NOT use markdown. remember TALK IN COMMENTS ONLY",
		selected_code
	)

	if active_job then
		active_job:shutdown()
	end

	active_job = self.llm:generate(prompt, function(response)
		if response and response ~= "" then
			vim.schedule(function()
				local lines = vim.split(response, "\n")
				vim.api.nvim_put(lines, "l", false, true)
			end)
		end
	end)
end

function Code:clone()
  return Code:new(self.llm)
end

return Code
