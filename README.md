lua_base64
==========

Lua base64 encoding

I was looking for some "native to Lua" base64 encoding and decoding routines
and didn't find any that were "fast enough." With Lua 5.2 and the new bit32
routines I suspected that a better job could be done. The best routine I found
really used a bunch of memory. For an 800K file, over 6.5M was needed for an
intermediate value. For my use, this was way too much. The alternative of
doing a popen("base64") was considered, but isn't overly portable.  Speed was
an issue when 800K files took over 2 full seconds.

This module "exports" 8 methods that allow interaction with the encoding /
decoding routines in 3 descrete ways.

The simplest is "string in" / "string out".

```lua
base64=require("base64")

print( base64.encode("This is a string") )
print( base64.decode("RHVkZSEgV2hlcmUgaXMgbXkgY2FyPz8/Cg==") )
```
**Output:**
```
VGhpcyBpcyBhIHN0cmluZw==
Dude! Where is my car???
```

For "very large strings" this may not be the best way to use the library.
> In fact, I likely wouldn't encourage using these routines **all the time**
for large strings. A Lua C-Module would handle this considerably faster.

More Examples:
--------------
(see test.lua when I check it in too!)
```lua
base64=require("base64")
ii=base64.encode_ii(io.stdin)
base64._encode_(ii,function(s) io.write(s) end)
```
```bash
lua test.lua < base64.lua
```
```output
LS1bWyoqKioqKioqKio  . . . dGVyYXRvcgp9Cg==
```

