local api = vim.api

local M = {}

function M.split_str(str, separator)
  local parts = {}
  local start = 1
  local split_start, split_end = string.find(str, separator, start)

  while split_start do
    table.insert(parts, string.sub(str, start, split_start - 1))
    start = split_end + 1
    split_start, split_end = string.find(str, separator, start)
  end

  table.insert(parts, string.sub(str, start))
  return parts
end

function M.get_cursor_pos()
  return unpack(api.nvim_win_get_cursor(0))
end

function M.get_screen_pos()
  local line = api.nvim_win_get_cursor(0)[1]
  return line, vim.fn.virtcol(".") - 1
end

function M.get_current_line()
  local line, _ = M.get_cursor_pos()
  return api.nvim_buf_get_lines(0, line - 1, line, true)[1]
end

function M.get_till_end_of_current_line()
  local line, col = M.get_cursor_pos()
  local current_line = api.nvim_buf_get_lines(0, line - 1, line, true)[1]
  return string.sub(current_line, col + 1)
end

function M.is_only_white_space(str)
  return str:match("^%s*$") ~= nil
end

function M.is_module_available(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.loaders) do
      local loader = searcher(name)
      if type(loader) == "function" then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end

function M.try_require(name)
  if not M.is_module_available(name) then
    return nil
  else
    return require(name)
  end
end

return M
