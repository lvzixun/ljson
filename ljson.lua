local lpeg = require "lpeg"

local tonumber = tonumber
local tostring = tostring
local type     = type
local concat   = table.concat

local R, P, C, Cp, S, V, Ct, Cmt, Carg = 
      lpeg.R, lpeg.P, lpeg.C, lpeg.Cp, lpeg.S, lpeg.V, lpeg.Ct, lpeg.Cmt, lpeg.Carg

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
local _raitonal = (P"-"^-1) * _dec^1 * ((P".")^-1) * (_dec^0)
local _hex = (P("0x") + P("0X")) * (R("09", "AF", "af")^1)
local number = C(_hex + _raitonal) / 
  function (...)
    return tonumber(...)
  end

-----  string
local _s = P"\""
local string = _s * C((P(1)-_s)^0) * _s

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

-------  syntax
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
        assert(#t%2 == 0)
        for i=1, #t, 2 do
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
    return "\""..t.."\""
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


