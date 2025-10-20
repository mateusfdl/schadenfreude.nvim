local Chat = require("chat")
local LLM = require("llm")
local Command = require("command")
local Utils = require("utils")
local BufferParser = require("buffer_parser")
local ModelBlockManager = require("model_block_manager")

local M = {}

local chat_instance = nil
local current_llm = nil
local active_job = nil
local command_instance = nil
local buffer_parser = nil
local block_manager = nil
local active_jobs = {}
M.llms = {}

function M.setup(configs)
	if type(configs) ~= "table" then
		error("Configs must be a table")
	end

	for _, config in pairs(configs) do
		if type(config) == "table" and config.provider then
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
				break
			end
		end
	elseif #M.llms > 0 and configs.selected_provider == nil then
		vim.api.nvim_echo({ { "Using " .. M.llms[1].name .. " as default", "Comment" } }, true, {})
		current_llm = M.llms[1].llm
	else
		error("No LLM providers configured")
	end

	chat_instance = Chat:new()
	command_instance = Command:new()
	buffer_parser = BufferParser:new()
	block_manager = ModelBlockManager:new()
end

function M.open_chat()
	if not chat_instance then
		error("Please setup the plugin first")
	end

	chat_instance:start()
end

function M.send_message(opts)
	if not current_llm or not chat_instance or not command_instance then
		error("Please setup the plugin first")
	end

	if opts.chat then
		opts.replace = true
	end

	if not command_instance then
		command_instance = Command:new()
	end

	if not buffer_parser then
		buffer_parser = BufferParser:new()
	end

	if not block_manager then
		block_manager = ModelBlockManager:new()
	end

	local prompt
	local history = {}

	if opts.chat and chat_instance.buffer then
		-- Extract conversation history and new user message from buffer
		history = buffer_parser:get_conversation_history(chat_instance.buffer, true)
		local new_message = buffer_parser:extract_new_user_message(chat_instance.buffer)
		if new_message then
			prompt = command_instance:handle(new_message)
		else
			prompt = command_instance:handle(Utils.get_prompt(opts.replace or false))
		end
	else
		-- Use traditional method for non-chat mode
		prompt = command_instance:handle(Utils.get_prompt(opts.replace or false))
	end

	if opts.chat and vim.api.nvim_get_current_buf() ~= chat_instance.buffer then
		chat_instance:focus()
		-- Only append the prompt if we couldn't extract it from buffer
		if not buffer_parser:extract_new_user_message(chat_instance.buffer) then
			chat_instance:append_text(prompt)
		end
	end

	-- Set the main chat buffer for the block manager
	if opts.chat and chat_instance.buffer then
		block_manager:set_main_chat_buffer(chat_instance.buffer)
		block_manager:set_chat_instance(chat_instance)
	end

	-- Check for model commands
	if command_instance:has_model_commands(prompt) then
		M._handle_concurrent_models(prompt, history, opts)
	else
		M._handle_single_model(prompt, history, opts)
	end
end

function M._handle_concurrent_models(prompt, history, opts)
	local model_commands, remaining_prompt = command_instance:parse_model_commands(prompt)
	
	-- Kill any existing jobs
	for job_id, job in pairs(active_jobs) do
		if job and job.shutdown then
			job:shutdown()
		end
	end
	active_jobs = {}

	-- Add remaining prompt to chat if it exists
	if remaining_prompt and remaining_prompt ~= "" then
		if opts.chat then
			chat_instance:append_text("\n" .. remaining_prompt .. "\n")
		end
	end

	-- Execute each model command concurrently
	for _, cmd in ipairs(model_commands) do
		local model_llm = M._find_model_llm(cmd.model)
		if model_llm then
			local block_id = Utils.create_message_id()
			local block = block_manager:create_model_block(cmd.model, block_id, cmd.prompt)
			
			-- Create the callback for this specific block
			local callback = function(content)
				-- Just append content to the specific block
				block_manager:append_to_block(block_id, content)
			end
			
			-- Create completion callback
			local completion_callback = function()
				-- Mark block as complete and add finish marker
				block_manager:complete_block(block_id)
				active_jobs[block_id] = nil
			end
			
			-- Start the generation job with skip_markers option and completion callback
			local job = model_llm:generate(cmd.prompt, callback, history, { 
				skip_markers = true,
				on_complete = completion_callback
			})
			active_jobs[block_id] = job
		else
			vim.api.nvim_echo({ { "Model '" .. cmd.model .. "' not found", "Error" } }, true, {})
		end
	end
end

function M._handle_single_model(prompt, history, opts)
	-- Kill existing job
	if active_job then
		active_job:shutdown()
	end

	if opts.chat then
		chat_instance:append_text("\n")
	end

	active_job = current_llm:generate(prompt, function(content)
		if opts.chat then
			chat_instance:append_text(content)
		end
	end, history)
end

function M._find_model_llm(model_name)
	for _, llm_info in ipairs(M.llms) do
		if llm_info.name == model_name then
			return llm_info.llm
		end
	end
	return nil
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
	if not chat_instance then
		error("Please setup the plugin first")
	end

	local selection = Utils.get_visual_selection()
	if not selection or selection == "" then
		return
	end

	local formatted_selection = "```" .. (vim.bo.filetype or "text") .. "\n" .. selection .. "\n```"
	chat_instance:focus()
	chat_instance:append_text("\n" .. formatted_selection .. "\n")
end

function M.stop_all_jobs()
	-- Stop single model job
	if active_job then
		active_job:shutdown()
		active_job = nil
	end
	
	-- Stop all concurrent model jobs
	for job_id, job in pairs(active_jobs) do
		if job and job.shutdown then
			job:shutdown()
		end
	end
	active_jobs = {}
	
	-- Clean up completed blocks
	if block_manager then
		block_manager:cleanup_completed_blocks()
	end
end

return M
