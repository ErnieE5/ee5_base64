lua_base64
==========

Lua base64 encoding

I was looking for some "native to Lua" base64 encoding and decoding routines
and didn't find any that were "fast enough." With Lua 5.2 and the new bit32
routines I suspected that a better job could be done. The best routine I found
really used a bunch of memory. For an 800K file, over 6.5M was needed for an
intermiedate value. For my use, this was way too much. The alternative of
doing a popen("base64") was considered, but isn't overly portable.  Speed was
an issue when 800K files took over 2 full seconds.

This module "exports" 8 methods that allow interaction with the encoding /
decoding routines in 3 descrete ways.

The simplest is "string in" / "string out".

```lua
base64=require("base64")

print( base64.encode("This is a string"))
```
```
VGhpcyBpcyBhIHN0cmluZw==
```
