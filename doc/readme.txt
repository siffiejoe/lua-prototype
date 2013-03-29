![prototype](prototype.png)

#        prototype -- Prototype Based OO Programming For Lua         #

##                           Introduction                           ##

There are basically two ways of doing object oriented programming:
class-based and prototype-based. While class-based OO is certainly
easier to implement for compiler-writers and therefore much more
familiar for most programmers (thanks to C++, Java, et al.),
prototype-based OO is actually easier (half the number of concepts and
less special cases) and fits nicely to dynamic interpreted languages
like Lua. [This wikipage][1] briefly handles prototype-based OO, but
fails to address the biggest problem: How to clone objects ...

  [1]: http://lua-users.org/wiki/InheritanceTutorial


##                           Basic Usage                            ##

The `prototype` module can create root objects for prototype-based OO
hierarchies:

    $ cat > test.lua
    local prototype = require( "prototype" )
    local object = prototype{
      default = prototype.assignment_copy,
    }
    local person = object:clone()
    person.name = "anonymous"
    function person:say()
      print( "Hi, I'm " .. self.name )
    end
    person:say()
    local alice = person:clone()
    alice.name = "Alice"
    alice:say()
    ^D

The output is (as expected):
    $ lua test.lua
    Hi, I'm anonymous
    Hi, I'm Alice


##                             Reference                            ##

The `prototype` module is a [functable][2] which serves as a generator
for custom tailored prototype root objects and as a container for some
predefined cloning policies. You call the `prototype` module passing
a configuration table as argument, which configures the default and
per-type cloning policies. The configuration table can have the
following fields:

*   `default = <function>`

    This specifies the default cloning policy for all fields (called
    slots in prototype terminology) when no per-slot or per-type
    cloning policies apply.

*   `boolean = <function>`
*   `number = <function>`
*   `string = <function>`
*   `table = <function>`
*   `["function"] = <function>`
*   `userdata = <function>`
*   `thread = <function>`

    You can specify a per-type cloning policy which is used in case a
    matching per-slot cloning policy is not available.

*   `use_prototype_delegation = <boolean>`

    A flag which specifies if delegation via __index metamethods
    should be used for the prototype objects to lookup non-existing
    slots in parent objects. If you use delegation there is no way
    of actually deleting slots if they are in parent objects, and
    modifications on parent objects might affect child objects that
    didn't redefine the inherited slots.

*   `use_slot_protection = <boolean>`

    Setting this flag to `true` sets a __newindex handler on the
    prototype objects that forbids creating new slots without
    declaring them first using the `slot`-method (see below). This
    forces per-slot cloning policies for all slots.

*   `use_extra_meta = <boolean>`

    Using this flag you can specify if a prototype object should act
    as its own metatable or allocate an extra table for this. Reusing
    the object's table saves some memory if delegation is used but you
    get those strange __index and/or __newindex slots in your
    prototype objects, and metatables are cached anyway. This flag has
    no effect if the prototype objects don't need a metatable.

*   `use_clone_delegation = <boolean>`

    The `clone` functable (see below) serves as a container for all
    per-slot cloning policies. Using this flag you can specify if
    the clone functables should use delegation itself instead of
    copying all per-slot cloning policies from parent objects. This
    might save some memory if you have lots of per-slot policies
    (e.g. if you `use_slot_protection = true`)


Calling the `prototype` module returns a root object, which provides
the following three methods:

*   `object:clone() -> newobject`

    This method creates a new object that inherits all currently
    existing slots from the original object. How this inheritance is
    done depends on the cloning policies. The `clone`-method (which
    is in fact a [functable][2]) also holds the per-slot cloning
    policies.

*   `object:mixin( cloneable, ... ) -> self`

    This method puts the `cloneable` object in a private slot and for
    each name given as extra argument sets up a forwarding method in
    `object`, that calls a method with the same name on the
    `cloneable` object.

    `cloneable` may be either a (full) userdata or a table, and must
    provide a clone-method. Prototype objects by default fulfill this
    requirement (obviously).

*   `object:slot( key [, policy] ) -> self`

    This method can be used to set the cloning policy (see below) of a
    slot. If `policy` is missing, `assignment_copy` is used. Slots
    without per-slot cloning policy use the per-type or default
    cloning policies.

    Using the `use_slot_protection = true` flag forces you to
    explicitly set a per-slot cloning policy beforehand for all slots.

  [2]: http://lua-users.org/wiki/FuncTables


###                        Cloning Policies                        ###

