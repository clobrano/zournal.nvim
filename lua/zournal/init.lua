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
M.virtual_text = require('zournal.virtual_text')
M.telescope = {
  relations = require('zournal.telescope.relations'),
  links = require('zournal.telescope.links'),
}

-- Setup <CR> in normal mode for markdown buffers so that pressing Enter on a
-- wikilink or markdown link follows (or creates) the target file.  When the
-- cursor is not on any link the default <CR> behaviour is preserved.
local function setup_link_keymaps()
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('ZournalLinkKeymaps', { clear = true }),
    pattern = 'markdown',
    callback = function(args)
      vim.keymap.set('n', '<CR>', function()
        local link = M.links.get_link_under_cursor()
        if link then
          M.links.follow_link()
        else
          -- Fall through to built-in <CR> (move to next line) without remapping
          local enter = vim.api.nvim_replace_termcodes('<CR>', true, true, true)
          vim.api.nvim_feedkeys(enter, 'n', false)
        end
      end, { buffer = args.buf, desc = 'Follow link under cursor', noremap = true })
    end,
  })
end

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

  -- Setup tag signs
  M.tags.setup_signs()

  -- Setup virtual text for tag references
  M.virtual_text.setup_virtual_text()

  -- Setup automatic link renaming
  M.links.setup_auto_rename()

  -- Setup workspace detection
  setup_workspace_detection()

  -- Setup <CR> keymap for link navigation in markdown files
  setup_link_keymaps()
end

return M
