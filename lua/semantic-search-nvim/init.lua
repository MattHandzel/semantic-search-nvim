local M = {}

M.config = {
	threshold = 0.6,
	-- other default options
}

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local curl = require("plenary.curl")

-- Helper functions
local function filter(tbl, predicate)
	local result = {}
	for _, v in ipairs(tbl) do
		if predicate(v) then
			table.insert(result, v)
		end
	end
	return result
end

local function get_buffer_content()
	return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

-- Configuration handling
local function save_config(key, value)
	local config_path = vim.fn.stdpath("data") .. "/semantic_search_config.json"
	local current_config = {}

	local file = io.open(config_path, "r")
	if file then
		current_config = vim.fn.json_decode(file:read("*all")) or {}
		file:close()
	end

	current_config[key] = value

	file = io.open(config_path, "w")
	if file then
		file:write(vim.fn.json_encode(current_config))
		file:close()
	end
end

local function load_config()
	local config_path = vim.fn.stdpath("data") .. "/semantic_search_config.json"
	local file = io.open(config_path, "r")
	if file then
		local content = file:read("*all")
		file:close()
		return vim.fn.json_decode(content) or {}
	end
	return {}
end

-- Server communication
local function query_server(payload)
	local response = curl.post("http://127.0.0.1:5000/query", {
		headers = { ["Content-Type"] = "application/json" },
		body = vim.fn.json_encode(payload),
		timeout = 30000,
	})
	return vim.json.decode(response.body)
end

-- Popup management
local function show_popup(results)
	local items = {}
	for _, result in ipairs(results) do
		table.insert(items, {
			title = result.title,
			content = result.content,
			similarity = result.similarity,
			selected = false,
		})
	end

	local popup = Popup({
		enter = true,
		focusable = true,
		border = { style = "rounded" },
		position = "50%",
		size = { width = "80%", height = "60%" },
		buf_options = { modifiable = true, readonly = false },
		win_options = { winblend = 10 },
	})

	local function update_display()
		local lines = {}
		for i, item in ipairs(items) do
			local check = item.selected and "✓" or " "
			table.insert(lines, string.format("%d. [%s] [[%s]] (%.2f)", i, check, item.title, item.similarity))
		end
		vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
	end

	local function select_item()
		local line = vim.api.nvim_win_get_cursor(popup.winid)[1]
		if line >= 1 and line <= #items then
			items[line].selected = not items[line].selected
			update_display()
		end
	end

	local function toggle_all()
		local any_unselected = false
		for _, item in ipairs(items) do
			if not item.selected then
				any_unselected = true
				break
			end
		end

		local new_state = any_unselected
		for _, item in ipairs(items) do
			item.selected = new_state
		end
		update_display()
	end

	-- Set keymaps
	vim.keymap.set("n", "<CR>", select_item, { noremap = true, silent = true, buffer = popup.bufnr })
	vim.keymap.set("n", "<C-a>", toggle_all, { noremap = true, silent = true, buffer = popup.bufnr })
	vim.keymap.set("n", "q", function()
		popup:unmount()
	end, { noremap = true, silent = true, buffer = popup.bufnr })

	popup:on(event.BufLeave, function()
		local selected = filter(items, function(item)
			return item.selected
		end)
		if #selected > 0 then
			local clipboard = table.concat(
				vim.tbl_map(function(item)
					return "[[" .. item.title .. "]]"
				end, selected),
				"\n"
			)
			vim.fn.setreg("+", clipboard)
			vim.notify(string.format("Copied %d items to clipboard", #selected))
		end
		popup:unmount()
	end)

	update_display()
	popup:mount()
end

-- Main functionality
function M.semantic_search()
	local payload = {
		query = get_buffer_content(),
		threshold = M.config.threshold,
	}

	local response = query_server(payload)
	if response and response.results then
		show_popup(response.results)
	else
		vim.notify("No results found!", vim.log.levels.WARN)
	end
end

-- Setup
function M.setup(opts)
	M.config = vim.tbl_deep_extend("keep", opts or {}, M.config)

	vim.api.nvim_create_user_command("SemanticSearch", M.semantic_search, {})
	vim.api.nvim_create_user_command("SemanticSearchSet", function(args)
		local parts = vim.split(args.args, "%s+", { trimempty = true })
		if #parts ~= 2 then
			vim.notify("Usage: SemanticSearchSet <key> <value>", vim.log.levels.ERROR)
			return
		end

		local key, value = parts[1], parts[2]
		if key == "threshold" then
			value = tonumber(value)
			if not value then
				vim.notify("Invalid threshold value", vim.log.levels.ERROR)
				return
			end
		end

		save_config(key, value)
		M.config[key] = value
		vim.notify(string.format("Set %s to %s", key, value))
	end, { nargs = "*" })
end

return M
