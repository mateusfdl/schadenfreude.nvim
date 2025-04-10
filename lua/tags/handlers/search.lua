local SearchHandler = {}
SearchHandler.__index = SearchHandler

function SearchHandler:new()
	local instance = {
		content = "",
	}
	return setmetatable(instance, self)
end

function SearchHandler:on_tag_start(context)
	context._search_pos = vim.api.nvim_win_get_cursor(0)
	context._search_content = ""
	context._current_search_idx = #(context._operations or {}) + 1
	return ""
end

function SearchHandler:on_content(content, context)
	context._search_content = (context._search_content or "") .. content
	return ""
end

function SearchHandler:on_tag_end(content, context)
	if context._search_content then
		if not context._operations then
			context._operations = {}
		end

		-- Store the search content to be paired with a replace later
		table.insert(context._operations, {
			type = "search",
			content = context._search_content,
			idx = context._current_search_idx,
			applied = false,
		})

		-- Save in context for easy access by replace tag
		context._last_search = context._current_search_idx

		context._search_content = nil
		context._current_search_idx = nil
	end
	return ""
end

return SearchHandler
