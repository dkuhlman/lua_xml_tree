package = "xml_tree"
version = "1.0-1"
source = {
  url = "https://github.com/dkuhlman/lua_xml_tree",
  tag = "v1.0"
}
description = {
  summary = "Build a tree of Lua objects from an XML document/file.",
  detailed = [[
  Support for a nested tree of Lua objects that represents XML data.
  Each object represents one XML element/node.
  The tree can be walked recusively.
  Support is provided for iterating children (and decendents) of a node.
  Call `convert_to_tree` in order to create a tree of objects from an XML file.
  See `test01.lua` in the Github repository for examples of use.
  ]],
  homepage = "https://github.com/dkuhlman/lua_xml_tree",
  license = "MIT"
}
dependencies = {
  "lua >= 5.4",
  "argparse",
  "luaexpat"
}
build = {
   type = "builtin",
   modules = {
      xml_tree = "src/xml_tree.lua"
   }
}
