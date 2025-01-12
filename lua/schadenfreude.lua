require("utils")

local M = {}
local Job = require("plenary.job")
local float_buf_message_history = {}
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
		if #float_buf_message_history > 0 then
			vim.list_extend(messages, float_buf_message_history)
		end
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

local function open_floating_buffer()
	if active_buffer_id == nil then
		local buf = vim.api.nvim_create_buf(false, true)
		if not buf then
			return nil
		end
		active_buffer_id = buf
	end

	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")

	local win_width = math.ceil(width * 0.7)
	local win_height = math.ceil(height * 0.7)

	local col = math.ceil((width - win_width) / 2)
	local row = math.ceil((height - win_height) / 2)

	local opts = {
		style = "minimal",
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		border = { "-", "-", "-", "|", "-", "-", "-", "|" },
	}

	vim.api.nvim_open_win(active_buffer_id, true, opts)
	vim.api.nvim_buf_set_option(active_buffer_id, "filetype", "markdown")
	vim.api.nvim_command("au! * <buffer>")

	return active_buffer_id
end

function M.wipe_floating_chat_buffer()
	float_buf_message_history = {}
end

local function open_ai_push_assistant_message(message)
	table.insert(float_buf_message_history, { role = "assistant", content = message })
end

local function open_ai_push_user_message(message)
	table.insert(float_buf_message_history, { role = "user", content = message .. "\n" })
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

function M.openai_write_answer_to_buffer(opt)
	local prompt = get_prompt(opt.replace or false)

	if not opt.vendor then
		print("Please provide a vendor")
	end

	if opt.floating_window and vim.api.nvim_get_current_buf() ~= active_buffer_id then
		open_floating_buffer()
	end

	if active_job_state then
		active_job_state:stop()
	end
	local args = openai_help(M.llm_options[opt.vendor], prompt, opt.floating_window)

	stream_string_to_current_window("\n\n" .. prompt .. "\n\n")
	if opt.floating_window then
		open_ai_push_user_message(prompt)
	end

	active_job_state = make_call(args, function(data)
		local filtered_data = data:match("^data: (.+)$")
		local success, response = pcall(vim.json.decode, filtered_data)
		if success then
			if response.choices and response.choices[1] then
				local content = response.choices[1].delta.content
				stream_string_to_current_window(content)
				if opt.floating_window then
					open_ai_push_assistant_message(content)
				end
			end
		end
	end)
end

return M
