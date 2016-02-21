ee5_base64
==========
Lua 5.2 and LuaJIT 2.x base64 encoding and decoding

This module is written for Lua 5.2 (and was ported to LuaJIT 2.x) and likely could be used in 5.1 using the [LuaRocks](http://luarocks.org/) [bit32](https://raw.github.com/hishamhm/lua-compat-5.2/bitlib-5.2.2/lbitlib.c) backport. **I** have not tested on 5.1 and likely never will.

This module "exports" 3 methods with various "overloads" that allow interaction with the encoding / decoding routines. Default is to encode and decode as RFC 2045. This implementation is not strict 2045. _Line breaking is the responsibility of the user._

The "base64 RFC 2045" encoding is tested against base64 (GNU coreutils) 8.22 & 8.13 and _can_ produce identical output (including line breaks, if _you_ write the data that way).

Decoding creates a duplicate copy of the input string to sanitize the input. Decoding is about 20% slower than encoding for standard alphabets. Custom alphabet decoding is considerably slower (_almost_ 2x) because of the lack of predictable coherent patterns.

__Use as you will.__ No warranty. (What do you expect for "free stuff" you find on the web?) **I'd like to know if others find this useful**, but other than that, meh.

-----

####_Why?_ (yet _another_ Lua base64 converter)
I was looking for some "natural Lua" base64 encoding routines and didn't find any "fast enough." The project this was written for runs on three different platforms (OSX, Linux, ARM/x64) and would require 3 different binaries, so I wanted to KISS it. With Lua 5.2 and the [bit32](http://www.lua.org/manual/5.2/manual.html#6.7) library I suspected that a better job could be done. The best routine I found (prior to starting this version) used a considerable amount of memory. For an 818K file, over 6.5M was needed for an intermediate value. This was way too much. I considered popen("base64"), but this isn't easily portable.  Speed was an issue when 818K files took over 2 full seconds. So...


Basic Usage
-----------

Simplest is "string in / string out".

```lua
base64=require("ee5_base64")

print( base64.encode("This is a string") )
print( base64.decode("RHVkZSEgV2hlcmUgaXMgbXkgY2FyPz8/Cg==") )

--[[ Output

VGhpcyBpcyBhIHN0cmluZw==
Dude! Where is my car???

]]--
```
> I don't encourage using these routines (**at all**) for huge strings. A Lua c-module will handle this _considerably_ faster. Just "for fun" I ran a 600M file through base64 and this utility. 0m3.306s vs **8m**13.139s! It is plausible that base64 spun multiple threads, but I suspect that the real reason is that all of the "overhead" of a function call vs an extremely tight and optimized C routine is the real factor. (this is a perverse example, it annoys me no end that base64 even _exists_)

> Update *2016/21/02*: Also 'just for fun' I timed test_encode.lua against base64 ( Ubuntu 15.10 Linux/4.2.0-23-generic/x86_64 ) today with a 1G file. _ALL_ of the time is in the encoding stage with a single core pegged at 100%. The decrease in time is mostly due to the test machine having a higher clock than the laptop I ran the tests on previously. (There are _MINOR improvements_ that impact the times, but not to the extent shown.)

```bash
$/usr/bin/time --format %E lua test_encode.lua < sample4kp.mp4 > woo.b64
6:43.89
$/usr/bin/time --format %E base64 -w 0 < sample4kp.mp4 > wow.b64
0:01.39
$diff woo.b64 wow.b64
$
```

###More examples:

####stdin to stdout
```lua
base64=require("ee5_base64")
base64.encode(io.stdin,io.stdout)

--[[ Output

$lua test.lua < ee5_base64.lua

LS1bWyoqKioqKioqKio ... dGVyYXRvcgp9Cg==

]]--
```

#### Output predicate
```lua
o={}
base64.encode("Encode this please",function(s) o[#o+1]=s end)
for i,v in ipairs(o) do
    print(i,v)
end

--[[ Output

1   RW5j
2   b2Rl
3   IHRo
4   aXMg
5   cGxl
6   YXNl

]]--
```

#### Line splitting
```lua
function linespliter()
    local c = 0
    return function(s)
        io.write(s)
        c=c+1
        if c > 5 then
            io.write("\n")
            c=0
        end
    end
end

f=io.open("ee5_base64.lua")
s=f:read("*a") -- read entire file into string
f:close()
base64.encode(s,linespliter())

--[[ Output

LS1bWyoqKioqKioqKioqKioq
KioqKioqKioqKioqKioqKioq
        . . .
ZGVjb2RlX2lpICAgPSBkZWNv
ZGU2NF9pb19pdGVyYXRvcgp9
Cg==

]]--
```


#### Garbled input
```lua
-- Mess with the input "V2hhdCBpcyB0aGlzPwo="
s="V 2 h h d C Bp c y(((@!!!!\n\n\r\t\tB0aGlzPwo=           :-)     ?"
print(base64.decode(s))

--[[ Output

What is this?

]]--
```


####RFC 4648 'base64url'
```lua
base64.alpha("base64url")
i=io.open("foo")
o=io.open("bar","w")
-- String in / out (probably shouldn't be a url!)
o:write(base64.encode(i:read("*a")))
i:close()
o:close()

--[[ No output ]]--
```

####Custom alphabet
```lua
base64.alpha("~`!1@2#3$4%\t6^7&8*9(0)_-+={[}]|\\:;'<D,./?qwertyuioplkjhgfdsazxcv","")
s=base64.encode("User base64 encoding, no term chars")
print(s)
print(base64.decode(s))

--[[ Output

)-^,}'`'+-^,^<8:=_d<[h*q[.}r$#du$3*,}.k:+h;;}/6
User base64 encoding, no term chars

]]--
```
#Timing
These numbers reflect the _encoding_ of an __818K__ file read into a buffer and written to stdout. The tests are run under OS X 10.9.1 with a 2.6 GHz Intel Core i7. 16 GB of memory is available with limited background processing. Each test is run five times. Decoding (not shown) is slower because of input sanitation.


```Textile
$ lua -v
Lua 5.2.3  Copyright (C) 1994-2013 Lua.org, PUC-Rio
$ ls
-rw-r--r-- 1 Ernie Ewert staff 818K 2014-01-16 21:07 818KDataFile
-rwxr-xr-x 1 Ernie Ewert staff 9.6K 2014-01-16 21:02 test_encode.lua
-rwxr-xr-x 1 Ernie Ewert staff  107 2014-01-16 21:03 test_encode_stdio.lua
-rw-r--r-- 1 Ernie Ewert staff 1.1M 2014-01-16 21:10 dataout.b64
```

[ErnieE5/lua_base64 (this library)](https://github.com/ErnieE5/lua_base64)
```lua
--[[ test_encode.lua ]]
require("ee5_base64").encode(io.stdin:read("*a"),io.stdout)
--                           |
--                           Reads entire file to string
```

```Textile
$ time lua test_encode.lua < 818KDataFile > dataout.b64 # repeat 5 times

