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

-- Main setup function
function M.setup(opts)
  M.config.setup(opts or {})

  -- Setup tag concealment
  M.tags.setup_concealment()

  -- Setup automatic link renaming
  M.links.setup_auto_rename()
end

return M
