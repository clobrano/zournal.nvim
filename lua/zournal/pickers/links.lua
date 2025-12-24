-- Picker for link navigation
local M = {}

local links = require('zournal.links')
local utils = require('zournal.utils')
local picker = require('zournal.picker')

-- Get first line of file content for preview
local function get_first_line(filepath)
  if not utils.file_exists(filepath) then
    return "[File not found]"
  end

  local content = utils.read_file(filepath)
  if not content then
    return "[Cannot read file]"
  end

  -- Get first non-empty line
  for line in content:gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and not trimmed:match("^%-%-%-") then
      return trimmed
    end
  end

  return "[Empty file]"
end

-- Pick links from current file
function M.pick_links()
  local current_file = vim.api.nvim_buf_get_name(0)

  -- Read current file content
  local content = utils.read_file(current_file)
  if not content then
    vim.notify("Could not read current file", vim.log.levels.ERROR)
    return
  end

  -- Find all links in the file
  local all_links = links.find_all_links(content)

  if #all_links == 0 then
    vim.notify("No links found in current file", vim.log.levels.INFO)
    return
  end

  -- Build entries for picker
  local entries = {}

  for _, link in ipairs(all_links) do
    local link_text = link.text
    local link_path = nil

    if link.type == "wikilink" then
      link_path = links.resolve_link(link_text, current_file, "wikilink")
    elseif link.type == "markdown" then
      link_path = links.resolve_link(link.path, current_file, "markdown")
    end

    local target_filename = link_path and vim.fn.fnamemodify(link_path, ":t") or "[Unknown]"
    local first_line = link_path and get_first_line(link_path) or "[Broken link]"
    local is_broken = not link_path or not utils.file_exists(link_path)

    local display_text = link.type == "markdown" and link.text or link_text

    -- Build display string
    local display_prefix = is_broken and "[BROKEN] " or ""
    local display = string.format("%s%s → %s - %s",
      display_prefix,
      display_text,
      target_filename,
      first_line
    )

    table.insert(entries, {
      display = display,
      value = {
        link_text = display_text,
        filepath = link_path,
        broken = is_broken,
      },
    })
  end

  -- Show picker using abstraction
  picker.show({
    title = "Links in Current File",
    items = entries,
    on_select = function(item)
      if item.broken then
        vim.notify("Cannot open broken link: " .. item.link_text, vim.log.levels.WARN)
      else
        utils.open_file_in_buffer(item.filepath)
      end
    end,
    preview = {
      type = 'file',
      get_file = function(item)
        return item.filepath
      end,
    },
  })
end

return M
