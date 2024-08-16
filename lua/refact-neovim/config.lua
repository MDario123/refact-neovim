local default_config = {
  -- For enterprice, put there your company's server address. Your admin should have emailed that to you.
  -- For Self-Hosted, use something like "http://127.0.0.1:8008"
  -- For inference in public cloud, use "Refact" or "HF".
  address_url = "Refact",

  -- Secret API Key, It's used to authenticate your requests.
  api_key = "",

  -- Path to LSP binary if you have it installed.
  --- @type string | nil
  lsp_bin = nil,

  -- Keymap for completion.
  accept_keymap = "<Tab>",

  -- Keymap for pausing autocompletion.
  --- @type string | nil
  pause_keymap = nil,

  -- How many milliseconds to wait before triggering a new request.
  debounce_ms = 200,

  -- Allow insecure server connections when using SSL, ignore certificate verification errors. Allows you to use self-signed certificates
  insecure_ssl = false,

  -- Maximum number of tokens to generate for code completion.
  max_tokens = 50,

  -- Send code snippets as corrected by you, in a form suitable to improve model quality.
  telemetry_code_snippets = false,

  -- Enable embedded vector database (VecDB) for search (experimental)
  vecdb = false,

  -- Enable Abstract Syntax Tree (AST) parser, works only for popular languages.
  -- Helps with code completion.
  ast = true,

  -- Limit the number of files for AST to process, to avoid memory issues.
  -- Increase this number if you have a large project and sufficient memory.
  ast_file_limit = 15000,

  -- Expression that is used to decide if it should do single line code completion.
  completion_expression = "^[%s%]:(){},.\"';>]*$",

  -- Configuration for chat, called with `:RefactChat`.
  chat = {
    -- System prompt, you might use to set your assistant's context, personality, etc.
    --- @type string
    prompt = "",

    -- Chat model, an empty string will use the default one,
    -- putting a wrong one will tell you which ones are available, when you call `:RefactChat`.
    --- @type string
    model = "",

    -- Maximum number of tokens to generate for chat response.
    max_tokens = 2000,

    -- Function that takes a buffer that contains the chat history, will be called on `:RefactChatShow` command.
    show_history = function(buffer)
      local function is_buffer_visible(bufnr)
        -- Get the list of all window IDs
        local windows = vim.api.nvim_list_wins()

        -- Iterate through each window
        for _, win_id in ipairs(windows) do
          -- Get the buffer associated with the window
          local visible_bufnr = vim.api.nvim_win_get_buf(win_id)

          -- Check if the buffer number matches
          if visible_bufnr == bufnr then
            return true, win_id -- The buffer is visible
          end
        end

        return false, nil -- The buffer is not visible
      end

      local visible, win_id = is_buffer_visible(buffer)

      if not visible then
        vim.cmd("vsplit")
        vim.api.nvim_set_current_buf(buffer)
      else
        assert(win_id, "If the buffer is visible, it must have a window ID")
        vim.api.nvim_set_current_win(win_id)
      end
    end,
  },
}

local M = {
  config = nil,
}

function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
end

function M.get()
  if M.config == nil then
    vim.notify("[REFACT] config is not initialized", vim.log.levels.ERROR)
    return nil
  end

  return M.config
end

return M
