local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local config = require("zournal.config")
local utils = require("zournal.utils")
local journal = require("zournal.journal")

local M = {}

-- Get the path for a journal file for a given date and format
local function get_journal_path(date_str, format_type)
	local workspace_config = config.get()
	if not workspace_config then
		return nil
	end

	local journal_dir = config.get_journal_dir()
	if not journal_dir then
		return nil
	end

	local format
	if format_type == "daily" then
		format = workspace_config.daily_format or "%Y-%m-%d.md"
	elseif format_type == "weekly" then
		format = workspace_config.weekly_format or "%Y-%m-%d-W%V.md"
	elseif format_type == "monthly" then
		format = workspace_config.monthly_format or "%Y-%m.md"
	else
		return nil
	end

	local date = utils.parse_date(date_str)
	if not date then
		return nil
	end

	local filename = utils.format_date(format, date)
	return journal_dir .. "/" .. filename
end

-- Check if a journal file exists for a given date
local function check_journal_exists(date_str)
	local exists = {
		daily = false,
		weekly = false,
		monthly = false,
	}

	-- Check daily journal
	local daily_path = get_journal_path(date_str, "daily")
	if daily_path and vim.fn.filereadable(daily_path) == 1 then
		exists.daily = true
	end

	-- Check weekly journal
	local weekly_path = get_journal_path(date_str, "weekly")
	if weekly_path and vim.fn.filereadable(weekly_path) == 1 then
		exists.weekly = true
	end

	-- Check monthly journal
	local monthly_path = get_journal_path(date_str, "monthly")
	if monthly_path and vim.fn.filereadable(monthly_path) == 1 then
		exists.monthly = true
	end

	return exists
end

-- Get the first line of content from a journal file for preview
local function get_journal_preview(date_str)
	local paths = {
		{ type = "daily", path = get_journal_path(date_str, "daily") },
		{ type = "weekly", path = get_journal_path(date_str, "weekly") },
		{ type = "monthly", path = get_journal_path(date_str, "monthly") },
	}

	for _, p in ipairs(paths) do
		if p.path and vim.fn.filereadable(p.path) == 1 then
			local lines = vim.fn.readfile(p.path, "", 3) -- Read first 3 lines
			if lines and #lines > 0 then
				-- Find first non-empty line
				for _, line in ipairs(lines) do
					local trimmed = vim.trim(line)
					if trimmed ~= "" and not trimmed:match("^#") then
						return trimmed:sub(1, 60) -- Limit to 60 chars
					end
				end
			end
		end
	end

	return ""
end

-- Generate a list of dates for the calendar view (newest to oldest, today and past only)
local function generate_date_list(days_back)
	local dates = {}
	local today = os.time()

	-- Generate today and past dates (newest to oldest)
	for i = 0, days_back do
		local date_time = today - (i * 24 * 60 * 60)
		local date_str = os.date("%Y-%m-%d", date_time)
		table.insert(dates, date_str)
	end

	return dates
end

-- Format date for display with day of week
local function format_date_display(date_str)
	local date = utils.parse_date(date_str)
	if not date then
		return date_str
	end

	local day_name = os.date("%A", date)
	local month_name = os.date("%B", date)
	local day = os.date("%d", date)
	local year = os.date("%Y", date)

	return string.format("%s, %s %s, %s", day_name, month_name, day, year)
end

-- Get status string for a date
local function get_status_string(exists)
	local parts = {}
	if exists.daily then
		table.insert(parts, "Daily")
	end
	if exists.weekly then
		table.insert(parts, "Weekly")
	end
	if exists.monthly then
		table.insert(parts, "Monthly")
	end

	if #parts > 0 then
		return "[" .. table.concat(parts, "/") .. "]"
	else
		return "[New]"
	end
end

-- Create entry maker for Telescope
local function make_entry(date_str)
	local exists = check_journal_exists(date_str)
	local preview = get_journal_preview(date_str)
	local status = get_status_string(exists)
	local formatted_date = format_date_display(date_str)

	local display_str
	if preview ~= "" then
		display_str = string.format("%s | %s %s | Preview: %s", date_str, formatted_date, status, preview)
	else
		display_str = string.format("%s | %s %s", date_str, formatted_date, status)
	end

	-- Determine which file to preview (prefer daily, then weekly, then monthly)
	local preview_file = nil
	if exists.daily then
		preview_file = get_journal_path(date_str, "daily")
	elseif exists.weekly then
		preview_file = get_journal_path(date_str, "weekly")
	elseif exists.monthly then
		preview_file = get_journal_path(date_str, "monthly")
	end

	return {
		value = date_str,
		display = display_str,
		ordinal = date_str .. " " .. formatted_date, -- Search by date or day name
		date_str = date_str,
		exists = exists,
		filename = preview_file, -- For Telescope preview
	}
end

-- Open calendar view
function M.show_calendar(opts)
	opts = opts or {}
	local days_back = opts.days_back or 1825 -- Default: 5 years back (today and past only)

	-- Check if workspace is configured
	local workspace_config = config.get()
	if not workspace_config then
		vim.notify("No active workspace. Use :ZournalSelectWorkspace first.", vim.log.levels.ERROR)
		return
	end

	-- Generate date list (today and past only)
	local dates = generate_date_list(days_back)

	-- Create Telescope picker
	pickers
		.new(opts, {
			prompt_title = "Journal Calendar",
			finder = finders.new_table({
				results = dates,
				entry_maker = make_entry,
			}),
			sorter = conf.generic_sorter(opts),
			previewer = previewers.new_buffer_previewer({
				title = "Journal Preview",
				define_preview = function(self, entry)
					if entry.filename and vim.fn.filereadable(entry.filename) == 1 then
						-- Use Telescope's built-in file preview
						local lines = vim.fn.readfile(entry.filename)
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
						-- Set filetype for syntax highlighting
						vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
					else
						-- Show message for non-existent journals
						local message = {
							"No journal entry exists for this date.",
							"",
							"Select to create a new journal entry.",
						}
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, message)
					end
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				-- Default action: open daily journal for selected date
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						journal.jump_to_date(selection.date_str)
					end
				end)

				return true
			end,
		})
		:find()
end

return M
