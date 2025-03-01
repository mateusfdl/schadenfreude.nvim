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
