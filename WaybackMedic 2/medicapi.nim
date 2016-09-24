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
# Given url (as .origiaurl or .formated), return best working wayback or altarch URL
#   Otherwise return "none"
#
proc api(url: string): tuple[m: string, z:int] =

  var url = strip(url)

  for tag in 0..GX.id:
    if WayLink[tag].origiaurl == url or WayLink[tag].formated == url:
      if WayLink[tag].status ~ "^2":
        if isarchiveorg(WayLink[tag].newiaurl) and WayLink[tag].available == "wayback":
          result[0] = WayLink[tag].newiaurl
          result[1] = tag
          return
        elif isarchiveorg(WayLink[tag].formated) and WayLink[tag].available == "wayback":
          result[0] = WayLink[tag].formated
          result[1] = tag
          return
        elif WayLink[tag].available == "altarch":
          result[0] = WayLink[tag].altarchencoded
          result[1] = tag
          return
        else:
          result[0] = "none"
          result[1] = -1
          return
      else:
        result[0] = "none"
        result[1] = -1
        return

  result[0] = "none"
  result[1] = -1


#
# Given an IA URL, check the timestamp date/time are within normal range 
#  eg. this is wrong: http://web.archive.org/web/20131414230300/http://www.iter.org/proj/iterandbeyond
# If out of range, download page and web scrape for correct date and return corrected URL
#
proc validiaurl(url: string): string =

  var body = ""
  var errC = 0
  var newstamp, re, vhour, vmin, vsec, vmonth, vday, vyear = ""

  var url = strip(url)
  var stamp = urltimestamp(url)

  if validate_datestamp(stamp) == false:

    if Debug.network: ("Out of range for " & url) >* "/dev/stderr"

    if url ~ "'":
      gsub("'","%27",url)    # shell escape literal string

    let command = "wget" & GX.wgetopts & "-O- -q '" & url & "'"

    (body, errC) = execCmdEx(command)

    if len(body) == 0:
      return url
    if body ~ "^/bin/sh[:] 1[:] Syntax error":
      sendlog(Project.syntaxerror, CL.name, "validiaurl")
      return url

    # Redirect type 1 (manual click through to new page)

     # <p class="impatient"><a href="/web/20160316190307/http://www.amazon.com/Game-Thrones-Season-Blu-ray-Digital/dp/B00VSG3MSC">Impatient?</a></p>

    if match(body, "[pP] [cC]lass[=][\"][Ii]mpatient[ ]?[\"][ ]?[>][ ]?[<][ ]?[aA] [hH]ref[ ]?[=][ ]?[\"]/w?e?b?/?[^>]*>", dest) > 0:
      match(dest, "[aA] [hH]ref[ ]?[=][ ]?[\"]/w?e?b?/?[^>]*[^>]", dest2)
      gsub("[aA] [hH]ref[ ]?[=][ ]?[\"]","",dest2)
      gsub("\"$", "", dest2)
      newstamp = "https://web.archive.org" & dest2
      return newstamp
        
    # Redirect type 2 (automatic push through to new page)

    elif match(body, "FILE ARCHIVED ON [0-9]{1,2}[:][0-9]{1,2}[:][0-9]{1,2}[^A]*AND[ ]RETRIEVED", dest) > 0:

      if match(dest, "[0-9]{1,2}[:][0-9]{1,2}[:][0-9]{1,2}", dest2) > 0:

        if awk.split(dest2, a, ":") == 3:
          vhour = a[0]
          if len(vhour) == 1: vhour = "0" & vhour
          vmin  = a[1]
          if len(vmin) == 1: vmin = "0" & vmin
          vsec  =  a[2]
          if len(vsec) == 1: vsec = "0" & vsec

      if match(dest, " (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) ", dest2) > 0:
        if dest2 == " Jan ": vmonth = "01"
        if dest2 == " Feb ": vmonth = "02"
        if dest2 == " Mar ": vmonth = "03"
        if dest2 == " Apr ": vmonth = "04"
        if dest2 == " May ": vmonth = "05"
        if dest2 == " Jun ": vmonth = "06"
        if dest2 == " Jul ": vmonth = "07"
        if dest2 == " Aug ": vmonth = "08"
        if dest2 == " Sep ": vmonth = "09"
        if dest2 == " Oct ": vmonth = "10"
        if dest2 == " Nov ": vmonth = "11"
        if dest2 == " Dec ": vmonth = "12"

        re = dest2 & "[0-9]{1,2}[,][ ][0-9]{4}"

        if match(dest, re, dest3) > 0:
          if awk.split(dest3, b, " ") == 4:
            if match(b[2], "[0-9]{1,2}", vday) > 0:
              if len(vday) == 1:
                vday = "0" & vday
            if len(b[3]) == 4:
              vyear = b[3]

      newstamp = vyear & vmonth & vday & vhour & vmin & vsec
      newstamp = strip(newstamp)

      echo "NEWSTAMP = " & newstamp

      if validate_datestamp(newstamp) == true:
        gsub(stamp,newstamp,url)

  return url

