-- Configuration management for multi-workspace support
local M = {}

-- Default values for workspace configuration
local workspace_defaults = {
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

-- All configured workspaces (name -> config)
M.workspaces = {}

-- Currently active workspace name
M.active_workspace = nil

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

-- Expand all path fields in a workspace config
local function expand_workspace_paths(workspace_config)
  local expanded = vim.deepcopy(workspace_config)
  expanded.root_dir = expand_path(expanded.root_dir)
  expanded.journal_dir = expand_path(expanded.journal_dir)
  expanded.daily_template = expand_path(expanded.daily_template)
  expanded.weekly_template = expand_path(expanded.weekly_template)
  expanded.monthly_template = expand_path(expanded.monthly_template)
  expanded.inbox_template = expand_path(expanded.inbox_template)
  return expanded
end

-- Setup function to initialize multi-workspace configuration
-- BREAKING CHANGE: Requires workspaces table
function M.setup(opts)
  opts = opts or {}

  -- Require workspaces table
  if not opts.workspaces or type(opts.workspaces) ~= "table" or vim.tbl_isempty(opts.workspaces) then
    vim.notify(
      "zournal.nvim: Configuration error - 'workspaces' table is required.\n" ..
      "Example:\n" ..
      "require('zournal').setup({\n" ..
      "  workspaces = {\n" ..
      "    personal = { root_dir = '~/notes/' },\n" ..
      "    work = { root_dir = '~/work-notes/' },\n" ..
      "  }\n" ..
      "})",
      vim.log.levels.ERROR
    )
    return
  end

  -- Process each workspace
  M.workspaces = {}
  for name, workspace_opts in pairs(opts.workspaces) do
    -- Validate workspace name
    if type(name) ~= "string" or name == "" then
      vim.notify(
        string.format("zournal.nvim: Invalid workspace name '%s' - must be a non-empty string", tostring(name)),
        vim.log.levels.ERROR
      )
      return
    end

    -- Validate workspace config
    if type(workspace_opts) ~= "table" then
      vim.notify(
        string.format("zournal.nvim: Workspace '%s' config must be a table", name),
        vim.log.levels.ERROR
      )
      return
    end

    -- Require root_dir for each workspace
    if not workspace_opts.root_dir or workspace_opts.root_dir == "" then
      vim.notify(
        string.format("zournal.nvim: Workspace '%s' requires 'root_dir' to be set", name),
        vim.log.levels.ERROR
      )
      return
    end

    -- Merge with defaults and expand paths
    local workspace_config = deep_merge(workspace_defaults, workspace_opts)
    M.workspaces[name] = expand_workspace_paths(workspace_config)
  end

  -- Set initial active workspace (use first workspace as fallback)
  if not M.active_workspace then
    -- Get first workspace name (tables don't have guaranteed order, but we need a fallback)
    for name, _ in pairs(M.workspaces) do
      M.active_workspace = name
      break
    end
  end

  -- Validate that active workspace exists
  if M.active_workspace and not M.workspaces[M.active_workspace] then
    M.active_workspace = nil
    for name, _ in pairs(M.workspaces) do
      M.active_workspace = name
      break
    end
  end
end

-- Detect workspace from file path
-- Returns workspace name if found, nil otherwise
function M.detect_workspace_from_path(path)
  if not path or path == "" then
    return nil
  end

  -- Expand path for comparison
  local expanded_path = vim.fn.fnamemodify(path, ":p")

  -- Find workspace with longest matching root_dir (most specific match)
  local best_match = nil
  local best_match_len = 0

  for name, workspace_config in pairs(M.workspaces) do
    local root_dir = workspace_config.root_dir
    -- Ensure root_dir ends with / for clean comparison
    if not root_dir:match("/$") then
      root_dir = root_dir .. "/"
    end

    -- Check if path is within this workspace's root_dir
    if expanded_path:sub(1, #root_dir) == root_dir then
      if #root_dir > best_match_len then
        best_match = name
        best_match_len = #root_dir
      end
    end
  end

  return best_match
end

-- Detect workspace from current context
-- Priority: current buffer path → cwd → active workspace → first workspace
-- Returns workspace name
function M.detect_workspace()
  -- Try current buffer path (if it's a markdown file)
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" and bufname:match("%.md$") then
    local workspace = M.detect_workspace_from_path(bufname)
    if workspace then
      return workspace
    end
  end

  -- Try current working directory
  local cwd = vim.fn.getcwd()
  local workspace = M.detect_workspace_from_path(cwd)
  if workspace then
    return workspace
  end

  -- Fallback to active workspace
  if M.active_workspace and M.workspaces[M.active_workspace] then
    return M.active_workspace
  end

  -- Last resort: return first workspace
  for name, _ in pairs(M.workspaces) do
    return name
  end

  return nil
end

-- Set active workspace (manual override)
function M.set_active_workspace(name)
  if not name or name == "" then
    vim.notify("zournal.nvim: Workspace name cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if not M.workspaces[name] then
    vim.notify(
      string.format("zournal.nvim: Workspace '%s' not found. Available workspaces: %s",
        name,
        table.concat(vim.tbl_keys(M.workspaces), ", ")),
      vim.log.levels.ERROR
    )
    return false
  end

  M.active_workspace = name
  vim.notify(string.format("zournal.nvim: Switched to workspace '%s'", name), vim.log.levels.INFO)
  return true
end

-- Get current workspace name
function M.get_workspace_name()
  -- Auto-detect workspace
  local detected = M.detect_workspace()
  if detected then
    M.active_workspace = detected
    return detected
  end

  vim.notify("zournal.nvim: No workspace detected or configured", vim.log.levels.ERROR)
  return nil
end

-- Get current workspace configuration
function M.get()
  local workspace_name = M.get_workspace_name()
  if not workspace_name then
    -- Return empty config as fallback (commands will fail gracefully)
    return {}
  end

  return M.workspaces[workspace_name]
end

-- Get list of all workspace names
function M.list_workspaces()
  return vim.tbl_keys(M.workspaces)
end

-- Get workspace info for display
function M.get_workspace_info(name)
  local workspace_config = M.workspaces[name]
  if not workspace_config then
    return nil
  end

  return {
    name = name,
    root_dir = workspace_config.root_dir,
    journal_dir = M.get_journal_dir_for_workspace(workspace_config),
    is_active = (name == M.active_workspace),
  }
end

-- Get the absolute journal directory path for a specific workspace config
-- If journal_dir is relative, it's relative to root_dir
-- If journal_dir is absolute, use it as-is
function M.get_journal_dir_for_workspace(workspace_config)
  local journal_dir = workspace_config.journal_dir or "Journal/"

  -- If journal_dir is already absolute (starts with / or ~), use it
  if journal_dir:match("^/") or journal_dir:match("^~") then
    return expand_path(journal_dir)
  end

  -- Otherwise, it's relative to root_dir
  local root = workspace_config.root_dir or "~/notes/"
  -- Remove trailing slash from root if present
  root = root:gsub("/$", "")
  return root .. "/" .. journal_dir
end

-- Get the absolute journal directory path for current workspace
function M.get_journal_dir()
  local workspace_config = M.get()
  if vim.tbl_isempty(workspace_config) then
    return nil
  end

  return M.get_journal_dir_for_workspace(workspace_config)
end

return M
