base64=require("base64")

function basic_tests()
    assert( "VGhpcyBpcyBhIHN0cmluZw==" == base64.encode("This is a string") )
    assert( "Dude! Where is my car???" == base64.decode("RHVkZSEgV2hlcmUgaXMgbXkgY2FyPz8/C") )
    -- Mess with the input "V2hhdCBpcyB0aGlzPwo="
    s="V 2 h h d C Bp c y(((@\n\n\r\t\tB0aGlzPw==      :-)         ?"
    assert( "What is this?\0" == base64.decode(s) )
end

basic_tests()

-- future stuff...
--ii=base64.encode_ii(io.stdin)

--base64._encode_(ii,function(s) io.write(s) end)

-- o={}
-- base64.encode_("Encode this please",function(s) o[#o+1]=s end)
-- for i,v in ipairs(o) do
--     print(i,v)
-- end

-- function linespliter()
--     local c = 0
--     return function(s)
--         io.write(s)
--         c=c+1
--         if c > 5 then
--             io.write("\n")
--             c=0
--         end
--     end
-- end

-- f=io.open("base64.lua")
-- s=f:read("*a")
-- f:close()
-- base64.encode_(s,linespliter())