#
# Memento API JSON -> MemLink object
#  example url:
#  http://timetravel.mementoweb.org/api/json/20090101075242/http://www.themusic.com.au:80/imm_display.php?s%3Dchristie%26id%3D556%26d%3D2008-08-12
#
#
proc japi2memlink(japi: string): bool =

  MemLink.closest = ""
  MemLink.prev = ""
  MemLink.next = ""
  MemLink.first = ""

  var date = ""
  var uri = ""

  # Basic validations
  if len(japi) == 0: 
    return false
  if japi[0] != '{' and japi[high(japi)] != '}':  
    return false

  for d, m in json.pairs(  parseJson(japi)  ):
    if d == "mementos":
      for e, n in json.pairs(m):
        if e == "closest":
          for f, o in json.pairs(n):
            if f == "datetime":
              date = gsub("-", "", substr($o, 1, 10))
            if f == "uri":
              for g in json.items(o):
                uri = substr($g, 1, len($g) - 2)
                break   # first one only
          if len(date) > 0 and len(uri) > 0:
            MemLink.closest = uri & " | " & date
          date = ""
          uri = ""
        if e == "prev":
          for f, o in json.pairs(n):
            if f == "datetime":
              date = gsub("-", "", substr($o, 1, 10))
            if f == "uri":
              for g in json.items(o):
                uri = substr($g, 1, len($g) - 2)
                break   # first one only
          if len(date) > 0 and len(uri) > 0:
            MemLink.prev = uri & " | " & date
          date = ""
          uri = ""
        if e == "first":
          for f, o in json.pairs(n):
            if f == "datetime":
              date = gsub("-", "", substr($o, 1, 10))
            if f == "uri":
              for g in json.items(o):
                uri = substr($g, 1, len($g) - 2)
                break   # first one only
          if len(date) > 0 and len(uri) > 0:
            MemLink.first = uri & " | " & date
          date = ""
          uri = ""
        if e == "next":
          for f, o in json.pairs(n):
            if f == "datetime":
              date = gsub("-", "", substr($o, 1, 10))
            if f == "uri":
              for g in json.items(o):
                uri = substr($g, 1, len($g) - 2)
                break   # first one only
          if len(date) > 0 and len(uri) > 0:
            MemLink.next = uri & " | " & date
          date = ""
          uri = ""

  if len(MemLink.first) > 1 or len(MemLink.closest) > 1 or len(MemLink.prev) > 1 or len(MemLink.next) > 1:
    return true
  return false

#
# IA JSON -> WayLinkObj
#  . use &tag from the API result to match with ID in WayLink 
#
proc japi2waylink(japi: string): int =
  
  var tag, count = 0

  # Basic validations
  if len(japi) == 0: 
    return 0
  if japi[0] != '{' and japi[high(japi)] != '}':  
    return 0

  for d, m in pairs(parseJson(japi)):
    if d == "results":
      for e in items(m):
        for f, n in pairs(e):
          if f == "tag":
            tag = parseInt(gsub("^\"|\"$","",$n))
            for g, o in pairs(e):
              if g == "archived_snapshots":
                if o.len > 0:
                  for h, p in pairs(o):
                    if h == "closest":
                      WayLink[tag].newurl = WayLink[tag].origurl
                      WayLink[tag].available = strip(gsub("^\"|\"$", "", $p["available"]))
                      if WayLink[tag].available == "true": 
                        WayLink[tag].available = "wayback"
                        WayLink[tag].newiaurl = validiaurl(formatediaurl(strip(gsub("^\"|\"$", "", $p["url"])), "barelink"))
                      else:
                        WayLink[tag].newiaurl = formatediaurl(strip(gsub("^\"|\"$", "", $p["url"])), "barelink")
                      WayLink[tag].newiaurl = replace(WayLink[tag].newiaurl, "\\\\", "\\")        # IA API turns "\" into "\\"
                      WayLink[tag].status = strip(gsub("^\"|\"$", "", $p["status"]))
                      count.inc
                else:                        # empty result "{}"
                  WayLink[tag].newurl = WayLink[tag].origurl
                  WayLink[tag].newiaurl = "none"
                  WayLink[tag].available = "false"
                  WayLink[tag].status = "0"
          tag = 0
  return count

#
# IA JSON (single record) -> URL value
#
proc japi2singleurl(japi: string): string =

  var val = ""

  # Basic validations
  if len(japi) == 0:
    return "none"
  if japi[0] != '{' and japi[high(japi)] != '}':
    return "none"          

  for d, m in pairs(parseJson(japi)):
    if d == "results":
      for e in items(m):
        for f, n in pairs(e):
          if f == "archived_snapshots":
            if n.len > 0:
              for h, p in pairs(n):
                if h == "closest":
                  val = strip( gsub("^\"|\"$", "", $p["url"]) )
                  if val ~ "^http":
                    return validiaurl(val)
                  else:
                    return "none"
  return "none"