real    0m0.202s
real    0m0.203s
real    0m0.204s
real    0m0.203s
real    0m0.205s
```


[paulmoore/base64.lua (Paul Moore)](https://gist.github.com/paulmoore/2563975) __Modified to use the [bit32](http://www.lua.org/manual/5.2/manual.html#6.7) library in 5.2__
The performance of encoding in this library is _GREATLY_ enhanced with a single line modification. (Nearly twice as fast.) These numbers are "as is." Removing the assert in toChar reduces the run time significantly (778ms total).
```lua
--[[ test_encode.lua ]]
io.stdout:write( require("pm_base64").encode( io.stdin:read("*a") ) )
--                                            |
--                                            Reads entire file to string
```



```Textile
$ time lua test_encode.lua < 818KDataFile > dataout.b64 # repeat 5 times

real    0m1.351s
real    0m1.360s
real    0m1.353s
real    0m1.368s
real    0m1.372s
```


[Lua wiki (Alex Kloss)](http://lua-users.org/wiki/BaseSixtyFour)
```lua
--[[ test_encode.lua ]]
io.stdout:write( enc( io.stdin:read("*a") ) )
--                    |
--                    Reads entire file to string
```

```Textile
$ time lua test_encode.lua < 818KDataFile > dataout.b64 # repeat 5 times

real    0m2.443s
real    0m2.391s
real    0m2.413s
real    0m2.401s
real    0m2.406s
```

#Memory Usage
The following results are based on the the tests above in the timing section. (string to string) Building the result string is the largest consumer of memory because all of the data must be accumulated and then concatenated.

### Test ( string / string )
```
ErnieE5/ee5_base64      ~16MB       15,888,384  maximum resident set size
paulmoore/base64.lua    ~68MB       68,558,848  maximum resident set size
Lua wiki                ~38MB       38,924,288  maximum resident set size
```

>I am not surprised at the Lua Wiki versions memory picture. I was _stunned_ at the amount of memory consumed by Paul's version. In fact, looking into why his code churns so much memory gave MY code a boost in encode performance. (Almost 20% from the prior check-in, thanks Paul!) I wasn't clear on the string:byte() method usage and a simple change was helpful. (The 'bytes' table in Paul's code is the input string as a table of bytes.)


### Test ( string / file out )
```lua
--[[ test_encode.lua
     Test: string in / file out ]]
i=io.open("818KDataFile")
o=io:open("dataout.b64","w")
require("ee5_base64").encode(i:read("*a"),o)
o:close()
i:close()
```
```Textile
$ time lua test_encode.lua

real    0m0.200s

$ /usr/bin/time -l lua test_encode.lua 2>&1 | grep "maximum"

   3,923,968  maximum resident set size

```

### Test ( file in / file out )
```lua
--[[ test_encode.lua
     Test: input iterator in / predicate out ]]
i=io.open("818KDataFile")
o=io:open("dataout.b64","w")
require("ee5_base64").encode(i,o)
o:close()
i:close()
```

```Textile
$ time lua test_encode.lua

real    0m0.350s

$ /usr/bin/time -l lua test_encode.lua 2>&1 | grep "maximum"

   1,519,616  maximum resident set size

```
![Ernie](http://ee5.net/ernie.png "Ernie")