Cloning is easy for value types like numbers and booleans, and for
constant reference types like strings. But non-constant reference
types like tables or even userdata are more of a problem. E.g. for an
array or a map-like data structure you typically want the table itself
copied (not just the reference put into the cloned object), but the
keys and values should refer to the old values, so that you can add or
remove elements from those data structures without affecting the
parent object but lookup the original values. For graph-like data
structures you want a deep copy which also handles cycles, etc. And
all bets are off for userdata or objects with metatables.

This module allows you to specify default, per-type, and per-slot
cloning policies to handle all cloning needs for your data. You can
define your own cloning policies (functions taking one argument and
returning its copy) or use one of the predefined functions in the
`prototype` module:

*   `prototype.no_copy`

    No copy is made, nil is assigned to the slot. Therefore, if the
    prototype implementation uses delegation, the slot is looked up in
    the parent object, otherwise the slot is no longer available.

*   `prototype.assignment_copy`

    The given value/reference is assigned to the new slot in the
    cloned object.

*   `prototype.shallow_copy`

    This policy only works for tables. The table itself is copied, but
    its keys and values are assigned. This is usually what you want
    for most arrays, maps and sets.

*   `prototype.delegate_copy`

    This policy only works for tables. Returns a new table with a
    metatable and an __index metamethod set to the original table.

*   `prototype.deep_copy`

    Only works for tables and creates a deep copy of the table and all
    its referenced subtables. Also handles cycles.

*   `prototype.clone_copy`

    Only works for (full) userdata and tables. Calls the
    `obj:clone()`-method for the value and assigns the result to the
    slot.


###                            Examples                            ###

Use delegation for almost everything (and shallow copy for tables):

    local object = prototype{
      default = prototype.no_copy,
      table = prototype.shallow_copy,
      use_prototype_delegation = true,
    }

Use assignment copy (and shallow copy for tables), no delegation or
index lookup:

    local object = prototype{
      default = prototype.assignment_copy,
      table = prototype.shallow_copy,
    }

Explicitly declare all slots, protect objects from undeclared slots,
use no default cloning policy:

    local object = prototype{
      -- should never happen:
      default = function() error( "Argh, unknown slot!" ) end,
      use_prototype_delegation = true,
      use_slot_protection = true,
      use_clone_delegation = true,
    }
    object:slot( "val", prototype.assignment_copy )
    object.val = 1

Use assignment for value data, delegation for references, and shallow
copy for tables (and don't put __index or __newindex in the objects):

    local object = prototype{
      default = prototype.no_copy,
      boolean = prototype.assignment_copy,
      number = prototype.assignment_copy,
      string = prototype.assignment_copy,
      table = prototype.shallow_copy,
      use_prototype_delegation = true,
      use_extra_meta = true,
    }


###                   Adding Mixins to Prototypes                  ###

There are cases where the desired functionality can only be
implemented using external C modules or where preexisting Lua objects
are available that should be integrated into the prototype hierarchy.

The good news is that the `mixin`-method can add delegation methods to
a prototype object which call the external C or Lua object. The
downside is that these external C or Lua objects must be cloneable
(i.e. they must provide a `clone`-method that returns a copy of its
single argument). Prototype objects provide such a method, so you can
use prototype objects as mixins in other prototype objects.

Basic usage (but probably using the C API) is:

    $ cat > test.lua
    local u = newproxy( true )
    local mt = getmetatable( u )
    mt.__index = {
      peek = function( self )
        print( "peeking:", self )
      end,
      clone = function( self )
        print( "cloning:", self )
        return newproxy( self )
      end
    }
    local prototype = require( "prototype" )
    local object = prototype{
      default = prototype.no_copy,
      use_prototype_delegation = true,
    }
    object:mixin( u, "peek" )
    local cloned = object:clone()
    cloned:peek()
    ^D

The result is:

    $ lua test.lua
    cloning:        userdata: 0x8052a4c
    peeking:        userdata: 0x805418c

(`newproxy` is an undocumented function included in Lua up to version
5.1, that creates a zero-size userdata.)


##                             Download                             ##

The source code (with documentation and test scripts) is available on
[github][3].

  [3]:  https://github.com/siffiejoe/lua-prototype/


##                           Installation                           ##

There are two ways to install this module, either using luarocks (if
this module already ended up in the [main luarocks repository][4]) or
manually.

Using luarocks, simply type:

    luarocks install prototype

To install the module manually just drop `prototype.lua` somewhere
into your Lua `package.path`.

  [4]:  http://luarocks.org/repositories/rocks/    (Main Repository)


##                             Contact                              ##

Philipp Janda, siffiejoe(a)gmx.net

Comments and feedback are always welcome.


##                             License                              ##

prototype is *copyrighted free software* distributed under the MIT
license (the same license as Lua 5.1). The full license text follows:

    prototype (c) 2013 Philipp Janda

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHOR OR COPYRIGHT HOLDER BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


