#!/usr/bin/env lua

local argparse = require("argparse")
local xml_tree = require('xml_tree')

local M = {}

local f = string.format

function M.load_tree(infilename)
  tree = xml_tree.to_tree(infilename, true)
  return tree
end

function M.test01(infilename)
  local tree = M.load_tree(infilename)
  local show
  show = function(node, indent)
    print(f('%s%s', indent, node.tag))
    for k, v in ipairs(node.attrib) do
      print(f('%s    attribute %d -- name: "%s"  value: "%s"', indent, k, v, node.attrib[v]))
    end
    print(f('%s    text: "%s"', indent, node.text))
    indent = indent .. "    "
    for _, child in pairs(node.children) do
      show(child, indent)
    end
  end
  local node = tree
  show(node, "")
end

local show_node
show_node = function(node, indent)
  print(f('%s%s', indent, node.tag))
  for k, v in ipairs(node.attrib) do
    print(f('%s    attribute %d -- name: "%s"  value: "%s"', indent, k, v, node.attrib[v]))
  end
  print(f('%s    text: "%s"', indent, node.text))
  indent = indent .. "    "
end

function walk_tree(node, fn, indent, quiet)
  local quiet = quiet or false
  if not quiet then
    fn(node, indent)
  end
  indent = indent .. "    "
  for _, child in pairs(node.children) do
    walk_tree(child, fn, indent, quiet)
  end
end

function M.test_iterator(infilename, quiet)
  local quiet = quiet or false
  local tree = M.load_tree(infilename)
  co = coroutine.create(xml_tree.iter_children_coroutine)
  local node = tree
  local cnt = 0
  while node ~= nil do
    cnt = cnt + 1
    if not quiet then
      show_node(node, '')
    end
--    print(f('%03d. %s', cnt, node.tag))
--    for k, v in ipairs(node.attrib) do
--      print(f('    attribute %d -- name: "%s"  value: "%s"', k, v, node.attrib[v]))
--    end
    _, node = coroutine.resume(co, node)
  end
end

function M.test(args)
  local tree = M.load_tree(args.infilename)
  walk_tree(tree, show_node, "", args.quiet)
end

function main()
  local parser = argparse(
    "script",
    "parse an XML file; build a tree of elements (XmlElementClass).")
  parser:argument("infilename", "Input XML file name")
  parser:flag(
    "-i --iterator",
    "Use iterator that uses coroutines.",
    false
    )
  parser:flag(
    "-q --quiet",
    "Do not display the constructed tree.",
    false
    )
--   parser:option(
--     "-t --trim",
--     "Trim white space from around character data",
--     true)
  local args = parser:parse()
  -- for k, v in pairs(args) do print(k, v) end
  if args.iterator then
    M.test_iterator(args.infilename, args.quiet)
  else
    M.test(args)
  end
end

-- function main()
--   if #arg ~= 1 then
--     print('\nusage: lua test05.lua <infilename>\n')
--     os.exit(false)
--   end
--   infilename = arg[1]
--   M.test(infilename)
--   -- M.test_iterator(infilename)
-- end

if pcall(debug.getlocal, 4, 1) then
  return M
else
  main()
end
