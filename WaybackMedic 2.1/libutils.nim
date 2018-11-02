import awk, strutils, uri, os, re, unicode

discard """

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
THE SOFTWARE."""

#
# Given a string return "true" of it's empty (0-length) or nil
#
proc empty*(s: string): bool =

  if s == nil:
    return true
  if len(s) < 1:
    return true
  return false

#
# Log (append) a line in a database
#
#  If you need more than 2 columns (ie. name|msg) then format msg with separators in the string itself.
#
proc sendlog*(database, name, msg: string): bool {.discardable.} =

  var safen = name
  var safem = msg
  var sep = "----"

  if(len(safem) > 0):
    safen & sep & safem >> database
  else:
    safen >> database


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
  if empty(pf.dir):  
    return "." & "/"
  else:
    return pf.dir & "/"

  return ""

#
# Given a month name ("Dec" or "December") return the month number 
#  Returns a string not int. Zero-padded.
#  eg. "Jan." = "01"
#
proc month2digit*(s: string): string =

    var 
      s = s

    if s ~ "^[Jj]an":
      s = "01"      
    elif s ~ "^[Ff]eb":
      s = "02"              
    elif s ~ "^[Mm]ar":
      s = "03"                
    elif s ~ "^[Aa]pr":
      s = "04"
    elif s ~ "^[Mm]ay":
      s = "05"
    elif s ~ "^[Jj]un":
      s = "06"
    elif s ~ "^[Jj]ul":
      s = "07"
    elif s ~ "^[Aa]ug":
      s = "08"
    elif s ~ "^[Ss]ep":
      s = "09"
    elif s ~ "^[Oo]ct":
      s = "10"
    elif s ~ "^[Nn]ov":
      s = "11"
    elif s ~ "^[Dd]ec":
      s = "12"

    return s

#
# Given a number from 1 to 9, add a zero-padding if not already padded
#  eg. "9" = "09"
#
proc zeropad*(s: string): string =

    var
      s = s

    if s == "0":
      s = "00"
    elif s == "1":  
      s = "01"
    elif s == "2":
      s = "02"
    elif s == "3":
      s = "03"
    elif s == "4":
      s = "04"
    elif s == "5":
      s = "05"
    elif s == "6":
      s = "06"
    elif s == "7":
      s = "07"
    elif s == "8":
      s = "08"
    elif s == "9":
      s = "09"

    return s

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
# Is even or odd
# Credit: https://nim-lang.org/docs/tut1.html
#
proc even*(n: int): bool

proc odd*(n: int): bool =
  assert(n >= 0) # makes sure we don't run into negative recursion
  if n == 0: false
  else:
    n == 1 or even(n-1)

proc even*(n: int): bool =
  assert(n >= 0) # makes sure we don't run into negative recursion
  if n == 1: false
  else:
    n == 0 or odd(n-1)

#
# Given a URL, return it with first occurance of ":80" removed
#
proc removeport80*(s: string): string =
  if s == "":
    return ""
  return awk.sub( "[:]80[/]", "/", s, 1)

#
# Count occurances of 'sub' string in 's'
#
proc countsubstring*(s, sub: string): int =

  return count(s, sub)

#
# Count occurances of regex 're' in string 's'
#
proc countsubstringregex*(s, re: string): int =

     var 
       field = newSeq[string](0)
       c = 0

     c = patsplit(s, field, re) 

     if c >= 0:
       return c
     else:
       return 0

#
# Count number of " " separated strings in s
#
proc countstrings*(s: string): int =

  if s == "" or s == nil:
    return 0
  if len(s) > 0:
    awk.split(s, a, " ")
    if high(a) == -1:
      return 1
    return high(a) + 1
  return 0

#
# Return the first word in a " " separated string .. return "" if trouble
#
proc firststring*(s: string): string =

  if s == "" or s == nil:
    return ""
  if len(s) > 0:
    awk.split(s, a, " ")
    if high(a) == -1:
      return s
    return a[0]
  return ""

#
# Return number of elements in a seq - only include non-empty elements in the count
#
proc seqlength*(a: seq): int =
  var
    tot = 0
  for i, v in a:
    if len(a[i]) > 0:
      tot = tot + 1
  return tot