#
# Validate webcitation.org URL 
#
proc validate_webcite(url: string): bool =

  var
    xmlin = ""
    errC: int

  let command = "wget" & GX.wgetopts & "-q -O- \"http://www.webcitation.org/query?url=" & url & "&returnxml=true\""
  if Debug.network: command >* "/dev/stderr"

  (xmlin, errC) = execCmdEx(command)

  if len(xmlin) == 0:
    libutils.sleep(2)
    (xmlin, errC) = execCmdEx(command)
    if len(xmlin) == 0:
      if Debug.network: 
        "ERROR: Webcite returned 0-length API" >* "/dev/stderr"
        return false

  if xmlin ~ "result status[ ]{0,}=[ ]{0,}\"success\"" :
    return true

  return false


#
# Pick the best Alternative Archive from Memento list, bypassing Wayback and archive.is snapshots
#  url should be encoded before passing
#  Sample JSON data: wget -q -O- "http://timetravel.mementoweb.org/api/json/20130115102033/http://cnn.com" | jq '. [ ]'
#
proc api_memento(url, date: string, tag: int): string =
  
  var jsonin = ""
  var errC: int

  let command = "wget" & GX.wgetopts & "-q -O- \"http://timetravel.mementoweb.org/api/json/" & date & "/" & url & "\"" 
  if Debug.network: command >* "/dev/stderr"

  (jsonin, errC) = execCmdEx(command)

  if len(jsonin) == 0:
    libutils.sleep(2)
    (jsonin, errC) = execCmdEx(command)
    if len(jsonin) == 0:
      if Debug.network: "ERROR: Memento returned 0-length API" >* "/dev/stderr"
      return "none"
  if jsonin ~ "^/bin/sh[:] 1[:] Syntax error":
    sendlog(Project.syntaxerror, CL.name, "api_memento")
    return "none"


  jsonin & "\n----" >> GX.datadir & "mementoapi.json"

  if japi2memlink(jsonin):
    let snap = "closest prev next first"  # Check in this order ("closest" is first checked, then "prev" etc) 
    var raw, muri, mdate = ""
    var q = 0    

    for i in split(snap):
      raw = fieldvalMO(MemLink, strip(i))
      if awk.split(raw, a, "[ ][|][ ]") == 2:
        muri = strip(a[0])
        mdate = strip(a[1])
        if not isarchiveorg(muri) and muri ~ "^http" and muri !~ "archive[.]is/":
          
         if muri ~ "webcitation[.]org":
           q = awk.split(muri, p, "/")  # webcitation.org with a path < 5 characters is a broken URL
           if len(p[q - 1]) < 5:
             continue
           if validate_webcite(url) == false:
             continue

         WayLink[tag].altarch = urldecode(muri)
         if muri ~ "webcitation[.]org":                # longform URL per RfC 
           WayLink[tag].altarchencoded = uriparseEncodeurl(muri) & "?url=" & url
         else:
           WayLink[tag].altarchencoded = uriparseEncodeurl(muri) 
         WayLink[tag].altarchdate = mdate
         return "OK"

  return "none"  

#
# Create a file w/ API POST data.
#
#   API documentation: http://207.241.231.246:8120/usage (archived https://archive.is/6ZcDv)
#                      https://wwwb-app37.us.archive.org:8120/usage
#
proc createpostdata(postfile: string): bool {.discardable.} =
  var request = ""
  if existsFile(postfile):
    removeFile(postfile)
  for tag in 0..GX.id:
    if WayLink[tag].origdate != "none" and WayLink[tag].origencoded != "none":
      request = "url=" & WayLink[tag].origencoded & "&closest=either&timestamp=" & WayLink[tag].origdate & "&tag=" & $tag & "&statuscodes=404&statuscodes=200&statuscodes=203&statuscodes=206"      
    else:
      request = "url=" & WayLink[tag].origencoded & "&closest=either&timestamp=19700101&tag=" & $tag & "&statuscodes=404&statuscodes=200&statuscodes=203&statuscodes=206"      
    request >> postfile


#
# Create a JSON file containing empty (ie. unavailable) records for everything in postfile
#  This routes around a problem with the API post method, and sets it up to allow for get method
#
proc createemptyjson(postfile: string): string =

  var s, ts = ""
  awk.split(readfile(postfile), sa, "\n")

  s = "{\"results\": ["

  for i in 0..high(sa):
    match(sa[i], "&timestamp[=][0-9]{1,14}", ts)
    gsub("url[=]", "", sa[i])
    if awk.split(sa[i], sc, "&") > 0:
      if sc[0] ~ "^http":
        s = s & "{\"url\": \"" & urldecode(sc[0]) & "\", \"timestamp\": \"" & ts & "\", \"archived_snapshots\": {}, \"tag\": \"" & $i & "\"}"
        if i != high(sa) - 1:
          s = s & ", "

  s = s & "]}"
  return s

