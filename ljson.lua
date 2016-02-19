local lpeg  = require "lpeg"
local bit32 = require "bit32"

local schar = string.char
local sbyte = string.byte
local band = bit32.band
local bor = bit32.bor
local lshift = bit32.lshift
local rshift = bit32.rshift
local extract = bit32.extract

local tonumber = tonumber
local tostring = tostring
local type     = type
local concat   = table.concat
local select   = select

local R, P, C, Cp, S, V, Ct, Cmt, Carg = 
      lpeg.R, lpeg.P, lpeg.C, lpeg.Cp, lpeg.S, lpeg.V, lpeg.Ct, lpeg.Cmt, lpeg.Carg

-------------------------- unicode to utf8 --------------------------------------
local function _gen_unicode(unicode, len)
  if len == 1 then return schar(unicode) end
  local ret = {}

  for i=0,len-2 do
    local v = extract(unicode, i*6, 6)
    local c = v + 128
    table.insert(ret, 1, schar(c))
  end

  local h  = lshift(lshift(1, len) - 1, 8-len)
  local hv = rshift(unicode, (len-1)*6)
  -- assert(lshift(1, 7-len)-1 >= hv)
  local head = bor(h, hv)
  table.insert(ret, 1, schar(head))

  return table.concat(ret)
end

-------- unicode -> utf8 string
local function unicode2utf8(unicode)
  if unicode <= 0x7f then  -- 1 char
    return schar(unicode)
  elseif unicode <= 0x7ff then -- 2 char
    return _gen_unicode(unicode, 2)
  elseif unicode <= 0xffff then -- 3 char
    return _gen_unicode(unicode, 3)
  elseif unicode <= 0x1fffff then --- 4 char
    return _gen_unicode(unicode, 4)
  elseif unicode <= 0x3ffffff then -- 5 char
    return _gen_unicode(unicode, 5)
  elseif unicode <= 0x7fffffff then --  6 char
    return _gen_unicode(unicode, 6)
  else
    error("unicode overflow")
  end
end

-------------------------- lex --------------------------------------
local eof = P(-1)

local space = S(" \r\t")
local line = Cmt(P"\n"*Carg(1), 
  function (_, pos, state)
    local line = state.line
    state.cur_line = line[pos] or state.cur_line + 1
    line[pos] = state.cur_line
    return true
  end)

local pass = (space + line)^0

-----  number
local _dec = R("09")
local _nc = R("09", "AF", "af")
local _raitonal = (P"-"^-1) * _dec^1 * ((P".")^-1) * (_dec^0)
local _hex = (P("0x") + P("0X")) * (_nc^1)
local number = C(_hex + _raitonal) / 
  function (...)
    return tonumber(...)
  end

-----  string
local _s = P"\""
local _u = P"\\u" * (C(_nc * _nc * _nc * _nc) /
  function (n)
    local unicode = tonumber("0x"..n)
    return unicode2utf8(unicode)
  end)
local _e = P"\\" * (C(P"b" + P"f" + P"n" + P"r" + P"t" + P"\"" + P"\\" + P"/") / 
  {
    ["b"] = "\b",
    ["f"] = "\f",
    ["n"] = "\n",
    ["r"] = "\r",
    ["t"] = "\t",
    ["\""] = "\"",
    ["\\"] = "\\",
    ["/"] = "/",
  })

local string = _s * Ct((_u + _e + C(1-_s))^0) * _s / 
  function (data)
    return table.concat(data)
  end

-----  boolean
local boolean = C(P"false" + P"true") / 
  function (b)
    if b == "false" then return false
    elseif b == "true" then return true end
    assert(false)
  end

---- null
local null = C(P"null") / 
  function ()
    return nil
  end

-----  exception
local exception = P(1)*Carg(1) / 
  function (state)
    error(("[@line: %d] invalid syntax."):format(state.cur_line))
  end

-----  except
local function E(s)
  return P(s) + P(1)*Carg(1) / 
    function (state)
      error(("[@line: %d] \"%s\" is expected."):format(state.cur_line, s))
    end
end

local function _gen_entry(patt)
  return (patt * (pass * P"," * pass * patt)^0) + P""/
          function()
            return nil
          end
end

local function _gen_table(...)
  local ret = {...}
  if #ret == 0 and ret[1] == nil then
    ret = {}
  end
  return ret
end

