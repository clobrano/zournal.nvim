-- Picker for Zettelkasten relationships
local M = {}

local zettelkasten = require('zournal.zettelkasten')
local frontmatter = require('zournal.frontmatter')
local utils = require('zournal.utils')
local picker = require('zournal.picker')

-- Get first line of file content for preview
local function get_first_line(filepath)
  if not utils.file_exists(filepath) then
    return ""
  end

  local content = utils.read_file(filepath)
  if not content then
    return ""
  end

  -- Get first non-empty line
  for line in content:gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and not trimmed:match("^%-%-%-") then
      return trimmed
    end
  end

  return ""
end

-- Pick related notes (parent, siblings, children)
function M.pick_relations()
  -- Get current file's zid
  local current_file = vim.api.nvim_buf_get_name(0)
  local zid = frontmatter.get_zid(current_file)

  if not zid then
    vim.notify("Current file does not have a zid in frontmatter", vim.log.levels.ERROR)
    return
  end

  -- Find related notes
  local parent = zettelkasten.get_parent(zid)
  local siblings = zettelkasten.get_siblings(zid)
  local children = zettelkasten.get_children(zid)

  -- Build entries for picker
  local entries = {}

  -- Add parent
  if parent and parent.path then
    local first_line = get_first_line(parent.path)
    local filename = vim.fn.fnamemodify(parent.path, ":t")
    local display = string.format("[Parent] %s - %s", filename, first_line)

    table.insert(entries, {
      display = display,
      value = {
        type = "Parent",
        filepath = parent.path,
        zid = parent.zid,
      },
    })
  end

  -- Add siblings
  for _, sibling in ipairs(siblings) do
    if sibling.path and sibling.path ~= current_file then
      local first_line = get_first_line(sibling.path)
      local filename = vim.fn.fnamemodify(sibling.path, ":t")
      local display = string.format("[Sibling] %s - %s", filename, first_line)

      table.insert(entries, {
        display = display,
        value = {
          type = "Sibling",
          filepath = sibling.path,
          zid = sibling.zid,
        },
      })
    end
  end

  -- Add children
  for _, child in ipairs(children) do
    if child.path then
      local first_line = get_first_line(child.path)
      local filename = vim.fn.fnamemodify(child.path, ":t")
      local display = string.format("[Child] %s - %s", filename, first_line)

      table.insert(entries, {
        display = display,
        value = {
          type = "Child",
          filepath = child.path,
          zid = child.zid,
        },
      })
    end
  end

  -- Check if there are any relations
  if #entries == 0 then
    vim.notify("No related notes found", vim.log.levels.INFO)
    return
  end

  -- Show picker using abstraction
  picker.show({
    title = "Zettelkasten Relations",
    items = entries,
    on_select = function(item)
      utils.open_file_in_buffer(item.filepath)
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
