--[[**************************************************************************]]
-- base64.lua
-- Copyright 2014 Ernest R. Ewert
--
--  This Lua module contains the implementation of a Lua base64 encode
--  and decode library.
--
--  The library exposes these methods.
--
--      Method      Args / usage
--      ----------- ----------------------------------------------
--      encode      String in / out
--      decode      String in / out
--
--      encode      String, function(value) predicate
--      decode      String, function(value) predicate
--
--      encode      iterator_64 in, function(value) predicate
--      decode      64_iterator in, function(value) predicate
--      encode_ii   creates an io read iterator for input
--      decode_ii   creates a string iterator (slightly slower)
--
--  The predicate versions allow a string to be converted without a complete
--  duplication of the memory in a temporary structure. This is useful if you
--  want to write an existing string encoded / decoded to an output routine
--  without creating a duplicate in memory.
--
--  The iterator versions allow fully iterative encoding from an input source.
--  See the input iterators for information.
--
--  History:
--      2014/01/13 Original implementation
--      2014/01/13 Performance enhancements & other base64 variants
--


--------------------------------------------------------------------------------
-- known_base64_alphabets
--
--
--  Table containing pre-calculated "constant" modifications to the encode /
--  decode routines.
--
local known_base64_alphabets=
{
    base64= -- RFC 2045 (Ignores max line length restrictions)
    {
        _alpha="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
        _run="[^%a%d%+%/]-([%a%d%+%/])",
        _end="[^%a%d%+%/%=]-([%a%d%+%/%=])",
        _strip="[^%a%d%+%/%=]",
        _term="="
    },

    base64url= -- RFC 4648 'base64url'
    {
        _alpha="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
        _run="[^%a%d%-%_]-([%a%d%-%_])",
        _end="[^%a%d%+%-%_=]-([%a%d%+%-%_=])",
        _strip="[^%a%d%+%-%_=]",
        _term=""
    },
}
local c_alpha=known_base64_alphabets.base64

--[[**************************************************************************]]
--[[****************************** Encoding **********************************]]
--[[**************************************************************************]]


--------------------------------------------------------------------------------
-- base64 encoding table
--
-- Each (zero based, six bit) index is matched against the ASCII
-- value that represents the six bit pattern.
--
--          [6 bit encoding]=ASCII value
--
-- This table varies from normal Lua one based indexing to avoid
-- extra math during the fix-ups. This is a performance improvement
-- for very long encoding runs.
--
local b64e=
{
    [ 0]= 65, [ 1]= 66, [ 2]= 67, [ 3]= 68, [ 4]= 69, [ 5]= 70,
    [ 6]= 71, [ 7]= 72, [ 8]= 73, [ 9]= 74, [10]= 75, [11]= 76,
    [12]= 77, [13]= 78, [14]= 79, [15]= 80, [16]= 81, [17]= 82,
    [18]= 83, [19]= 84, [20]= 85, [21]= 86, [22]= 87, [23]= 88,
    [24]= 89, [25]= 90, [26]= 97, [27]= 98, [28]= 99, [29]=100,
    [30]=101, [31]=102, [32]=103, [33]=104, [34]=105, [35]=106,
    [36]=107, [37]=108, [38]=109, [39]=110, [40]=111, [41]=112,
    [42]=113, [43]=114, [44]=115, [45]=116, [46]=117, [47]=118,
    [48]=119, [49]=120, [50]=121, [51]=122, [52]= 48, [53]= 49,
    [54]= 50, [55]= 51, [56]= 52, [57]= 53, [58]= 54, [59]= 55,
    [60]= 56, [61]= 57, [62]= 43, [63]= 47
}

-- Tail padding values
local tail_padd64=
{
    "==",   -- two bytes modulo
    "="     -- one byte modulo
}