---------------------------  syntax  ----------------------------------
local map, array, node, entry  = V"map", V"array", V"node", V"entry"
local G = P{
  "trunk",
  trunk = map + array,
  node  =  number + string + boolean + null + map + array,
  array = P"[" * pass *  _gen_entry(node)  * pass * E"]" / 
    function (...)
      return _gen_table(...)
    end,
  entry = string * pass * E":" * pass * node,
  map   = P"{" * pass *  _gen_entry(entry) * pass * E"}" / 
    function (...)
        local t = _gen_table(...)
        local ret = {}
        local len = select("#", ...)
        assert(len%2 == 0)
        for i=1, len, 2 do
          local k = t[i]
          local v = t[i+1]
          ret[k] = v
        end
        return ret
    end,
}
local G = pass * G * pass * eof + exception


local function _jtype(value)
  local t = type(value)
  if t=="number" or t=="string" or t=="table" or t=="boolean" then
    return t
  else
    error(("invalid json type \"%s\"."):format(t))
  end
end


--------------------------- utf8 -> unicode -------------------------------
local function _utf8_char(s, pos, len)
  local c = sbyte(s, pos)
  local mask = lshift(1, (8 - len)) - 1
  local unicode = band(c, mask)

  for i=1,len-1 do
    local c = sbyte(s, pos + i)
    c = band(c, 0x3f)
    unicode = bor(lshift(unicode, 6), c)
  end
  return unicode
end

local function _utf8_len(s, pos)
  local c = sbyte(s, pos)
  if band(c, 0x80) == 0 then            -- 1 char
    return 1
  elseif band(c, 0xe0) == 0xc0 then     -- 2 char
    return 2
  elseif band(c, 0xf0) == 0xe0 then     -- 3 char
    return 3
  elseif band(c, 0xf8) == 0xf0 then     -- 4 char
    return 4
  elseif band(c, 0xfc) == 0xf8 then     -- 5 char
    return 5
  elseif band(c, 0xfe) == 0xfc then     -- 6 char
    return 6
  else
    error("utf8 overflow")
  end
end

local function _utf8(s, pos)
  local len = _utf8_len(s, pos)
  return _utf8_char(s, pos, len), len
end

local function utf82unicode_table(s)
  local ret = {}
  local pos = 1 

  while pos <= #s do
    local unicode, len = _utf8(s, pos)
    pos = pos + len
    ret[#ret+1] = unicode
  end 

  return ret
end


---  unicode -> json escape char
local _escape_char = {
  [8] = "\\b",
  [10] = "\\n",
  [13] = "\\r",
  [12] = "\\f",
  [9] = "\\t",
  [92] = "\\\\",
  [47] = "\\/",
  [34] = "\\\"",
}
local function unicode2escape(unicode)
  if _escape_char[unicode] then
    return _escape_char[unicode]
  elseif unicode <= 0x7f then
    return schar(unicode)
  else
    return ("\\u%.4x"):format(unicode)
  end
end


--- utf8 -> json unicode
local function utf82json_unicode(s)
  local ret = {}
  local us = utf82unicode_table(s)
  for i=1, #us do
    local unicode = us[i]
    ret[#ret+1] = unicode2escape(unicode)
  end

  return table.concat(ret)
end

---------------------------  convert  ------------------------------------
local _2value, _2array, _2map, _2table

_2table = function (value, meta)
  assert(type(value) == "table")
  local array_size = #value
  if array_size > 0 then
    return _2array(value, meta)
  else
    return _2map(value, meta)
  end
end

_2value = function (value, meta)
  local t = _jtype(value)
  if t == "number"  or t == "boolean" then
    return tostring(value)
  elseif t == "string" then
    return "\""..utf82json_unicode(value).."\""
  elseif t == "table" then
    return _2table(value, meta)
  end
  assert(false)
end

_2array = function (array, meta)
  assert(meta[array]==nil, "circular reference.")
  meta[array] = true
  local ret = {}
  for i=1,#array do
    local v = array[i]
    ret[#ret+1] = _2value(v, meta)
  end
  meta[array] = nil
  return "["..concat(ret, ",").."]"
end

_2map = function (map, meta)
  assert(meta[map]==nil, "circular reference.")
  meta[map] = true
  local ret = {}
  for k,v in pairs(map) do
    assert(type(k)=="string", "invalid map key type.")
    ret[#ret+1] = ("\"%s\" : %s"):format(k, _2value(v, meta))
  end
  meta[map] = nil
  return "{"..concat(ret, ",").."}"
end


------ lua table -> json string
local function encode(lua_table)
  local success, ret = pcall(function ()
      return _2table(lua_table, {})
    end)
  return success, ret
end

------ json string -> lua table
local function decode(json)
  local success, ret = pcall(function ()
      assert(type(json) == "string")
      return lpeg.match(G, json, 1, {line = {}, pos = 0, cur_line = 1})
    end)
  return success, ret
end


return {
  encode = encode,
  decode = decode
}




