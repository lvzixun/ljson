ljson
=====

a lib for json convert lua.

### require
lpeg version 0.12

### API
```
function encode(lua_table);   
  -- convert lua_table to json string.
  -- return is success and result json string.

function decode(json);
  -- convert json string to lua table object.
  -- return is success and a result table.
```
