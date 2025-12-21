-- ~/.config/nvim/lua/plugins/conform.lua
return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_fallback = true })
      end,
      mode = { "n", "v" },
      desc = "Format buffer",
    },
  },
  opts = {
    formatters_by_ft = {
      -- lua
      lua = { "stylua" },

      -- C/C++ - use clang-format
      c = { "clang-format" },
      cpp = { "clang-format" },
      
     -- Web languages - use prettier
     javascript = { "prettier" },
     typescript = { "prettier" },
     javascriptreact = { "prettier" },
     typescriptreact = { "prettier" },
     css = { "prettier" },
     scss = { "prettier" },
     html = { "prettier" },
     json = { "prettier" },
     jsonc = { "prettier" },
     markdown = { "prettier" },
     yaml = { "prettier" },
     graphql = { "prettier" },
     -- Other languages - use prettier
      ["_"] = { "prettier" },
    },
  },
}