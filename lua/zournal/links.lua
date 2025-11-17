-- Link parsing, resolution, and automatic renaming
local M = {}

local utils = require('zournal.utils')
local config = require('zournal.config')

-- Find all WikiLinks in content
-- Returns: list of {text = "link_text", start_pos = pos, end_pos = pos}
function M.find_wikilinks(content)
  local links = {}
  local pattern = "%[%[([^%]]+)%]%]"

  for link_text, pos in content:gmatch("()%[%[([^%]]+)%]%]()") do
    table.insert(links, {
      text = link_text,
      type = "wikilink"
    })
  end

  -- More precise pattern matching
  for match in content:gmatch(pattern) do
    table.insert(links, {
      text = match,
      type = "wikilink"
    })
  end

  -- Remove duplicates
  local seen = {}
  local unique_links = {}
  for _, link in ipairs(links) do
    if not seen[link.text] then
      seen[link.text] = true
      table.insert(unique_links, link)
    end
  end

  return unique_links
end

-- Find all Markdown links in content
-- Returns: list of {text = "link_text", path = "path", type = "markdown"}
function M.find_markdown_links(content)
  local links = {}
  local pattern = "%[([^%]]+)%]%(([^%)]+)%)"

  for text, path in content:gmatch(pattern) do
    table.insert(links, {
      text = text,
      path = path,
      type = "markdown"
    })
  end

  return links
end

-- Find all links (WikiLinks + Markdown links) in content
-- Returns: list of link objects
function M.find_all_links(content)
  local all_links = {}

  -- Get WikiLinks
  local wikilinks = M.find_wikilinks(content)
  for _, link in ipairs(wikilinks) do
    table.insert(all_links, link)
  end

  -- Get Markdown links
  local md_links = M.find_markdown_links(content)
  for _, link in ipairs(md_links) do
    table.insert(all_links, link)
  end

  return all_links
end

-- Resolve a link to an absolute file path
-- For WikiLinks: search in root_dir for matching filename
-- For Markdown links: resolve relative paths from current file
function M.resolve_link(link_text, current_file_path, link_type)
  local conf = config.get()
  local root_dir = vim.fn.expand(conf.root_dir)

  if link_type == "wikilink" then
    -- WikiLink: search for file in root_dir
    -- Try with and without .md extension
    local candidates = {
      link_text,
      link_text .. ".md"
    }

    for _, candidate in ipairs(candidates) do
      -- Search in root directory
      local files = utils.find_files_with_pattern(root_dir, candidate)
      if #files > 0 then
        return files[1] -- Return first match
      end
    end

    -- If not found, construct expected path
    local expected = utils.join_path(root_dir, link_text)
    if not expected:match("%.md$") then
      expected = expected .. ".md"
    end
    return expected

  elseif link_type == "markdown" then
    -- Markdown link: resolve relative to current file
    if link_text:match("^/") then
      -- Absolute path
      return link_text
    elseif link_text:match("^~") then
      -- Home directory
      return vim.fn.expand(link_text)
    else
      -- Relative path
      local current_dir = vim.fn.fnamemodify(current_file_path, ":h")
      return utils.join_path(current_dir, link_text)
    end
  end

  return nil
end

-- Get link under cursor
-- Returns: {text = "link", type = "wikilink"|"markdown", path = "resolved_path"} or nil
function M.get_link_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- Convert to 1-indexed

  -- Check for WikiLink [[...]]
  local wikilink_pattern = "%[%[([^%]]+)%]%]"
  for match_start, link_text, match_end in line:gmatch("()%[%[([^%]]+)%]%]()") do
    if col >= match_start and col < match_end then
      local current_file = vim.api.nvim_buf_get_name(0)
      local resolved_path = M.resolve_link(link_text, current_file, "wikilink")
      return {
        text = link_text,
        type = "wikilink",
        path = resolved_path
      }
    end
  end

  -- Check for Markdown link [text](path)
  local md_pattern = "%[([^%]]+)%]%(([^%)]+)%)"
  for match_start, text, path, match_end in line:gmatch("()%[([^%]]+)%]%(([^%)]+)%)()") do
    if col >= match_start and col < match_end then
      local current_file = vim.api.nvim_buf_get_name(0)
      local resolved_path = M.resolve_link(path, current_file, "markdown")
      return {
        text = text,
        type = "markdown",
        path = resolved_path
      }
    end
  end

  return nil
