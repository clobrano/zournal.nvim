-- Configuration management and defaults
local M = {}

-- Default configuration values
local defaults = {
  -- Root directory for Zettelkasten notes
  root_dir = "~/notes/",

  -- Journal directory for daily/weekly/monthly journals
  -- Can be absolute or relative to root_dir
  journal_dir = "Journal/",

  -- Filename formats for different journal types
  daily_format = "%Y-%m-%d.md",
  weekly_format = "%Y-%m-%d-W%V.md",
  monthly_format = "%Y-%m.md",

  -- Template paths (empty strings if not provided)
  daily_template = "",
  weekly_template = "",
  monthly_template = "",
  inbox_template = "",

  -- Inbox directory (relative to root_dir)
  inbox_dir = "Resources/",

  -- Concealment symbols for tags
  tag_symbol = "📌",
  reference_symbol = "→📌",
}

-- Active configuration (will be merged with user options)
M.options = {}

-- Helper function to deep merge tables
local function deep_merge(base, override)
  local result = vim.deepcopy(base)
  for k, v in pairs(override) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

-- Helper function to expand tilde (~) in paths
local function expand_path(path)
  if not path or path == "" then
    return path
  end

  -- Expand ~ to home directory
  if path:sub(1, 1) == "~" then
    local home = vim.loop.os_homedir()
    return home .. path:sub(2)
  end

  return path
end

-- Setup function to initialize configuration
function M.setup(opts)
  opts = opts or {}

  -- Merge user options with defaults
  M.options = deep_merge(defaults, opts)

  -- Expand tilde in path configurations
  M.options.root_dir = expand_path(M.options.root_dir)
  M.options.journal_dir = expand_path(M.options.journal_dir)
  M.options.daily_template = expand_path(M.options.daily_template)
  M.options.weekly_template = expand_path(M.options.weekly_template)
  M.options.monthly_template = expand_path(M.options.monthly_template)
  M.options.inbox_template = expand_path(M.options.inbox_template)
end

-- Getter function to access configuration
function M.get()
  return M.options
end

-- Get the absolute journal directory path
-- If journal_dir is relative, it's relative to root_dir
-- If journal_dir is absolute, use it as-is
function M.get_journal_dir()
  local journal_dir = M.options.journal_dir or "Journal/"

  -- If journal_dir is already absolute (starts with / or ~), use it
  if journal_dir:match("^/") or journal_dir:match("^~") then
    return expand_path(journal_dir)
  end

  -- Otherwise, it's relative to root_dir
  local root = M.options.root_dir or "~/notes/"
  -- Remove trailing slash from root if present
  root = root:gsub("/$", "")
  return root .. "/" .. journal_dir
end

-- Initialize with defaults on module load
M.setup()

return M
