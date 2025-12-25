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

local function build_llm_entry(config)
	if not config.provider or not config.api_key or not config.interface then
		error("Provider, API key, and interface are required")
	end

	local llm = LLM:new(config.interface, config.provider, config.api_key, config.options)
	return { name = config.provider, llm = llm }
end

function M.setup(configs)
	if not configs or not configs.models or #configs.models == 0 then
		error("No LLM providers configured")
	end

	stop_active_job()

	state.llms = {}
	for _, conf in ipairs(configs.models) do
		table.insert(state.llms, build_llm_entry(conf))
	end

	local selected = configs.selected_provider
	state.current_llm = nil
	for _, entry in ipairs(state.llms) do
		if selected and entry.name == selected then
			state.current_llm = entry.llm
			break
		end
	end

	if not state.current_llm then
		state.current_llm = state.llms[1].llm
		vim.notify("Using " .. state.llms[1].name .. " as default")
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

	if not name or name == "" then
		vim.notify("Model not found", vim.log.levels.ERROR)
		return
	end

	for _, entry in ipairs(state.llms) do
		if entry.name == name then
			stop_active_job()
			state.current_llm = entry.llm
			vim.notify("Switched to " .. name)
			return
		end
	end

	vim.notify("Model not found", vim.log.levels.ERROR)
end

function M.send_selection_to_chat()
	ensure_setup()

	local selection = Utils.get_visual_selection()
	if not selection or selection == "" then
		return
	end

	local formatted = string.format("```%s\n%s\n```\n", vim.bo.filetype or "text", selection)
	state.chat:focus()
	state.chat:append_text("\n" .. formatted)
end

function M.stop_all_jobs()
	stop_active_job()
end

return M
