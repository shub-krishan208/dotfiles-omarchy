local ls = require("luasnip")

local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  -- codeforces related snippets
 s("cfstd", {
    t({ "#include <bits/stdc++.h>", "" }),
    i(1, ""),
    t({ "", "int main() {", "  " }),
    i(2),
    t({ "", "  return 0;", "}" }),
  }),
}
