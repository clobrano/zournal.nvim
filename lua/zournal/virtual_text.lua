-- Virtual text display for tag references
local M = {}

-- Namespace for virtual text extmarks
local ns_id = nil

-- Debounce timer for updates
local update_timer = nil

-- Track last processed changedtick per buffer to avoid redundant updates
-- Key: bufnr, Value: changedtick
local last_changedtick = {}

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

-- Wrap text into multiple lines based on max width
-- Returns array of lines for virt_lines (each line is {text, highlight})
local function wrap_text_for_virt_lines(text, max_width, highlight)
  if #text <= max_width then
    return {{{text, highlight}}}
  end

  local lines = {}
  local remaining = text

  while #remaining > 0 do
    if #remaining <= max_width then
      table.insert(lines, {{remaining, highlight}})
      break
    end

    -- Try to break at a space near the max width
    local break_pos = max_width
    local space_pos = remaining:sub(1, max_width):match("^.*()%s")

    -- If we found a space in the last 40% of the line, break there
    if space_pos and space_pos > max_width * 0.6 then
      break_pos = space_pos - 1
    end

    table.insert(lines, {{remaining:sub(1, break_pos), highlight}})
    remaining = remaining:sub(break_pos + 1):gsub("^%s+", "") -- Strip leading whitespace
  end

  return lines
end

-- Find the original tag content for a given UUID (uses cache)
-- Returns: {content, filepath, line_num} or nil
local function find_original_content(uuid)
  local tag_cache = require('zournal.tag_cache')
  return tag_cache.get_original_content(uuid)
end

-- Clear all virtual text in a buffer
function M.clear_virtual_text(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ns = init_namespace()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

-- Update virtual text for all reference tags across all files
function M.update_virtual_text_all()
  local config = require('zournal.config').get()
  local tag_cache = require('zournal.tag_cache')

  -- Check if virtual text is enabled
  if not config.virtual_text_enabled then
    return
  end

  local ns = init_namespace()

  -- Find all reference tags across all files
  local references = tag_cache.find_all_references()

  -- Group references by file
  local refs_by_file = {}
  for _, ref in ipairs(references) do
    if not refs_by_file[ref.filepath] then
      refs_by_file[ref.filepath] = {}
    end
    table.insert(refs_by_file[ref.filepath], ref)
  end

  -- Update virtual text for each file
  for filepath, file_refs in pairs(refs_by_file) do
    -- Find buffer for this file (if loaded)
    local bufnr = vim.fn.bufnr(filepath)

    -- Only update if buffer is loaded
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
      -- Check if buffer has changed since last update
      local current_tick = vim.api.nvim_buf_get_changedtick(bufnr)
      if last_changedtick[bufnr] == current_tick then
        -- Buffer hasn't changed, skip update
        goto continue
      end
      last_changedtick[bufnr] = current_tick

      -- Clear existing virtual text
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

      -- Cache window width to avoid repeated API calls
      local win_width = vim.api.nvim_win_get_width(0)

      -- Add virtual text for each reference
      for _, ref in ipairs(file_refs) do
        local original = find_original_content(ref.uuid)

        if original and original.content ~= "" then
          -- Format the virtual text (no truncation)
          local content = original.content
          local virt_text = string.format(config.virtual_text_format, content)

          -- Use virt_lines for all lines (wrapped)
          local wrapped_lines = wrap_text_for_virt_lines(virt_text, win_width - 4, "ZournalVirtualText")

          vim.api.nvim_buf_set_extmark(bufnr, ns, ref.line_num - 1, 0, {
            virt_lines = wrapped_lines,
          })
        end
      end
    end
    ::continue::
  end
end

-- Update virtual text for current buffer only
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

  -- Check if buffer has changed since last update
  local current_tick = vim.api.nvim_buf_get_changedtick(bufnr)
  if last_changedtick[bufnr] == current_tick then
    -- Buffer hasn't changed, skip update
    return
  end
  last_changedtick[bufnr] = current_tick

  local ns = init_namespace()

  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Get all lines in buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Cache window width to avoid repeated API calls
  local win_width = vim.api.nvim_win_get_width(0)

  for line_num, line_content in ipairs(lines) do
    -- Look for reference tags {zref<uuid>}
    local uuid = line_content:match("{zref([0-9a-f%-]+)}")

    if uuid then
      -- Find the original tag content (uses cache)
      local original = find_original_content(uuid)

      if original and original.content ~= "" then
        -- Format the virtual text (no truncation)
        local content = original.content
        local virt_text = string.format(config.virtual_text_format, content)

        -- Use virt_lines for all lines (wrapped)
        local wrapped_lines = wrap_text_for_virt_lines(virt_text, win_width - 4, "ZournalVirtualText")

        vim.api.nvim_buf_set_extmark(bufnr, ns, line_num - 1, 0, {
          virt_lines = wrapped_lines,
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
    -- Force update by clearing changedtick to bypass cache
    last_changedtick[bufnr] = nil
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

  -- Update virtual text on buffer enter (deferred to avoid blocking)
  vim.api.nvim_create_autocmd({'BufEnter', 'BufWinEnter'}, {
    group = group,
    pattern = '*.md',
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      -- Defer rendering to avoid blocking buffer switch
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          M.update_virtual_text(bufnr)
        end
      end, 10) -- 10ms delay - imperceptible but prevents blocking
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

  -- Clean up cache when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    pattern = '*.md',
    callback = function(args)
      local bufnr = args.buf
      last_changedtick[bufnr] = nil
    end,
  })
end

return M
