-- local json = require "ljson"
local json = dofile("../ljson.lua")
local util = dofile("../util.lua")


local t = {
  a = 0xff1,
  b = 2, 
  c = {3, 4, "aa", 5},
  d = "bb",
  e = {
    g = {6, -7, 8.8},
    k = {},
  },
  f = false,
  g = true,
  h = "中文123显示abc",
  l = "\\aaaaa"
}

local j_str = [[
{
  "name" : "",
  "find" : "\u9996\u5145\u6709\u79ae",
  "sprite" : 
  [
    {
      "add color" : "0x00000000",
      "angle" : 0.0,
      "clip" : false,
      "filepath" : "file.json",
      "multi color" : "0xffffffff",
      "name" : "",
      "position" : 
      {
        "x" : 0.0,
        "y" : 0.0
      },
      "tag" : "",
      "x mirror" : false,
      "x offset" : 0.0,
      "x scale" : 0.6000000238418579
    }
  ]
}
]]



print(json.encode(t))
print("-----------------")
local success, data = json.decode(j_str)
util.print_table(data)
