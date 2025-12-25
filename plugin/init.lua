vim.api.nvim_create_user_command("ModelSwitch", function(opts)
	require("schadenfreude").switch_model(opts.args)
end, {
	nargs = 1,
	complete = function()
		local M = require("schadenfreude")
		return vim.tbl_map(function(llm) return llm.name end, M.llms or {})
	end,
	desc = "Switch the active LLM model",
})

vim.api.nvim_create_user_command("SendToChat", function()
	require("schadenfreude").send_selection_to_chat()
end, {
	desc = "Send visual selection to the Chat buffer",
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function()
		local wo = vim.wo
		wo.foldmethod = "syntax"
		wo.foldenable = true
		wo.conceallevel = 2
		wo.concealcursor = "nc"
		wo.foldlevel = 1
		
		vim.api.nvim_set_hl(0, "Conceal", { bold = true, fg = "#00FF00" })
		vim.api.nvim_set_hl(0, "aiResponseStart", { link = "Conceal" })
	end,
})
