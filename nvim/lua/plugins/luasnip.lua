return {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
      require("luasnip").setup(opts)
      
      -- Automatically load all Lua snippets from ~/.config/nvim/lua/snippets/
      require("luasnip.loaders.from_lua").load({
        paths = { "~/.config/nvim/lua/snippets" }
      })
    end,
  }