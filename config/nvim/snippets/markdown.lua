local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
   s({ trig = "mermaid", name = "Mermaid Diagram", dscr = "Insert a Mermaid diagram with Hugo shortcode" }, {
      t({ "", "<!-- prettier-ignore-start -->" }),
      t({ "", '{{< mermaid title="' }),
      i(1, "diagram"),
      t({ '" >}}' }),
      t({ "", "graph TD", "\t" }),
      i(0, "A --> B"),
      t({ "", "{{< /mermaid >}}" }),
      t({ "", "<!-- prettier-ignore-end -->", "" }),
   }),
}
