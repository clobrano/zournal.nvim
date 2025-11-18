-- Shared utility functions (file operations, date formatting, etc.)
local M = {}

-- Plenary modules
local Path = require("plenary.path")
local scandir = require("plenary.scandir")

-- ============================================================================
-- File Operations (3.1)
-- ============================================================================

--- Check if file exists
---@param path string
---@return boolean
function M.file_exists(path)
  if not path or path == "" then
    return false
  end
  local p = Path:new(path)
  return p:exists() and p:is_file()
end

--- Create directory if it doesn't exist
---@param path string
---@return boolean success
function M.ensure_dir(path)
  if not path or path == "" then
    return false
  end
  local p = Path:new(path)
  if not p:exists() then
    p:mkdir({ parents = true })
  end
  return true
end

--- Read entire file contents
---@param path string
---@return string|nil content
function M.read_file(path)
  if not M.file_exists(path) then
    return nil
  end
  local p = Path:new(path)
  return p:read()
end

--- Write content to file
---@param path string
---@param content string
---@return boolean success
function M.write_file(path, content)
  if not path or path == "" then
    return false
  end

  -- Ensure parent directory exists
  local p = Path:new(path)
  local parent = p:parent()
  if parent then
    M.ensure_dir(parent.filename)
  end

  -- Write file
  p:write(content, "w")
  return true
end

--- Find files matching pattern in directory
---@param dir string
---@param pattern string Lua pattern to match filenames
---@return table files List of file paths
function M.find_files_with_pattern(dir, pattern)
  if not dir or not M.file_exists(dir) and not Path:new(dir):is_dir() then
    return {}
  end

  local files = scandir.scan_dir(dir, {
    hidden = false,
    depth = 10,
    search_pattern = pattern,
  })

  return files or {}
end

-- ============================================================================
-- Date Formatting (3.2)
-- ============================================================================

--- Format date using strftime-like patterns
--- Special handling: %V is replaced with week number from configured system
---@param format_string string
---@param date number|nil Unix timestamp (defaults to current time)
---@return string
function M.format_date(format_string, date)
  date = date or os.time()

  -- Check if format contains %V (ISO week number)
  if format_string:match("%%V") then
    -- Replace %V with the configured week number
    local week = M.get_iso_week(date)
    -- Format the week number with leading zero (2 digits)
    local week_str = string.format("%02d", week)
    -- Replace %V with the calculated week number
    format_string = format_string:gsub("%%V", week_str)
  end

  return os.date(format_string, date)
end

--- Calculate ISO 8601 week number
--- Week 1 is the week containing the first Thursday of the year
---@param date number Unix timestamp
---@return number week_number
local function calculate_iso8601_week(date)
  -- Use system's %V which implements ISO 8601
  return tonumber(os.date("%V", date))
end

--- Calculate Gregorian week number
--- Week 1 is the week containing January 1st
---@param date number Unix timestamp
---@return number week_number
local function calculate_gregorian_week(date)
  local date_info = os.date("*t", date)

  -- Get January 1st of the same year
  local jan1 = os.time({
    year = date_info.year,
    month = 1,
    day = 1,
    hour = 0,
    min = 0,
    sec = 0,
  })

  -- Calculate day of year (1-366)
  local day_of_year = tonumber(os.date("%j", date))

  -- Get day of week for Jan 1 (1=Monday, 7=Sunday)
  local jan1_wday = tonumber(os.date("%u", jan1))

  -- Calculate week number:
  -- Days from Jan 1 + (day of week offset for Jan 1), divided by 7, rounded up
  local week = math.ceil((day_of_year + jan1_wday - 1) / 7)

  return week
end

--- Get week number for a date using configured system
---@param date number|nil Unix timestamp (defaults to current time)
---@param system string|nil Week numbering system ("iso8601" or "gregorian", defaults to config)
---@return number week_number
function M.get_iso_week(date, system)
  date = date or os.time()

  -- Get system from config if not provided
  if not system then
    local config = require("zournal.config")
    local cfg = config.get()
    system = cfg.week_numbering_system or "iso8601"
  end

  if system == "gregorian" then
    return calculate_gregorian_week(date)
  else
    -- Default to ISO 8601
    return calculate_iso8601_week(date)
  end
end

--- Parse date string to date object (timestamp)
---@param date_string string Date in format YYYY-MM-DD
---@return number|nil timestamp
function M.parse_date(date_string)
  if not date_string or date_string == "" then
    return nil
  end

  -- Parse YYYY-MM-DD format
  local year, month, day = date_string:match("(%d+)-(%d+)-(%d+)")
  if not year or not month or not day then
    return nil
  end

  return os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = 0,
    min = 0,
    sec = 0,
  })
end

-- ============================================================================
-- Path Utilities (3.3)
-- ============================================================================

--- Join path components
---@param ... string Path components
---@return string
function M.join_path(...)
  local parts = { ... }
  return Path:new(unpack(parts)).filename
end

--- Expand ~ and environment variables
---@param path string
---@return string
function M.expand_path(path)
  if not path or path == "" then
    return path
  end

  -- Expand environment variables
  path = vim.fn.expand(path)

  -- Create Path object which handles normalization
  return Path:new(path).filename
end

--- Extract filename without extension
---@param path string
---@return string
function M.get_filename_without_ext(path)
  if not path or path == "" then
    return ""
  end

  local p = Path:new(path)
  local name = p:_fs_filename()

  -- Remove extension
  return name:match("(.+)%..+$") or name
end

-- ============================================================================
-- Buffer/Window Utilities (3.4)
-- ============================================================================

--- Open file in current or new buffer
---@param path string
---@return boolean success
function M.open_file_in_buffer(path)
  if not path or path == "" then
    return false
  end

  -- Use vim.cmd.edit to open file
  vim.cmd.edit(path)
  return true
end

--- Get currently selected text in visual mode
---@return string|nil
function M.get_visual_selection()
  -- Save current register content
  local saved_reg = vim.fn.getreg('"')
  local saved_regtype = vim.fn.getregtype('"')

  -- Yank visual selection
  vim.cmd('noautocmd normal! "vy')
  local selection = vim.fn.getreg('"')

  -- Restore register
  vim.fn.setreg('"', saved_reg, saved_regtype)

  return selection
end

--- Replace visual selection with text
---@param replacement string
---@return boolean success
function M.replace_visual_selection(replacement)
  if not replacement then
    return false
  end

  -- Get visual selection start and end positions
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  -- Replace the selection
  vim.api.nvim_buf_set_text(
    0,
    start_line - 1,
    start_col - 1,
    end_line - 1,
    end_col,
    vim.split(replacement, "\n")
  )

  return true
end

return M