--------------------------------------------------------------------------------
-- m64
--
--  Helper function to convert three eight bit values into four ASCII
--  encoded base64 values.
--
local function m64( a, b, c )
    local cvt=bit32.lshift(a,16)+bit32.lshift(b,8)+c
  return
        b64e[ bit32.band( bit32.rshift(cvt,18), 0x3f ) ],
        b64e[ bit32.band( bit32.rshift(cvt,12), 0x3f ) ],
        b64e[ bit32.band( bit32.rshift(cvt, 6), 0x3f ) ],
        b64e[ bit32.band( cvt, 0x3f ) ]
end


--------------------------------------------------------------------------------
-- encode_tail64
--
--  Send a tail pad value to the output predicate provided.
--
local function encode_tail64( out, x, y )
    -- If we have a number of input bytes that isn't exactly divisible
    -- by 3 then we need to pad the tail
    if x ~= nil then
        local r = 1
        a = x

        if y ~= nil then
            b = y
            r = 2
        else
            b = 0
        end

        -- Encode three bytes of info, with the tail byte as zeros and
        -- ignore any fourth encoded ASCII value. (We should NOT have a
        -- forth byte at this point.)
        local b1, b2, b3 = m64( a, b, 0 )

        -- always add the first 2 six bit values to the res table
        -- 1 remainder input byte needs 8 output bits
        local tail_value = string.char( b1, b2 )

        -- two remainder input bytes will need 18 output bits (2 as pad)
        if y ~= nil then
            tail_value=tail_value..string.char( b3 )
        end

        -- send the last 4 byte sequence with appropriate tail padding
        out( tail_value .. tail_padd64[r] )
    end
end


--------------------------------------------------------------------------------
-- encode64_io_iterator
--
--  Create an io input iterator to read an input file and split values for
--  proper encoding.
--
local function encode64_io_iterator(file)

    local ii = { } -- Table for the input iterator
    local s

    -- Begin returns an input read iterator
    --
    function ii.begin()
        -- The iterator returns three bytes from the file for encoding or nil
        -- when the end of the file has been reached.
        --
        return function()
            s = file:read(3)
            if s ~= nil and #s == 3 then
                return s:byte(1), s:byte(2), s:byte(3)
            end
            return nil
        end
    end

    -- The tail method on the iterator allows the routines to run faster
    -- because each sequence of bytes doesn't have to test for EOF.
    --
    function ii.tail()
        -- If the file was evenly divisible by three then we just return
        -- nil, nil. If one or two "overflow" bytes exist, return those.
        --
        local x,y
        if s ~= nil and #s > 0 then
            x = s:byte(1)
            if #s > 1 then
                y = s:byte(2)
            end
        end
        return x, y
    end

    return ii
end


--------------------------------------------------------------------------------
-- encode64_string_iterator
--
--  This is a reference example of a encode string iterator. Encoding an
--  existing string using an iterator is ~slightly~ slower than using the
--  predicate version.
--
local function encode64_string_iterator( raw )
    local ii = { }      -- table for the input iterator
    local rem=#raw%3    -- remainder
    local len=#raw-rem  -- 3 byte input adjusted

    local index = 1

    function ii.begin()
        return function()
            index = index + 3
            if index < len then
                return raw:byte(index-3), raw:byte(index-2), raw:byte(index-1)
            else
                return nil
            end
        end
    end

    function ii.tail()
        local x, y
        if rem > 0 then
            x = raw:byte(len+1)
            if rem > 1 then
                y = raw:byte(len+2)
            end
        end
        return x, y
    end

    return ii
end


--------------------------------------------------------------------------------
-- encode64_with_ii
--
--      Convert the value provided by an encode iterator that provides a begin
--      method, a tail method, and an iterator that returns three bytes for
--      each call until at the end. The tail method should return either 1 or 2
--      tail bytes (for source values that are not evenly divisible by three).
--
local function encode64_with_ii( ii, out )

    for a, b, c in ii.begin() do
        out( string.char( m64( a, b, c ) ) )
    end

    encode_tail64( out, ii.tail() )

end


