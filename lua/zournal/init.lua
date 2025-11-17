-- Main plugin setup and configuration
local M = {}

-- Lazy-load modules
M.config = require('zournal.config')
M.journal = require('zournal.journal')
M.zettelkasten = require('zournal.zettelkasten')
M.tags = require('zournal.tags')
M.links = require('zournal.links')
M.utils = require('zournal.utils')
M.frontmatter = require('zournal.frontmatter')
M.template = require('zournal.template')
M.telescope = {
  relations = require('zournal.telescope.relations'),
  links = require('zournal.telescope.links'),
}

-- Setup workspace detection autocmds
local function setup_workspace_detection()
  local group = vim.api.nvim_create_augroup('ZournalWorkspaceDetection', { clear = true })

  -- Detect workspace when entering a markdown buffer (file path based)
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = '*.md',
    callback = function()
      local bufname = vim.api.nvim_buf_get_name(0)
      if bufname ~= "" then
        local workspace = M.config.detect_workspace_from_path(bufname)
        if workspace and workspace ~= M.config.active_workspace then
          M.config.active_workspace = workspace
        end
      end
    end,
  })

  -- Detect workspace when directory changes (cwd based)
  vim.api.nvim_create_autocmd('DirChanged', {
    group = group,
    callback = function()
      local cwd = vim.fn.getcwd()
      local workspace = M.config.detect_workspace_from_path(cwd)
      if workspace and workspace ~= M.config.active_workspace then
        M.config.active_workspace = workspace
      end
    end,
  })
end

-- Main setup function
function M.setup(opts)
  M.config.setup(opts or {})

  -- Setup tag concealment
  M.tags.setup_concealment()

  -- Setup automatic link renaming
  M.links.setup_auto_rename()

  -- Setup workspace detection
  setup_workspace_detection()
end

return M
