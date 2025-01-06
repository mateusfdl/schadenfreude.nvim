local M = {}
local Job = require("plenary.job")
local active_job_state = nil

M.llm_options = {
	gpt = {
		url = "https://api.openai.com/v1/chat/completions",
		model = "gpt-4o-mini",
		system_message_context = "You should replace the code that you are sent, in case is sent code, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Do not output backticks, any questions asked that is not code related shall be answered straight to the topic, once more, no provide any backticks or nothing that can break the experience",
		api_key = "",
	},
	groq = {
		url = "https://api.groq.com/openai/v1/chat/completions",
		model = "llama-3.3-70b-versatile",
		system_message_context = "in case is sent code, you should replace the code, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Do not output backticks, any questions asked that is not code related shall be answered",
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

function M.get_lines_until_cursor()
	local current_buffer = vim.api.nvim_get_current_buf()
	local current_window = vim.api.nvim_get_current_win()
	local cursor_position = vim.api.nvim_win_get_cursor(current_window)
	local row = cursor_position[1]

	local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, row, true)

	return table.concat(lines, "\n")
end

function M.get_visual_selection()
	local _, srow, scol = unpack(vim.fn.getpos("v"))
	local _, erow, ecol = unpack(vim.fn.getpos("."))

	if vim.fn.mode() == "V" then
		if srow > erow then
			return vim.api.nvim_buf_get_lines(0, erow - 1, srow, true)
		else
			return vim.api.nvim_buf_get_lines(0, srow - 1, erow, true)
		end
	end

	if vim.fn.mode() == "v" then
		if srow < erow or (srow == erow and scol <= ecol) then
			return vim.api.nvim_buf_get_text(0, srow - 1, scol - 1, erow - 1, ecol, {})
		else
			return vim.api.nvim_buf_get_text(0, erow - 1, ecol - 1, srow - 1, scol, {})
		end
	end

	if vim.fn.mode() == "\22" then
		local lines = {}
		if srow > erow then
			srow, erow = erow, srow
		end
		if scol > ecol then
			scol, ecol = ecol, scol
		end
		for i = srow, erow do
			table.insert(
				lines,
				vim.api.nvim_buf_get_text(0, i - 1, math.min(scol - 1, ecol), i - 1, math.max(scol - 1, ecol), {})[1]
			)
		end
		return lines
	end
end

local function get_prompt(opts)
	local replace = opts.replace
	local visual_lines = M.get_visual_selection()
	local prompt = ""

	if visual_lines then
		prompt = table.concat(visual_lines, "\n")
		if replace then
			vim.api.nvim_command("normal! d")
			vim.api.nvim_command("normal! k")
		else
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", false, true, true), "nx", false)
		end
	else
		prompt = M.get_lines_until_cursor()
	end

	return prompt
end

local function openai_help(opt, prompt)
	local url = opt.url
	local api_key = opt.api_key

	local payload = {
		model = opt.model,
		messages = {
			{ role = "system", content = opt.system_message_context },
			{ role = "user", content = prompt },
		},
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
	local buf = vim.api.nvim_create_buf(false, true)
	if not buf then
		return nil
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

	vim.api.nvim_open_win(buf, true, opts)

	return buf
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


M.get_text_visual_selection = function(replace)
	return get_prompt({ replace = replace })
end

M.setup = function(opt)
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
	local prompt = M.get_text_visual_selection(opt.replace or false)

  if not opt.vendor then
    print("Please provide a vendor")
  end

	local args = openai_help(M.llm_options[opt.vendor], prompt)

	if opt.floating_window then
		open_floating_buffer()
	end

	if active_job_state then
		active_job_state:stop()
	end

	active_job_state = make_call(args, function(data)
		local filtered_data = data:match("^data: (.+)$")
		local success, response = pcall(vim.json.decode, filtered_data)
		if success then
			if response.choices and response.choices[1] then
				M.stream_string_to_current_window(response.choices[1].delta.content)
			end
		end
	end)
end

function M.stream_string_to_current_window(str)
	vim.schedule(function()
		local current_window = vim.api.nvim_get_current_win()
		local cursor_position = vim.api.nvim_win_get_cursor(current_window)
		local row, col = cursor_position[1], cursor_position[2]

		if not str then
			return
		end
		local lines = vim.split(str, "\n")

		vim.cmd("undojoin")
		vim.api.nvim_put(lines, "c", true, true)

		local num_lines = #lines
		local last_line_length = #lines[num_lines]
		vim.api.nvim_win_set_cursor(current_window, { row + num_lines - 1, col + last_line_length })
	end)
end

return M
