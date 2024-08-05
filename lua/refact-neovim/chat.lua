local curl = require("plenary.curl")
local util = require("refact-neovim.util")

local config = require("refact-neovim.config").get()
assert(config, "[REFACT] Config not found, did you run `refact-neovim.setup`?")

local M = {
  history = { {
    role = "system",
    content = config.chat.default_prompt,
  } },
}

local function fetch_chat_promise(model)
  local messages = M.history
  local url = "127.0.0.1:" .. config.http_port .. "/v1/chat"

  -- TODO: stream the response
  local response = curl.post(url, {
    headers = {
      ["Content-Type"] = "application/json",
      Authorization = "Bearer " .. config.api_key,
    },
    body = vim.fn.json_encode({
      messages = messages,
      model = model,
      parameters = {
        max_new_tokens = 1000,
      },
      stream = true,
    }),
    timeout = 100000,
  })

  if not (response.status == 200) then
    vim.notify("[REFACT] " .. vim.inspect(response), vim.log.levels.DEBUG)
    return nil
  end

  local response_body = util.split_str(response.body, "\n\n")

  -- To be filled in the next for loop
  local full_msg = ""

  -- Take the first choice as the full message
  -- TODO: handle multiple choices
  for _, value in ipairs(response_body) do
    -- remove first 6 characters from value, which has the form "data: {... }", to keep only the json valid content
    value = value:sub(7)

    local ob = vim.fn.json_decode(value)
    if ob.content == nil then
      if ob.choices[1].delta.content == vim.NIL then
        break
      end
      full_msg = full_msg .. ob.choices[1].delta.content
    end
  end

  table.insert(M.history, { role = "assistant", content = full_msg })
  return full_msg
end

M.send_prompt = function(message, model)
  table.insert(M.history, { role = "user", content = message })
  return fetch_chat_promise(model)
end

M.send_prompt_common = function(message)
  local response = M.send_prompt(message, config.chat.default_model)
  if response then
    vim.notify("[REFACT] AI: " .. response, vim.log.levels.INFO)
  else
    vim.notify("[REFACT] Error while getting response from chat.", vim.log.levels.ERROR)
  end
end

M.setup = function()
  vim.api.nvim_create_user_command("RefactChat", function(opts)
    M.send_prompt_common(opts.args)
  end, { nargs = 1 })
end

return M
