local json = require "ljson"

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
}

local j_str = [[
{
  "name" : "",
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
    },
    {
      "font" : "E",
      "font_filename" : "",
      "label_height" : 19,
      "label_width" : 160,
      "multi color" : "0xffffffff",
      "name" : "title",
      "position" : 
      {
        "x" : 9.703887939453125,
        "y" : 1.0
      },
      "size" : 14,
      "tag" : "",
      "x mirror" : false,
      "x offset" : 0.0,
      "x scale" : 1.0,
      "x shear" : 0.0,
      "y mirror" : false,
      "y offset" : 0.0,
      "y scale" : 1.0,
      "y shear" : 0.0
    }
  ]
}
]]



print(json.encode(t))
print(json.decode(j_str))
