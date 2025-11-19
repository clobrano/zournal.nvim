-- Virtual text display for tag references
local M = {}

-- Namespace for virtual text extmarks
local ns_id = nil

-- Debounce timer for updates
local update_timer = nil

-- Initialize namespace
local function init_namespace()
  if not ns_id then
    ns_id = vim.api.nvim_create_namespace('zournal_virtual_text')
  end
  return ns_id
end

-- Extract UUID from a tag (works with both {ztag and {zref)
local function extract_uuid(tag_string)
  return tag_string:match("{z[tr][ea][fg]([0-9a-f%-]+)}")
end

-- Find the original tag content for a given UUID
-- Returns: {content, filepath, line_num} or nil
local function find_original_content(uuid)
  local config = require('zournal.config').get()
  local utils = require('zournal.utils')

  -- Find all markdown files
  local files = utils.find_files_with_pattern(config.root_dir, "%.md$")

  local occurrences = {}

  for _, filepath in ipairs(files) do
    local content = utils.read_file(filepath)
    if content then
      local line_num = 1
      for line in content:gmatch("[^\r\n]+") do
        -- Look for original tag {ztag<uuid>}
        local ztag_match = line:match("{ztag" .. vim.pesc(uuid) .. "}")

        if ztag_match then
          -- Found original tag - extract line content without the tag
          local clean_content = line:gsub("{ztag" .. vim.pesc(uuid) .. "}", ""):match("^%s*(.-)%s*$")

          table.insert(occurrences, {
            content = clean_content,
            filepath = filepath,
            line_num = line_num,
            -- Use file modification time for sorting (oldest = original)
            mtime = vim.loop.fs_stat(filepath).mtime.sec,
          })
        end
        line_num = line_num + 1
      end
    end
  end

  if #occurrences == 0 then
    return nil
  end

  -- Sort by modification time (oldest first)
  table.sort(occurrences, function(a, b) return a.mtime < b.mtime end)

  return occurrences[1]
end

-- Clear all virtual text in a buffer
function M.clear_virtual_text(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ns = init_namespace()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

-- Update virtual text for all reference tags in buffer
function M.update_virtual_text(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local config = require('zournal.config').get()

  -- Check if virtual text is enabled
  if not config.virtual_text_enabled then
    return
  end

  -- Only apply to markdown files in journal directory
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local root_dir = vim.fn.expand(config.root_dir)
  if not filepath:match('^' .. vim.pesc(root_dir)) then
    return
  end

  local ns = init_namespace()

  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Get all lines in buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for line_num, line_content in ipairs(lines) do
    -- Look for reference tags {zref<uuid>}
    local uuid = line_content:match("{zref([0-9a-f%-]+)}")

    if uuid then
      -- Find the original tag content
      local original = find_original_content(uuid)

      if original and original.content ~= "" then
        -- Format the virtual text
        local content = original.content

        -- Truncate if too long
        if #content > config.virtual_text_max_length then
          content = content:sub(1, config.virtual_text_max_length - 3) .. "..."
        end

        -- Apply format string
        local virt_text = string.format(config.virtual_text_format, content)

        -- Add virtual text at end of line
        vim.api.nvim_buf_set_extmark(bufnr, ns, line_num - 1, 0, {
          virt_text = {{" " .. virt_text, "ZournalVirtualText"}},
          virt_text_pos = 'eol',
        })
      end
    end
  end
end

-- Toggle virtual text for current buffer
function M.toggle()
  local config = require('zournal.config')
  local current_config = config.get()

  -- Toggle the setting
  current_config.virtual_text_enabled = not current_config.virtual_text_enabled

  local bufnr = vim.api.nvim_get_current_buf()

  if current_config.virtual_text_enabled then
    M.update_virtual_text(bufnr)
    vim.notify("Virtual text enabled", vim.log.levels.INFO)
  else
    M.clear_virtual_text(bufnr)
    vim.notify("Virtual text disabled", vim.log.levels.INFO)
  end
end

-- Setup virtual text with autocommands
function M.setup_virtual_text()
  local config = require('zournal.config').get()

  -- Only setup if enabled
  if not config.virtual_text_enabled then
    return
  end

  -- Create autocommand group
  local group = vim.api.nvim_create_augroup('ZournalVirtualText', { clear = true })

  -- Update virtual text on buffer enter
  vim.api.nvim_create_autocmd({'BufEnter', 'BufWinEnter'}, {
    group = group,
    pattern = '*.md',
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      M.update_virtual_text(bufnr)
    end,
  })

  -- Update virtual text on text change (debounced)
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    group = group,
    pattern = '*.md',
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()

      -- Debounce: cancel existing timer
      if update_timer then
        update_timer:stop()
        update_timer:close()
      end

      -- Create new timer (300ms delay)
      update_timer = vim.loop.new_timer()
      update_timer:start(300, 0, vim.schedule_wrap(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          M.update_virtual_text(bufnr)
        end
      end))
    end,
  })
end

return M
