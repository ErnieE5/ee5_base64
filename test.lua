--[[ Simple verifications for the base64 encode / decode ]]

require("util")

base64=require("base64")


function test_file_helper()
    local o,f

    function value(_)
        return table.concat(o)
    end

    function collect(s)
        o={}
        return function(s)
            o[#o+1]=s
        end
    end

    function doit(_,v)
        if v == nil and f ~= nil then
            f:seek("set")
            return f, collect()
        end
        if f ~= nil then f:close() end
        f=io.tmpfile()
        f:write(v)
        f:seek("set")
        return f, collect()
    end

    function delete(_)
        f:close()
    end

    return
    {
        value=value,
        doit=doit,
        delete=delete,
    }
end


function basic_tests()
    local a,t,s

    assert( "VGhpcyBpcyBhIHN0cmluZw==" == base64.encode("This is a string") )
    assert( "Dude! Where is my car???" == base64.decode("RHVkZSEgV2hlcmUgaXMgbXkgY2FyPz8/C") )
    -- Mess with the input "V2hhdCBpcyB0aGlzPw=="
    s="V 2 h h d C Bp c y((@\n\n\r\t\tB0aGlzPw= =      :-)         ?"
    assert( "What is this?" == base64.decode(s) )


    a,t = base64.alpha("base64url")
    assert( a == "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_" )
    assert( t == "" )
    assert( "RQ"    == base64.encode("E"        ) )
    assert( "E"     == base64.decode("RQ"       ) )
    assert( "ER"    == base64.decode("RVI"      ) )
    assert( "ERN"   == base64.decode("RVJO"     ) )
    assert( "ERNI"  == base64.decode("RVJOSQ"   ) )
    assert( "ERNIE" == base64.decode("RVJOSUU"  ) )
    assert( "Ernie" == base64.decode("RXJuaWU"  ) )

    a,t = base64.alpha("base64")
    assert( a == "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" )
    assert( t == "=" )
    assert( "RQ=="  == base64.encode("E"        ) )
    assert( "E"     == base64.decode("RQ=="     ) )
    assert( "ER"    == base64.decode("RVI="     ) )
    assert( "ERN"   == base64.decode("RVJO"     ) )
    assert( "ERNI"  == base64.decode("RVJOSQ==" ) )
    assert( "ERNIE" == base64.decode("RVJOSUU=" ) )
    assert( "Ernie" == base64.decode("RXJuaWU=" ) )

    local custom_a="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789~!"
    local custom_t="%"

    a,t = base64.alpha(custom_a,custom_t)
    assert( a == custom_a )
    assert( t == custom_t )
    assert( "RQ%%"  == base64.encode("E"        ) )
    assert( "E"     == base64.decode("RQ%%"     ) )
    assert( "ER"    == base64.decode("RVI%"     ) )
    assert( "ERN"   == base64.decode("RVJO"     ) )
    assert( "ERNI"  == base64.decode("RVJOSQ%%" ) )
    assert( "ERNIE" == base64.decode("RVJOSUU%" ) )
    assert( "Ernie" == base64.decode("RXJuaWU%" ) )

    s="This is a test string."

    local f = test_file_helper()

    base64.decode( f:doit("VGhpcyBpcyBhIHRlc3Qgc3RyaW5nLg%%") )
    assert( s == f:value() )

    base64.alpha("base64")
    base64.decode( f:doit("VGhpcyBpcyBhIHRlc3Qgc3RyaW5nLg==") )
    assert( s == f:value() )

    base64.alpha("base64url")
    base64.decode( f:doit("VGhpcyBpcyBhIHRlc3Qgc3RyaW5nLg") )
    assert( s == f:value() )

    base64.encode( f:doit( s ) )
    assert( "VGhpcyBpcyBhIHRlc3Qgc3RyaW5nLg"    == f:value() )

    base64.alpha("base64")
    base64.encode( f:doit() )
    assert( "VGhpcyBpcyBhIHRlc3Qgc3RyaW5nLg=="  == f:value() )

    base64.alpha( custom_a )
    base64.encode( f:doit() )
    assert( "VGhpcyBpcyBhIHRlc3Qgc3RyaW5nLg%%"  == f:value() )

    f:delete()

end


basic_tests()

print("\nIt's all  good...\n")
