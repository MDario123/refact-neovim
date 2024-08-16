local Job = require("plenary.job")

local lsp = require("refact-neovim.lsp")
local config = require("refact-neovim.config").get()
assert(config, "[REFACT] Config not found, did you run `refact-neovim.setup`?")

local modify_buf_lines = require("refact-neovim.util").modify_buf_lines

-- As a function so that every time it produces a different table
local default_history = function()
  return { {
    role = "system",
    content = config.chat.prompt,
  } }
end

local M = {
  history = default_history(),
  buf = nil,
  state = {
    busy = false,
  },
}

--- This function appends the user's message to the chat history, and sends it to the assistant.
--- It then waits for the assistant to send a response, and appends it to the chat history.
--- It also manages the chat history and updates the specified buffer with the conversation.
---
--- @param model string: The model to be used for generating the response.
--- @param message string: The user's message to be sent to the assistant.
---
--- @return boolean: If the request was successful.
---
--- Returns true if the request was initiated successfully,
---                  and false if there was an error (e.g., if the setup was not called,
---                  or if a previous request is still being processed).
---
--- @note This function requires that `setup` has been called prior to its invocation.
---       It also ensures that only one request is processed at a time to prevent
---       overlapping requests.
---
--- @usage
--- local success = M.fetch_chat_promise("gpt-3.5-turbo", "Hello, how are you?")
--- if not success then
---   print("Failed to fetch response.")
--- end
M.fetch_chat_promise = function(model, message)
  if not M.buf then
    vim.notify("[REFACT] You must call `setup` before calling `fetch_chat_promise`.", vim.log.levels.ERROR)
    return false
  end
  if M.state.busy then
    vim.notify("[REFACT] Currently busy with another request.", vim.log.levels.ERROR)
    return false
  end
  -- Set busy to true so that you can't call while it's already answering
  M.state.busy = true

  table.insert(M.history, { role = "user", content = message })
  local messages = M.history
  local url = "127.0.0.1:" .. lsp.port .. "/v1/chat"
  local body = vim.fn.json_encode({
    messages = messages,
    model = model,
    parameters = {
      max_new_tokens = config.chat.max_tokens,
    },
    stream = true,
  })

  -- Set user message in the buffer
  modify_buf_lines(M.buf, -1, -1, { "[REFACT] User:", message, "" })

  -- To delete new ones if necessary
  local chat_line_count = vim.api.nvim_buf_line_count(M.buf)

  -- Set assistant response tag
  modify_buf_lines(M.buf, -1, -1, { "[REFACT] Assistant:", "" })

  -- Store the return values in a table for it to act as a reference
  local full_msg = ""

  -- Function to call curl and process its output
  Job:new({
    command = "curl",
    args = {
      "-s",
      url,
      "-H",
      "Content-Type=application/json",
      "-H",
      "Authorization=Bearer " .. config.api_key,
      "--json",
      body,
      "--no-buffer",
    },
    on_stdout = function(_, line)
      vim.schedule(function()
        local output = line
        local token = ""
        -- Get the token, if any
        if output ~= "" then
          local value = output:sub(7)
          if value ~= "[DONE]" then
            local ob = vim.fn.json_decode(value)
            if ob.content == nil then
              if not (ob.choices[1].delta.content == vim.NIL) then
                token = ob.choices[1].delta.content
              end
            end
          end
        end
        full_msg = full_msg .. token
        -- write token to buffer

        local last_line = vim.api.nvim_buf_get_lines(M.buf, -2, -1, false)
        local x = require("refact-neovim.util").split_str(last_line[1] .. token, "\n")
        modify_buf_lines(M.buf, -2, -1, x)
      end)
    end,
    on_exit = function(j, result)
      vim.schedule(function()
        M.state.busy = false
        local finished_successfully = result == 0

        -- Show errrs such as "Model not found"
        local success, response = pcall(vim.fn.json_decode, j:result())
        if success and response.detail then
          vim.notify(response.detail, vim.log.levels.ERROR)
        end

        if finished_successfully then
          table.insert(M.history, { role = "assistant", content = full_msg })
          modify_buf_lines(M.buf, -1, -1, { "", "[REFACT] End transmission.", "" })
        else
          table.remove(M.history)
          -- TODO: Maybe a more helpful error message, maybe what comes from curl's stderr, maybe with a toggle in config
          -- Replaces assistant response with error message
          modify_buf_lines(
            M.buf,
            chat_line_count,
            -1,
            { "[REFACT] Error:\n", "Something went wrong, please check everything and try again", "\n" }
          )
        end
      end)
    end,
  }):start() -- Start the job
end

M.send_prompt = function(message)
  M.fetch_chat_promise(config.chat.model, message)
  return true
end

M.setup = function()
  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = M.buf })
  vim.api.nvim_buf_set_lines(M.buf, -2, -1, false, { "[REFACT] System to AI:", M.history[1].content, "" })
  vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })

  vim.api.nvim_create_user_command("RefactChat", function(opts)
    local worked = M.send_prompt(opts.args)
    if worked then
      config.chat.show_history(M.buf)
    end
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("RefactChatShow", function(_)
    config.chat.show_history(M.buf)
  end, { nargs = 0 })

  vim.api.nvim_create_user_command("RefactChatClear", function(_)
    if M.state.busy then
      vim.notify("[REFACT] Currently busy with another request.", vim.log.levels.ERROR)
      return false
    end
    M.history = default_history()
    modify_buf_lines(M.buf, 0, -1, { "[REFACT] System to AI:", M.history[1].content, "" })
  end, { nargs = 0 })
end

return M