#
# Fill WayLink[] with values        
#
proc fillway(tag: int, status, available, newiaurl, newurl: string): void =

  WayLink[tag].status = status
  WayLink[tag].available = available
  WayLink[tag].newiaurl = formatediaurl(newiaurl, "barelink")
  WayLink[tag].newurl = newurl

  if WayLink[tag].newiaurl != "none":          # Security check
    if not isarchiveorg(WayLink[tag].newiaurl):
      WayLink[tag].newiaurl = "none"

#
# Header response code (200 is OK, 403 is permission denied etc..)
#  Return the code, otherwise -1    
#
proc headerresponse(head: string): int =

  var cache = newSeq[int](0)
  var c, d, le: int

  c = awk.split(head, a, "\n")
  for i in 0..c - 1:
    if a[i] ~ "^[ ]{0,5}[Hh][Tt][Tt][Pp]/1[.]1": 
      if awk.split(a[i], b, " ") > 0:
        d = parseInt(strip(b[3])) 
        if d > 1:               
          cache.add(d)         
 
  le = len(cache) 
  if le > 0: 
    if cache[le - 1] > 0:  # Get the last HTTP response        
      return cache[le - 1]   
  return -1

#
# Return first X lines of wget body file .. presume interesting info there -- rest is content.
#  prevent large files (mp4s etc) from killing swap
#
proc bodylead(bodypath: string): string =

  var final = ""
  var fp: File
  var j = 0

  try:
    fp = open(bodypath)
  except:
    return ""
  try:
    while j < 1000:
      final = final & readLine(fp) & "\n"      
      j.inc
  except:
    return ""
  finally:
    close(fp)
    return final
  return final

#    
# Page is a bummer or robots or etc.
#
proc pageerror(body: string): string =

  var c: int
  var status = "none"

  c = awk.split(bodylead(body), a, "\n")
  for i in 0..c - 1:
    if a[i] ~ "The machine that serves this file is down":                          # archive.org and archive.is
      status = "bummer" 
    if a[i] ~ "Page cannot be crawled or displayed due to robots.txt":              # archive.org and archive.is
      status = "robots"   
    if a[i] ~ "404[ ]{0,}[-][ ]{0,}Page cannot be found":
      status = "404"
    if a[i] ~ "404[ ]{0,}[-][ ]{0,}File or directory not found":
      status = "404"
    if a[i] ~ "show[_]404":
      status = "404"
    if a[i] ~ "This URL has been excluded from the Wayback Machine":             
      status = "excluded"    
    if a[i] ~ "Redirecting to[.][.][.]":
      status = "redirect"

  return status


#
# Page is an IA info page of any kind.. (add more here as they are found)
#
proc iainfopage(body: string): bool =

  var c: int
  var status = false
  
  c = awk.split(bodylead(body), a, "\n")
  for i in 0..c - 1:
    if a[i] ~ "Your use of the Wayback Machine is subject to the Internet Archive":
      status = true
    if a[i] ~ "Wayback Machine doesn't have that page archived":
      status = true
    if a[i] ~ "Redirecting to[.][.][.]":
      status = true
  return status

#
# Page is an IA redirect page
#
# Example 200 page that is a redirect to a dead page
#  http://web.archive.org/web/20120512133959/http://www.nileslibrary.org:2065/pqdweb?index=405&did=575152532&SrchMode=1&sid=2&Fmt=10&VInst=PROD&VType=PQD&RQT=309&VName=HNP&TS=1250223809&clientId=68442
# Example 200 page that is a redirect to a working page and the API says this URL has no snapshots available
#  http://web.archive.org/web/20090205165059/http://news.bbc.co.uk/sport1/hi/cricket/7485935.stm
#
proc iaredirect(body: string): bool =

  var c: int
  var status = false

  c = awk.split(bodylead(body), a, "\n")
  for i in 0..c - 1:
    if a[i] ~ "Got an HTTP 302 response at crawl time":
      status = true
    if a[i] ~ "Redirecting to[.][.][.]":
      status = true
  return status


