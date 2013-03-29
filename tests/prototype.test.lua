#!/usr/bin/lua

package.path = "../src/?.lua;" .. package.path
local prototype = require( "prototype" )
local newproxy = newproxy or require( "newproxy" ) -- for Lua5.2

local bar = string.rep( "=", 70 )


local function test_prototype( conf, call_slots )
  print( bar )

  local object = prototype( conf )
  local myobject = object:clone()

  local u
  do
    u = newproxy( true )
    local mt = getmetatable( u )
    mt.__index = {
      peek = function( self )
        print( "peeking:", self )
      end,
      clone = function( self )
        return newproxy( self )
      end,
    }
  end
  if call_slots then
    myobject:slot( "number" )
            :slot( "string" )
            :slot( "table", prototype.deep_copy )
            :slot( "array", prototype.shallow_copy )
  end
  myobject.number = 1
  myobject.string = "hello"
  myobject.table = { 1, 2, 3 }
  myobject.table.self = myobject.table
  myobject.clone.table = prototype.deep_copy
  myobject.array = { 1, 2, 3 }
  myobject:mixin( u, "peek" )

  local copy = myobject:clone()
  copy.number = 2
  copy.table[ 1 ] = 1000
  copy.array[ 1 ] = 1000
  print( "myobject.number =", myobject.number, "(should be 1)" )
  print( "copy.number =", copy.number, "(should be 2)" )
  print( "copy.string =", copy.string, "(should be 'hello')" )
  print( "myobject.table =", myobject.table )
  print( "myobject.table[ 1 ] =", myobject.table[ 1 ], "(should be 1)" )
  print( "copy.table =", copy.table, "(should be different from myobject.table)" )
  print( "copy.table[ 1 ] =", copy.table[ 1 ], "(should be 1000)" )
  print( "copy.table.self =", copy.table.self, "(should be equal to copy.table)" )
  print( "myobject.array =", myobject.array )
  print( "myobject.array[ 1 ] =", myobject.array[ 1 ], "(should be 1)" )
  print( "copy.array =", copy.array, "(should be different from myobject.array)" )
  print( "copy.array[ 1 ] =", copy.array[ 1 ], "(should be 1000)" )
  myobject:peek()
  copy:peek()
  print( "those two peeks should have different addresses!" )
  myobject.string = "hi"
  print( "copy.string =", copy.string, "(should be 'hello' or 'hi' depending on implementation)" )
  copy.number = nil
  print( "copy.number =", copy.number, "(should be `nil' or `1' depending on implementation)" )
end


print( _VERSION )
-- use delegation (and shallow copy for tables)
test_prototype{
  default = prototype.no_copy,
  table = prototype.shallow_copy,
  use_prototype_delegation = true,
}
-- use assignment copy (and shallow copy for tables)
-- no delegation or index lookup
test_prototype{
  default = prototype.assignment_copy,
  table = prototype.shallow_copy,
}
-- explicitly declare all slots, protect objects from
-- undeclared slots, no default cloning policy
test_prototype( {
  default = function() error( "unknown slot" ) end,
  use_prototype_delegation = true,
  use_slot_protection = true,
  use_clone_delegation = true,
}, true )

-- use delegation but more per-type policies, use extra
-- metatable
test_prototype{
  -- set the default cloning policy
  default = prototype.no_copy,
  -- set per-type cloning policies
  number = prototype.assignment_copy,
  string = prototype.assignment_copy,
  boolean = prototype.assignment_copy,
  table = prototype.shallow_copy,
  -- set various flags that affect prototype behavior
  use_prototype_delegation = true,
  use_extra_meta = true,
}

