require("utils")
local Chat = require("chat")
local Job = require("plenary.job")

local M = {}

M.float_buf_message_history = {}
local active_job_state = nil
local active_buffer_id = nil

local chat_buffer_context = [[
This session will focus exclusively on topics related to programming, computer science, and engineering.
Provide accurate, concise, and contextually relevant answers.
Avoid unnecessary explanations unless explicitly requested.
The chat supports markdown so use backticks for code snippets surrounding them with ``` and the language.
Prioritize solutions that are simple, efficient, and align with best practices.
Validate code or technical solutions before providing them.
If asked for examples or demonstrations, provide complete and working snippets.
For any ambiguities, clarify with concise follow-up questions.
Avoid casual conversation or off-topic discussions; strictly adhere to the domain focus.
DO NOT TALK AT ALL IF IS NOT ASKED TO
]]

M.llm_options = {
	gpt = {
		url = "https://api.openai.com/v1/chat/completions",
		model = "gpt-4o-mini",
		system_message_context = [[
            You shall replace the code that you are sent, only following the comments.
            Do not talk at all. Only output valid code. Do not provide any backticks that surround the code.
            Never output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them.
            Do not output backticks. 
            Prefer concise and straightforward solutions and always valid code.
            Invalid code is not torelerated and will be you be your responsibility to not provide any invalid code at all.
        ]],
		api_key = "",
	},
	groq = {
		url = "https://api.groq.com/openai/v1/chat/completions",
		model = "llama-3.3-70b-versatile",
		system_message_context = [[
            You shall replace the code that you are sent, only following the comments.
            Do not talk at all. Only output valid code. Do not provide any backticks that surround the code.
            Never output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them.
            Do not output backticks. 
            Prefer concise and straightforward solutions and always valid code.
            Invalid code is not torelerated and will be you be your responsibility to not provide any invalid code at all.
        ]],
		api_key = "",
	},
}

local function setup_gpt_options(opt)
	for k, v in pairs(opt) do
		M.llm_options.gpt[k] = v
	end
end

local function setup_groq_options(opt)
	for k, v in pairs(opt) do
		M.llm_options.groq[k] = v
	end
end

local function openai_help(opt, prompt, is_chating_window)
	local url = opt.url
	local api_key = opt.api_key
	local messages = { { role = "system", content = opt.system_message_context } }

	if is_chating_window then
		messages = { { role = "system", content = chat_buffer_context } }
	end
	table.insert(messages, { role = "user", content = prompt })

	local payload = {
		model = opt.model,
		messages = messages,
		max_tokens = 2048,
		temperature = 0.7,
		stream = true,
	}

	local args = { "-N", "-X", "POST", "-H", "Content-Type: application/json", "-d", vim.json.encode(payload) }

	if api_key then
		table.insert(args, "-H")
		table.insert(args, "Authorization: Bearer " .. api_key)
	end
	table.insert(args, url)

	return args
end

local function make_call(args, data_handler)
	local job = Job:new({
		command = "curl",
		args = args,
		on_stdout = function(_, data)
			data_handler(data)
		end,
		on_stderr = function(_, _) end,
		on_exit = function()
			active_job_state = nil
		end,
	})

	job:start()

	return job
end

function M.setup(opt)
	for k, v in pairs(opt) do
		if k == "gpt" then
			setup_gpt_options(v)
		end

		if k == "groq" then
			setup_groq_options(v)
		end
	end
end

function M.AttachChatToWin()
	active_buffer_id = Chat.start(vim.api.nvim_get_current_win())
end

function M.openai_write_answer_to_buffer(opt)
	if opt.chat then
		opt.replace = true
	end

	local prompt = get_prompt(opt.replace or false)

	if not opt.vendor then
		print("Please provide a vendor")
	end

	if opt.chat and vim.api.nvim_get_current_buf() ~= active_buffer_id then
		if active_buffer_id then
			vim.api.nvim_set_current_buf(active_buffer_id)
		end
	end

	if active_job_state then
		active_job_state:stop()
	end
	local args = openai_help(M.llm_options[opt.vendor], prompt, opt.chat)

	stream_string_to_current_window("\n\n")

	active_job_state = make_call(args, function(data)
		local filtered_data = data:match("^data: (.+)$")
		local success, response = pcall(vim.json.decode, filtered_data)
		if success then
			if response.choices and response.choices[1] then
				local content = response.choices[1].delta.content
				stream_string_to_current_window(content)
			end

			if response.choices[1].finish_reason == "stop" then
				stream_string_to_current_window("\n\n")
			end
		end
	end)
end

return M