#
# Find the redirect URL from body of IA 302 info page
#  Since using scrape, try 2 methods in case page formatting changes.
#
proc getredirurl(origurl, filename: string): string =

  var body, k, url, newurl, path, origpath, origurl2 = ""

  if existsFile(filename):
    body = readfile(filename)
  else:
    return

  gsub("\n|\r|\t"," ",body)     

  # Method 1
  # <p class="impatient"><a href="/web/20090205165059/http://news.bbc.co.uk/sport2/hi/cricket/7485935.stm">

  if match(body,"[<][ ]{0,}[Pp][ ]{1,}[Cc][Ll][Aa][Ss]{2}[ ]{0,}[=][ ]{0,}\"[ ]{0,}[Ii]mpatient[ ]{0,}\"[ ]{0,}>[ ]{0,}[<][ ]{0,}[Aa][ ]{1,}[Hh][Rr][Ee][Ff][ ]{0,}[=][ ]{0,}\"[^\"]*\"", k) > 0:
    if awk.split(k, a, "\"") == 5:                
      url = strip(a[3])

  # Method 2      
  # function go() { document.location.href = "\/web\/20090205165059\/http:\/\/news.bbc.co.uk\/sport2\/hi\/cricket\/7485935.stm"

  if len(url) == 0 and match(body, "function[ ]{1,}go[(][)][ ]{0,}[{][ ]{0,}document[.]location[.]href[ ]{0,}[=][ ]{0,}\"[^\"]*\"", k) > 0:
     if awk.split(k, a, "\"") == 3:
       gsub("\\/","/",a[1])
       url = strip(a[1])

  url = convertxml(url)
  url = "https://web.archive.org"  & url
  newurl = wayurlurl(url)

  if isarchiveorg(origurl):
    origurl2 = wayurlurl(origurl)

  if newurl ~ "^http" and origurl2 ~ "^http" and len(newurl) < len(origurl2):    # Basic filters soft-404
    path = uriparseElement(newurl, "path")
    origpath = uriparseElement(origurl2, "path")
    if len(path) < 2:                                                                # If path is empty, probably a home page
      if Debug.network: "Redir URL failed check 1. Path " & path & " too short." >* "/dev/stderr"
      return ""
    if path ~ "[Nn][Oo][Tt][^Ff]*[Ff][Oo][Uu][Nn][Dd]":
      if Debug.network: "Redir URL failed check 2" >* "/dev/stderr"
      return ""
    if path ~ "[^0-9]404[^0-9]|[^a-zA-Z][Ee]rror[^a-zA-Z]|[^a-zA-Z][Uu]nknown[^a-zA-Z]":
      if Debug.network: "Redir URL failed check 3" >* "/dev/stderr"
      return ""
    if newurl[high(newurl)] == '/' and url[high(url)] != '/':                    # If last char of new URL is /
      if Debug.network: "Redir URL failed check 4" >* "/dev/stderr"
      return ""
    if awk.split(path, a, "/") == 2 and awk.split(origpath, a, "/") > 2:
      if Debug.network: "Redir URL failed check 5: path is too short" >* "/dev/stderr"
      return ""

  return url
  

#
#   Return web page status.
#
#   Return 1 if 2XX
#   Return 0 if 4xx etc..
#   Return -1 if timeout.
#   Return actual status code if flag="code"
#   If checking status of a page in which the API said 404 (or missing), set flag="404" to avoid false positives
#
proc webpagestatus(url: string, fl: varargs[string]): int =

  var tries = 3  # Number of times to retry 
  var url = strip(url)
  var returnval, errC = 0
  var j = 1
  var responsecode = -1
  var head, flag, wgethead, pe, redirurl = ""

  if len(fl) > 0:
    flag = fl[0]
  else:
    flag = ""

  if flag == "one":
    tries = 1

  if url ~ "'": 
    gsub("'","%27",url)    # shell escape literal string

  let wgetbody = mktempname(GX.datadir & "wgetbody.")

  # Headers go to stderr, body to stdout.
  # content-on-error needed to see output of body during a 403/4 which is redirected to a temp file.

  let command = "wget" & GX.wgetopts & "--content-on-error -SO- -q '" & url & "' 2>&1 > " & wgetbody

  while j <= tries:

    head = ""

    if Debug.network: "Starting headers (" & $(j) & ") for " & url >* "/dev/stderr"
    if Debug.wgetlog: 
      wgethead = mktempname(GX.datadir & "wgethead.")

    (head, errC) = execCmdEx(command)

    responsecode = headerresponse(head)

    if Debug.network: "Ending headers (" & $(len(head)) & " / " & $responsecode & ")" >* "/dev/stderr"
    if Debug.wgetlog:
      head >* wgethead

    if len(head) == 0 or responsecode == -1:
      j.inc
      libutils.sleep(2)
    else:
      break

  if j == tries and (len(head) == 0 or responsecode == -1):
    if Debug.network: "Headers time out" >* "/dev/stderr"
    sendlog(Project.timeout, CL.name, "headers:" & url)
    returnval = -1
  if head ~ "^/bin/sh[:] 1[:] Syntax error":
    sendlog(Project.syntaxerror, CL.name, "webpagestatus")
    returnval = -1


  elif responsecode != -1:
    if responsecode > 199 and responsecode < 300:
      if iainfopage(wgetbody) and flag ~ "404":
        if iaredirect(wgetbody) and GX.redirloop == 0:                # 302 redirect page .. follow it and verify header
          GX.redirloop = 1
          redirurl = getredirurl(url, wgetbody)
          if redirurl ~ "^http":
            if webpagestatus(redirurl) == 1:                      # recursive call
              returnval = 3
              responsecode = 200
              GX.redirloop = 0                                       # Global flag to stop endless loop
            else:
              returnval = 0
              GX.redirloop = 0
          else:
            returnval = 0
            GX.redirloop = 0
        else:
          returnval = 0
      else:
        returnval = 1

    elif responsecode == 503 or responsecode == 504:              # HTTP/1.1 503 Service Unavailable
      if isarchiveorg(url) and GX.unavailableloop == 0:
        GX.unavailableloop = 1
        libutils.sleep(4)
        if webpagestatus(url) == 1:                               # recursive call
          GX.unavailableloop = 0
          returnval = 1
          responsecode = 200
        else:
          GX.unavailableloop = 0
          returnval = 0
      elif isarchiveorg(url) and GX.unavailableloop == 1:
        return 0
      else:      
        returnval = 5
        responsecode = 503

    elif responsecode == 417: 
      if Debug.network: "417 bot rate limit exceeded / cache busting detected" >* "/dev/stderr"
      returnval = 0

    elif responsecode == 400: 
      if Debug.network: "400 Invalid URI: noSlash" >* "/dev/stderr"
      responsecode = 400
      returnval = 4

    pe = pageerror(wgetbody)
    if pe == "bummer":
      if Debug.network: "Bummer page" >* "/dev/stderr"
      sendlog(Project.bummer, CL.name, url)
      returnval = 1                            # Treat as a 200 response
      responsecode = 200
    elif pe == "robots":
      if Debug.network: "Page cannot be crawled or displayed due to robots.txt" >* "/dev/stderr"
      returnval = 0
      responsecode = 403
    elif pe == "excluded":
      if Debug.network: "This URL has been excluded from the Wayback Machine" >* "/dev/stderr"
      returnval = 0
      responsecode = 403
    elif pe == "404":
      if Debug.network: "title:og header says 404 not found" >* "/dev/stderr"
      returnval = 0
      responsecode = 404
    elif pe == "redirect" and returnval != 3:    # Only return this code if a double redirect (see recursive action above)
      if Debug.network: "Double redirect.. " & url >* "/dev/stderr"
      returnval = 0
      responsecode = 302

  if not Debug.wgetlog:                     # delete wget.* files unless Debug
    if existsFile(wgetbody):
      for file in walkFiles(GX.datadir & "wget*"):
        removeFile(file)

  if flag == "code":
    return responsecode
  else:                 
    return returnval

 