#
# Return true if s contains a wikicomment
#
proc ifwikicomments*(s: string): bool =

  var
    space = "[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}"

  if s ~ ("[<]" & space & "[!]" & space & "[-][-]"):
    return true
  return false


#
# Remove the <!-- and --> wiki-markup
# eg. <!-- test --> becomes "test"
#
proc removecommentmarkup*(s: string): string =

  var
    s = s
    space = "[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}"

  gsub("[<]" & space & "[!]" & space & "[-][-]", "stripwiki-AA-WaybackMedic", s)
  gsub("[-][-]" & space & "[>]", "stripwiki-ZZ-WaybackMedic", s)
  gsub("[<]" & space & "[!]" & space & "[-][-]", "stripwiki-AA-WaybackMedic", s)
  gsub("[-][-]" & space & "[>]", "stripwiki-ZZ-WaybackMedic", s)
  gsubs("stripwiki-AA-WaybackMedic", "", s)
  gsubs("stripwiki-ZZ-WaybackMedic", "", s)

  return s

#
# Given a string, return a seq containing the wikicomments
#   getwikicomments("{{cite web|url=http..|date=..<!--|archiveurl=http://..|archivedate=..-->|accessdate=<!--June 6 2018}}-->")
#     @[<!--|archiveurl=http://..|archivedate=..-->, <!--June 6 2018}}-->]
#
#   var comments = @[""]
#   comments = getwikicomments(s)
#   echo $seqlength(comments) #=> 2
#
proc getwikicomments*(s: string): seq =

  if s == "" or s == nil:
    return @[""]

  var
    s = s
    field, sep = @[""]
    space = "[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}"

  gsub("[<]" & space & "[!]" & space & "[-][-]", "stripwiki-AA-WaybackMedic", s)
  gsub("[-][-]" & space & "[>]", "stripwiki-ZZ-WaybackMedic", s)

  gsubs("<", "stripwiki-FF-WaybacKmedic", s)
  gsubs(">", "stripwiki-GG-WaybacKmedic", s)
  gsubs("stripwiki-AA-WaybackMedic", "<!--", s)
  gsubs("stripwiki-ZZ-WaybackMedic", "-->", s)

  var c = patsplit(s, field, "[<]" & space & "[!]" & space & "[-][-][^>]*[>]", sep)

  if c == 0:                                         # no comments
    gsubs("stripwiki-FF-WaybacKmedic", "<", s)
    gsubs("stripwiki-GG-WaybacKmedic", ">", s)
    return @[""]

  if len(sep) == 1 and empty(sep[0]):             # whole string is a comment
    return field

  return field


#
# strip wiki markup <!-- comment --> containing <ref></ref> pairs but leave other comments alone
#
proc stripwikicommentsref*(s: string): string =

  if s == "" or s == nil:
    return ""

  var
    s = s
    field, sep = @[""]
    c = 0
    space = "[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}"

  gsub("[<]" & space & "[!]" & space & "[-][-]", "stripwiki-AA-WaybackMedic", s)
  gsub("[-][-]" & space & "[>]", "stripwiki-ZZ-WaybackMedic", s)

  gsubs("<", "stripwiki-FF-WaybacKmedic", s)
  gsubs(">", "stripwiki-GG-WaybacKmedic", s)
  gsubs("stripwiki-AA-WaybackMedic", "<!--", s)
  gsubs("stripwiki-ZZ-WaybackMedic", "-->", s)

  c = patsplit(s, field, "[<]" & space & "[!]" & space & "[-][-][^>]*[>]", sep)

  if c > 0:          
    for i in 0..c-1:
      if field[i] ~ ("stripwiki[-]FF[-]WaybacKmedic" & space & "[Rr][Ee][Ff]"):   # ie. <ref
        field[i] = ""        
    s = unpatsplit(field,sep)

  gsubs("stripwiki-FF-WaybacKmedic", "<", s)
  gsubs("stripwiki-GG-WaybacKmedic", ">", s)

  return s  

