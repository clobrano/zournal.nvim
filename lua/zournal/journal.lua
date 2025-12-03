-- Daily/weekly/monthly journal commands
local M = {}

local config = require("zournal.config")
local utils = require("zournal.utils")
local template = require("zournal.template")

-- ============================================================================
-- Daily Journal (6.1)
-- ============================================================================

--- Create or open daily journal
---@return boolean success
function M.create_daily_journal()
  local cfg = config.get()

  -- Get current date
  local date = utils.format_date("%Y-%m-%d")

  -- Format filename using daily_format from config
  local filename = utils.format_date(cfg.daily_format)

  -- Build full path: journal_dir/filename
  local journal_dir = config.get_journal_dir()
  local file_path = utils.join_path(journal_dir, filename)

  -- Ensure journal directory exists
  utils.ensure_dir(journal_dir)

  -- Check if file exists; if not, create from template
  if not utils.file_exists(file_path) then
    local content = template.apply_daily_template(cfg.daily_template, { date = date })
    utils.write_file(file_path, content)
  end

  -- Open file in buffer
  return utils.open_file_in_buffer(file_path)
end

-- ============================================================================
-- Weekly Journal (6.2)
-- ============================================================================

--- Create or open weekly journal
---@return boolean success
function M.create_weekly_journal()
  local cfg = config.get()

  -- Get current date and ISO week number
  local date = utils.format_date("%Y-%m-%d")
  local week = utils.get_iso_week()

  -- Format filename using weekly_format from config
  local filename = utils.format_date(cfg.weekly_format)

  -- Build full path: journal_dir/filename
  local journal_dir = config.get_journal_dir()
  local file_path = utils.join_path(journal_dir, filename)

  -- Ensure journal directory exists
  utils.ensure_dir(journal_dir)

  -- Check if file exists; if not, create from template
  if not utils.file_exists(file_path) then
    local content = template.apply_weekly_template(cfg.weekly_template, {
      date = date,
      week = tostring(week),
    })
    utils.write_file(file_path, content)
  end

  -- Open file in buffer
  return utils.open_file_in_buffer(file_path)
end

-- ============================================================================
-- Monthly Journal (6.3)
-- ============================================================================

--- Create or open monthly journal
---@return boolean success
function M.create_monthly_journal()
  local cfg = config.get()

  -- Get current year and month
  local year = utils.format_date("%Y")
  local month = utils.format_date("%B")

  -- Format filename using monthly_format from config
  local filename = utils.format_date(cfg.monthly_format)

  -- Build full path: journal_dir/filename
  local journal_dir = config.get_journal_dir()
  local file_path = utils.join_path(journal_dir, filename)

  -- Ensure journal directory exists
  utils.ensure_dir(journal_dir)

  -- Check if file exists; if not, create from template
  if not utils.file_exists(file_path) then
    local content = template.apply_monthly_template(cfg.monthly_template, {
      year = year,
      month = month,
    })
    utils.write_file(file_path, content)
  end

  -- Open file in buffer
  return utils.open_file_in_buffer(file_path)
end

-- ============================================================================
-- Inbox Note (6.4)
-- ============================================================================

--- Find next available root zid
---@return string next_root_zid
local function find_next_root_zid()
  local frontmatter = require("zournal.frontmatter")
  local cfg = config.get()
  local files = utils.find_files_with_pattern(cfg.root_dir, "%.md$")

  -- Collect all root zids (single numbers)
  local root_zids = {}
  for _, file_path in ipairs(files) do
    local zid = frontmatter.get_zid(file_path)
    if zid then
      zid = tostring(zid)
      -- Check if it's a root zid (only digits, no letters)
      if zid:match("^%d+$") then
        table.insert(root_zids, tonumber(zid))
      end
    end
  end

  -- Find next available root zid
  if #root_zids == 0 then
    return "1"
  end

  -- Sort to find gaps
  table.sort(root_zids)

  -- Check for gaps
  for i = 1, #root_zids do
    if root_zids[i] ~= i then
      return tostring(i)
    end
  end

  -- No gaps, return next number
  return tostring(#root_zids + 1)
end

--- Create inbox note with user-provided title
---@return boolean success
function M.create_inbox_note()
  local cfg = config.get()
  local frontmatter = require("zournal.frontmatter")

  -- Prompt user for filename/title
  local title = vim.fn.input("Note title: ")
  if not title or title == "" then
    vim.notify("Note creation cancelled", vim.log.levels.INFO)
    return false
  end

  -- Sanitize filename (add .md if not present)
  local filename = title
  if not filename:match("%.md$") then
    filename = filename .. ".md"
  end

  -- Build full path: root_dir/inbox_dir/filename
  local inbox_path = utils.join_path(cfg.root_dir, cfg.inbox_dir)
  local file_path = utils.join_path(inbox_path, filename)

  -- Ensure inbox directory exists
  utils.ensure_dir(inbox_path)

  -- Check if file exists; if not, create from template
  if not utils.file_exists(file_path) then
    -- Find next available root zid
    local next_zid = find_next_root_zid()

    -- Create title line
    local title_line = "# " .. title

    -- Create frontmatter with zid and creation date
    frontmatter.update_frontmatter(file_path, {
      zid = next_zid,
      created = os.date("%Y-%m-%d"),
    }, title_line)

    vim.notify("Created inbox note with zid: " .. next_zid .. " - " .. filename, vim.log.levels.INFO)
  else
    vim.notify("Note already exists: " .. filename, vim.log.levels.WARN)
  end

  -- Open file in buffer
  return utils.open_file_in_buffer(file_path)
end

-- ============================================================================
-- Jump to Date (15.0 - implemented here for logical grouping)
-- ============================================================================

--- Jump to journal for a specific date
---@param date_string string Date in YYYY-MM-DD format
---@return boolean success
function M.jump_to_date(date_string)
  local cfg = config.get()
  local journal_dir = config.get_journal_dir()

  -- Parse date string
  local timestamp = utils.parse_date(date_string)
  if not timestamp then
    vim.notify("Invalid date format. Use YYYY-MM-DD", vim.log.levels.ERROR)
    return false
  end

  -- Try daily journal first
  local daily_filename = utils.format_date(cfg.daily_format, timestamp)
  local daily_path = utils.join_path(journal_dir, daily_filename)
  if utils.file_exists(daily_path) then
    return utils.open_file_in_buffer(daily_path)
  end

  -- Try weekly journal
  local weekly_filename = utils.format_date(cfg.weekly_format, timestamp)
  local weekly_path = utils.join_path(journal_dir, weekly_filename)
  if utils.file_exists(weekly_path) then
    return utils.open_file_in_buffer(weekly_path)
  end

  -- Try monthly journal
  local monthly_filename = utils.format_date(cfg.monthly_format, timestamp)
  local monthly_path = utils.join_path(journal_dir, monthly_filename)
  if utils.file_exists(monthly_path) then
    return utils.open_file_in_buffer(monthly_path)
  end

  -- No journal found for this date
  vim.notify("No journal found for date: " .. date_string, vim.log.levels.WARN)
  return false
end

return M
