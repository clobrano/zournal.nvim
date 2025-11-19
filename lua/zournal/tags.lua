-- Line tagging with UUID management
local M = {}

-- Generate a UUID tag for line tagging
-- Returns: formatted tag string in the form "{ztag<uuid>}" (e.g., "{ztaga3f9b2c1-4d5e-6f7a-8b9c-0d1e2f3a4b5c}")
function M.generate_uuid()
  -- Call system uuidgen command to generate a UUID
  local handle = io.popen("uuidgen")
  if not handle then
    vim.notify("Failed to generate UUID: uuidgen command not available", vim.log.levels.ERROR)
    return nil
  end

  local uuid = handle:read("*a")
  handle:close()

  -- Trim whitespace/newlines
  uuid = uuid:gsub("%s+", "")

  -- Convert to lowercase for consistency
  uuid = uuid:lower()

  -- Format as {ztag<uuid>}
  local tag = "{ztag" .. uuid .. "}"

  return tag
end

-- Add a tag to the current line
-- Appends a UUID tag in format {ztag<uuid>} to the end of the current line
function M.add_tag()
  -- Get current line number and content
  local line_num = vim.api.nvim_win_get_cursor(0)[1]
  local line_content = vim.api.nvim_get_current_line()

  -- Generate new UUID tag
  local tag = M.generate_uuid()
  if not tag then
    return -- Error already shown by generate_uuid
  end

  -- Append tag to end of line with space separator
  local new_content = line_content .. " " .. tag

  -- Update line in buffer
  vim.api.nvim_set_current_line(new_content)

  vim.notify("Line tagged with " .. tag, vim.log.levels.INFO)
end

-- Copy tag reference from current line to clipboard
-- Extracts UUID from current line and copies it as {zref<uuid>} to clipboard
function M.copy_tag_reference()
  -- Get current line content
  local line_content = vim.api.nvim_get_current_line()

  -- Parse line to find tag pattern {ztag or {zref followed by UUID
  -- UUID format: hex digits and hyphens, ending with }
  local uuid = line_content:match("{z[tr][ea][fg]([0-9a-f%-]+)}")

  if not uuid then
    vim.notify("No tag found on current line", vim.log.levels.ERROR)
    return
  end

  -- Create reference tag format
  local ref_tag = "{zref" .. uuid .. "}"

  -- Copy reference tag to system clipboard
  vim.fn.setreg('+', ref_tag)

  -- Show confirmation message
  vim.notify("Tag reference copied to clipboard: " .. ref_tag, vim.log.levels.INFO)
end

-- Setup tag concealment for markdown files in journal directory
-- Conceals UUID tags with symbols from config
function M.setup_concealment()
  local config = require('zournal.config').get()

  -- Create autocommand group for tag concealment
  local group = vim.api.nvim_create_augroup('ZournalTagConcealment', { clear = true })

  vim.api.nvim_create_autocmd({'BufEnter', 'BufWinEnter'}, {
    group = group,
    pattern = '*.md',
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local filepath = vim.api.nvim_buf_get_name(bufnr)

      -- Only apply concealment to files in the journal directory
      local root_dir = vim.fn.expand(config.root_dir)
      if not filepath:match('^' .. vim.pesc(root_dir)) then
        return
      end

      -- Set up syntax concealment for tags
      -- Original tags: {ztag<uuid>} -> concealed with tag_symbol (📌)
      -- Reference tags: {zref<uuid>} -> concealed with reference_symbol (→)
      local tag_symbol = config.tag_symbol or "📌"
      local ref_symbol = config.reference_symbol or "→"

      vim.cmd(string.format([[
        syntax match ZournalTagOriginal /{ztag[0-9a-f-]\+}/ conceal cchar=%s
      ]], tag_symbol))

      vim.cmd(string.format([[
        syntax match ZournalTagReference /{zref[0-9a-f-]\+}/ conceal cchar=%s
      ]], ref_symbol))

      -- Ensure concealment is enabled (respect user's conceallevel setting)
      if vim.o.conceallevel == 0 then
        vim.wo.conceallevel = 2
      end
    end,
  })
end

return M