#
# Query API via GET method. Return a working IA URL or "none"
#
#  Wayback API: https://archive.org/help/wayback_api.php (old)
#               http://207.241.231.246:8120/usage (archived https://archive.is/6ZcDv)
#
proc queryapiget(url, timestamp: string): string =

  let tries = 3
  var urlapi, japi, japi2 = ""
  var j = 1
  var errC1, errC2 = 0

  if url !~ "^http": return "none"

  urlapi = url & "&tag=1&closest=either&statuscodes=200&statuscodes=203&statuscodes=206&statuscodes=404&timestamp=" & timestamp

  let wgetapi = "wget" & GX.wgetopts & "--header=\"Wayback-Api-Version: 2\" --post-data=\"url=" & urlapi & "\" -q -O- \"http://archive.org/wayback/available\""
 
  while j <= tries:

    japi = ""
    japi2 = ""

    if Debug.network: "Starting API (get) (" & $(j) & ") for " & urlapi >* "/dev/stderr"

    (japi, errC1) = execCmdEx(wgetapi)
    libutils.sleep(2)
    (japi2, errC2) = execCmdEx(wgetapi)

    if Debug.network: "Ending API (get) (" & $len(japi) & "|" & $len(japi2) & ")" >* "/dev/stderr"

    if( (len(japi) == 0 or len(japi2) == 0) and j != tries ):        # Problem retrieving API data, try again.
      libutils.sleep(2)
      j.inc
    elif j == tries:
      if Debug.network: "IA API (get) time out?" >* "/dev/stderr"
      sendlog(Project.timeout, CL.name, "queryapiget")
      return "none"
    elif len(japi) != len(japi2):                                    # Choose largest (bytes) of two API results
      sendlog(Project.jsonmismatch, CL.name, "queryapiget")
      japi >> GX.datadir & "japi-get.orig"
      japi2 >> GX.datadir & "japi2-get.orig"
      if len(japi2) > len(japi):
        japi = japi2
      break
    else:                                                            # 2 requests match. exit.
      break

  if japi ~ "^/bin/sh[:] 1[:] Syntax error":
    sendlog(Project.syntaxerror, CL.name, "queryapipost")
    return "none"

  var newurl = japi2singleurl(japi)
  if newurl != "none":
    let status = webpagestatus(newurl)
    if status == 1 or status == 3:
      gsub("^http[:]", "https:", newurl)     # Convert to https
      return newurl
    elif status == 5:
      if Debug.network: "Step queryapiget: 503 SERVERS DOWN." >* "/dev/stderr"
      sendlog(Project.critical, CL.name, " 503_servers_down queryapiget")
      return "none"

  return "none"


