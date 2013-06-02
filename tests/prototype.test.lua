#!/usr/bin/lua

package.path = "../src/?.lua;" .. package.path
local prototype = require( "prototype" )
local newproxy = newproxy or require( "newproxy" ) -- for Lua5.2

local bar = string.rep( "=", 70 )

local function check( ok, ... )
  local oks = ok and "[ ok ]" or "[FAIL]"
  print( oks, ... )
end

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
        return tostring( self )
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
  check( myobject.number == 1, "myobject.number =", myobject.number )
  check( copy.number == 2, "copy.number =", copy.number )
  check( copy.string == "hello", "copy.string =", copy.string )
  print( "myobject.table =", myobject.table )
  check( myobject.table[ 1 ] == 1, "myobject.table[ 1 ] =", myobject.table[ 1 ] )
  check( copy.table ~= myobject.table, "copy.table =", copy.table )
  check( copy.table[ 1 ] == 1000, "copy.table[ 1 ] =", copy.table[ 1 ] )
  check( copy.table.self == copy.table, "copy.table.self =", copy.table.self )
  print( "myobject.array =", myobject.array )
  check( myobject.array[ 1 ] == 1, "myobject.array[ 1 ] =", myobject.array[ 1 ] )
  check( copy.array ~= myobject.array, "copy.array =", copy.array )
  check( copy.array[ 1 ] == 1000, "copy.array[ 1 ] =", copy.array[ 1 ] )
  local mop, cp = myobject:peek(), copy:peek()
  check( mop ~= cp, "myobject:peek(), copy:peek() =", mop, cp )
  myobject.string = "hi"
  check( copy.string == "hello" or copy.string == "hi", "copy.string =", copy.string )
  copy.number = nil
  check( copy.number == nil or copy.number == 1, "copy.number =", copy.number )
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

