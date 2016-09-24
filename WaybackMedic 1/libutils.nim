import awk, strutils, uri, os

discard """ 

The MIT License (MIT)

Copyright (c) 2016 by User:Green Cardamom (at en.wikipedia.org)

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
THE SOFTWARE."""


#
# Sleep X seconds (module:os)
#
proc sleep*(sec: int): bool {.discardable.} =
  var t: int
  t = sec * 1000
  os.sleep(t)

#
# Print the directory portion of a /dir/filename string. End with trailing "/"
#   eg. /home/adminuser/wi-awb/tcount.awk -> /home/adminuser/wi-awb/
#
proc dirname*(pathname: string): string =
  var pf = splitFile(pathname)
  if len(pf.dir) == 0:  
    return "." & "/"
  else:
    return pf.dir & "/"

  return ""

#
# Return true if string contains only numbers and is > 0 chars in length
#
proc isanumber*(s: string): bool =

  if s == "" or s == nil:
    return false

  if isDigit(s):
    return true
  return false

#
# Count occurances of 'sub' string in 's'
#
proc countsubstring*(s, ss: string): int =
  return count(s, ss)

#
# strip wiki markup <!-- comment -->
#  eg. "George Henry is a [[lawyer]]<!-- source? --> from [[Charlesville (Virginia)|Charlesville <!-- west? --> Virginia]]"
#      "George Henry is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]]"
#
proc stripwikicomments*(s: string): string =

  if s == "" or s == nil:
    return ""

  var field, sep = @[""]
  var c = patsplit(s, field, "<[ ]{0,}[!][^>]*>", sep)
  var build = sep[0]
  for i in 1..c - 1:
    if sep[i] !~ "<[ ]{0,}[!][ ]{0,}[-]":
      build = build & sep[i]
  #  build = build & sep[i]
  if build.len > 0:
    return build
  else:
    return s
  return s
#
# Convert XML to plain
#
proc convertxml*(str: string): string =
  var safe = str
  gsub("&lt;","<",safe)
  gsub("&gt;",">",safe)
  gsub("&quot;","\"",safe)
  gsub("&amp;","&",safe)
  gsub("&#039;","'",safe)
  return safe

#
# Remove substring defined by 'start' and 'end' in string 'source'
#  . Returns the new string
#  . If error return full original 'source'
#
proc removesection*(source: string, s, e: int, caller: string): string =

  var debug = false
  if caller ~ "none":
    debug = true

  if debug:
    "removesection (e): " & $e >* "/dev/stderr"
    "removesection (s): " & $s >* "/dev/stderr"

  if source.len == 0 or e == 0 or s >= high(source):
    if debug: 
      "removesection: numbers wrong: " & $source.len & " " & $e & " " & $s >* "/dev/stderr"
    return source                  
  var newsource = source
  var final = ""        
  for i in 0..high(source):         
    if i < s or i > e :
      add(final, newsource[i])   
  if len(final) > 0:
    if debug:
      if final.len > 1000: 
        "removesection (final): <too big to display>" >* "/dev/stderr"
      else:
        "removesection (final): " & final >* "/dev/stderr"
    return final                 
  else:
    if debug: "removesection (abort) early" >* "/dev/stderr"
    return source

  return ""