--------------------------------------------------------------------------------
-- encode64_with_predicate
--
--      Implements the basic raw data --> base64 conversion. Each three byte
--      sequence in the input string is converted to the encoded string and
--      given to the predicate provided in 4 output byte chunks. This method
--      is slightly faster for traversing existing strings in memory.
--
local function encode64_with_predicate( raw, out )
    local rem=#raw%3        -- remainder
    local len=#raw-rem      -- 3 byte input adjusted
    local s  =string.char   -- mostly for notation
    local b  =raw.byte      -- mostly for notation

    -- Main encode loop converts three input bytes to 4 base64 encoded
    -- ACSII values and calls the predicate with the value.
    for i=1,len,3 do
        -- This really isn't intended as obfuscation. It is more about
        -- loop optimization and removing temporaries.
        --
        out( s( m64( b( raw ,i ), b( raw, i+1 ), b( raw, i+2 ) ) ) )
        --   |  |    |            |              |
        --   |  |    byte 1       byte 2         byte 3
        --   |  |
        --   |  returns 4 encoded values
        --   |
        --   creates a string with the 4 returned values
    end

    -- If we have a number of input bytes that isn't exactly divisible
    -- by 3 then we need to pad the tail
    if rem > 0 then
        local x, y = b( raw, len+1 )

        if rem > 1 then
            y = b( raw, len+2 )
        end

        encode_tail64( out, x, y )
    end
end


