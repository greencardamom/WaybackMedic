#!/usr/bin/lua

--[[---------------------------------------------------

The MIT License (MIT) 

Copyright (c) 2016-2018 by User:GreenC (at en.wikipedia.org)        

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

 ]]


-- Given a Webcite ID on arg[1], return dates in mdy|dmy|iso|ymd format
--   example ID: 6H8pdR68H

-- http://convertxy.com/index.php/numberbases/
-- http://www.onlineconversion.com/unix_time.htm


--[[--------------------------< base62 >-----------------------

     Convert base-62 to base-10
     Credit: https://de.wikipedia.org/wiki/Modul:Expr 

  ]]

local function base62( value )

    local r = 1

    if value:match( "^%w+$" ) then
        local n = #value
        local k = 1
        local c
        r = 0
        for i = n, 1, -1 do
            c = value:byte( i, i )
            if c >= 48  and  c <= 57 then
                c = c - 48
            elseif c >= 65  and  c <= 90 then
                c = c - 55
            elseif c >= 97  and  c <= 122 then
                c = c - 61
            else    -- How comes?
                r = 1
                break    -- for i
            end
            r = r + c * k
            k = k * 62
        end -- for i
    end
    return r
end 

local function main()

  -- "!" in os.date means use GMT 

  zday = os.date("!%d", string.sub(string.format("%d", base62(arg[1])),1,10) )
  day = zday:match("0*(%d+)")                                                             -- remove leading zero
  zmonth = os.date("!%m", string.sub(string.format("%d", base62(arg[1])),1,10) )
  month = zmonth:match("0*(%d+)")
  nmonth = os.date("!%B", string.sub(string.format("%d", base62(arg[1])),1,10) ) 
  year = os.date("!%Y", string.sub(string.format("%d", base62(arg[1])),1,10) )

  mdy = nmonth .. " " .. day .. ", " .. year
  dmy = day .. " " .. nmonth .. " " .. year
  iso = year .. "-" .. zmonth .. "-" .. zday
  ymd = year .. " " .. nmonth .. " " .. day  

  year = tonumber(year)
  month = tonumber(month)
  day = tonumber(day)

  if year < 1970 or year > 2020 then
    print "error"
  elseif day < 1 or day > 31 then
    print "error"
  elseif month < 1 or month > 12 then
    print "error"
  else
    print(mdy .. "|" .. dmy .. "|" .. iso .. "|" .. ymd)
  end 

end

main()