#
# Insert 'new' string in 'source' at character location 'start' (w/ special rules for spaces customized for Wikipedia templates and external links)
#
proc insertsection*(source: string, start: int, new, caller: string): string =

  var debug = false
  if caller ~ "none":
    debug = true

  if debug: 
    "insertsection (source length): " & $source.len  >* "/dev/stderr"
    if source.len < 1000: 
      "insertsection (source value): |" & source & "|"  >* "/dev/stderr"
    else:
      "insertsection (source value): too big for display (whole article?)" >* "/dev/stderr"
    "insertsection (new length): " & $new.len  >* "/dev/stderr"
    if new.len < 1000: 
      "insertsection (new value): |" & new & "|"  >* "/dev/stderr"
    else:
      "insertsection (new value): too big for display (whole article?)" >* "/dev/stderr"
    "insertsection (start): " & $start  >* "/dev/stderr"
   
  if source.len == 0:                                 
    if debug: "insertsection (source is zero)"  >* "/dev/stderr"
    return new

  if new.len == 0:                                     
    if debug: "insertsection (new is zero)"  >* "/dev/stderr"
    return source

  if start > high(source):                               # Append to end of source if start is > length of source.
    if source[high(source)] == ' ':
      if debug: "insertsection (trap 1)"  >* "/dev/stderr"
      return source & new
    else:
      if debug: "insertsection (trap 2)"  >* "/dev/stderr"
      return source & " " & new

  var build = source

  for i in 0..high(source):

    if i == start:
      if debug: "insertsection (trap 3)"  >* "/dev/stderr"
                                                            # Append space if "start" is | or }, and preceeding is not a space
      if awk.substr(source,i,1) ~ "[|]|[}]":
        if i > 0:
          if source[i - 1] != ' ':
            if debug: "insertsection (case 1)" >* "/dev/stderr"
            insert(build, new & " ", i)
          else:
            if debug: "insertsection (case 4)" >* "/dev/stderr"
            insert(build, new, i)
        else:
          insert(build, new, i)
          if debug: "insertsection (case 3)"  >* "/dev/stderr"

      else:
        insert(build, new, i)
        if debug: 
          "insertsection (case 2)"  >* "/dev/stderr"
          "insertsection (start) = " & $start >* "/dev/stderr"
          if source.len > 1000:
            "insertsection (source5) = <too big to display>" >* "/dev/stderr"
          else:
            "insertsection (source5) = " & source >* "/dev/stderr"

  return build

#
# In 'source' string, replace 'old' text with 'new' text (via non-regex)
#
proc replacetext*(source, old, new, caller: string): string =

  var debug = false
  if caller ~ "none":
    debug = true

  if debug: 
    "Caller: " & caller >* "/dev/stderr"
    "Source:" >* "/dev/stderr"
    if source.len > 1000:
      "<source too big to display>" >* "/dev/stderr"
    else:
      source >* "/dev/stderr"
    "Old:" >* "/dev/stderr"
    old >* "/dev/stderr"
    "New:"  >* "/dev/stderr"
    new >* "/dev/stderr"

  if len(source) == 0 or len(old) == 0:
    if debug:
      var msg = "Replacetext(1): Aborted: found " & $len(source) & " " & $len(old)                            
      msg >* "/dev/stderr"
    return source

  var source = source
  var old = old
  gsub("\n", "***!!***", source)    # For multi-line templates.. convert to a single line with "***!!***" as location of \n
  gsub("\n", "***!!***", old)

  var c = countsubstring(source, old)

  if c != 1:  # found 0 (or >1) instances of 'old' in 'source'
    if debug:
      echo "|" & old & "| is " & $old.len & " chars long."
      var msg = "Replacetext(2): Aborted: found " & intToStr(c) & " copy(s) of string (" & old & ") in source"
      msg >* "/dev/stderr"
    gsub("[*][*][*][!][!][*][*][*]", "\n", source)   # For multi-line templates.. restore \n
    return source

  var safe = source
  var inx = index(safe, old)
  if debug: "Index = " & $inx  >* "/dev/stderr"
  if inx == 0 and len(old) == len(safe):
    safe = ""
  else:
    safe = removesection(safe, inx, len(old) + inx - 1, caller)
  if debug: 
    "Post-remove (start block): " >* "/dev/stderr" 
    if safe.len > 1000:
      "<too big to display>" >* "/dev/stderr"
    else:
      safe >* "/dev/stderr"
    "Post-remove (end block): " >* "/dev/stderr" 
  safe = insertsection(safe, inx, new, caller)
  if debug: 
    "Post-insert (start block): " >* "/dev/stderr" 
    if safe.len > 1000:
      "<too big to display>" >* "/dev/stderr"
    else:
      safe >* "/dev/stderr"    
    "Post-insert (end block): " >* "/dev/stderr" 

  gsub("[*][*][*][!][!][*][*][*]", "\n", safe)   # For multi-line templates.. restore \n

  return safe