end

-- Follow link under cursor
function M.follow_link()
  local link = M.get_link_under_cursor()

  if not link then
    vim.notify("No link under cursor", vim.log.levels.WARN)
    return
  end

  if not link.path then
    vim.notify("Could not resolve link: " .. link.text, vim.log.levels.ERROR)
    return
  end

  -- Open the file
  utils.open_file_in_buffer(link.path)
end

-- Update links in a single file when a file is renamed
-- Replaces all occurrences of old_name with new_name in WikiLinks and Markdown links
function M.update_links_in_file(file_path, old_name, new_name)
  if not utils.file_exists(file_path) then
    return false
  end

  local content = utils.read_file(file_path)
  if not content then
    return false
  end

  local modified = false

  -- Strip .md extension for comparison
  local old_base = old_name:gsub("%.md$", "")
  local new_base = new_name:gsub("%.md$", "")

  -- Update WikiLinks: [[old_name]] -> [[new_name]]
  local updated_content = content:gsub("%[%[" .. vim.pesc(old_base) .. "%]%]", "[[" .. new_base .. "]]")
  if updated_content ~= content then
    modified = true
    content = updated_content
  end

  -- Also check with .md extension
  updated_content = content:gsub("%[%[" .. vim.pesc(old_name) .. "%]%]", "[[" .. new_name .. "]]")
  if updated_content ~= content then
    modified = true
    content = updated_content
  end

  -- Update Markdown links: [text](old_name.md) -> [text](new_name.md)
  -- Match both with and without .md
  updated_content = content:gsub("(%[.-%])%(([^%)]*)" .. vim.pesc(old_name) .. "(%)?)", "%1(%2" .. new_name .. "%3)")
  if updated_content ~= content then
    modified = true
    content = updated_content
  end

  updated_content = content:gsub("(%[.-%])%(([^%)]*)" .. vim.pesc(old_base) .. "%.md(%)?)", "%1(%2" .. new_base .. ".md%3)")
  if updated_content ~= content then
    modified = true
    content = updated_content
  end

  -- Write back if modified
  if modified then
    utils.write_file(file_path, content)
  end

  return modified
end

-- Update all links across the journal when a file is renamed
-- Searches all files in root_dir and updates references
function M.update_all_links(old_name, new_name)
  local conf = config.get()
  local root_dir = vim.fn.expand(conf.root_dir)

  -- Find all markdown files in root_dir
  local files = utils.find_files_with_pattern(root_dir, "*.md")

  local updated_count = 0
  for _, file in ipairs(files) do
    if M.update_links_in_file(file, old_name, new_name) then
      updated_count = updated_count + 1
    end
  end

  if updated_count > 0 then
    vim.notify(string.format("Updated links in %d file(s)", updated_count), vim.log.levels.INFO)
  end

  return updated_count
end

-- Setup automatic link renaming on file rename
function M.setup_auto_rename()
  -- Track old filename before rename
  local old_name = nil

  -- Listen for BufFilePost event (after file rename)
  vim.api.nvim_create_autocmd("BufFilePre", {
    group = vim.api.nvim_create_augroup("ZournalLinkRename", { clear = true }),
    pattern = "*.md",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      local conf = config.get()
      local root_dir = vim.fn.expand(conf.root_dir)

      -- Only track renames in journal directory
      if filepath:match("^" .. vim.pesc(root_dir)) then
        old_name = vim.fn.fnamemodify(filepath, ":t")
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufFilePost", {
    group = vim.api.nvim_create_augroup("ZournalLinkRename", { clear = false }),
    pattern = "*.md",
    callback = function()
      if not old_name then
        return
      end

      local bufnr = vim.api.nvim_get_current_buf()
      local new_filepath = vim.api.nvim_buf_get_name(bufnr)
      local conf = config.get()
      local root_dir = vim.fn.expand(conf.root_dir)

      -- Only handle renames in journal directory
      if new_filepath:match("^" .. vim.pesc(root_dir)) then
        local new_name = vim.fn.fnamemodify(new_filepath, ":t")

        if old_name ~= new_name then
          -- Update all links in the journal
          M.update_all_links(old_name, new_name)
        end
      end

      -- Reset tracking
      old_name = nil
    end,
  })
end

return M
