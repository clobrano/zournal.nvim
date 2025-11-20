-- Caching layer for tag UUID lookups
local M = {}

-- Cache structure:
-- {
--   uuid = {
--     content = "original line content",
--     filepath = "/path/to/file.md",
--     line_num = 42,
--     last_updated = timestamp,
--     file_mtimes = {[filepath] = mtime, ...}  -- All files that had this UUID
--   }
-- }
local cache = {}

-- Get cache statistics
function M.get_stats()
  local count = 0
  for _ in pairs(cache) do
    count = count + 1
  end
  return {
    entries = count,
    cache_hits = M.stats_hits or 0,
    cache_misses = M.stats_misses or 0,
  }
end

-- Clear all cache entries
function M.clear_cache()
  cache = {}
  M.stats_hits = 0
  M.stats_misses = 0
end

-- Check if a cache entry is still valid
local function is_cache_valid(entry, config)
  if not entry then
    return false
  end

  local ttl = config.tag_cache_ttl or 300  -- 5 minutes default
  local age = os.time() - (entry.last_updated or 0)

  -- Check TTL
  if age > ttl then
    return false
  end

  -- Check if any source files have been modified
  for filepath, cached_mtime in pairs(entry.file_mtimes or {}) do
    local stat = vim.loop.fs_stat(filepath)
    if not stat or stat.mtime.sec ~= cached_mtime then
      return false
    end
  end

  return true
end

-- Find original tag content by scanning all files
-- Returns: {content, filepath, line_num}
local function scan_for_original(uuid, config)
  local utils = require('zournal.utils')

  -- Find all markdown files
  local files = utils.find_files_with_pattern(config.root_dir, "%.md$")

  local occurrences = {}
  local file_mtimes = {}

  for _, filepath in ipairs(files) do
    local stat = vim.loop.fs_stat(filepath)
    if stat then
      file_mtimes[filepath] = stat.mtime.sec
    end

    local content = utils.read_file(filepath)
    if content then
      local line_num = 0
      -- Split by newlines but keep empty lines
      for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        line_num = line_num + 1
        -- Look for original tag {ztag<uuid>}
        local ztag_match = line:match("{ztag" .. vim.pesc(uuid) .. "}")

        if ztag_match then
          -- Found original tag - extract line content without the tag
          local clean_content = line:gsub("{ztag" .. vim.pesc(uuid) .. "}", ""):match("^%s*(.-)%s*$")

          table.insert(occurrences, {
            content = clean_content,
            filepath = filepath,
            line_num = line_num,
            mtime = stat and stat.mtime.sec or 0,
          })
        end
      end
    end
  end

  if #occurrences == 0 then
    return nil, file_mtimes
  end

  -- Sort by modification time (oldest first = original)
  table.sort(occurrences, function(a, b) return a.mtime < b.mtime end)

  return occurrences[1], file_mtimes
end

-- Get original tag content for a UUID (with caching)
function M.get_original_content(uuid)
  local config = require('zournal.config').get()
  local entry = cache[uuid]

  -- Check cache validity
  if is_cache_valid(entry, config) then
    M.stats_hits = (M.stats_hits or 0) + 1
    return {
      content = entry.content,
      filepath = entry.filepath,
      line_num = entry.line_num,
    }
  end

  -- Cache miss or stale - rescan
  M.stats_misses = (M.stats_misses or 0) + 1

  local original, file_mtimes = scan_for_original(uuid, config)

  if original then
    -- Store in cache
    cache[uuid] = {
      content = original.content,
      filepath = original.filepath,
      line_num = original.line_num,
      last_updated = os.time(),
      file_mtimes = file_mtimes,
    }

    return {
      content = original.content,
      filepath = original.filepath,
      line_num = original.line_num,
    }
  end

  return nil
end

-- Find all reference tags (with their UUIDs) across all markdown files
-- Returns: array of {uuid, filepath, line_num, line_content}
function M.find_all_references()
  local config = require('zournal.config').get()
  local utils = require('zournal.utils')

  local files = utils.find_files_with_pattern(config.root_dir, "%.md$")
  local references = {}

  for _, filepath in ipairs(files) do
    local content = utils.read_file(filepath)
    if content then
      local line_num = 0
      -- Split by newlines but keep empty lines
      for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        line_num = line_num + 1
        -- Look for reference tags {zref<uuid>}
        local uuid = line:match("{zref([0-9a-f%-]+)}")

        if uuid then
          table.insert(references, {
            uuid = uuid,
            filepath = filepath,
            line_num = line_num,
            line_content = line,
          })
        end
      end
    end
  end

  return references
end

-- Preload cache by scanning all files once
-- Useful for initial load or after workspace switch
function M.preload_cache()
  local config = require('zournal.config').get()
  local utils = require('zournal.utils')

  -- Find all markdown files
  local files = utils.find_files_with_pattern(config.root_dir, "%.md$")

  local uuids = {}
  local file_mtimes = {}

  -- First pass: collect all UUIDs and file mtimes
  for _, filepath in ipairs(files) do
    local stat = vim.loop.fs_stat(filepath)
    if stat then
      file_mtimes[filepath] = stat.mtime.sec
    end

    local content = utils.read_file(filepath)
    if content then
      -- Find all tags (both ztag and zref)
      for uuid in content:gmatch("{z[tr][ea][fg]([0-9a-f%-]+)}") do
        uuids[uuid] = true
      end
    end
  end

  -- Second pass: for each unique UUID, find the original
  for uuid in pairs(uuids) do
    -- Check if already cached and valid
    if not is_cache_valid(cache[uuid], config) then
      -- Scan for this UUID's original
      local original, _ = scan_for_original(uuid, config)

      if original then
        cache[uuid] = {
          content = original.content,
          filepath = original.filepath,
          line_num = original.line_num,
          last_updated = os.time(),
          file_mtimes = file_mtimes,  -- Use global file mtimes snapshot
        }
      end
    end
  end

  return M.get_stats()
end

return M
