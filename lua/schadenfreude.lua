local Chat = require("chat")
local LLM = require("llm")
require("utils")

local M = {}

local chat_instance = nil
local current_llm = nil
local active_job = nil
M.llms = {}

function M.setup(configs)
	if type(configs) ~= "table" then
		error("Configs must be a table")
	end

	for _, config in pairs(configs) do
		if type(config) == "table" then
			if not config.provider or not config.api_key then
				error("Provider and API key are required for each config")
			end

			if not config.interface then
				error("Interface is required for each config, please specify either 'openai' or 'anthropic'")
			end

			local llm = LLM:new(config.interface, config.provider, config.api_key, config.options)
			table.insert(M.llms, { name = config.provider, llm = llm })
		end
	end

	if #M.llms > 0 and configs.selected_provider then
		for _, llm in pairs(M.llms) do
			if llm.name == configs.selected_provider then
				current_llm = llm.llm
			end
		end
	elseif #M.llms > 0 and configs.selected_provider == nil then
		vim.api.nvim_echo({ { "Using " .. M.llms[1].name .. " as default", "Comment" } }, true, {})
		current_llm = M.llms[1].llm
	else
		error("No LLM providers configured")
	end

	chat_instance = Chat:new()
end

function M.open_chat()
	if not chat_instance then
		chat_instance = Chat:new()
	end
	chat_instance:start()
end

function M.send_message(opts)
	if not current_llm then
		error("Please setup the plugin first with a provider and API key")
	end

	if opts.chat then
		opts.replace = true
	end

	local prompt = get_prompt(opts.replace or false)
	if has_file_references(prompt) then
		prompt = prepend_file_contents(prompt)
	end

	if opts.chat and vim.api.nvim_get_current_buf() ~= chat_instance.buffer then
		chat_instance:focus()
		chat_instance:append_text(prompt)
	end

	if active_job then
		active_job:shutdown()
	end

	chat_instance:append_text("\n\n")

	active_job = current_llm:generate(prompt, function(content)
		chat_instance:append_text(content)
	end)
end

function M.switch_model(name)
	for _, llm in ipairs(M.llms) do
		if llm.name == name then
			current_llm = llm.llm
			vim.api.nvim_echo({ { "Switched to " .. name, "Comment" } }, true, {})
			return
		end
	end

	vim.api.nvim_echo({ { "Model not found", "Error" } }, true, {})
end

function M.send_selection_to_chat()
	local selection = get_visual_selection()
	if not selection or selection == "" then
		vim.api.nvim_echo({ { "No selection found", "Error" } }, true, {})
		return
	end
	if not chat_instance then
		chat_instance = Chat:new()
	end
	local formatted_selection = "```" .. (vim.bo.filetype or "text") .. "\n" .. selection .. "\n```"
	chat_instance:focus()
	chat_instance:append_text("\n" .. formatted_selection .. "\n")
end

return M