#
# Percent-encode. Modified version of stdlib cgi:encodeUrl()
# . don't convert '/' 
# . msg = "plus" means spaces are rendered '+' (default: %20)
#
proc quote*(s: string, msg: varargs[string]): string =

  if s == "" or s == nil:
    return ""

  var magic = ""
  if msg.len == 0:
    magic = "twenty"
  else:
    if msg[0] == nil:
      magic = "twenty"
    elif msg[0] == "plus": 
      magic = "plus"
    else: 
      magic = "twenty"

  result = newStringOfCap(s.len + s.len shr 2) # assume 12% non-alnum-chars

  for i in 0..s.len-1:
    case s[i]
    of 'a'..'z', 'A'..'Z', '0'..'9', '_', '/': add(result, s[i])
    of ' ':
      if magic == "plus":
        add(result, '+')
      else:
        add(result, "%20")
    else:
      add(result, '%')
      add(result, toHex(ord(s[i]), 2))

#
# Given a URI, return percent-encoded in the hostname (limited), path and query portion only. Retain +
#
#  Doesn't do international hostname encoding "http://你好.com/" different from percent encoding
#
#  Example:
#  https://www.cwi.nl:80/guido&path/Python/http://www.test.com/Władysław T. Benda.com ->
#    https://www.cwi.nl:80/guido%26path/Python/http%3A//www.test.com/W%C5%82adys%C5%82aw%20T.%20Benda.com
#
proc uriparseEncodeurl*(url: string): string =

  if url == "" or url == nil:
    return ""

  var u: Uri
  var p, q, a, newurl = ""

  try:
    u = parseUri(url)
  except:
    return ""

  if url ~ "^//":                    # default to http:// if..
    newurl = "http:" & url           #  ..relative protocol
    try:
      u = parseUri(newurl)
    except:
      return ""
  elif u.scheme ~ "[.]" or u.scheme.len == 0:
    newurl = "http://" & url         #  ..no protocol
    try:
      u = parseUri(newurl)
    except:
      return ""

  if u.port.len > 0:
    p = ":" & u.port
  else:
    p = ""
  if u.query.len > 0:
    q = "?" & quote(u.query, "plus")
  else:
    q = ""
  if u.anchor.len > 0:
    a = "#" & quote(u.anchor)
  else:
    a = ""

  result = u.scheme & "://" & u.hostname & p & quote(u.path) & q & a

#
# Return portion of URL string defined by one of 4 'element'
#  eg. uriparseElement("http://www.google.com/path/index.htm", "scheme") -> "http"
#  If no available (as in "anchor" in example) returns blank string
#
proc uriparseElement*(url, element: string): string {.discardable.} =

  if url == "" or url == nil:
    return ""

  var u = parseUri(url)

  if element == "scheme":
    return u.scheme
  if element == "hostname":
    return u.hostname
  if element == "path":  
    return u.path  
  if element == "anchor":
    return u.anchor
  else: 
    return ""

#
# Needed for urldecode() - from stdlib cgi
#
proc handleHexChar(c: char, x: var int) {.inline.} =
  case c
  of '0'..'9': x = (x shl 4) or (ord(c) - ord('0'))
  of 'a'..'f': x = (x shl 4) or (ord(c) - ord('a') + 10)
  of 'A'..'F': x = (x shl 4) or (ord(c) - ord('A') + 10)
  else: x = x

#
# Decode URL. Modified version of stdlib cgi:decodeUrl()
#
# . Don't decode '+'
#
proc urldecode*(s: string): string =

  if s == "" or s == nil:
    return ""

  result = newString(s.len)
  var i = 0
  var j = 0
  while i < s.len:
    case s[i]
    of '%':
      var x = 0
      handleHexChar(s[i+1], x)
      handleHexChar(s[i+2], x)
      inc(i, 2)
      result[j] = chr(x)
    of '+': result[j] = '+'
    else: result[j] = s[i]
    inc(i)
    inc(j)
  setLen(result, j)

#
# Debug for quick exit
#
proc qq*() =
  quit(QuitSuccess)
