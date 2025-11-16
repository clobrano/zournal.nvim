-- Zettelkasten ID system, child/sibling/parent logic
local M = {}

local config = require("zournal.config")
local utils = require("zournal.utils")
local frontmatter = require("zournal.frontmatter")

-- ============================================================================
-- ZID Validation (7.1)
-- ============================================================================

--- Check if zid is valid (alternating number/letter pattern)
---@param zid string
---@return boolean
function M.is_valid_zid(zid)
  if not zid or type(zid) ~= "string" or zid == "" then
    return false
  end

  -- Pattern: starts with digit, then alternates between letters and digits
  -- Examples: 1, 1a, 1a2, 1a2b, 1a2b3
  -- Must start with a number
  if not zid:match("^%d") then
    return false
  end

  -- Check alternating pattern: digit -> letter -> digit -> letter...
  local expecting_letter = true
  local i = 2
  while i <= #zid do
    local char = zid:sub(i, i)
    if expecting_letter then
      if not char:match("%a") then
        return false
      end
      expecting_letter = false
    else
      if not char:match("%d") then
        return false
      end
      expecting_letter = true
    end
    i = i + 1
  end

  return true
end

-- ============================================================================
-- ZID Parsing Functions (7.2)
-- ============================================================================

--- Get parent zid by removing last segment
---@param zid string
---@return string|nil parent_zid
function M.get_parent_zid(zid)
  if not M.is_valid_zid(zid) then
    return nil
  end

  -- If root (single number), no parent
  if zid:match("^%d+$") then
    return nil
  end

  -- Remove last segment (either a letter or a number)
  -- Examples: 1a3 -> 1a, 1a -> 1, 1a3c -> 1a3
  local parent = zid:sub(1, -2)
  return parent
end

--- Get root zid (first number)
---@param zid string
---@return string|nil root_zid
function M.get_root_zid(zid)
  if not M.is_valid_zid(zid) then
    return nil
  end

  -- Extract leading digits
  local root = zid:match("^(%d+)")
  return root
end

-- ============================================================================
-- Next ZID Generation (7.3)
-- ============================================================================

--- Parse zid segments into a table
---@param zid string|number
---@return table segments List of segments
local function parse_segments(zid)
  -- Convert to string if needed
  zid = tostring(zid)

  local segments = {}
  local i = 1
  while i <= #zid do
    local char = zid:sub(i, i)
    if char:match("%d") then
      -- Collect all consecutive digits
      local num = ""
      while i <= #zid and zid:sub(i, i):match("%d") do
        num = num .. zid:sub(i, i)
        i = i + 1
      end
      table.insert(segments, tonumber(num))
    elseif char:match("%a") then
      table.insert(segments, char)
      i = i + 1
    else
      i = i + 1
    end
  end
  return segments
end

--- Build zid from segments
---@param segments table
---@return string
local function build_zid(segments)
  local result = ""
  for _, seg in ipairs(segments) do
    result = result .. tostring(seg)
  end
  return result
end