#
# strip wiki markup <!-- comment -->
#  eg. "George Henry is a [[lawyer]]<!-- source? --> from [[Charlesville (Virginia)|Charlesville <!-- west? --> Virginia]]"
#      "George Henry is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]]"
#
proc stripwikicomments*(s: string): string =

  if s == "" or s == nil:
    return ""

  var
    s = s
    build, sand = ""
    field, sep = @[""]
    space = "[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}"

  gsub("[<]" & space & "[!]" & space & "[-][-]", "stripwiki-AA-WaybackMedic", s)
  gsub("[-][-]" & space & "[>]", "stripwiki-ZZ-WaybackMedic", s)

  gsubs("<", "stripwiki-FF-WaybacKmedic", s)
  gsubs(">", "stripwiki-GG-WaybacKmedic", s)
  gsubs("stripwiki-AA-WaybackMedic", "<!--", s)
  gsubs("stripwiki-ZZ-WaybackMedic", "-->", s)

  var c = patsplit(s, field, "[<]" & space & "[!]" & space & "[-][-][^>]*[>]", sep)

  if c == 0:                                         # no comments
    gsubs("stripwiki-FF-WaybacKmedic", "<", s)
    gsubs("stripwiki-GG-WaybacKmedic", ">", s)
    return s

  if len(sep) == 1 and empty(sep[0]):             # whole string is a comment
    return ""

  for i in 0..len(sep) - 1:
    build = build & sep[i]

  if build.len > 0:
    sand = build
  else:
    sand = s

  gsubs("stripwiki-FF-WaybacKmedic", "<", sand)
  gsubs("stripwiki-GG-WaybacKmedic", ">", sand)

  return sand

#
# This will delete all wikilinks 
#  eg. {{cite news |url=http.. |publisher=[[Boxoffice (magazine)|Boxoffice.com]]|accessdate=December 19, 2013}}
#      {{cite news |url=http.. |publisher=|accessdate=December 19, 2013}}
#
# Function is needed for when split()'ing a template along "|" since the wikilink contains it
#
proc stripwikilinks*(s: string): string =

  var 
    field, sep = newSeq[string](0)
    c = 0
    s = s

  gsub("[[]{2}", "stripwikilinks-AA-WaybacKmedic", s)
  gsub("[]]{2}", "stripwikilinks-ZZ-WaybacKmedic", s)

  c = patsplit(s, field, "stripwikilinks-AA-WaybacKmedic|stripwikilinks-ZZ-WaybacKmedic", sep)
  if c > 0:
    for i in 0..c-1:
      if field[i] == "stripwikilinks-AA-WaybacKmedic":
        sep[i+1] = ""
        field[i] = ""
      elif field[i] == "stripwikilinks-ZZ-WaybacKmedic":
        field[i] = ""
    s = unpatsplit(field, sep)

  gsub("stripwikilinks-AA-WaybacKmedic", "[[", s)
  gsub("stripwikilinks-ZZ-WaybacKmedic", "]]", s)

  return s

#
# Convert XML to plain
#
proc convertxml*(str: string): string =
  var safe = str

  gsubs("&lt;",   "<",  safe)
  gsubs("&gt;",   ">",  safe)
  gsubs("&quot;", "\"", safe)
  gsubs("&amp;",  "&",  safe)
  gsubs("&#039;", "'",  safe)

  return safe

#
# Convert common HTML encodings to URL encoding 
#  These are HTML commonly found in archive.org URLs that need to be converted so it can be found in the Wayback Machine
#
proc html2percent*(s: string): string =

  if len(s) < 1:
    return s

  var s = s

  gsubs("&#91;", "%5B", s)    # [
  gsubs("&#93;", "%5D", s)    # ]
  gsubs("&#123;", "%7B", s)   # {
  gsubs("&#125;", "%7D", s)   # }
  gsubs("&#124;", "%7C", s)   # |
  gsubs("&#32;", "%20", s)    # space
  gsubs("&#35;", "%23", s)    # #
  gsubs("&#38;", "%26", s)    # &
  gsubs("&amp;", "%26", s)    # &
  gsubs("&#34;", "%22", s)    # "
  gsubs("&quot;", "%22", s)   # "
  gsubs("&#60;", "%3C", s)    # <
  gsubs("&lt;", "%3C", s)     # <
  gsubs("&#62;", "%3E", s)    # >
  gsubs("&gt;", "%3E", s)     # >

  return s


