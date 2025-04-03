vim.api.nvim_create_user_command("ModelSwitch", function(opts)
	local M = require("schadenfreude")
	M.switch_model(opts.args)
end, {
	nargs = 1,
	complete = function(_, _, _)
		local M = require("schadenfreude")
		return vim.tbl_map(function(llm)
			return llm.name
		end, M.llms or {})
	end,
	desc = "Switch the active LLM model",
})

vim.api.nvim_create_user_command("SendToChat", function()
	local M = require("schadenfreude")
	M.send_selection_to_chat()
end, {
	desc = "Send visual selection to the Chat buffer",
})

vim.api.nvim_create_user_command("RefactorCode", function()
	local M = require("schadenfreude")
	M.refactor_code()
end, {
	desc = "Refactor visually selected code in current buffer",
	range = true,
})

local function setup_ai_response_highlighting()
	vim.wo.foldmethod = "syntax"
	vim.wo.foldenable = true
	vim.wo.conceallevel = 2
	vim.wo.concealcursor = "nc"
	vim.wo.foldlevel = 1
	vim.api.nvim_set_hl(0, "Conceal", { bold = true, fg = "#00FF00" })
	vim.api.nvim_set_hl(0, "aiResponseStart", { link = "Conceal" })
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = setup_ai_response_highlighting,
})