--- Get next child zid
---@param parent_zid string
---@param existing_children table List of existing child zids
---@return string next_child_zid
function M.get_next_child_zid(parent_zid, existing_children)
  existing_children = existing_children or {}

  local segments = parse_segments(parent_zid)
  local last_segment = segments[#segments]

  -- If parent ends in number, append next letter (starting from 'a')
  if type(last_segment) == "number" then
    -- Find used letters at this level
    local used_letters = {}
    for _, child in ipairs(existing_children) do
      local child_segments = parse_segments(child)
      if #child_segments == #segments + 1 then
        local child_letter = child_segments[#child_segments]
        if type(child_letter) == "string" then
          used_letters[child_letter] = true
        end
      end
    end

    -- Find first available letter (fill gaps)
    for i = string.byte("a"), string.byte("z") do
      local letter = string.char(i)
      if not used_letters[letter] then
        table.insert(segments, letter)
        return build_zid(segments)
      end
    end

    -- If all letters used, just append 'a' (shouldn't happen in practice)
    table.insert(segments, "a")
    return build_zid(segments)
  else
    -- If parent ends in letter, append next number (starting from 1)
    -- Find used numbers at this level
    local used_numbers = {}
    for _, child in ipairs(existing_children) do
      local child_segments = parse_segments(child)
      if #child_segments == #segments + 1 then
        local child_num = child_segments[#child_segments]
        if type(child_num) == "number" then
          used_numbers[child_num] = true
        end
      end
    end

    -- Find first available number (fill gaps)
    for i = 1, 1000 do
      if not used_numbers[i] then
        table.insert(segments, i)
        return build_zid(segments)
      end
    end

    -- Fallback
    table.insert(segments, 1)
    return build_zid(segments)
  end
end

--- Get next sibling zid
---@param zid string
---@param existing_siblings table List of existing sibling zids
---@return string next_sibling_zid
function M.get_next_sibling_zid(zid, existing_siblings)
  existing_siblings = existing_siblings or {}

  local segments = parse_segments(zid)
  local last_segment = segments[#segments]

  if type(last_segment) == "string" then
    -- If ends in letter, increment letter
    local used_letters = {}
    for _, sibling in ipairs(existing_siblings) do
      local sib_segments = parse_segments(sibling)
      if #sib_segments == #segments then
        local sib_letter = sib_segments[#sib_segments]
        if type(sib_letter) == "string" then
          used_letters[sib_letter] = true
        end
      end
    end

    -- Find first available letter after current (or fill gaps)
    local current_byte = string.byte(last_segment)
    for i = string.byte("a"), string.byte("z") do
      local letter = string.char(i)
      if i > current_byte and not used_letters[letter] then
        segments[#segments] = letter
        return build_zid(segments)
      end
    end

    -- If no available letter found, increment current
    segments[#segments] = string.char(current_byte + 1)
    return build_zid(segments)
  else
    -- If ends in number, increment number
    local used_numbers = {}
    for _, sibling in ipairs(existing_siblings) do
      local sib_segments = parse_segments(sibling)
      if #sib_segments == #segments then
        local sib_num = sib_segments[#sib_segments]
        if type(sib_num) == "number" then
          used_numbers[sib_num] = true
        end
      end
    end

    -- Find first available number after current (or fill gaps)
    for i = 1, 1000 do
      if i > last_segment and not used_numbers[i] then
        segments[#segments] = i
        return build_zid(segments)
      end
    end

    -- Fallback: increment current
    segments[#segments] = last_segment + 1
    return build_zid(segments)
  end
end

-- ============================================================================
-- Relationship Queries (7.4)
-- ============================================================================

--- Find all markdown files in root_dir
---@return table files List of file paths
local function find_all_markdown_files()
  local cfg = config.get()
  return utils.find_files_with_pattern(cfg.root_dir, "%.md$")
end

--- Find notes by zid pattern
---@param pattern string ZID or pattern to match
---@return table notes List of {path, zid} tables
function M.find_notes_by_zid_pattern(pattern)
  local files = find_all_markdown_files()
  local results = {}

  for _, file_path in ipairs(files) do
    local zid = frontmatter.get_zid(file_path)
    if zid and tostring(zid):match(pattern) then
      table.insert(results, { path = file_path, zid = tostring(zid) })
    end
  end

  return results
end

--- Get all children of a parent zid
---@param parent_zid string
---@return table children List of {path, zid} tables
function M.get_children(parent_zid)
  if not M.is_valid_zid(parent_zid) then
    return {}
  end

  local files = find_all_markdown_files()
  local children = {}
  local parent_segments = parse_segments(parent_zid)

  for _, file_path in ipairs(files) do
    local zid = frontmatter.get_zid(file_path)
    if zid then
      zid = tostring(zid) -- Ensure zid is a string
      local zid_segments = parse_segments(zid)
      -- Child has exactly one more segment than parent
      if #zid_segments == #parent_segments + 1 then
        -- Check if all parent segments match
        local matches = true
        for i = 1, #parent_segments do
          if zid_segments[i] ~= parent_segments[i] then
            matches = false
            break
          end
        end
        if matches then
          table.insert(children, { path = file_path, zid = zid })
        end
      end
    end
  end

  return children
end

--- Get all siblings of a zid
---@param zid string
---@return table siblings List of {path, zid} tables
function M.get_siblings(zid)
  if not M.is_valid_zid(zid) then
    return {}
  end

  -- Get parent and find its children (excluding self)
  local parent_zid = M.get_parent_zid(zid)
  if not parent_zid then
    -- Root note - find all other root notes
    local files = find_all_markdown_files()
    local siblings = {}
    for _, file_path in ipairs(files) do
      local other_zid = frontmatter.get_zid(file_path)
      if other_zid then
        other_zid = tostring(other_zid)
        if other_zid ~= zid and M.get_parent_zid(other_zid) == nil then
          table.insert(siblings, { path = file_path, zid = other_zid })
        end
      end
    end
    return siblings
  end

  -- Get all children of parent
  local parent_children = M.get_children(parent_zid)
  local siblings = {}
  for _, child in ipairs(parent_children) do
    if tostring(child.zid) ~= tostring(zid) then
      table.insert(siblings, child)
    end
  end

  return siblings
end

--- Get parent note
---@param zid string
---@return table|nil parent {path, zid} or nil if no parent
function M.get_parent(zid)
  if not M.is_valid_zid(zid) then
    return nil
  end

  local parent_zid = M.get_parent_zid(zid)
  if not parent_zid then
    return nil
  end

  -- Find file with parent zid
  local files = find_all_markdown_files()
  for _, file_path in ipairs(files) do
    local file_zid = frontmatter.get_zid(file_path)
    -- Convert both to strings for comparison (frontmatter might store numbers)
    if file_zid and tostring(file_zid) == tostring(parent_zid) then
      return { path = file_path, zid = tostring(file_zid) }
    end
  end

  return nil
end

return M
