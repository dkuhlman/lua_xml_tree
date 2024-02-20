# xml_tree

Supports the ability in Lua to create a recursively nested tree of
nodes from an XML document/file.

See `test01.lua` for examples of use.

Also try any of the following:

```
$ lua xml_tree.lua --help
$ lua xml_tree.lua infilename.xml
$ lua xml_tree.lua infilename.xml --outfilepath=output.xml
```

Module `src/xml_tree.lua` provides public functions for each of the
following (among others):

- Convert an XML document (file) to a tree of nodes -- `xml_tree.to_tree`

- Convert a tree of nodes to a string -- `xml_tree.to_string`
