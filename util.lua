local _seri_table = {}

local function _table2str(lua_table, indent, result_table, n,
    pairs, type, format, tostring
  )
  local indent_str = "  "
  indent = indent or 0

  for k, v in pairs(lua_table) do
    local tpk, tpv = type(k), type(v)
    if tpk == "string" then
      k = format("%q", k)
    else
      k = tostring(k)
    end
    if tpv == "table" then
      for i=1,indent do
        n=n+1; result_table[n] = indent_str
      end
      n=n+1; result_table[n] = "["
      n=n+1; result_table[n] = k
      n=n+1; result_table[n] = "]={\n"

      -- recursive
      n = _table2str(v, indent+1, result_table, n,
        pairs, type, format, tostring)

      for i=1,indent do
        n=n+1; result_table[n] = indent_str
      end
      n=n+1; result_table[n] = "},\n"
    else
      if tpv == "string" then
        v = format("%q", v)
      else
        v = tostring(v)
      end
      for i=1,indent do
        n=n+1; result_table[n] = indent_str
      end
      n=n+1; result_table[n] = "["
      n=n+1; result_table[n] = k
      n=n+1; result_table[n] = "]="
      n=n+1; result_table[n] = v
      n=n+1; result_table[n] = ",\n"
    end
  end

  return n
end

local function serialize_table(lua_table)
  local n = 0  -- length of _seri_table
  n=n+1; _seri_table[n] = '{\n'
  n = _table2str(lua_table, 1, _seri_table, n,
    pairs, type, string.format, tostring)
  n=n+1; _seri_table[n] = '}'

  return table.concat(_seri_table, '')
end

return {
  print_table = function (t)
    return print(serialize_table(t))
  end  
}


