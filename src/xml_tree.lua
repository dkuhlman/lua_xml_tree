#!/usr/bin/env lua

--
-- synopsis:
--   parse an XML file; build a tree of elements (XmlElementClass).
-- usage:
--   $ lua xmltest05.lua xmlinputfile.xml
--   $ lua xmltest05.lua xmlinputfile.xml --show
--   $ lua xmltest05.lua xmlinputfile.xml --show --trim
--
--   $ lua
--   > xml_tree = require "xml_tree"
--   > tree = xml_tree.to_tree('test07-01.xml' )
--   > xml_tree.show_tree(tree)
--   > tree = xml_tree.to_tree('test07-01.xml', true )
--   > xml_tree.show_tree(tree)
--

local argparse = require("argparse")
local lxp = require("lxp")
local M = {}

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function get_indent_filler(indentlevel)
  return string.rep('    ', indentlevel)
end

--
-- class XmlElementClass

local XmlElementClass = {}
XmlElementClass.__index = XmlElementClass

function XmlElementClass.new(tag, attrib)
  local self = setmetatable({}, XmlElementClass)
  self.tag = tag
  self.attrib = attrib
  self.text = ""
  self.children = {}
  return self
end

function XmlElementClass:collect_children(collection)
  collection = collection or {}
  table.insert(collection, self)
  for _, item in pairs(self.children) do
    item:collect_children(collection)
  end
  return collection
end

-- end class XmlElementClass

--
-- XmlElementClass utility functions

function M.iter_children_coroutine(node, cnt)
  for _, child in pairs(node.children) do
    coroutine.yield(child)
    M.iter_children_coroutine(child)
  end
end

function M.iter_coroutine(node)
  coroutine.yield(node)
  for _, child in pairs(node.children) do
    M.iter_coroutine(child)
  end
end

--
-- class XmlParserClass

local XmlParserClass = {}
XmlParserClass.__index = XmlParserClass

function XmlParserClass.new(trim)
  local self = setmetatable({}, XmlParserClass)
  self.trim = trim
  self.elstack = {}
  return self
end

function XmlParserClass.start_element(self, _, name, attrib)
  -- split namespace and qname (tag), if necessary.
  local tag_table = {}
  for substr in string.gmatch(name, "%S+") do
    table.insert(tag_table, substr)
  end
  if #tag_table == 2 then
    name = string.format('{%s}%s', tag_table[1], tag_table[2])
  end
  local element = XmlElementClass.new(name, attrib)
  table.insert(self.elstack, element)
end

function XmlParserClass.end_element(self, _, _)
  local child = table.remove(self.elstack)
  if #self.elstack > 0 then
    local current = self.elstack[#self.elstack]
    table.insert(current.children, child)
  else
    self.root = child
  end
end

function XmlParserClass.characters(self, _, str)
  if #str > 0 then
    if self.trim then
      str = trim(str)
    end
    local current = self.elstack[#self.elstack]
    current.text = current.text .. str
  end
end

-- end class XmlParserClass

-- Walk the element tree.
-- Convert node.text of each node to upper case.
local function to_upper_case_text(node)
  node.text = string.upper(node.text)
  for _, child in ipairs(node.children) do
    to_upper_case_text(child)
  end
end

-- Display information on each node in the XML tree.
function M.show_tree(node, level, cnt)
  level = level or 0
  cnt = cnt or 1
  local filler = get_indent_filler(level)
  print(string.format(
    "%s%d. Tag: %s", filler, cnt, node.tag))
  level = level + 1
  filler = get_indent_filler(level)
  if node.text ~= nil then
    -- local text = trim(node.text)
    local text = node.text
    if text ~= "" then
      print(string.format(
        '%sText: "%s"',
        filler, text))
    end
  end
  if #node.attrib > 0 then
    print(string.format('%sAttributes:', filler))
    for k, v in pairs(node.attrib) do
      if type(k) ~= 'number' then
        print(string.format('%s    "%s" --> "%s"', filler, k, v))
      end
    end
  end
  local cnt = 0
  for _, child in ipairs(node.children) do
    cnt = cnt + 1
    M.show_tree(child, level, cnt)
  end
end

-- Read an XML file.
-- Convert it to a tree of objects (instances of XmlElementClass).
-- Return the root node of that tree.
function M.to_tree(infilename, trim)
  local infile = io.open(infilename, 'r')
  local content = infile:read('*a')
  local cb_object = XmlParserClass.new(trim)
  local callbacks = {
    StartElement = function (
      xparser, name, attrib) cb_object:start_element(xparser, name, attrib) end,
    EndElement = function (
      xparser, name) cb_object:end_element(xparser, name) end,
    CharacterData = function (
      xparser, str) cb_object:characters(xparser, str) end,
  }
  -- Ask LuaExpat to deliver namespace (URI).
  local xmlparser = lxp.new(callbacks, " ")
  xmlparser:parse(content)
  return cb_object.root
end

function main()
  local parser = argparse(
    "script",
    "parse an XML file; build a tree of elements (XmlElementClass).")
  parser:argument("infilename", "Input XML file name")
  parser:flag(
    "-t --trim",
    "Trim surrounding white space (default: false)."
    )
  parser:flag(
    "-s --show",
    "Display the constructed tree."
    )
  local args = parser:parse()
  local root = M.to_tree(args.infilename, args.trim)
  if args.show then
    print('--------------------------------------------')
    M.show_tree(root, 0)
    -- to_upper_case_text(root)
    print('--------------------------------------------')
  end
end

if pcall(debug.getlocal, 4, 1) then
  return M
else
  main()
end
