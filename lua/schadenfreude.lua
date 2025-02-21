local Chat = require("chat")
local LLM = require("llm")
require("utils")

local M = {}

local chat_instance = nil
local current_llm = nil
local active_job = nil
local llms = {}

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
			table.insert(llms, { name = config.provider, llm = llm })
		end
	end

	if #llms > 0 and configs.selected_provider then
		for _, llm in pairs(llms) do
			if llm.name == configs.selected_provider then
				current_llm = llm.llm
			end
		end
	elseif #llms > 0 and configs.selected_provider == nil then
		vim.api.nvim_echo({ { "Using " .. llms[1].name .. " as default", "Comment" } }, true, {})
		current_llm = llms[1].llm
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
	prompt = prepend_file_contents(prompt)

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

function M.select_model()
	if #llms == 0 then
		vim.api.nvim_echo({ { "No LLM providers configured", "Error" } }, true, {})
		return
	end

	local model_names = {}
	for _, llm in ipairs(llms) do
		table.insert(model_names, llm.name)
	end

	local telescope = require("telescope")
	if not telescope then
		vim.api.nvim_echo(
			{ { "Telescope is not available. Please ensure it’s installed and loaded.", "Error" } },
			true,
			{}
		)
		return
	end

	local actions = require("telescope.actions")
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local config = require("telescope.config")
	local action_state = require("telescope.actions.state")
	pickers
		.new({}, {
			prompt_title = "Select LLM Model",
			finder = finders.new_table({
				results = model_names,
			}),
			sorter = config.values.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", function()
					local selection = action_state.get_selected_entry()
					if selection then
						for _, llm in ipairs(llms) do
							if llm.name == selection.value then
								current_llm = llm.llm
								break
							end
						end
						vim.api.nvim_echo({ { "Selected model: " .. selection.value, "Comment" } }, true, {})
					end
					actions.close(prompt_bufnr)
				end)
				return true
			end,
		})
		:find()
end

return M