#
# Given a URL, does it not have a protocol in the scheme?
#  eg. "www.dally.com" -> true
#      "www.dally.com/http://" -> true
#      "mailto://dally.com" -> false
#
proc noprotocol*(url: string): bool =

  var
    p = 0

  p = awk.index(url, "://")

  if p < 0:
    return true

  if system.substr(url,0,p-1) ~ "[.]":  # ignore if outside scheme
    return true

  return false

#
# Percent-encode. Modified version of stdlib cgi:encodeUrl()
# . don't convert '/' or '.'
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
    of 'a'..'z', 'A'..'Z', '0'..'9', '_', '/', '.': add(result, s[i])
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
    "ERROR (1): Unable to parse URL " & url >* "/dev/stderr"
    return ""

  if url ~ "^//":                    # default to http:// if..
    newurl = "http:" & url           #  ..relative protocol
    try:
      u = parseUri(newurl)
    except:
      "ERROR (2): Unable to parse URL " & url >* "/dev/stderr"     
      return ""
  elif empty(u.scheme) or u.scheme ~ "[.]":
    newurl = "http://" & url         #  ..no protocol
    try:
      u = parseUri(newurl)
    except:
      "ERROR (3): Unable to parse URL " & url >* "/dev/stderr"     
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

  var u: Uri

  if url == "" or url == nil:
    return ""

  try:
    u = parseUri(url)
  except:
    "ERROR (1): Unable to parse URL " & url >* "/dev/stderr"     
    return "" 

  if element == "scheme":
    return u.scheme
  if element == "hostname":
    return u.hostname
  if element == "path":  
    return u.path  
  if element == "query":  
    return u.query
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
      if high(s) >= (i + 2):
        var x = 0
        handleHexChar(s[i+1], x)
        handleHexChar(s[i+2], x)
        inc(i, 2)
        result[j] = chr(x)
      else:
        result[j] = s[i]
    of '+': result[j] = '+'
    else: result[j] = s[i]
    inc(i)
    inc(j)
  setLen(result, j)

#
# Given a "." string eg. "6.7.4" increase the last digit by 1 eg. "6.7.5"
#
proc incstep*(s: string): string =
  var
    s = s            
    c,i = 0

  c = awk.split(s, a, "[.]")
  if c > 1:
    i = parseInt(a[c-1])
    inc(i)
    gsub("[.]" & a[c-1] & "$", "." & $i, s)
    return s
  else:
    i = parseInt(s)
    inc(i)
    return $i                  
  return s


#
# Make string safe for shell
#  print shquote("Hello' There")    produces 'Hello'\'' There'
#  echo 'Hello'\'' There'           produces Hello' There
#
proc shquote*(s: string): string =

    var safe = s
    awk.gsub("'", "'\\''", safe)
    awk.gsub("’", "'\\’'", safe)
    return "'" & safe & "'"


#
# See uniReversedPreserving()           
#
proc isComb*(r: Rune): bool =
  (r >=% Rune(0x300) and r <=% Rune(0x36f)) or
    (r >=% Rune(0x1dc0) and r <=% Rune(0x1dff)) or
    (r >=% Rune(0x20d0) and r <=% Rune(0x20ff)) or
    (r >=% Rune(0xfe20) and r <=% Rune(0xfe2f))
#
# Reverse string
#           
# credit: https://github.com/def-/nim-unsorted/blob/master/reverse.nim
#
proc uniReversedPreserving*(s: string): string =
  result = newStringOfCap(s.len)
  var tmp: seq[Rune] = @[]            
  for r in runes(s):
    if isComb(r): tmp.insert(r, tmp.high)               
    else: tmp.add(r)
  for i in countdown(tmp.high, 0):
    result.add(toUtf8(tmp[i]))


#
# print string > stderr - useful for temporary debugging ..
#
proc se*(s: string): bool {.discardable} =
  s >* "/dev/stderr"

#
# Quick exit - useful for tempoary debugging a break point
#
proc qq*() =
  quit(QuitSuccess)