--------------------------------------------------------------------------------
-- encode64_tostring
--
--      Convenience method that accepts a string value and returns the
--      encoded version of that string.
--
local function encode64_tostring(raw)

    local sb={} -- table to build string

    local function collection_predicate(v)
        sb[#sb+1]=v
    end

    -- Encoding with the predicate is slightly faster than using the
    -- string iterator and is used preferentially.
    --
    -- Tests with an 820K string in memory. Result is 1.1M of data.
    --      Lua         Lua         base64
    --      predicate   iterator    (gnu 8.21)
    --      0.555s      0.635s      0.054s
    --      0.557s      0.576s      0.048s
    --      0.598s      0.609s      0.050s
    --      0.541s      0.602s      0.042s
    --      0.539s      0.604s      0.046s
    --
    encode64_with_predicate( raw, collection_predicate )
--  encode64_with_ii( encode64_string_iterator( raw ), collection_predicate )

    return table.concat(sb)
end


--[[**************************************************************************]]
--[[****************************** Decoding **********************************]]
--[[**************************************************************************]]


--------------------------------------------------------------------------------
-- base64 decoding table
--
-- Each ASCII encoded value index is matched against the zero based, six bit
-- bit pattern.
--
--          [ASCII value]=6 bit encoding value
--
local b64d=
{
    [ 65]= 0, [ 66]= 1, [ 67]= 2, [ 68]= 3, [ 69]= 4, [ 70]= 5,
    [ 71]= 6, [ 72]= 7, [ 73]= 8, [ 74]= 9, [ 75]=10, [ 76]=11,
    [ 77]=12, [ 78]=13, [ 79]=14, [ 80]=15, [ 81]=16, [ 82]=17,
    [ 83]=18, [ 84]=19, [ 85]=20, [ 86]=21, [ 87]=22, [ 88]=23,
    [ 89]=24, [ 90]=25, [ 97]=26, [ 98]=27, [ 99]=28, [100]=29,
    [101]=30, [102]=31, [103]=32, [104]=33, [105]=34, [106]=35,
    [107]=36, [108]=37, [109]=38, [110]=39, [111]=40, [112]=41,
    [113]=42, [114]=43, [115]=44, [116]=45, [117]=46, [118]=47,
    [119]=48, [120]=49, [121]=50, [122]=51, [ 48]=52, [ 49]=53,
    [ 50]=54, [ 51]=55, [ 52]=56, [ 53]=57, [ 54]=58, [ 55]=59,
    [ 56]=60, [ 57]=61, [ 43]=62, [ 47]=63
}


--------------------------------------------------------------------------------
-- u64
--
--  Helper function to convert four six bit values into three full eight
--  bit values. Input values are the integer expression of the six bit value
--  encoded in the original base64 encoded string.
--
local function u64( b1, b2, b3, b4 )
    -- Shift the four six bit values into the byte pattern for the three
    -- full eight bit values
    --
    local cvt=bit32.lshift(b64d[ b1 ], 18) +
              bit32.lshift(b64d[ b2 ], 12) +
              bit32.lshift(b64d[ b3 ],  6) +
                           b64d[ b4 ]

    -- Return the three full eight bit values that are the raw data
    --
    return
        bit32.band( bit32.rshift(cvt,16), 0xff ),
        bit32.band( bit32.rshift(cvt, 8), 0xff ),
        bit32.band( cvt, 0xff )
end

-- pattern_run is the base expression to strip four "valid"
-- characters from the input used by gmatch_run
--
local pattern_run   = "[^%a%d%+%/]-([%a%d%+%/])"
local gmatch_run    = pattern_run..pattern_run..pattern_run..pattern_run

-- pattern_end is the foundation expression for matching
-- the end of a base64 encoded input
--
local pattern_end   = "[^%a%d%+%/%=]-([%a%d%+%/%=])"
local find_end      = ".*"..pattern_end..pattern_end..pattern_end.."([%=]).*$"

-- pattern_strip is used to filter "invalid" input from
-- partial strings used by input iterators
--
local pattern_strip = "[^%a%d%+%/%=]"


--------------------------------------------------------------------------------
-- decode_tail64
--
--  Send the end of stream bytes that didn't get decoded via the main loop.
--
local function decode_tail64( out, e1, e2 ,e3, e4 )

    if tail_padd64[2] == "" or e4 == tail_padd64[2] then
        local n3 = b64e[0]

        if e3 ~= nil and e3 ~= tail_padd64[2] then
            n3 = e3:byte()
        end

        -- Unpack the six bit values into the 8 bit values
        local b1, b2, b3 = u64( e1:byte(), e2:byte(), n3, b64e[0] )

        -- And add them to the res table
        if e3 ~= nil then
            out( string.char( b1, b2, b3 ) )
        else
            out( string.char( b1, b2 ) )
        end
    end
end


--------------------------------------------------------------------------------
-- decode64_io_iterator
--
--  Create an io input iterator to read an input file and split values for
--  proper decoding.
--
local function decode64_io_iterator( file )

    local ii = { }

    -- An enumeration coroutine that handles the reading of an input file
    -- to break data into proper pieces for building the original string.
    --
    local function enummerate( file )
        local ll="" -- last line storage

        -- Read a "reasonable amount" of data into the line buffer. Line by
        -- line is not used so that a file with no line breaks doesn't
        -- cause an inordinate amount of memory usage.
        --
        for cl in file:lines(2048) do
            -- Reset the current line to contain valid chars and any previous
            -- "leftover" bytes from the previous read
            --
            cl = ll:sub( #ll-#ll%4+1, #ll )..cl:gsub(pattern_strip,"")
            --   |                           |
            --   |                           Remove "Invalid" chars
            --   |                           (white space etc)
            --   Left over from last line
            --

            -- see the comments in decode64_with_predicate for a rundown of
            -- the results of this loop (sans the coroutine)
            for a,b,c,d in cl:gmatch( gmatch_run ) do
                coroutine.yield
                (
                    string.char( u64( a:byte(), b:byte(), c:byte(), d:byte() ) )
                )
            end
            -- Set last line for next iteration
            ll = cl
        end

        local e1,e2,e3,e4

        if tail_padd64[2] ~= "" then _,_,e1,e2,e3,e4 = ll:find( find_end )
        elseif #ll%4 == 3       then     e1,e2,e3    = ll:sub(-3,-3), ll:sub(-2,-2), ll:sub(-1,-1)
        elseif #ll%4 == 2       then     e1,e2       = ll:sub(-2,-2), ll:sub(-1,-1)
        elseif #ll%4 == 1       then     e1          = ll:sub(-1,-1)
        end
        if e1 ~= nil then
            decode_tail64( function(s) coroutine.yield( s ) end, e1, e2, e3, e4 )
        end
    end

    -- Returns an input iterator that is implemented as a coroutine. Each
    -- yield of the co-routine sends reconstructed bytes to the lopp handling
    -- the iteration.
    --
    function ii.begin()
        local co = coroutine.create( function() enummerate(file) end )

        return function()
            local code,res = coroutine.resume(co)
            return res
        end
    end

    return ii
end


--------------------------------------------------------------------------------
-- decode64_with_ii
--
--      Convert the value provided by a decode iterator that provides a begin
--      method, a tail method, and an iterator that returns four (usable!) bytes
--      for each call until at the end.
--
local function decode64_with_ii( ii, out )

    -- Uses the iterator to pull values. Each reconstructed string
    -- is sent to the output predicate.
    --
    for l in ii.begin() do out( l ) end

end


--------------------------------------------------------------------------------
-- decode64_with_predicate
--
-- Decode an entire base64 encoded string in memory using the predicate for
-- output.
--
local function decode64_with_predicate( raw, out )
    if tail_padd64[2] ~= "" then
        -- Scan through the input string for four character sequences that
        -- match the rules for base64 encoding. The gmatch_run pattern skips
        -- white space and other non matching characters.
        --
        -- Each byte is converted to a bit pattern via b64d and then sent to
        -- the unpack routine that splits each resulting six bit value set into
        -- three full bytes.
        --
        -- The three full bytes are sent into string.char to build a result
        -- string and finally this string is sent to the output predicate.
        --
        for a, b, c, d in raw:gmatch( gmatch_run ) do
            out( string.char( u64( a:byte(), b:byte(), c:byte(), d:byte() ) ) )
        end

        -- For extra long strings, the find pattern is not very fast so use
        -- a negative index. This runs the risk that a perversely terminated
        -- (but still valid) base64 encoding can fail. This risk is considered
        -- acceptable vs doing a pre-conversion gsub to remove invalid data.
        -- This is to avoid creating a copy of the string.
        --
        local e1, e2, e3, e4
        if raw:len() > 100 then
            _,_, e1, e2, e3, e4 = raw:find( find_end, -100 )
        else
            _,_, e1, e2, e3, e4 = raw:find( find_end )
        end

        decode_tail64( out, e1, e2, e3, e4 )
    else
        for i=1,#raw-#raw%4,4 do
            out( string.char( u64( raw:byte(i), raw:byte(i+1), raw:byte(i+2), raw:byte(i+3) ) ) )
        end

        if     #raw%4 == 3 then decode_tail64( out, raw:sub(-3,-3), raw:sub(-2,-2), raw:sub(-1,-1) )
        elseif #raw%4 == 2 then decode_tail64( out, raw:sub(-2,-2), raw:sub(-1,-1) )
        elseif #raw%4 == 1 then decode_tail64( out, raw:sub(-1,-1) )
        end
    end
end


--------------------------------------------------------------------------------
-- decode64_tostring
--
--  Takes a string that is encoded in base64 and returns the decoded value in
--  a new string.
--
local function decode64_tostring( raw )

    local sb={} -- table to build string

    local function collection_predicate(v)
        sb[#sb+1]=v
    end

    decode64_with_predicate( raw, collection_predicate )

    return table.concat(sb)
end


--------------------------------------------------------------------------------
-- set_and_get_alphabet
--
--  Sets and returns the encode / decode alphabet.
--
--
local function set_and_get_alphabet(alpha,term)

    if alpha ~= nil then
        local magic=
        {
    --        ["%"]="%%",
            [" "]="% ",
            ["^"]="%^",
            ["$"]="%$",
            ["("]="%(",
            [")"]="%)",
            ["."]="%.",
            ["["]="%[",
            ["]"]="%]",
            ["*"]="%*",
            ["+"]="%+",
            ["-"]="%-",
            ["?"]="%?",
        }

        c_alpha=known_base64_alphabets[alpha]
        if c_alpha == nil then
            c_alpha={ _alpha=alpha, _term=term }
        end

        assert( #c_alpha._alpha == 64,    "The alphabet ~must~ be 64 unique values."  )
        assert( #c_alpha._term  <=  1,    "Specify zero or one termination character.")

        b64d={}
        b64e={}
        local s=""
        for i = 1,64 do
            local byte = c_alpha._alpha:byte(i)
            local str  = string.char(byte)
            b64e[i-1]=byte
            assert( b64d[byte] == nil, "Duplicate value '"..str.."'" )
            b64d[byte]=i-1
            s=s..str
        end
        if c_alpha._term ~= "" then
            tail_padd64[1]=string.char(c_alpha._term:byte(),c_alpha._term:byte())
            tail_padd64[2]=string.char(c_alpha._term:byte())
        else
            tail_padd64[1]=""
            tail_padd64[2]=""
        end


        if not c_alpha._run then
            local p=s:gsub("%%",function (s) return "__unique__" end)
            for k,v in pairs(magic)
            do
                p=p:gsub(v,function (s) return magic[s] end )
            end
            c_alpha._run=p:gsub("__unique__",function() return "%%" end)
            if magic[c_alpha._term] ~= nil then
                c_alpha._term=c_alpha._term:gsub(magic[c_alpha._term],function (s) return magic[s] end)
            end
            if c_alpha._term == "%" then c_alpha._term = "%%" end

            pattern_run     = string.format("[^%s]-([%s])",c_alpha._run,c_alpha._run)
            pattern_end     = string.format("[^%s%s]-([%s%s])",c_alpha._run,c_alpha._term,c_alpha._run,c_alpha._term)
            pattern_strip   = string.format("[^%s%s]",c_alpha._run,c_alpha._term)
        else
            assert( c_alpha._end   )
            assert( c_alpha._strip )
            pattern_run   = c_alpha._run
            pattern_end   = c_alpha._end
            pattern_strip = c_alpha._strip
        end

        gmatch_run  = pattern_run..pattern_run..pattern_run..pattern_run

        if c_alpha._term ~= "" then
            find_end = string.format(".*%s%s%s([%s]).*$",pattern_end,pattern_end,pattern_end,c_alpha._term)
        else
            find_end = string.format(".*%s%s%s%s.*$",pattern_end,pattern_end,pattern_end,pattern_end)
        end

        local c =0 for i in pairs(b64d) do c=c+1 end

        assert( c_alpha._alpha == s,        "Integrity error." )
        assert( c == 64,                    "The alphabet must be 64 unique values." )
        if c_alpha._term ~= "" then
            assert( not c_alpha._alpha:find(c_alpha._term), "Tail characters must not exist in alphabet." )
        end

        if known_base64_alphabets[alpha] == nil then
            known_base64_alphabets[alpha]=c_alpha
        end
    end

    return c_alpha._alpha,c_alpha._term
end


--------------------------------------------------------------------------------
-- encode64
--
--  Entry point mode selector.
--
--
local function encode64(i,o)
    if type(i) == "table" then
        assert( type(o) == "function", "input iterator requires output predicate")
        encode64_with_ii(i,o)
    elseif type(i) == "string" then
        if type(o) == "function" then
            encode64_with_predicate(i,o)
        else
            assert( o == nil, "unsupported request")
            return encode64_tostring(i)
        end
    end
end


--------------------------------------------------------------------------------
-- decode64
--
--  Entry point mode selector.
--
--
local function decode64(i,o)
    if type(i) == "table" then
        assert( type(o) == "function", "input iterator requires output predicate")
        decode64_with_ii(i,o)
    elseif type(i) == "string" then
        if type(o) == "function" then
            decode64_with_predicate(i,o)
        else
            assert( o == nil, "unsupported request")
            return decode64_tostring(i)
        end
    end
end


--[[**************************************************************************]]
--[[******************************  Module  **********************************]]
--[[**************************************************************************]]
return
{
    encode      = encode64,
    decode      = decode64,
    encode_ii   = encode64_io_iterator,
    decode_ii   = decode64_io_iterator,
    alpha       = set_and_get_alphabet,
}
