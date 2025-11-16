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
---@param content string File content
---@return table result Table with 'frontmatter' and 'body' keys
function M.parse_frontmatter(content)
  if not content or content == "" then
    return { frontmatter = {}, body = "" }
  end

  -- Check for frontmatter delimiters (---)
  local frontmatter_pattern = "^%-%-%-\n(.-)%-%-%-\n(.*)$"
  local yaml_content, body = content:match(frontmatter_pattern)

  if yaml_content and body then
    return {
      frontmatter = parse_yaml(yaml_content),
      body = body,
    }
  end

  -- No frontmatter found
  return {
    frontmatter = {},
    body = content,
  }
end

--- Serialize frontmatter data to YAML string with delimiters
---@param data table Frontmatter data
---@return string
function M.serialize_frontmatter(data)
  if not data or vim.tbl_isempty(data) then
    return ""
  end

  local yaml = serialize_yaml(data)
  return "---\n" .. yaml .. "\n---\n"
end

-- ============================================================================
-- Frontmatter Update Functions (4.3)
-- ============================================================================

--- Update frontmatter in a file
---@param file_path string
---@param updates table Fields to update in frontmatter
---@return boolean success
function M.update_frontmatter(file_path, updates)
  if not file_path or not updates then
    return false
  end

  -- Read file content
  local content = utils.read_file(file_path)

  -- If file doesn't exist, create with frontmatter only
  if not content then
    local frontmatter_str = M.serialize_frontmatter(updates)
    return utils.write_file(file_path, frontmatter_str)
  end

  -- Parse existing frontmatter
  local parsed = M.parse_frontmatter(content)

  -- Merge updates with existing frontmatter
  for key, value in pairs(updates) do
    parsed.frontmatter[key] = value
  end

  -- Reconstruct file content
  local new_content = M.serialize_frontmatter(parsed.frontmatter) .. parsed.body

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
