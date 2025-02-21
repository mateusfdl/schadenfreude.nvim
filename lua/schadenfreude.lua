local Chat = require("chat")
local LLM = require("llm")
require("utils")

local M = {}

local chat_instance = nil
local current_llm = nil
local active_job = nil

function M.setup(config)
	if not config.provider or not config.api_key then
		error("Provider and API key are required")
	end

	current_llm = LLM:new(config.provider, config.api_key, config.options)
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

return M
