local M = {}

M.config = {
	threshold = 0.6,
	-- other default options
}

function filter(tbl, predicate)
	local result = {}
	for _, v in ipairs(tbl) do
		if predicate(v) then
			table.insert(result, v)
		end
	end
	return result
end

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

-- Function to save a key-value pair
local function save_config(key, value)
	local config_path = vim.fn.stdpath("data") .. "/autolink_config.json"
	local current_config = {}

	-- Read existing config if it exists
	local file = io.open(config_path, "r")
	if file then
		local content = file:read("*all")
		file:close()
		current_config = vim.fn.json_decode(content) or {}
	end

	-- Update the config
	current_config[key] = value

	-- Write the updated config
	file = io.open(config_path, "w")
	if file then
		file:write(vim.fn.json_encode(current_config))
		file:close()
	end
end

-- Function to load the entire config
local function load_config()
	local config_path = vim.fn.stdpath("data") .. "/autolink_config.json"
	local file = io.open(config_path, "r")
	if file then
		local content = file:read("*all")
		file:close()
		return vim.fn.json_decode(content) or {}
	end
	return {}
end

-- Command to set any config value

local curl = require("plenary.curl")

-- Function to get buffer content
local function get_buffer_content()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	return table.concat(lines, "\n")
end

function trim(s)
	return s:match("^%s*(.-)%s*$")
end

-- vim.fn.setreg("+", "Text to copy")
-- -- -- Get current buffer number
-- local bufnr = vim.api.nvim_get_current_buf()
--
-- -- Append lines to the end of the buffer
-- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"New line 1", "New line 2"})
--
-- -- Insert lines at a specific position (line 5 in this example)
-- vim.api.nvim_buf_set_lines(bufnr, 4, 4, false, {"Inserted line 1", "Inserted line 2"})
--

-- Function to make HTTP POST request

local function query_server(payload)
	local response = curl.post("http://127.0.0.1:5000/query", {
		headers = {
			["Content-Type"] = "application/json",
		},
		body = vim.fn.json_encode(payload),
		timeout = 30000,
	})

	return vim.json.decode(response.body)
end

-- Function to display popup with results
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

	-- Create a popup window with NUI
	local popup = Popup({
		enter = true,
		focusable = true,
		border = { style = "rounded" },
		position = "50%",
		size = { width = "80%", height = "60%" },
		buf_options = { modifiable = true, readonly = false },
		win_options = { winblend = 10 },
	})

	-- Set popup content
	local lines = {}
	for i, item in ipairs(items) do
		table.insert(lines, string.format("%d. [%s] (%.2f)", i, item.title, item.similarity))
	end
	vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)

	local function print_table_to_buffer(t)
		local buf = vim.api.nvim_create_buf(false, true)
		local lines = vim.split(vim.inspect(t), "\n")
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_set_current_buf(buf)
	end

	local function select_item()
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		items[cursor_pos[1]].selected = not items[cursor_pos[1]].selected
		-- print(vim.inspect(items))
	end

	local function select_all_items()
		for i, item in ipairs(items) do
			item.selected = not item.selected
		end
	end

	-- Keymap for selecting an item and previewing its content
	vim.keymap.set("n", "<CR>", select_item, { noremap = true, silent = true })
	vim.keymap.set("n", "<C-a>", select_all_items, { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "q", ":bdelete!<CR>", { noremap = true, silent = true })

	-- vim.fn.setreg("+", "Text to copy")
	-- -- -- Get current buffer number
	-- local bufnr = vim.api.nvim_get_current_buf()
	--
	-- -- Append lines to the end of the buffer
	-- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"New line 1", "New line 2"})
	--
	-- -- Insert lines at a specific position (line 5 in this example)
	-- vim.api.nvim_buf_set_lines(bufnr, 4, 4, false, {"Inserted line 1", "Inserted line 2"})
	--
	-- Close popup on buffer leave
	popup:on(event.BufLeave, function()
		vim.keymap.del("n", "<CR>", { noremap = true, silent = true })
		print("asf")
		local selected_items = filter(items, function(item)
			return item.selected
		end)
		local clipboard_string = ""
		for i, item in ipairs(selected_items) do
			print(item.title)
			clipboard_string = clipboard_string .. "[[" .. item.title .. "]]\n"
		end

		vim.fn.setreg("+", clipboard_string)

		popup:unmount()
	end)

	-- Mount the popup
	popup:mount()
end

-- Function to preview selected note content
function M.preview_selected()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local line_num = cursor_pos[1]

	print(vim.inspect(cursor_pos))
	local selected_note_content = cursor_pos.content

	local preview_popup = Popup({
		-- Show another popup for previewing content
		enter = true,
		focusable = true,
		border = { style = "rounded" },
		position = "50%",
		size = { width = "70%", height = "50%" },
		buf_options = { modifiable = false, readonly = true },
		win_options = { winblend = 10 },
	})

	vim.api.nvim_buf_set_lines(preview_popup.bufnr, 0, -1, false, vim.split(selected_note_content, "\n"))

	preview_popup:on(event.BufLeave, function()
		preview_popup:unmount()
	end)

	preview_popup:mount()
end

-- Main command for Autolink functionality
function M.autolink()
	local buffer_content = get_buffer_content()

	-- Prepare payload for query
	local payload = {
		query = buffer_content,
		threshold = M.config.threshold,
	}

	-- Query server and get results
	local response_data = query_server(payload)

	if response_data and response_data.results then
		show_popup(response_data.results)
	else
		print("No results found!")
	end
end

-- Setup function for configuration
M.config = {}
function M.setup(opts)
	M.config.threshold = opts.threshold or M.config.threshold

	-- Create Autolink command
	vim.api.nvim_create_user_command("Autolink", function()
		M.autolink()
	end, {})

	vim.api.nvim_create_user_command("AutolinkSet", function(opts)
		local args = vim.split(opts.args, " ")
		if #args ~= 2 then
			print("Usage: AutolinkSet <key> <value>")
			return
		end
		local key, value = args[1], args[2]

		-- Convert to number if it's the threshold
		if key == "threshold" then
			value = tonumber(value)
			if not value then
				print("Invalid threshold value")
				return
			end
		end

		save_config(key, value)
		M.config[key] = value
		print(string.format("Autolink %s set to %s", key, tostring(value)))
	end, { nargs = "*" })
end

return M
