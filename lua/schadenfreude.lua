local Chat = require("chat")
local LLM = require("llm")
local Command = require("command")
local Utils = require("utils")

local M = {}

local state = {
	chat = nil,
	command = nil,
	current_llm = nil,
	llms = {},
	active_job = nil,
}

local function stop_active_job()
	if state.active_job then
		if state.active_job.shutdown then
			state.active_job:shutdown()
		elseif state.active_job.kill then
			state.active_job:kill()
		end
	end
	state.active_job = nil
end

local function ensure_setup()
	if not state.chat or not state.command or not state.current_llm then
		error("Please setup the plugin first")
	end
end

local function collect_providers(configs)
	return configs.models
end

local function build_llm_entry(config)
	if type(config) ~= "table" then
		error("LLM config must be a table")
	end

	if not config.provider or not config.api_key then
		error("Provider and API key are required for each config")
	end

	if not config.interface then
		error("Interface is required for each config, please specify either 'openai' or 'anthropic'")
	end

	local llm = LLM:new(config.interface, config.provider, config.api_key, config.options)
	return { name = config.provider, llm = llm }
end

function M.setup(configs)
	if type(configs) ~= "table" then
		error("Configs must be a table")
	end

	stop_active_job()

	local providers = collect_providers(configs)
	if #providers == 0 then
		error("No LLM providers configured")
	end

	state.llms = {}
	state.current_llm = nil

	for _, conf in ipairs(providers) do
		local entry = build_llm_entry(conf)
		table.insert(state.llms, entry)
		if configs.selected_provider and entry.name == configs.selected_provider then
			state.current_llm = entry.llm
		end
	end

	if not state.current_llm then
		state.current_llm = state.llms[1].llm
		if not configs.selected_provider then
			vim.api.nvim_echo({ { "Using " .. state.llms[1].name .. " as default", "Comment" } }, true, {})
		end
	end

	state.chat = Chat:new()
	state.command = Command:new()
	M.llms = state.llms
end

function M.open_chat()
	ensure_setup()
	state.chat:start()
end

function M.send_message(opts)
	ensure_setup()

	opts = opts or {}
	local replace = opts.chat or opts.replace or false
	local prompt = state.command:handle(Utils.get_prompt(replace))

	if opts.chat and (not state.chat.buffer or vim.api.nvim_get_current_buf() ~= state.chat.buffer) then
		state.chat:focus()
		state.chat:append_text(prompt)
	end

	stop_active_job()
	state.chat:append_text("\n")

	state.active_job = state.current_llm:generate(prompt, function(content)
		state.chat:append_text(content)
	end, function()
		state.active_job = nil
	end)
end

function M.switch_model(name)
	ensure_setup()

	if type(name) ~= "string" or name == "" then
		vim.api.nvim_echo({ { "Model not found", "Error" } }, true, {})
		return
	end

	for _, entry in ipairs(state.llms) do
		if entry.name == name then
			stop_active_job()
			state.current_llm = entry.llm
			vim.api.nvim_echo({ { "Switched to " .. name, "Comment" } }, true, {})
			return
		end
	end

	vim.api.nvim_echo({ { "Model not found", "Error" } }, true, {})
end

function M.send_selection_to_chat()
	ensure_setup()

	local selection = Utils.get_visual_selection()
	if not selection or selection == "" then
		return
	end

	local formatted = "```" .. (vim.bo.filetype or "text") .. "\n" .. selection .. "\n```\n"
	state.chat:focus()
	state.chat:append_text("\n" .. formatted)
end

function M.stop_all_jobs()
	if active_job then
		active_job:shutdown()
		active_job = nil
	end

	for job_id, job in pairs(active_jobs) do
		if job and job.shutdown then
			job:shutdown()
		end
	end
	active_jobs = {}

	if block_manager then
		block_manager:cleanup_completed_blocks()
	end
end

return M
