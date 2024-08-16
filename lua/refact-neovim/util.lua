local api = vim.api

local M = {}

--- Get a free TCP port.
---
--- This function creates a TCP socket, binds it to a free port (using port 0),
--- retrieves the assigned port number, and then closes the socket. It returns
--- the free port number. The port is expected to be free, but there is no
--- guarantee that it will remain free after this function returns.
---
--- @return integer: The free port number assigned by the operating system.
---
--- Usage:
--- local free_port = get_free_port()
M.get_free_port = function()
  -- Create a TCP socket
  local server = vim.uv.new_tcp()
  server:bind("127.0.0.1", 0) -- Bind to port 0
  local port = server:getsockname().port -- Get the assigned port
  server:close() -- Close the socket
  return port -- Return the free port and hope it stays free
end

--- @param buf integer: The buffer to modify.
--- @param _start integer: The starting line number for the modification.
--- @param _end integer: The ending line number for the modification.
--- @param _lines table: A table containing the lines to insert into the buffer.
---
--- Usage:
--- This function behaves similarly to `nvim_buf_set_lines`, but with the following
--- differences:
--- - Strict indexing is false.
--- - It allows modifications to a buffer that is set to non-modifiable.
--- - It keeps the buffer as non-modifiable after the modification.
--- - It automatically moves the cursor to the last character of the buffer if the
---   buffer is focused and the current mode is normal.
---
--- This function is particularly useful for updating chat history.
M.modify_buf_lines = function(buf, _start, _end, _lines)
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })

  vim.api.nvim_buf_set_lines(buf, _start, _end, false, _lines)

  -- If this window is focused move cursor to the end of the buffer
  local curr_win = vim.api.nvim_get_current_win()
  local curr_mode = vim.api.nvim_get_mode()
  local focused_bufnr = vim.api.nvim_win_get_buf(curr_win)
  if focused_bufnr == buf and curr_mode.mode == "n" then
    vim.api.nvim_feedkeys("G$", "", false)
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end
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
  return line, vim.fn.virtcol('.') - 1
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
      if type(loader) == 'function' then
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
