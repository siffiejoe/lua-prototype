-- module for using prototype based object oriented programming in Lua

-- cache globals
local assert = assert
local require = assert( require )
local type = assert( type )
local pairs = assert( pairs )
local select = assert( select )
local rawset = assert( rawset )
local setmetatable = assert( setmetatable )
local loadstring = assert( loadstring or load )
local string = require( "string" )
local s_fmt = assert( string.format )

-- module table
local prototype = {}


----------------------------------------------------------------------
-- cloning policies

function prototype.no_copy()
end

function prototype.assignment_copy( v )
  return v
end

function prototype.shallow_copy( val )
  assert( type( val ) == "table", "not a table" )
  local copy = {}
  for k,v in pairs( val ) do
    copy[ k ] = v
  end
  return copy
end

function prototype.delegate_copy( val )
  assert( type( val ) == "table", "not a table" )
  local copy = {}
  setmetatable( copy, { __index = val } )
  return copy
end

local function deep_copy( val, cache )
  if not cache[ val ] then
    local copy = {}
    cache[ val ] = copy
    for k,v in pairs( val ) do
      local new_k, new_v = k, v
      if type( k ) == "table" then
        new_k = deep_copy( k, cache )
      end
      if type( v ) == "table" then
        new_v = deep_copy( v, cache )
      end
      copy[ new_k ] = new_v
    end
  end
  return cache[ val ]
end
function prototype.deep_copy( val )
  assert( type( val ) == "table", "not a table" )
  return deep_copy( val, {} )
end

function prototype.clone_copy( v )
  local t = type( v )
  assert( t == "table" or t == "userdata", "not a table or userdata" )
  return v:clone()
end


----------------------------------------------------------------------
-- create a custom prototype object according to the specification


-- function used as __newindex for protecting undeclared slots
local function protect_slots( t, k, v )
  assert( t.clone[ k ], "undeclared slot on prototype object" )
  if t.clone[ k ] then
    rawset( t, k, v )
  end
end


-- generic implementation for a prototype's slot method
local function slot( self, key, handler )
  self.clone[ key ] = handler or prototype.assignment_copy
  return self
end


-- creates a mixin method for a prototype object
local function make_mixin( policy )
  return function( self, obj, ... )
    local ID = {}
    self:slot( ID, prototype.clone_copy )
    self[ ID ] = obj
    -- add forwarding methods
    for i = 1, select( '#', ... ) do
      local m_name = select( i, ... )
      if m_name ~= "clone" then
        if policy then
          self:slot( m_name, policy )
        end
        self[ m_name ] = function( self, ... )
          local obj = self[ ID ]
          return obj[ m_name ]( obj, ... )
        end
      end
    end
    return self
  end
end


local template = [[
local spec, protect, type, pairs, setmetatable = ...
local cache = setmetatable( {}, { __mode = "kv" } )
local shared_meta = { __newindex = protect }
local function clone_ft_call( ft, o )
  local new_o = {}
  for k,v in pairs( o ) do
    new_o[ k ] = (ft[ k ] or spec[ type( v ) ])( v )
  end
%s  return new_o
end
local clone_ft_meta = { __call = clone_ft_call }
local function clone_ft_cloner( ct )
  local new_ct = {}
%s
  return new_ct
end
local clone_ft = {
  clone = clone_ft_cloner
}
setmetatable( clone_ft, clone_ft_meta )
return clone_ft]]


local function setup_meta( spec )
  if spec.use_slot_protection and spec.use_extra_meta and
     not spec.use_prototype_delegation then -- use shared metatable
    return "    setmetatable( new_o, shared_meta )\n"
  elseif spec.use_prototype_delegation or
         spec.use_slot_protection then -- need a metatable
    local s
    if spec.use_extra_meta then
      s = "  local meta = cache[ o ] or {}\n  cache[ o ] = meta\n"
    else
      s = "  local meta = new_o\n"
    end
    return s .. "  setmetatable( new_o, meta )\n"
  end
  return ""
end


local function setup_delegation( spec )
  if spec.use_prototype_delegation then
    return "  meta.__index = o\n"
  end
  return ""
end


local function setup_protection( spec )
  if spec.use_slot_protection and
     (spec.use_prototype_delegation or
      not spec.use_extra_meta) then
    return "  meta.__newindex = protect\n"
  end
  return ""
end


local function setup_c_body( spec )
  if spec.use_clone_delegation then
    return [[  local meta = { __call = clone_ft_call, __index = ct }
  setmetatable( new_ct, meta )]]
  else
    return [[  for k,v in pairs( ct ) do new_ct[ k ] = v end
  setmetatable( new_ct, clone_ft_meta )]]
  end
end


-- creates custom code for a clone functable
local function make_clone( spec )
  local o_init = setup_meta( spec ) ..
                 setup_delegation( spec ) ..
                 setup_protection( spec )
  local c_body = setup_c_body( spec )
  local code = s_fmt( template, o_init, c_body )
  return assert( loadstring( code ) )(
    spec, protect_slots, type, pairs, setmetatable
  )
end


local types = {
  "nil", "boolean", "number", "string",
  "table", "userdata", "function", "thread"
}

local function make_prototype( _, spec )
  assert( type( spec ) == "table", "invalid prototype specification" )
  for i = 1, #types do
    local t = types[ i ]
    if type( spec[ t ] ) ~= "function" then
      spec[ t ] = spec.default
    end
  end
  local f_policy = spec.use_slot_protection and
                   (spec[ "function" ] or
                    (spec.use_prototype_delegation and
                     prototype.no_copy or prototype.assignment_copy))
  local root = {
    clone = make_clone( spec ),
    mixin = make_mixin( f_policy ),
    slot = slot
  }
  if spec.use_prototype_delegation and not spec.use_extra_meta then
    slot( root, "__index", prototype.no_copy )
  end
  if spec.use_slot_protection then
    slot( root, "mixin", f_policy )
    slot( root, "slot", f_policy )
    if not spec.use_extra_meta then
      slot( root, "__newindex", prototype.no_copy )
    end
    local meta = (spec.use_extra_meta and {}) or root
    meta.__newindex = protect_slots
    setmetatable( root, meta )
  end
  return root
end


-- return module table
setmetatable( prototype, { __call = make_prototype } )
return prototype

