-- YAML frontmatter parsing and manipulation
local M = {}

local utils = require("zournal.utils")

-- ============================================================================
-- YAML Parsing and Serialization (4.1 & 4.2)
-- ============================================================================

--- Simple YAML parser for frontmatter
--- Note: This is a minimal parser for basic key-value pairs
---@param yaml_string string
---@return table
local function parse_yaml(yaml_string)
  local result = {}

  if not yaml_string or yaml_string == "" then
    return result
  end

  for line in yaml_string:gmatch("[^\r\n]+") do
    -- Match key: value pattern
    local key, value = line:match("^([%w_]+):%s*(.*)$")
    if key and value then
      -- Trim quotes if present
      value = value:gsub('^["\'](.-)["\']*$', '%1')
      -- Convert to number if possible
      local num = tonumber(value)
      if num then
        result[key] = num
      else
        result[key] = value
      end
    end
  end

  return result
end

--- Simple YAML serializer for frontmatter
---@param data table
---@return string
local function serialize_yaml(data)
  local lines = {}

  for key, value in pairs(data) do
    if type(value) == "string" then
      -- Quote strings if they contain special characters
      if value:match("[:#%[%]{}]") then
        table.insert(lines, string.format("%s: \"%s\"", key, value))
      else
        table.insert(lines, string.format("%s: %s", key, value))
      end
    else
      table.insert(lines, string.format("%s: %s", key, tostring(value)))
    end
  end

  -- Sort for consistency
  table.sort(lines)

  return table.concat(lines, "\n")
end

--- Parse frontmatter from file content
--- Supports two formats:
--- 1. After first header: # Title\n---\nkey: value\n---\nContent
--- 2. At file start (legacy): ---\nkey: value\n---\n# Title\nContent
---@param content string File content
---@return table result Table with 'frontmatter', 'body', and 'title' keys
function M.parse_frontmatter(content)
  if not content or content == "" then
    return { frontmatter = {}, body = "", title = "" }
  end

  -- Try to match frontmatter after first header (new format)
  -- Pattern: # Title\n\n---\nYAML\n---\nBody
  local title, yaml_content, body = content:match("^(#[^\n]+)\n+%-%-%-\n(.-)%-%-%-\n(.*)$")

  if title and yaml_content then
    return {
      frontmatter = parse_yaml(yaml_content),
      body = body,
      title = title,
    }
  end

  -- Try to match frontmatter at file start (legacy format)
  -- Pattern: ---\nYAML\n---\nBody (which may include title)
  yaml_content, body = content:match("^%-%-%-\n(.-)%-%-%-\n(.*)$")

  if yaml_content and body then
    -- Extract title from body if present (with optional whitespace)
    local first_line = body:match("^%s*(#[^\n]+)")
    return {
      frontmatter = parse_yaml(yaml_content),
      body = body,
      title = first_line or "",
    }
  end

  -- No frontmatter found - check if there's a title
  local first_line = content:match("^%s*(#[^\n]+)")
  return {
    frontmatter = {},
    body = content,
    title = first_line or "",
  }
end

--- Serialize frontmatter data to YAML string with delimiters
--- If title is provided, places frontmatter after the title
---@param data table Frontmatter data
---@param title string|nil Optional title (e.g., "# My Note")
---@return string
function M.serialize_frontmatter(data, title)
  if not data or vim.tbl_isempty(data) then
    if title then
      return title .. "\n\n"
    end
    return ""
  end

  local yaml = serialize_yaml(data)
  local frontmatter_block = "---\n" .. yaml .. "\n---\n"

  if title and title ~= "" then
    -- Place frontmatter after title
    return title .. "\n\n" .. frontmatter_block
  else
    -- No title, return frontmatter at start (legacy behavior)
    return frontmatter_block
  end
end

-- ============================================================================
-- Frontmatter Update Functions (4.3)
-- ============================================================================

--- Update frontmatter in a file
--- Places frontmatter after first header if title exists
---@param file_path string
---@param updates table Fields to update in frontmatter
---@param title string|nil Optional title to use if creating new file
---@return boolean success
function M.update_frontmatter(file_path, updates, title)
  if not file_path or not updates then
    return false
  end

  -- Read file content
  local content = utils.read_file(file_path)

  -- If file doesn't exist, create with frontmatter (and optional title)
  if not content then
    local frontmatter_str = M.serialize_frontmatter(updates, title)
    return utils.write_file(file_path, frontmatter_str)
  end

  -- Parse existing frontmatter
  local parsed = M.parse_frontmatter(content)

  -- Merge updates with existing frontmatter
  for key, value in pairs(updates) do
    parsed.frontmatter[key] = value
  end

  -- Reconstruct file content
  -- Use existing title if found, otherwise use provided title
  local file_title = parsed.title ~= "" and parsed.title or title
  local new_content = M.serialize_frontmatter(parsed.frontmatter, file_title) .. parsed.body

  -- Write back to file
  return utils.write_file(file_path, new_content)
end

-- ============================================================================
-- Frontmatter Getter/Setter Functions (4.4)
-- ============================================================================

--- Get zid from file frontmatter
---@param file_path string
---@return string|nil zid
function M.get_zid(file_path)
  if not file_path then
    return nil
  end

  local content = utils.read_file(file_path)
  if not content then
    return nil
  end

  local parsed = M.parse_frontmatter(content)
  return parsed.frontmatter.zid
end

--- Set zid in file frontmatter
---@param file_path string
---@param zid string
---@return boolean success
function M.set_zid(file_path, zid)
  if not file_path or not zid then
    return false
  end

  return M.update_frontmatter(file_path, { zid = zid })
end

return M
