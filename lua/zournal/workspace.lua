-- Workspace management utilities
local M = {}

local config = require('zournal.config')

--- List all configured workspaces
function M.list_workspaces()
  local workspaces = config.list_workspaces()

  if vim.tbl_isempty(workspaces) then
    vim.notify("zournal.nvim: No workspaces configured", vim.log.levels.WARN)
    return
  end

  -- Build output message
  local lines = { "Configured workspaces:" }

  for _, name in ipairs(workspaces) do
    local info = config.get_workspace_info(name)
    if info then
      local status = info.is_active and " [ACTIVE]" or ""
      table.insert(lines, string.format("  • %s: %s%s", name, info.root_dir, status))
    end
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

--- Show current workspace information
function M.show_current_workspace()
  local workspace_name = config.get_workspace_name()

  if not workspace_name then
    vim.notify("zournal.nvim: No workspace detected", vim.log.levels.WARN)
    return
  end

  local info = config.get_workspace_info(workspace_name)
  if not info then
    vim.notify(
      string.format("zournal.nvim: Workspace '%s' not found", workspace_name),
      vim.log.levels.ERROR
    )
    return
  end

  -- Build detailed info message
  local lines = {
    string.format("Current workspace: %s", info.name),
    string.format("  Root directory: %s", info.root_dir),
    string.format("  Journal directory: %s", info.journal_dir),
  }

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
