#!/usr/bin/env lua

Doc = [[

Usage: script [-h] [-o <outfilepath>] [-t] [-s] <infilepath>

Synopsis:
    Parse an XML file;
    build a tree of elements (XmlElementClass).

Arguments:
   infilepath            Input XML file path (name)

Options:
   -h, --help            Show this help message and exit.
              -o <outfilepath>,
   --outfilepath <outfilepath>
                         Write output to outfile, not stdout.
   -t, --trim            Trim surrounding white space (default: false).
   -s, --silence         Silence.  Do not write out the constructed tree (default: false, write the tree).

Usage from command line:

   $ lua xml_tree.lua my_xml_doc.xml
   $ lua xml_tree.lua --trim my_xml_doc.xml

Usage in Lua REPL:

   >  xml_tree = require('xml_tree')
   >  -- Load tree from XML file.  Trim whitespace on text content.
   >  tree = xml_tree.to_tree('my_xml_doc.xml', true)
   >  xml_tree.show_tree(tree)

]]


local argparse = require("argparse")
local lxp = require("lxp")
local M = {}

local f = string.format

function table.shallow_copy(t)
  local t2 = {}
  for k, v in pairs(t) do
    t2[k] = v
  end
  return t2
end

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

function XmlElementClass.new(tag, attrib, nsmap)
  local self = setmetatable({}, XmlElementClass)
  self.tag = tag
  self.attrib = attrib
  self.nsmap = nsmap
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
  self.nsmap = {}
  return self
end

function XmlParserClass:convert_attr(attr)
  local attrib = {}
  for k, value in ipairs(attr) do
    attrib[value] = attr[value]
  end
  return attrib
end

function XmlParserClass:start_element(_, name, attr)
  -- split namespace and qname (tag), if necessary.
  local tag_table = {}
  for substr in string.gmatch(name, "%S+") do
    table.insert(tag_table, substr)
  end
  if #tag_table == 2 then
    name = f('{%s}%s', tag_table[1], tag_table[2])
  end
  local attrib = self:convert_attr(attr)
  local element = XmlElementClass.new(
    name,
    attrib,
    table.shallow_copy(self.nsmap))
  table.insert(self.elstack, element)
end

function XmlParserClass:end_element(_, _)
  local child = table.remove(self.elstack)
  if #self.elstack > 0 then
    local current = self.elstack[#self.elstack]
    table.insert(current.children, child)
  else
    self.root = child
  end
end

function XmlParserClass:characters(_, str)
  if #str > 0 then
    if self.trim then
      str = trim(str)
    end
    local current = self.elstack[#self.elstack]
    current.text = current.text .. str
  end
end

function XmlParserClass.start_namespace_decl(self, _, ns_name, ns_uri)
  self.nsmap[ns_name] = ns_uri
end

function XmlParserClass.end_namespace_decl(self, _, ns_name)
  self.nsmap[ns_name] = nil
end

-- end class XmlParserClass

-- Walk the element tree.
-- Convert node.text of each node to upper case.
-- local function to_upper_case_text(node)
--   node.text = string.upper(node.text)
--   for _, child in ipairs(node.children) do
--     to_upper_case_text(child)
--   end
-- end

-- Display information on each node in the XML tree.
function M.show_tree(node, level, cnt)
  level = level or 0
  cnt = cnt or 1
  local filler = get_indent_filler(level)
  print(f("%s%d. Tag: %s", filler, cnt, node.tag))
  level = level + 1
  filler = get_indent_filler(level)
  if node.text ~= nil then
    local text = node.text
    if text ~= "" then
      print(f('%sText: "%s"', filler, text))
    end
  end
  if #node.attrib > 0 then
    print(f('%sAttributes:', filler))
    for k, v in pairs(node.attrib) do
      if type(k) ~= 'number' then
        print(f('%s    "%s" --> "%s"', filler, k, v))
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
    StartNamespaceDecl = function (
      xparser, ns_name, ns_uri) cb_object:start_namespace_decl(xparser, ns_name, ns_uri) end,
    EndNamespaceDecl = function (
      xparser, ns_name) cb_object:end_namespace_decl(xparser, ns_name) end,
  }
  -- Ask LuaExpat to deliver namespace (URI).
  local xmlparser = lxp.new(callbacks, " ")
  xmlparser:parse(content)
  return cb_object.root
end

function M.to_string(node)
  local tbl = {}
  local wrt = function (str) table.insert(tbl, str) end
  local args = {wrt = wrt}
  M.export(node, '', args)
  local str = table.concat(tbl)
  return str
end

local function split_str(inputstr, sep)
  if sep == nil then
    sep = "%s" -- Default separator is whitespace
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function reverse_map(nsmap)
  local revnsmap = {}
  for k, v in pairs(nsmap) do
    revnsmap[v] = k
  end
  return revnsmap
end

function M.format_tag(orig_tag, nsmap)
  local gname
  local revnsmap = reverse_map(nsmap)
  local tbl = split_str(orig_tag, '}')
  if #tbl == 2 then
    ns = string.sub(tbl[1], 2)
    nsprefix = revnsmap[ns]
    qname = f('%s:%s', nsprefix, tbl[2])
  else
    qname = tbl[1]
  end
  return qname
end

function M.format_attrib(node)
  local str = ""
  local sep = " "
  for k, v in pairs(node.attrib) do
    str = str .. f('%s%s="%s"', sep, k, v)
  end
  for k, v in pairs(node.nsmap) do
    str = str .. f('%sxmlns:%s="%s"', sep, k, v)
  end
  return str
end

--
-- see https://stackoverflow.com/questions/1091945/what-characters-do-i-need-to-escape-in-xml-documents
function M.escape_text(text)
  local str = text
  str = string.gsub(str, '&', '&amp;')
  str = string.gsub(str, '<', '&lt;')
  return str
end

function M.export(node, indent, args)
  local attrib_str = M.format_attrib(node)
  local tag_str = M.format_tag(node.tag, node.nsmap)
  args.wrt(f('%s<%s%s>', indent, tag_str, attrib_str))
  if #node.children > 0 then
    args.wrt('\n')
    local indent01 = indent .. '    '
    for _, child in pairs(node.children) do
      M.export(child, indent01, args)
    end
    args.wrt(f('%s</%s>\n', indent, tag_str))
  else
    local text = M.escape_text(node.text)
    args.wrt(text)
    args.wrt(f('</%s>\n', tag_str))
  end
end

function M.test(args)
  local outfile
  local tree = M.to_tree(args.infilepath)
  if not args.silence then
    if args.outfilepath then
      outfile = io.open(args.outfilepath, 'w')
      args.wrt = function (s) outfile:write(s) end
    else
      args.wrt = function (s) io.stdout:write(s) end
    end
    M.export(tree, '', args)
    if args.outfilepath then
      outfile:close()
    end
  end
  return tree
end

function main()
  local parser = argparse(
    "script",
    [[
Synopsis:
    Parse an XML file;
    build a tree of elements (XmlElementClass). ]]
    )
  parser:argument(
    "infilepath",
    "Input XML file path (name)"
    )
  parser:option(
    "-o --outfilepath",
    "Write output to outfile, not stdout."
    )
  parser:flag(
    "-t --trim",
    "Trim surrounding white space (default: false)."
    )
  parser:flag(
    "-s --silence",
    "Silence.  Do not write out the constructed tree (default: false, write the tree)."
    )
  local args = parser:parse()
  M.test(args)
end

function M.dbg()
  print('test 03')
end

if pcall(debug.getlocal, 4, 1) then
  return M
else
  main()
end
