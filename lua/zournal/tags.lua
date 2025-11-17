-- Line tagging with UUID management
local M = {}

-- Generate a UUID tag for line tagging
-- CRITICAL: Prepends 'z' to UUID for Neovim tag compatibility
-- (Neovim tags must start with a letter)
-- Returns: formatted tag string in the form "#z<uuid>" (e.g., "#za3f9b2c1-4d5e-6f7a-8b9c-0d1e2f3a4b5c")
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

  -- Prepend 'z' for Neovim tag compatibility and add '#' prefix
  local tag = "#z" .. uuid

  return tag
end

-- Tag the current line with a UUID
-- Appends a UUID tag to the end of the current line
function M.tag_current_line()
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

-- Copy tag from current line to clipboard
-- Extracts UUID tag from current line and copies it to system clipboard
function M.copy_tag_from_line()
  -- Get current line content
  local line_content = vim.api.nvim_get_current_line()

  -- Parse line to find tag pattern #z[0-9a-f-]+
  -- UUID format: #z followed by hex digits and hyphens
  local tag = line_content:match("#z[0-9a-f%-]+")

  if not tag then
    vim.notify("No tag found on current line", vim.log.levels.ERROR)
    return
  end

  -- Copy tag to system clipboard
  vim.fn.setreg('+', tag)

  -- Show confirmation message
  vim.notify("Tag copied to clipboard: " .. tag, vim.log.levels.INFO)
end

return M
