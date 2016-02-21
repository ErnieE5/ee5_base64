--[[ test_encode.lua ]]
require("ee5_base64").encode(io.stdin:read("*a"),io.stdout)
--                           |
--                           Reads entire file to string