#
# Query Wayback API via POST method and and load answers into WayLink[]
#
#  Assumes process_article("getlinks", "xyz") has previously run loading WayLink.origiaurl, origurl, and origdate from Wikipedia article.
#
proc queryapipost(internalcount: int): bool =

  let tries = 3
  var j = 1
  var errC1, errC2 = 0
  var japi, japi2 = ""

  let postfile = GX.datadir & "postfile"
  createpostdata(postfile)

  let wgetapi = "wget" & GX.wgetopts & "--header=\"Wayback-Api-Version: 2\" --post-file=\"" & postfile & "\" -q -O- \"http://archive.org/wayback/available\""

  if internalcount > 0:

    while j <= tries:

      japi = ""
      japi2 = ""

      if Debug.network: "Starting API (try " & $j & ")" >* "/dev/stderr"
      
      (japi, errC1) = execCmdEx(wgetapi)

      libutils.sleep(2)

      (japi2, errC2) = execCmdEx(wgetapi)

      if Debug.network: "Ending API (" & $len(japi) & "|" & $len(japi2) & ")" >* "/dev/stderr"

      if( (len(japi) == 0 or len(japi2) == 0) and j != tries ):        # Problem retrieving API data, try again.
        j.inc
      elif j == tries:                                                 # Sometimes API returns blank (0-length json) on large postloads. 
        if Debug.network: "IA API time out?" >* "/dev/stderr"          #  create a placeholder json file and punt upstream to get method 
        sendlog(Project.timeout, CL.name, "queryapi")
        japi = createemptyjson(postfile)
        japi >* GX.datadir & "japi.orig"
        break
      elif len(japi) != len(japi2):                                    # Choose largest (bytes) of two API results
        sendlog(Project.jsonmismatch, CL.name, "queryapipost")
        japi >* GX.datadir & "japi.orig"
        japi2 >* GX.datadir & "japi2.orig"
        if len(japi2) > len(japi):
          japi = japi2
        break
      else:                                                            # 2 requests match. exit.
        japi >* GX.datadir & "japi.orig"
        japi2 >* GX.datadir & "japi2.orig"
        break

    if japi ~ "^/bin/sh[:] 1[:] Syntax error":
      sendlog(Project.syntaxerror, CL.name, "queryapipost")
      return false

    var apicount = japi2waylink(japi)

    if Debug.api: "\nAPI found " & $apicount & " records vs. " & $internalcount & " internal count records." >* "/dev/stderr"

    if apicount < internalcount:
      sendlog(Project.apimismatch, CL.name, $internalcount & "|" & $apicount)

    " " >* GX.datadir & "waylink.start"
    " " >* GX.datadir & "waylink.end"

    var url, turl = ""
    var status: int

    # Check a known working "canary" URL and abort if dead.
    if not Debug.api:
      status = webpagestatus("https://web.archive.org/20101013023507/http://ftp.resource.org:80/courts.gov/c/F2/295/295.F2d.192.16752_1.html")
      if status != 1:
        sendlog(Project.critical, CL.name, " 503_servers_down Z1 ----" & "CANARY URL DEAD")
        return false

    for tag in 0..GX.id:

      debugarray(tag, GX.datadir & "waylink.start")

      if WayLink[tag].status ~ "^2":                                      # API reports 2xx
          if WayLink[tag].newiaurl != "none":
            status = webpagestatus(WayLink[tag].newiaurl)
            if status == 1:                                               # If newiaurl is different from origiaurl, but origiaurl is working use that.
              if (urltimestamp(WayLink[tag].origiaurl) != urltimestamp(WayLink[tag].newiaurl)) and validate_datestamp(urltimestamp(WayLink[tag].origiaurl)) == true:
                status = webpagestatus(WayLink[tag].origiaurl)
                if status == 1:
                  if Debug.network: "Step A1.01: ORIG. Using original URL." >* "/dev/stderr"
                  WayLink[tag].newiaurl = WayLink[tag].origiaurl
            elif status == 4:
              turl = replace(WayLink[tag].newiaurl, "/web/", "/")         # Sometimes need to remove "/web/" from URL for it to work
              status = webpagestatus(turl)
              if status == 1:
                WayLink[tag].newiaurl = turl
                WayLink[tag].formated = WayLink[tag].newiaurl
              else:
                if Debug.network: "Step A1.0: NOT FOUND. Page headers verified *not* 200" >* "/dev/stderr"
                sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A1.0")
                fillway(tag, "0", "false", "none", "none")
            elif status == 5:
              if Debug.network: "Step A1.1: 503 SERVERS DOWN." >* "/dev/stderr"
              sendlog(Project.critical, CL.name, " 503_servers_down A1.1 ----" & WayLink[tag].newiaurl)
              return false
            elif status != 1 and status != 3:                             # Page headers *not* 200 .. sleep and try again 3 times (persistance needed)
              libutils.sleep(30)                                                   # (Condition A1 occured in 400 of 10000 checks. Timeout etc)
              status = webpagestatus(WayLink[tag].newiaurl)
              if status != 1 and status != 3:
                libutils.sleep(300)
                status = webpagestatus(WayLink[tag].newiaurl)                
                if status != 1 and status != 3:
                  libutils.sleep(60)
                  status = webpagestatus(WayLink[tag].newiaurl)
                  if status != 1 and status != 3:
                    if Debug.network: "Step A1: NOT FOUND. Page headers verified *not* 200" >* "/dev/stderr"
                    sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A1")
                    fillway(tag, "0", "false", "none", "none")
                  if status == 5:
                    if Debug.network: "Step A1.2.3: 503 SERVERS DOWN." >* "/dev/stderr"
                    sendlog(Project.critical, CL.name, " 503_servers_down A1.2.3 ----" & WayLink[tag].newiaurl)
                    return false
                if status == 5:
                  if Debug.network: "Step A1.2.2: 503 SERVERS DOWN." >* "/dev/stderr"
                  sendlog(Project.critical, CL.name, " 503_servers_down A1.2.2 ----" & WayLink[tag].newiaurl)
                  return false
              if status == 5:
                if Debug.network: "Step A1.2.1: 503 SERVERS DOWN." >* "/dev/stderr"
                sendlog(Project.critical, CL.name, " 503_servers_down A1.2.1 ----" & WayLink[tag].newiaurl)
                return false
          else:
            fillway(tag, "0", "false", "none", "none")
            if Debug.network: "Step A2: NOT FOUND. Unknown." >* "/dev/stderr"
      
      elif WayLink[tag].status ~ "^404$|^0$":                        # API reports 404 or missing
        if Debug.network: "Step 1: API reports 404 or missing" >* "/dev/stderr"        
        if WayLink[tag].origiaurl != "none": 
          if Debug.network: "Step 2: Verified origiaurl is not none." >* "/dev/stderr"
          status = webpagestatus(WayLink[tag].origiaurl, "404")    
          if status == 1:                                          # Page headers verify as 200
            if Debug.network: "Step A3: FOUND. Page headers verify as 200" >* "/dev/stderr"
            if tag <= apicount:
              sendlog(Project.bogusapi, CL.name, WayLink[tag].origiaurl & " A3")
            fillway(tag, "200", "wayback", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl)
          elif status == 3:                                        # Page redirect 302 to a working page of unknown status (soft 404? working?)
            if Debug.network: "Step A4: FOUND. 302 to a working page of unknown status" >* "/dev/stderr"
            if tag <= apicount:
              sendlog(Project.bogusapi, CL.name, WayLink[tag].origiaurl & " A4")
            fillway(tag, "200", "wayback", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl)
          elif status == 5:
            if Debug.network: "Step A4: 503 SERVERS DOWN." >* "/dev/stderr"
            sendlog(Project.critical, CL.name, " 503_servers_down A4 ----" & WayLink[tag].origiaurl)
            return false
          else:
            if Debug.network: "Step 3: Try again with earliest date 1970101 using original URL" >* "/dev/stderr"
            url = queryapiget(WayLink[tag].origencoded, "19700101")  # Try again with earliest date 1970101 using original URL
            if url != "none" and url ~ "^http":
              if Debug.network: "Step 4: url verified not none." >* "/dev/stderr"
              status = webpagestatus(url)
              if status == 1:                                      # Page headers verify 200
                if Debug.network: "Step A5: FOUND. Page headers verify 200" >* "/dev/stderr"
                if tag <= apicount:
                  sendlog(Project.bogusapi, CL.name, url & " A5")
                fillway(tag, "200", "wayback", url, WayLink[tag].origurl)
              elif status == 3:                                    # Page redirect 302 to a working page of unknown status (soft 404? working?)
                if Debug.network: "Step A6: FOUND. 302 to a working page of unknown status" >* "/dev/stderr"
                if tag <= apicount:
                  sendlog(Project.bogusapi, CL.name, url & " A6")
                fillway(tag, "200", "wayback", url, WayLink[tag].origurl)
              elif status == 5:
                if Debug.network: "Step A6: 503 SERVERS DOWN." >* "/dev/stderr"
                sendlog(Project.critical, CL.name, " 503_servers_down A6 ----" & WayLink[tag].origencoded)
                return false

          # Try alt archives via Memento

        if WayLink[tag].status ~ "^404$|^0$":
          if Debug.network: "Step 5: Try alt archives via Memento API" >* "/dev/stderr"
          if api_memento(WayLink[tag].origencoded, WayLink[tag].origdate, tag) == "OK":
            status = webpagestatus(WayLink[tag].altarchencoded)
            if status == 1:
              if Debug.network: "Step A7: FOUND. Alt archive" >* "/dev/stderr"
              WayLink[tag].status = "200"
              WayLink[tag].available = "altarch"

      if Debug.api: debugarray(tag, "/dev/stderr")           # optionaly print to screen
      debugarray(tag, GX.datadir & "waylink.end")               # always to file

    return true

  else:
    return false

  return false
