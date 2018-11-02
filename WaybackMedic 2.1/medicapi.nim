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
# Given url (as .origiaurl or .formated), return best working wayback or altarch URL
#   Otherwise return "none"
#
proc api(url: string): tuple[m: string, z:int] =

  var
    url = strip(url)
    newurl = "none"
    newtag = -1
    fragorig = ""

  for tag in 0..GX.id:
    if WayLink[tag].origiaurl == url or WayLink[tag].formated == url:

      if WayLink[tag].status ~ "^2":
        if isarchiveorg(WayLink[tag].newiaurl) and WayLink[tag].available == "wayback":
          newurl = WayLink[tag].newiaurl
          newtag = tag
          break
        elif isarchiveorg(WayLink[tag].formated) and WayLink[tag].available == "wayback":
          newurl = WayLink[tag].formated
          newtag = tag
          break
        elif WayLink[tag].available == "altarch":
          newurl = WayLink[tag].altarchencoded
          newtag = tag
          break
        elif WayLink[tag].available == "altarchunencoded":
          newurl = WayLink[tag].altarch
          newtag = tag
          break
        else:
          newurl = "none"
          newtag = -1
          break
      else:
        newurl = "none"
        newtag = -1
        break

  # Remove "/http%3A// - a hack - should be done when URLs are created
  if awk.match(newurl, "(?i)[/]https?%3A[/][/]") > 0:
    sub("(?i)%3A[/][/]","://",newurl)

  # Copy fragment over to new URL - a hack - should be done when URLs are created
  awk.match(url, "[#][^$]*[^$]", fragorig)
  if not empty(fragorig) and newurl ~ "^(http|ftp)":
    if awk.match(newurl, "[#][^$]*[^$]") == 0:
      newurl = newurl & fragorig

  result[0] = newurl
  result[1] = newtag

#
# Given url (as .formated), return tag number
#   Otherwise return "none"
#
proc apitag(url: string): int =

  var url = strip(url)
  for tag in 0..GX.id:
    if WayLink[tag].formated == url:
      return tag

  return -1

#
# Return the timestamp of the Location: field in the header
#  If multiple Location's pick the last one
#  Return the timstamp, otherwise ""    
#  Optional return full URL if fl set to "fullurl"
#    Location: /web/20160304054056/http://www.
#    Location: http://web.archive.org/web/20160304054056/http://www.
#
proc headerlocation*(head: string, fl: varargs[string]): string =

  var
    mcache = newSeq[string](0)
    c, f, le: int
    flag, flag2 = ""

  if len(fl) == 1:
    flag = fl[0]

  if len(fl) == 2:
    flag = fl[0]
    flag2 = fl[1]

  c = awk.split(head, a, "\n")
  for i in 0..c - 1:
    if a[i] ~ "^[ ]{0,5}[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn][ ]?[:]":
      if not empty(flag): # get URLs
        awk.sub("^[ ]*[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn][ ]*[:][ ]*", "", a[i])
        if a[i] !~ "^http":
          a[i] = "https://web.archive.org" & a[i]
        if empty(flag2):
          if isarchiveorg(a[i]):
            mcache.add(strip(a[i]))
        else:
          mcache.add(strip(a[i]))
      else:  # get timestamps
        if awk.split(strip(a[i]), b, " ") > 1:
            f = awk.split(b[1], e, "/")
            for k in 0..f-1:
              if e[k] ~ "^[0-9]{14}$":
                mcache.add(e[k])
                break
          
  le = len(mcache)
  if le > 0:
    if len(mcache[le - 1]) > 0:  # Get the last HTTP response
      return mcache[le - 1]

  return ""


#
# Given a URL to an alt-archive, see of it's in the file soft404.bm which was created manually during step 8 of 0README
#   return true if URL is contained in soft404.bm
#
proc manual_soft404(url: string): bool =

  var
    url = url
    urld = ""

  # sed("Checking manual_soft404: " & url, Debug.network)

  gsub("(?i)(https[:])", "http:", url)
  gsub("(?i)(https[:])", "http:", urld)

  urld = urldecode(url)

  if GX.soft404c > 0:
    for i in 0..GX.soft404c - 1:
      if GX.soft404a[i] ~ "(?i)(^http)":
        if urlequal(url, GX.soft404a[i]):
          sed("Found match (1) in soft404.bm for " & url, Debug.network)
          sendlog(Project.syslog, CL.name,  "Found match (1) in soft404.bm for " & url)
          return true           

  return false

#
# Given a URL to Wayback, see of it's in the file soft404i.bm which was created manually during step 8 of 0README
#   return true if URL is contained in soft404i.bm
#
proc manual_soft404i(url: string): bool =

  var
    url = url

  if GX.soft404ic > 0:
    for i in 0..GX.soft404ic - 1:
      if GX.soft404ia[i] ~ "(?i)(^http)":
        gsub("(?i)(https[:])", "http:", url)
        if contains(GX.soft404ia[i], url):
          sed("Found match (2) in soft404i.bm for " & url, Debug.network)
          sendlog(Project.syslog, CL.name,  "Found match (2) in soft404i.bm for " & url)
          return true

  return false

#
# Given an IA URL, check the timestamp date/time are within normal range 
#  eg. this is wrong: http://web.archive.org/web/20131414230300/http://www.iter.org/proj/iterandbeyond
# If out of range, download page and web scrape for correct date and return corrected URL
#
proc validiaurl(url: string): string =

  var body, head, bodyfilename = ""
  var c = 0
  var newstamp, re, vhour, vmin, vsec, vmonth, vday, vyear = ""

  var url = strip(url)
  var stamp = urltimestamp(url)

  # HTML redirects

  if validate_datestamp(stamp) == false:

    sed("Out of range for " & url, Debug.network)

    (head, bodyfilename) = getheadbody(url)
    body = readfile(bodyfilename)

    if empty(head):
      sed("Zero length page header for " & url, Debug.network)
      return url
    if empty(body) and empty(head):
      sed("Zero length web page for " & url, Debug.network)
      return url
    if body ~ "^/bin/sh[:] 1[:] Syntax error":
      sed("(1) /bin/sh Syntax error for " & url, Debug.network)
      sendlog(Project.syntaxerror, CL.name, url & " ---- (1)")
      return url

    # HTML redirect type 1 (manual click through to new page)

     # <p class="impatient"><a href="/web/20160316190307/http://www.amazon.com/Game-Thrones-Season-Blu-ray-Digital/dp/B00VSG3MSC">Impatient?</a></p>

    if match(body, "[pP][ ][cC]lass[ ]*[=][ ]*[\"][Ii]mpatient[ ]{0,}[\"][ ]{0,}[>][ ]{0,}[<][ ]{0,}[aA][ ][hH]ref[ ]{0,}[=][ ]{0,}[\"]/[Ww]?[Ee]?[Bb]?/?[^>]*>", dest) > 0:
      match(dest, "[aA][ ][hH]ref[ ]{0,}[=][ ]{0,}[\"]/[Ww]?[Ee]?[Bb]?/?[^>]*[^>]", dest2)
      gsub("[aA][ ][hH]ref[ ]{0,}[=][ ]{0,}[\"]","",dest2)
      gsub("\"$", "", dest2)
      newstamp = "https://web.archive.org" & dest2
      sed("New timestamp (1.1) = " & newstamp, Debug.network)
      return newstamp

     # <p class="impatient"><a href="http://web.archive.org/web/20160316190307/http://www.amazon.com/Game-Thrones-Season-Blu-ray-Digital/dp/B00VSG3MSC">Impatient?</a></p>

    elif match(body, "[pP][ ][cC]lass[ ]*[=][ ]*[\"][Ii]mpatient[ ]{0,}[\"][ ]{0,}[>][ ]{0,}[<][ ]{0,}[aA][ ][hH]ref[ ]{0,}[=][ ]{0,}[\"]http[^>]*>", dest) > 0:
      match(dest, "[aA][ ][hH]ref[ ]{0,}[=][ ]{0,}[\"]http[^>]*[^>]", dest2)
      gsub("[aA][ ][hH]ref[ ]{0,}[=][ ]{0,}[\"]","",dest2)
      gsub("\"$", "", dest2)
      sed("New timestamp (1.2) = " & newstamp, Debug.network)
      if isarchiveorg(newstamp):
        return newstamp
      else:
        return url

    # HTML redirect type 2 (automatic push through to new page)

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

        vmonth = month2digit(strip(dest2))

        re = dest2 & "[0-9]{1,2}[,][ ][0-9]{4}"
        if match(dest, re, dest3) > 0:
          if awk.split(dest3, b, " ") == 4:
            if match(b[2], "[0-9]{1,2}", vday) > 0:
              vday = zeropad(vday)
            if len(b[3]) == 4:
              vyear = b[3]

      newstamp = vyear & vmonth & vday & vhour & vmin & vsec
      newstamp = strip(newstamp)

      sed("New timestamp (2) = " & newstamp, Debug.network)

      if validate_datestamp(newstamp) == true:
        gsubs(stamp, newstamp, url)
        return url

    # Header redirect using Location: 
        
    # Location: /web/20121412462900/http://www.nbmg.unr.edu/geothermal/site.php?sid=Elko%20Hot%20Springs
    # Location: http://web.archive.org/web/20121412462900/http://www.nbmg.unr.edu/geothermal/site.php?sid=Elko%20Hot%20Springs
    elif match(head, "[Ll]ocation[ ]{0,}[:]") > 0:

      var dest = headerlocation(head)
      if validate_datestamp(dest):
        sed("New timestamp (3) = " & dest, Debug.network)
        gsubs(stamp, dest, url)
        return url

   # All else fails try the Memento "timemap" snapshots in the Link: header .. it will pick the first one with a valid date

    else:
      var origurl = wayurlurl(url)
      if len(origurl) > 5:   
        var field = newSeq[string](0)
        re = GX.iare & "/?w?e?b/[0-9]{14}/" & escapeRe(origurl)
        c = patsplit(head, field, re)
        for k in 0..c-1:
          var dest = urltimestamp(field[k])
          if validate_datestamp(dest):
            sed("New timestamp (4) = " & dest, Debug.network)
            gsubs(stamp, dest, url)
            return url

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
  if empty(japi): 
    return false
  if japi[0] != '{' and japi[high(japi)] != '}':  
    return false

  for d, m in json.pairs(  parseJson(japi)  ):
    if d == "mementos":
      for e, n in json.pairs(m):
        if e == "closest":
          for f, o in json.pairs(n):
            if f == "datetime":
              date = gsubs("-", "", substr($o, 1, 10))
              # date = replacet(substr($o, 1, 10), "-", "")
              # date = gsub("[-]", "", substr($o, 1, 10))
            if f == "uri":
              for g in json.items(o):
                uri = substr($g, 1, len($g) - 2)
                break   # first one only
          if not empty(date) and not empty(uri):
            MemLink.closest = uri & " | " & date
          date = ""
          uri = ""
        if e == "prev":
          for f, o in json.pairs(n):
            if f == "datetime":
              date = gsubs("-", "", substr($o, 1, 10))
              # date = replacet(substr($o, 1, 10), "-", "")
              # date = gsub("[-]", "", substr($o, 1, 10))
            if f == "uri":
              for g in json.items(o):
                uri = substr($g, 1, len($g) - 2)
                break   # first one only
          if not empty(date) and not empty(uri):
            MemLink.prev = uri & " | " & date
          date = ""
          uri = ""
        if e == "first":
          for f, o in json.pairs(n):
            if f == "datetime":
              date = gsubs("-", "", substr($o, 1, 10))
              # date = replacet(substr($o, 1, 10), "-", "")
              # date = gsub("[-]", "", substr($o, 1, 10))
            if f == "uri":
              for g in json.items(o):
                uri = substr($g, 1, len($g) - 2)
                break   # first one only
          if not empty(date) and not empty(uri):
            MemLink.first = uri & " | " & date
          date = ""
          uri = ""
        if e == "next":
          for f, o in json.pairs(n):
            if f == "datetime":
              date = gsubs("-", "", substr($o, 1, 10))
              # date = replacet(substr($o, 1, 10), "-", "")
              # date = gsub("[-]", "", substr($o, 1, 10))
            if f == "uri":
              for g in json.items(o):
                uri = substr($g, 1, len($g) - 2)
                break   # first one only
          if not empty(date) and not empty(uri):
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
  
  var 
    tag, count = 0
    anchor = ""

  # Basic validations
  if empty(japi): 
    return 0
  if japi[0] != '{' and japi[high(japi)] != '}':  
    return 0

 # Temporary save data as it sometimes crashes at parseJason 
  # japi >* GX.datadir & "japi.crash"

  for d, m in pairs(parseJson(japi)):
    if d == "results":
      for e in items(m):
        for f, n in pairs(e):
          if f == "tag":
            tag = parseInt(gsub("^\"|\"$","",$n))
            for g, o in pairs(e):
              if g == "archived_snapshots":
                if len(o) > 0:
                  for h, p in pairs(o):
                    if h == "closest":
                      WayLink[tag].newurl = WayLink[tag].origurl
                      WayLink[tag].available = strip(gsub("^\"|\"$", "", $p["available"]))
                      anchor = ""
                      if not empty(uriparseElement(WayLink[tag].origurl, "anchor")):
                        anchor = "#" & uriparseElement(WayLink[tag].origurl, "anchor")            # IA API strips anchor, re-add
                      if not empty uriparseElement(strip(gsub("^\"|\"$", "", $p["url"])), "anchor"):
                        anchor = ""                                                               # ..unless already in API url
                      if WayLink[tag].available == "true": 
                        WayLink[tag].available = "wayback"
                        WayLink[tag].newiaurl = validiaurl(formatediaurl( strip(gsub("^\"|\"$", "", $p["url"])) & anchor, "barelink")) 
                      else:
                        WayLink[tag].newiaurl = formatediaurl( strip(gsub("^\"|\"$", "", $p["url"])) & anchor, "barelink")
                      WayLink[tag].newiaurl = replace(WayLink[tag].newiaurl, "\\\\", "\\")        # IA API turns "\" into "\\"
                      awk.sub( "[:]80/", "/", WayLink[tag].newiaurl, 1)                           # IA API adds :80, remove
                      awk.sub( "[?]$", "", WayLink[tag].newiaurl, 1)                              # IA API adds trailing ?, remove
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

  var 
    val, anchor = ""

  # Basic validations
  if empty(japi):
    return "none"
  if japi[0] != '{' and japi[high(japi)] != '}':
    return "none"          

  # Get anchor 
  for d, m in pairs(parseJson(japi)):
    if d == "results":
      for e in items(m):
        for f, n in pairs(e):
          if f == "url":
            val = strip( gsub("^\"|\"$", "", $n) )
            if not empty(val):
              if not empty(uriparseElement(val, "anchor")):
                anchor = "#" & uriparseElement(val, "anchor")               

  for d, m in pairs(parseJson(japi)):
    if d == "results":
      for e in items(m):
        for f, n in pairs(e):
          if f == "archived_snapshots":
            if len(n) > 0:
              for h, p in pairs(n):
                if h == "closest":
                  val = strip( gsub("^\"|\"$", "", $p["url"]) )               # IA API strips anchor, re-add
                  if empty(uriparseElement(val, "anchor")) and not empty(anchor):
                    val = val & anchor
                  if val ~ GX.shttp:
                    val = replace(val, "\\\\", "\\")                          # IA API turns "\" into "\\"
                    awk.sub( "[:]80/", "/", val, 1)                           # IA API adds :80, remove it
                    return validiaurl(val)
                  else:
                    return "none"
  return "none"


#
# Validate UK National Archives
# Main URL with frames hiding underlying content page:
#   http://webarchive.nationalarchives.gov.uk/20110426160949/http://www.humanities.uci.edu/history/levineconference/papers/aburaiya.pdf
# It links to the content page:
#   http://webarchive.nationalarchives.gov.uk/content/20110426160949/http://www.humanities.uci.edu/history/levineconference/papers/aburaiya.pdf
# Check for soft404s by making sure content page size > 2000
#
proc validate_natarchivesuk(url: string): bool = 

  var
    head, bodyfilename, fp, underurl = ""
    url = url
    c = 0

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  # Check for non-existent main page
  (head, bodyfilename) = getheadbody(url, "one")  # scrape body
  fp = readfile(bodyfilename)
  if empty(fp) or len(fp) < 1000:
    sed("validate_natarchivesuk: empty fp", Debug.network) 
    return false

 # Check for 404/3
  if head ~ "(?i)(HTTP[/]1[.][0-9][ ]*40[43])":
    sed("validate_natarchivesuk: head contains 404/403", Debug.network)
    return false

 # Check for binary download (pdf, doc, xls etc) or text-plain
  c = awk.split(head, a, "\n")
  for i in 0..c-1:
    # Content-Type: text/html
    if a[i] ~ "(?i)(^[ ]*content[-]?type[ ]*[:])":
      if a[i] !~ "(?i)(text)":                         # binary 
        return true 
      if a[i] ~ "(?i)(text[/]plain)":                  # plain text (not HTML but a .txt file)
        return true

  # Check for videos
  if fp ~ "(?i)(UK Government Web Archive[:]?[ ]*videos)":
    return true

  # Get the underlying content URL when frames exist
  # <iframe id="theWebpage" class="theWebpage" src="http://webarchive.nationalarchives.gov.uk/content/20110426160949/http://www.stuff"
  if match(fp, "(?i)(class[ \\n]*[=][ \\n]*\"theWebpage\"[ \\n]*src[ \\n]*[=][ \\n]*\"http[^\"]*\")", dest) > 0:
    if awk.split(dest, a, "\"") > 3:
      if a[3] ~ "^(?i)(http)":
        underurl = strip(a[3])

    if empty(underurl):
      sed("validate_natarchivesuk: unable to determine /content page for: " & url, Debug.network)
      sendlog(Project.syslog, CL.name,  " error - unable to determine /content page for: " & url)
      return false

    # Check underlying /content/ page for soft404 by size of HTML (imperfect but catches missing pages)
    (head, bodyfilename) = getheadbody(underurl, "one")  # scrape body
    fp = readfile(bodyfilename)
    if len(fp) < 2000:
      sed("validate_natarchivesuk: underurl looks like soft404: " & underurl, Debug.network)
      return false

  if len(fp) > 2000:
    return true
  else:
    return false

#
# Validate NLA Australia 
#  This can't determine of type http://webarchive.nla.gov.au/gov/20120326012340/http://news.defence.gov.au/2011/09/09/army-airborne-insertion-capability/
#  Due to frames and scrapeing.
#  It will determine other types of NLA URLs.
#
proc validate_nlaau(url: string): bool =

  var
    head, bodyfilename, fp = ""

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  (head, bodyfilename) = getheadbody(url, "one")  # scrape body
  fp = readfile(bodyfilename)
  if empty(fp):
    return false
  if contains(fp, ">Page not found</span>"):
    return false
  return true

#
# Validate Bib Alexandria
#  Sometimes snapshots are down temporary with code 503 .. presumably they will return?
#
proc validate_bibalex(url: string, fl: varargs[string]): bool =

  var
    head, bodyfilename, fp, flag, newurl = ""
    c = 0
    url = url

 # recurse flag to stop endless loop
  if len(fl) > 0:
    flag = fl[0]

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  (head, bodyfilename) = getheadbody(url, "one")  # scrape body
  fp = readfile(bodyfilename)
  if head ~ "(?i)(HTTP[/]1.[0-9][ ]*503)":
    return true
  if empty(fp):
    return false

 # Check/verify for redirect - might need to also check header.. (see archive-it example)
  if fp ~ "This article exists elsewhere on the site":
    if awk.match(fp, "If you are not automatically forwarded[,] please click [<][^<]*[<]", dest) > 0:
      awk.split(dest, a, "[<|>]")
      if a[1] ~ "href":
        awk.split(a[1],b,"\"")
        newurl = b[1]

      if isbibalex(newurl):
          if manual_soft404(newurl):
            sed("validate_bibalex: redirected URL is in soft404.bm", Debug.network)
            return false
          # Skip if URL has no path (ie. a homepage). More often than not these get caught by soft404() but are false positives
          if awk.split(urlurl(newurl), a, "[/]") == 4 and awk.split(urlurl(url), b, "[/]") != 4:
            if empty(a[3]):
              sed("validate_bibalex: root path skip", Debug.network)
              return false
            else:
              sed("validate_bibalex: root path contains something", Debug.network)
              return true
          elif c > 1:
            sed("validate_bibalex: Number of Locations > 1: " & $c, Debug.network)
            if empty(flag):   
               if validate_bibalex(newurl, "recurse"):
                 url = newurl
                 sed("validate_bibalex: Found redirect URL (c>1) at " & url, Debug.network)
                 return true
               else:
                 sed("validate_bibalex: Unable to validate location (c>1)", Debug.network)
                 return false
            else:
              sed("validate_bibalex: Redirect loop (c>1)", Debug.network)
              return false
          else:  # recursive call
            if empty(flag): 
              if validate_bibalex(newurl, "recurse"):
                url = newurl
                sed("validate_bibalex: Found redirect URL at " & url, Debug.network)
                return true
              else:
                sed("validate_bibalex: Unable to validate location", Debug.network)
                return false
            else:
              sed("validate_bibalex: Redirect loop", Debug.network)
              return false
      else:
        sed("validate_bibalex: Location URL doesn't verify as Bibalex", Debug.network)
        sendlog(Project.syslog, CL.name, " error -- validate_bibalex: Location URL doesn't verify as Bibalex for " & url)
        return true



  return true

#
# Validate Library of Congress
#
proc validate_locgov(url: string): bool =

  var
    head, bodyfilename, fp = ""

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  (head, bodyfilename) = getheadbody(url, "one")  # scrape body
  fp = readfile(bodyfilename)
  if empty(fp):
    return false
  if fp ~ "The Resource you requested is not in this archive":
    return false
  return true

#
# Validate Archive-It - url is type "var string"
#
proc validate_archiveit(url: var string, fl: varargs[string]): bool =

  var
    c, errC = 0
    field, sep   = newSeq[string](0)
    head, body, bodyfilename, fp, flag = ""

 # recurse flag to stop endless loop
  if len(fl) > 0:
    flag = fl[0]

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  (head, bodyfilename) = getheadbody(url, "one")  # scrape body
  fp = readfile(bodyfilename)
  if empty(fp):
    sed("validate_archiveit: body is empty", Debug.network)
    return false
 
  # Pure file check - archive-it returns these as-is with no archive-it header info in body 
  if url ~ GX.filext and head !~ "(?i)([\\n][ ]*location[ ]*[:][ ]*[^\\n]*[\\n]?)":
    sed("validate_archiveit: page is a binary - skipping (1)", Debug.network)
    return true

  let command = GX.unixfile & " " & shquote(bodyfilename)   # check for binary file
  (body, errC) = execCmdEx(command)
  awk.split(body,a,"[:]"); body = a[1]
  if body ~ "([Vv]ideo file|[Aa]udio file|Composite Document File|JPG|GIF|PNG|PDF|PPT|PPS|MP3|MP4|FLV|WAV|XLS|SWF|XLSX)":
    sed("validate_archiveit: page is a binary - skipping (2)", Debug.network)
    if Debug.network:
      body >* GX.datadir & "fileout.body"
    return true
  if fp ~ "^(?i)(rtsp[:][/][/])":
    sed("validate_archiveit: page is a binary (rtsp) - skipping (3)", Debug.network)
    return true
  if not contains(fp, "archive-it"):              # sometimes a java redirect and no way to determine except this way
    sed("validate_archiveit: Unable to find archive-it in body", Debug.network)
    return false
  if contains(fp, "The page you requested has not been archived in Archive-It"):
    sed("validate_archiveit: The page you requested has not been archived in Archive-It", Debug.network)
    return false
  if head ~ "(?i)(HTTP[/]1.[0-9][ ]*30[12])":
    sed("validate_archiveit: Found redirect..", Debug.network)
    c = patsplit(head, field, "(?i)([\\n][ ]*location[ ]*[:][ ]*[^\\n]*[\\n]?)", sep)  
    if c > 0:
      field[c-1] = strip(field[c-1])
      gsub("(?i)(location[ ]*[:][ ]*)", "", field[c-1])
      if field[c-1] ~ "^/all":
        field[c-1] = "https://wayback.archive-it.org" & field[c-1]
      sed("validate_archiveit: Location = " & field[c-1], Debug.network)
      if field[c-1] ~ "(?i)(^https?[:]//wayback[.]archive[-]it[.]org)":
        if manual_soft404(field[c-1]):
          sed("validate_archiveit: redirected URL is in soft404.bm", Debug.network)
          return false
        # Skip if URL has no path (ie. a homepage). More often than not these get caught by soft404() but are false positives
        if awk.split(urlurl(field[c-1]), a, "[/]") == 4 and awk.split(urlurl(url), b, "[/]") != 4:
          if empty(a[3]):
            sed("validate_archiveit: root path skip", Debug.network)
            return false
          else:
            sed("validate_archiveit: root path contains something", Debug.network)
            return true
        elif c > 1:
          sed("validate_archiveit: Number of Locations > 1: " & $c, Debug.network)
          if empty(flag):   
            if validate_archiveit(field[c-1], "recurse"):
              url = field[c-1]
              sed("validate_archiveit: Found redirect URL (c>1) at " & url, Debug.network)
              return true
            else:
              sed("validate_archiveit: Unable to validate location (c>1)", Debug.network)
              return false
          else:
            sed("validate_archiveit: Redirect loop (c>1)", Debug.network)
            return false
        else:  # recursive call
          if empty(flag): 
            if validate_archiveit(field[c-1], "recurse"):
              url = field[c-1]
              sed("validate_archiveit: Found redirect URL at " & url, Debug.network)
              return true
            else:
              sed("validate_archiveit: Unable to validate location", Debug.network)
              return false
          else:
            sed("validate_archiveit: Redirect loop", Debug.network)
            return false
      else:
        sed("validate_archiveit: Location URL doesn't verify as archive-it", Debug.network)
        sendlog(Project.syslog, CL.name, " error -- validate_archiveit: Location URL doesn't verify as archive-it for " & url)
        return true
    else: 
      sed("validate_archiveit: unable to find redirect for " & url, Debug.network)
      sendlog(Project.syslog, CL.name, " error -- validate_archiveit: Unable to find redirect for " & url)
      return false
  return true

#
# Validate arquivo.pt (Portuguese) given the arquivo.pt URL
#
proc validate_porto(url: string): bool =

  var
    head, bodyfilename, body, fp = ""
    errC, c = 0
    field, sep = newSeq[string](0)

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  (head, bodyfilename) = getheadbody(url, "one")  # scrape body
  fp = readfile(bodyfilename)
  if empty(fp):
    sed("validate_porto: body is empty", Debug.network)
    return false

 # check for binary
  let command = GX.unixfile & " " & shquote(bodyfilename)   # check for binary file
  (body, errC) = execCmdEx(command)
  if body ~ "([Vv]ideo file|[Aa]udio file|Composite Document File|JPG|GIF|PNG|PDF|PPT|PPS|DOC|MP3|MP4|FLV|WAV|XLS|SWF|XLSX)":
    sed("validate_porto: page is a binary - skipping", Debug.network)
    return true

 # Check for 404/3
  if head ~ "(?i)(HTTP[/]1[.][0-9][ ]*40[43])":
    sed("validate_porto: head contains 404/403", Debug.network)
    return false

 # Check for redirect
  if head ~ "(?i)(HTTP[/]1.[0-9][ ]*30[12])":
    c = patsplit(head, field, "(?i)([\\n][ ]*location[ ]*[:][ ]*[^\\n]*[\\n]?)", sep)  
    if c > 0:
      field[c-1] = strip(field[c-1])
      gsub("(?i)(location[ ]*[:][ ]*)", "", field[c-1])
      field[c-1] = strip(field[c-1])
      if field[c-1] ~ "^[/]wayback":
        field[c-1] = "http://arquivo.pt" & field[c-1]
      if field[c-1] ~ "(?i)(^https?[:]//arquivo[.]pt[/])":
          # Skip if URL has no path (ie. a homepage). More often than not these get caught by soft404() but are false positives
          if awk.split(urlurl(field[c-1]), a, "[/]") == 4 and awk.split(urlurl(url), b, "[/]") != 4:
            if empty(a[3]):
              sed("validate_porto: root path skip", Debug.network)
              return false
            elif manual_soft404(field[c-1]):
              sed("validate_porto: redirected URL is in soft404.bm", Debug.network)
              return false
          elif manual_soft404(field[c-1]):
            sed("validate_porto: redirected URL is in soft404.bm", Debug.network)
            return false
      else:
        sed("validate_porto: unable to find redirect Location: URL for " & url, Debug.network)
        sendlog(Project.syslog, CL.name, " error -- Unable to find redirect Location: URL for " & url)
        return false        
    else: 
      sed("validate_porto: unable to find redirect Location: for " & url, Debug.network)
      sendlog(Project.syslog, CL.name, " error -- Unable to find redirect Location: for " & url)
      return false

  return true

#
# Validate wikiwix.cim given the Wikiwix URL
#
proc validate_wikiwix(url: string): bool = 

  var
    errC = 0
    jsonin,apiurl,command,sourceurl,dest,origurl = ""
    url = url

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  origurl = url

 # strip &title and &apirepose 
  if contains(url, "apiresponse"):
    gsub("[&]apiresponse[=][0-9]", "", url)
  if awk.match(url, "[&]title[=][^<$]*[^<$]?", dest) > 0:
    if awk.split(dest, a, "[&][^=]*[=]") == 2:
      gsubs(dest, "", url)
    else:                  
      sed("Error: Wikiwik URL has more than one &title : " & origurl, Debug.network)  
      return true

 # get source URL
  if awk.match(url, "cache/[?]url[=][^$]*[^$]?", sourceurl) > 0:
    gsubs("cache/?url=", "", sourceurl)
  elif awk.match(url, "cache/[0-9]{4,14}/[^$]*[^$]?", sourceurl) > 0:
    gsub("cache/[0-9]{4,14}/", "", sourceurl)
  else:                     # non-archive wikiwix URL - skip it
    sed("Warning: Wikiwik URL not an archive: " & origurl, Debug.network)  
    return true
  if empty(sourceurl):
    sed("Warning: Unable to determine Wikiwix source URL: " & origurl, Debug.network)  
    return true

  sourceurl = uriparseEncodeurl(urldecode(sourceurl))
  apiurl = "http://archive.wikiwix.com/cache/?url=" & sourceurl & "&apiresponse=1"
  command = "timeout 5m wget" & GX.wgetopts & "-q -O- " & shquote(apiurl) & " | head -c 1024"
  sed(command, Debug.network)  

  (jsonin, errC) = execCmdEx(command)

  if empty(jsonin):         
    libutils.sleep(10)
    sed(command, Debug.network)  
    (jsonin, errC) = execCmdEx(command)
    if empty(jsonin):
      libutils.sleep(30)  # Sometimes lynx works where wget doesn't
      command = "timeout 8m lynx " & GX.agentlynx & " --source " & shquote(apiurl) & " | head -c 1024"
      sed(command, Debug.network)  
      (jsonin, errC) = execCmdEx(command)
      if empty(jsonin):
        if Debug.network: sed("ERROR: WikiWix returned 0-length API", Debug.network)
        return false     
  
  if awk.split(jsonin, a, "\"") > 13:
    if strip(a[13]) ~ "^[0-9]{4,14}$" and strip(a[3]) == "200":
      if contains(a[13], awk.substr(todaysdateymd(),0,6) ):     # Skip if snapshot date = today because it is probably a soft-404 due to how WikiWix seems to
                                                                # grab a snapshot real-time with the API call(!) then say it's available regardless of status
        return false
      return true
    else:
      sed("Unable to verify Wikiwix JSON: " & jsonin, Debug.network)

  return false

#
# Validate freezepage.com given the freezepage URL
#
proc validate_freezepage(url: string): bool =

  var
    head, bodyfilename, fp = ""

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  (head, bodyfilename) = getheadbody(url, "one")  # scrape body
  fp = readfile(bodyfilename)
  if empty(fp):
    return false
  if awk.match(fp, "[Tt]he frozen page [(][^)]*[)] could not be found on our system") > 0:
    return false
  if awk.match(fp, "as of [0-9]{1,2}[-][A-Za-z]{3,9}[-][0-9]{4}") > 0:
    return true
  return false

#
# Validate webcitation.org given the archived url
#
proc validate_webcite(url: string): bool =

  var
    xmlin = ""
    errC: int

  if not GX.webciteok:  # API is down, treat link as working
    return true

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  # head -c 1024 needed to deal with API bug that causes endless data stream such as /query?id=5ZprY4O4g&returnxml=true
  let command = "timeout 5m wget" & GX.wgetopts & "-q -O- \"http://www.webcitation.org/query?returnxml=true&url=" & url & "\" | head -c 1024 "
  sed(command, Debug.network)

  (xmlin, errC) = execCmdEx(command)

  if empty(xmlin):
    libutils.sleep(10)
    (xmlin, errC) = execCmdEx(command)
    if empty(xmlin):
      libutils.sleep(30)  # Sometimes lynx works where wget doesn't
      (xmlin, errC) = execCmdEx("timeout 8m lynx " & GX.agentlynx & " --source \"http://www.webcitation.org/query?returnxml=true&url=" & url & "\" | head -c 1024 ")
      if empty(xmlin):
        if Debug.network: sed("ERROR: Webcite returned 0-length API", Debug.network)
        return false

  if xmlin ~ "result[ \\n]*status[ \\n]*[=][ \\n]*\"success\"" :
    return true

  return false

#
# Validate webcitation.org URL given a Webcite url
#
proc validate_webciteid(url: string): bool =

  var
    id = webciteid(url)
    xmlin,newurl = ""
    errC: int

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  if not GX.webciteok:  # API is down, treat link as working
    return true

  if id == "nobase62":        # alternate format URLs
    newurl = urlurl(url) 
    if newurl == url:         # urlurl() returns same url if can't determine an attached url
      if match(newurl, "id[=][0-9]{16}$", dest) > 0:          # http://www.webcitation.org/query?id=1249967769270858
        gsubs("id=","",dest)
        id = dest
      elif match(newurl, "[.]org[/][0-9]{16}$", dest) > 0:    # http://www.webcitation.org/1249967769270858
        gsubs(".org/", "",dest)
        id = dest 
      elif newurl ~ "[.]org[/]cache[/]|getfile[.]php":        # http://www.webcitation.org/cache/73e53dd1f16cf8c5da298418d2a6e452870cf50e
        return true                                           # http://www.webcitation.org/getfile.php?fileid=1c46e791d68e89e12d0c2532cc3cf629b8bc8c8e
      else:
        return true
    elif not empty(newurl):
      if not validate_webcite(newurl):                       # try unencoded
        if not validate_webcite(uriparseEncodeurl(newurl)):  # try encoded
          return false
        else:
          return true
      else: 
        return true
    else:
      return true

  if id == "error":
    return false

  # head -c 1024 needed to deal with API bug that causes endless data stream such as /query?id=5ZprY4O4g&returnxml=true
  let command = "timeout 5m wget" & GX.wgetopts & "-q -O- \"http://www.webcitation.org/query?returnxml=true&id=" & id & "\" | head -c 1024"
  sed(command, Debug.network)

  (xmlin, errC) = execCmdEx(command)

  if empty(xmlin):
    libutils.sleep(2)
    (xmlin, errC) = execCmdEx(command)
    if empty(xmlin):
      if Debug.network: 
        sed("ERROR: Webcite returned 0-length API", Debug.network)
        return false

  if xmlin ~ "result[ \\n]*status[ \\n]*[=][ \\n]*\"success\"" :
    return true

  return false



#
# Given an archive.is HTML, strip headers and save to GX.data "plaintext.html" 
#  Return a plain text version (using lynx --dump) with \n removed
#  On error return bodyHTML
#
proc plaintextualize(bodyHTML: string, lb: int): string =

    var
      field, sep   = newSeq[string](0)
      c, loc, errC = 0
      a, cmd, outp = ""

    if Debug.network: bodyHTML >* GX.datadir & "plaintextdebug1.html"

     # Remove javascript 
    c = patsplit(bodyHTML, field, "[<]script|[<][/]script", sep)
    for i in 0..c-1: 
      if odd(i):   
        sep[i] = ""  
    a = unpatsplit(field, sep)   

    if Debug.network: a >* GX.datadir & "plaintextdebug2.html"

     # Remove archive.is headers (must be done after javascript remove)
    loc = match(a, "(?i)([|][ ]*archive[-]?date[^\\n]*[\\n])", b)
    if loc > 0:
      gsubs(b, "", a)
      a = substr(a, loc, len(a) - 1)    

      if Debug.network: a >* GX.datadir & "plaintextdebug3.html"

      a >* GX.datadir & "plaintext.html"
      # Seems to work better more often when HTML piped via stdin rather than on command-line don't know why
      cmd = "cat " & shquote(GX.datadir & "plaintext.html") & " | lynx " & GX.agentlynx & " --stdin --dump --nolist --nonumbers"
      sed(cmd, Debug.network)
      (outp, errC) = execCmdEx(cmd)
      if errC == 0:
        if Debug.network: outp >* GX.datadir & "plaintextdebug4.html"
        # Remove stuff added by lynx
        awk.gsub("[0-9]{1,3}%", "", outp)         # remove "10%, 20%" etc..
        awk.gsub("\n", " ", outp)                 # remove \n
        awk.gsub("[[][^]]*[]]", "", outp)         # remove [counter?id=2825109;js=na] [jpg] etc..
        awk.gsub("_{3,}", "", outp)               # remove ______
        if Debug.network: outp >* GX.datadir & "plaintextdebug5.html"
        if lb < 12000:
          sendlog(Project.syslog, CL.name, cmd & " ---- " & $len(outp))
        return outp

    if Debug.network: bodyHTML >* GX.datadir & "plaintextdebug0.html"
    return bodyHTML

#
# Given an original URL and redirect URL, compare to see if the later is a soft404
#  returns "soft404" or ""
#  If "mode" == "strict" be strict
#  if "mode" == "easy" be easy
#
proc isredirsoft404(origurl, newurl, mode: string): string =

    var
      path, origpath = ""
      mode = mode

    if origurl ~ "(?i)(gamespot|livejournal[.]com)":  # go easy on common problem domains
      mode = "easy"

    origpath = uriparseElement(urlurl(origurl), "path")
    path = uriparseElement(newurl, "path")
    if len(path) < 2:                                                                # If path is empty, probably a home page
      if urlurl(origurl) != newurl and len(origpath) > 2:
        sed("Redir URL failed check 1. Path " & path & " too short.", Debug.network)
        sendlog(Project.syslog, CL.name, mode & " ---- " & origurl & " ---- " & newurl  & " ---- " & "isredirsoft404: Check 1: Path too short1")
        return "soft404"
    if path ~ "[Nn][Oo][Tt][^Ff]*[Ff][Oo][Uu][Nn][Dd]":
      sed("Redir URL failed check 2", Debug.network)
      sendlog(Project.syslog, CL.name, mode & " ---- " & origurl & " ---- " & newurl  & " ---- " & "isredirsoft404: Check 2")
      return "soft404"
    if path ~ "[^0-9]404[^0-9]|[^a-zA-Z][Ee]rror[^a-zA-Z]|[^a-zA-Z][Uu]nknown[^a-zA-Z]":
      sed("Redir URL failed check 3", Debug.network)
      sendlog(Project.syslog, CL.name, mode & " ---- " & origurl & " ---- " & newurl  & " ---- " & "isredirsoft404: Check 3")
      return "soft404"
    if newurl ~ "(?i)(errors?|signin|main)([.](cfm|mpx|aspx?|html?|php))?$" and origurl !~ "(?i)(errors?|signin|main)([.](cfm|mpx|aspx?|html?|php))?$":
      sed("Redir URL failed check 6", Debug.network)
      sendlog(Project.syslog, CL.name, mode & " ---- " & origurl & " ---- " & newurl  & " ---- " & "isredirsoft404: Check 6")
      return "soft404"
    if newurl ~ "(?i)([#]|errors?|news|topic|english|sports|escenario|portal)[/]?$" and origurl !~ "(?i)([#]|errors?|news|topic|english|sports|escenario|portal)[/]?$":
      sed("Redir URL failed check 7", Debug.network)
      sendlog(Project.syslog, CL.name, mode & " ---- " & origurl & " ---- " & newurl  & " ---- " & "isredirsoft404: Check 7")
      return "soft404"
    if newurl ~ "(?i)(home|index|default)([.](cfm|mpx|aspx?|html?|php))?$" and origurl !~ "(?i)(home|index|default)([.](cfm|mpx|aspx?|html?|php))?$":
      if len(origpath) > 1:
        sed("Redir URL failed check 8", Debug.network)
        sendlog(Project.syslog, CL.name, mode & " ---- " & origurl & " ---- " & newurl  & " ---- " & "isredirsoft404: Check 8")
        return "soft404"
     
    if mode == "strict":
      if newurl[high(newurl)] == '/' and origurl[high(origurl)] != '/':                             # If last char of new URL is /
        if not urlequal(system.substr(newurl, 0, high(newurl) - 1), urlurl(origurl)):               # ..but only if URLs are not otherwise the same
          sed("Redir URL failed check 4", Debug.network)
          sendlog(Project.syslog, CL.name, mode & " ---- " & origurl & " ---- " & newurl  & " ---- " & "isredirsoft404: Check 4: Ends with slash")
          return "soft404"
      if awk.split(path, a, "/") == 2 and awk.split(origpath, a, "/") > 2 and origurl !~ "googleusercontent[.]com":
        if not urlequal(system.substr(newurl, 0, high(newurl) ), urlurl(origurl)):              
          sed("Redir URL failed check 5: path is too short" ,Debug.network)
          sendlog(Project.syslog, CL.name, mode & " ---- " & origurl & " ---- " & newurl  & " ---- " & "isredirsoft404: Check 5: Path too short5")
          return "soft404"

    return ""


#
# Get an archiveispage
#
proc archiveispage*(url: string): tuple[m:string, z:int] =

  var
    urllynx = url
    command,xmlin = ""
    errC = 0

  if url ~ GX.shttp:                              # lynx and cloudflare.py can't do ssl
    gsub(GX.shttp, "http", urllynx)

  command = "timeout 5m lynx " & GX.agentlynx & " --source " & shquote(urllynx)   # lynx required for archive.is
  sed("Checking Archive.is ..", Debug.network)
  sed(command, Debug.network)
  (xmlin, errC) = execCmdEx(command)

  if xmlin ~ "(?i)(DDoS protection by Cloudflare)":
    command = "timeout 5m ./cloudflare.py content " & shquote(urllynx)
    sed("Checking Archive.is with cloudflare.py", Debug.network)
    sed(command, Debug.network)
    (xmlin, errC) = execCmdEx(command)
    if xmlin ~ "(?i)(DDoS protection by Cloudflare)":
      sendlog(Project.critical, CL.name, " ArchiveIS Cloudflare DDOS protection")
      result[0] = ""
      result[1] = errC
      return

  if empty(xmlin):  # check for empty response
    sed("Try 2: Checking Archive.is ..", Debug.network)
    if not Debug.network:
      libutils.sleep(10)
    (xmlin, errC) = execCmdEx(command)
    if empty(xmlin):
      sed("Try 3: Checking Archive.is ..", Debug.network)
      if not Debug.network:
        libutils.sleep(20)
      (xmlin, errC) = execCmdEx(command)
      if empty(xmlin):
        sed("ERROR: Archive.is archive returned 0-length", Debug.network)
        # command = "timeout 1m lynx " & GX.agentlynx & " --source http://archive.is"
        command = "timeout 1m ./cloudflare.py content " & shquote("http://archive.is")
        (xmlin, errC) = execCmdEx(command)
        if empty(xmlin) or errC == 124:
          sed("ERROR: Archive.is appears to be down entirely.", Debug.network)
          sendlog(Project.critical, CL.name, " ArchiveIS Down")
        result[0] = ""
        result[1] = errC
        return

  if not empty(xmlin):
    result[0] = xmlin
    result[1] = errC
    return
  else:
    result[0] = ""
    result[1] = errC
    return


# ---------------

include soft404                                            # --> soft404.nim

# ---------------

#
# Given a wayback URL return true if it's a soft-404
#
proc wayback_soft404(origurl: string): bool =

  var
    url = origurl
    cmd, outp, title, bodyhtml, res, head, filestick = ""
    errC = -1
    j = 0

  if empty(url):
    return true

  # Pure image check - also in soft404.nim
  if url ~ GX.filext:
    return false

 # Skip if URL has no path (ie. a homepage). More often than not these get caught by soft404() but are false positives
  if awk.split(wayurlurl(url), a, "[/]") == 4:
    if empty(a[3]):
      return false

 # If a single wgetbody.* file exist use that otherwise download it
  for file in walkFiles(GX.datadir & "wgetbody*"):
    j = j + 1
    filestick = file
  if j == 1:
    bodyhtml = filestick
    head = "200"
  else:
    # Via wget. Limit size of download. Limit number of retries to one.
    (head,bodyhtml) = getheadbody(url, "one")

  if not empty(head):
    if not empty(bodyhtml):

     # Works better via stdin
      cmd = "cat " & shquote(bodyhtml) & " | lynx --dump --stdin --nolist --nonumbers"
      sed("wayback_soft404: " & cmd, Debug.network)
      (outp, errC) = execCmdEx(cmd)

      if errC == 0:

        bodyhtml = readfile(bodyhtml)

        if match(bodyhtml, "[<][ ]*title[^<]*[<][ ]*[/][ ]*title[ ]*[>]", b) > 0:
          gsub("[<][ ]*title[^>]*[>]","",b)
          gsub("[<][ ]*[/]title[^>]*[>]","",b)
          title = b
        else:
          title = ""

        awk.gsub("\n", " ", outp)                 # remove \n
        gsub("[ ]{2,}", " ", outp)                # remove multiple spaces between words

       # Lynx can't handle frames
        if outp !~ "FRAME[:]":
          res = soft404(url, title, outp, bodyhtml, " ", "api")
        else:
          res = "OK"
     
        if res != "OK":
          if not empty(res):
            sendlog(Project.syslog, CL.name, origurl & " ---- wayback_soft404: " & res)
            sed("wayback_soft404: " & res, Debug.network)
          return true

  return false


#
# Check archive.is redirect info in body-header for soft404
#
proc archiveis_soft404_redir(cite, bodyHTML, origurl, source, rest, mode: string): bool =

  var
    newurl = ""
    mode = mode

  if bodyHTML ~ "(?i)([>][ ]{0,}redirected from)":
      match(cite, "url" & GX.space & "[=][^|]*[^|]?", newurl)
      gsub( "url" & GX.space & "[=]" & GX.space, "", newurl)
      newurl = strip(convertxml(newurl))
      if len(newurl) > 2:
        if source == "api" and mode != "easy":
          mode = "strict"
        else:
          mode = "easy"
        if isredirsoft404(origurl, newurl, mode) == "soft404" or isredirsoft404(urldecode(origurl), newurl, mode) == "soft404":
          sed("archiveis_soft404: failed redir check", Debug.network)
          sendlog(Project.syslog, CL.name, origurl & " ---- archiveis_soft404: failed redir check")
          return true

  return false

#
# Given a {{cite..}} obtained from the header of an archive.is web scrape,
#  Check for known soft-404 problems. 
#  Return true if soft-404 detected
#  Don't check if source is "wiki"
#
proc archiveis_soft404(cite, bodyHTML, origurl, source: string): bool =

  var
    plainbody, res, rest = ""
    softy = true

  if source != "api":   # Skip if source of link is wikitext - assume it probably works
    sed("archiveis_soft404: source != api", Debug.network)
    return false

  match(cite, "title" & GX.space & "[=][^|]*[^|]?", title)
  gsub( "title" & GX.space & "[=]" & GX.space, "", title)
  title = strip(convertxml(title))
  if empty(title):
    sed("archiveis_soft404: empty title", Debug.network)
    return true

  match(cite, "url" & GX.space & "[=][^|]*[^|]?", url)
  gsub( "url" & GX.space & "[=]" & GX.space, "", url)
  url = strip(convertxml(url))
  if empty(url):
    sed("archiveis_soft404: empty url", Debug.network)
    return true

 # short-form archive.is URL
  match(cite, "archive[-]?url" & GX.space & "[=][^|]*[^|]?", shorturl)
  gsub( "archive[-]?url" & GX.space & "[=]" & GX.space, "", shorturl)
  shorturl = strip(convertxml(shorturl))

 # Convert to plain text 
  var lb = len(bodyHTML)
  plainbody = plaintextualize(bodyHTML, lb)
  plainbody >* GX.datadir & "plaintextbody.html"
  if len(plainbody) < lb:
    gsub("[ ]{2,}", " ", plainbody)   # collapse multiple spaces between words

 # soft404.nim

 # res  = result of in-house soft404 checker
 # rest = result of archive.is soft404 checker (http://archive.is/2Ehff:showstatus) which I call "ais"

 #  lynx can't handle frames
  if plainbody !~ "FRAME[:]":
    res = soft404(url, title, plainbody, bodyHTML, origurl, source)

  if empty(res): 
    res = "OK"
  if res ~ "Blank page": # safe call most times
    return true

  rest = soft404ais(shorturl)

  if plainbody ~ "FRAME[:]":
    return archiveis_soft404_redir(cite, bodyHTML, origurl, source, rest, "strict")
    
 # log differences of opinion
  if res == "OK":  
    if rest != "OK":                           
      sendlog(Project.syslog, CL.name, origurl & " ---- soft404() mismatch soft404ais() (OK vs not OK)" )
  if res != "OK":  
    if rest == "OK":                           
      sendlog(Project.syslog, CL.name, origurl & " ---- soft404() mismatch soft404ais() (not OK vs OK)" )

 # core logic    
  if res == "OK" and rest == "OK":
    softy = archiveis_soft404_redir(cite, bodyHTML, origurl, source, rest, "easy")
    if softy == false and rest ~ "Status": # override if ais returns a status code ie. 4xx,5xx but not 3xx or 2xx
      softy = true
    sed("archiveis_soft404: logic1 " & $softy & " (" & res & " vs " & rest & ")", Debug.network)
    sendlog(Project.syslog, CL.name, origurl & " ---- archiveis_soft404: logic1 " & $softy & " (" & res & " vs " & rest & ")")
    return softy
  elif res == "OK" and rest != "OK":
    softy = archiveis_soft404_redir(cite, bodyHTML, origurl, source, rest, "strict")
    if softy == false and rest ~ "Status": # see note above
      softy = true
    sed("archiveis_soft404: logic2 " & $softy & " (" & res & " vs " & rest & ")", Debug.network)
    sendlog(Project.syslog, CL.name, origurl & " ---- archiveis_soft404: logic2 " & $softy & " (" & res & " vs " & rest & ")")
    return softy
  elif res != "OK" and rest == "OK":
    softy = archiveis_soft404_redir(cite, bodyHTML, origurl, source, rest, "strict")
    if softy == false and rest ~ "Status": # see note above
      softy = true
    sed("archiveis_soft404: logic3 " & $softy & " (" & res & " vs " & rest & ")", Debug.network)
    sendlog(Project.syslog, CL.name, origurl & " ---- archiveis_soft404: logic3 " & $softy & " (" & res & " vs " & rest & ")")
    return softy
  elif res != "OK" and rest != "OK":
    sed("archiveis_soft404: logic4 true (" & res & " vs " & rest & ")", Debug.network)
    return true
  
  return false


#
# Given HTML body and original URL return the redirect URL using 3 methods
#
proc getredirurl_helper(body, origurl: string): string =

  var
    url = ""
    body = body

  gsub("\n|\r|\t"," ",body)     

  # Method 1
  # <p class="impatient"><a href="/web/20090205165059/http://news.bbc.co.uk/sport2/hi/cricket/7485935.stm">
  # <p class="impatient"><a href="http://web.archive.org/web/20090205165059/http://news.bbc.co.uk/sport2/hi/cricket/7485935.stm">

  if match(body,"[<][ ]{0,}[Pp][ ]{1,}[Cc][Ll][Aa][Ss]{2}[ ]{0,}[=][ ]{0,}\"[ ]{0,}[Ii]mpatient[ ]{0,}\"[ ]{0,}>[ ]{0,}[<][ ]{0,}[Aa][ ]{1,}[Hh][Rr][Ee][Ff][ ]{0,}[=][ ]{0,}\"/[Ww][Ee][Bb]/[^\"]*\"", k) > 0:
    if awk.split(k, a, "\"") == 5:                
      if strip(a[3]) ~ "^[/][Ww][Ee][Bb]":
        url = strip(a[3])
  elif match(body,"[<][ ]{0,}[Pp][ ]{1,}[Cc][Ll][Aa][Ss]{2}[ ]{0,}[=][ ]{0,}\"[ ]{0,}[Ii]mpatient[ ]{0,}\"[ ]{0,}>[ ]{0,}[<][ ]{0,}[Aa][ ]{1,}[Hh][Rr][Ee][Ff][ ]{0,}[=][ ]{0,}\"[Hh][Tt][Tt][Pp][^\"]*\"", k) > 0:
    if awk.split(k, a, "\"") == 5:                
      if strip(a[3]) ~ "^[Hh][Tt][Tt][Pp]":
        url = strip(a[3])

  # Method 2      
  # function go() { document.location.href = "\/web\/20090205165059\/http:\/\/news.bbc.co.uk\/sport2\/hi\/cricket\/7485935.stm"
  # function go() { document.location.href = "http:\/\/web.archive.org\/web\/20090205165059\/http:\/\/news.bbc.co.uk\/sport2\/hi\/cricket\/7485935.stm"

  if empty(url) and match(body, "function[ ]{1,}go[(][)][ ]{0,}[{][ ]{0,}document[.]location[.]href[ ]{0,}[=][ ]{0,}\"\\\\/[Ww][Ee][Bb][^\"]*\"", k) > 0:
     if awk.split(k, a, "\"") == 3:
       gsub("\\\\/","/",a[1])
       if strip(a[1]) ~ "^[/][Ww][Ee][Bb]":
         url = strip(a[1])
  elif empty(url) and match(body, "function[ ]{1,}go[(][)][ ]{0,}[{][ ]{0,}document[.]location[.]href[ ]{0,}[=][ ]{0,}\"[Hh][Tt][Tt][Pp][^\"]*\"", k) > 0:
     if awk.split(k, a, "\"") == 3:
       gsub("\\\\/","/",a[1])
       if strip(a[1]) ~ "^[Hh][Tt][Tt][Pp]":
         url = strip(a[1])

  # Method 2.2
  # <a href="https://web.archive.org/web/20120605133852/http://my.sycamoreschools.org/webapps/login?new_loc=%2Fmodules%2F_299_1%2Ffast%2520facts%2520updated%252010-1-10.pdf">
  # <strong>Click here to access the page to which you are being forwarded.</strong></a>
  
  if(match(body, "<a href[ ]{0,}[=][ ]{0,}\"[^\"]*\"[ ]{0,}>[ ]{0,}<[ ]{0,}strong[ ]{0,}>[ ]{0,}Click here to access the page to which you are being forwarded.[ ]{0,}<[ ]{0,}/strong[ ]{0,}>[ ]{0,}<[ ]{0,}/a[ ]{0,}>", k) > 0):
    if awk.split(k, a, "\"") == 3: 
      url = strip(a[1])

  # Method 3 - lynx 
  #  When unable to determine from HTML source alone. This will render the HTML via lynx --dump
  if empty(url):
    var bodylynx = getbodylynx(origurl, "dump")
    if not empty(bodylynx):
      # [125]Impatient?
      if awk.match(bodylynx, "[[][0-9]{1,4}[]][\\s]*Impatient[?]", dest) > 0:
        awk.match(dest, "[[][0-9]{1,4}[]]", dest2)
        gsub("^[[]|[]]$", "", dest2)
        # 125. https://web.archive.org/web/20110725221826/http://www.dayagainsthomophobia.org/Brazil-s-President-Lula-decrees,280
        awk.match(bodylynx, "[ ]*" & dest2 & "[.] http[^\\n]*[^\\n]", dest3)
        gsub("[ ]*" & dest2 & "[.]", "", dest3)
        dest3 = strip(dest3)
        if isarchiveorg(dest3):
          url = dest3

  if empty(url):
    return ""

  url = convertxml(url)
  if not isarchiveorg(url) and isarchiveorg(origurl):
    url = "https://web.archive.org"  & url
  if isarchiveorg(origurl) and isarchiveorg(url):
    gsub("^[Hh][Tt][Tt][Pp][:]", "https:", url)

  return url

#
# Find the redirect URL from body of IA 302 info page
#  Since using scrape, try 3 methods in case page formatting changes.
#
proc getredirurl(origurl, filename: string): string =

  var body, url, newurl, origurl2 = ""

  if existsFile(filename):
    body = readfile(filename)
  else:
    return

  url = getredirurl_helper(body, origurl)

  newurl = wayurlurl(url)
  if isarchiveorg(origurl):
    origurl2 = wayurlurl(origurl)

  if newurl ~ GX.shttp and origurl2 ~ GX.shttp and len(newurl) < len(origurl2):    # Basic filters soft-404
    if isredirsoft404(origurl2, newurl, "strict") == "soft404":
      return ""

  return url

#
# Validate archive.is - check for blank page, missing snapshot or soft-404
# source = "api" or "wiki" (where the URL was found - from an API result, or from the wikitext)
# return true if OK; otherwise false if not OK
#
proc validate_archiveis(url: var string, source: string, fl: varargs[string]): bool =

  var
    xmlin, flag, url2 = ""
    errC: int

 # recurse flag to stop endless loop
  if len(fl) > 0:
    flag = fl[0]

  (xmlin,errC) = archiveispage(url)
  if empty(xmlin):
    return false

  if contains(xmlin, ">No results<div"):  # No results page
    sed("Archive.is returned 'No Results'", Debug.network)
    sendlog(Project.syslog, CL.name, url & " ---- validate_archiveis: check 1")
    return false

  # for cases such as http://archive.is/oFCDR/cf40b2b632a0c373d888a1201c892a97da538015.jpg
  if url ~ "(?i)(jpg$|gif$)" and url !~ "[/][0-9]{8,14}[/]" and not empty(xmlin):  
    return true

  if match(xmlin, GX.cite, destcite) > 0:
    if not archiveis_soft404(destcite, xmlin, url, source):
      return true

  if url ~ "(?i)([/]https[:][/][/])" and flag != "recurse":
    url2 = url
    awk.sub("(?i)([/]https[:][/][/])", "/http://", url2)
    if validate_archiveis(url2, source, "recurse"):
      sed("Archive.is redirect to http", Debug.network)
      sendlog(Project.syslog, CL.name, url & " ---- " & url2 & " ---- validate_archiveis: redirect to http")
      url = url2
      return true

  # dreaded "loading" page .. don't delete existing links
  if contains(xmlin, "www.henley-putnam.edu/Portals/_default/Skins/henley/images/loading.gif") and source == "wiki":
    sed("Archive.is returned 'loading.gif' (wiki)", Debug.network)
    sendlog(Project.syslog, CL.name, url & " ---- validate_archiveis: wiki loading.gif")
    return true

  if contains(xmlin, "www.henley-putnam.edu/Portals/_default/Skins/henley/images/loading.gif") and source != "wiki":
    sed("Archive.is returned 'loading.gif' (api)", Debug.network)
    sendlog(Project.syslog, CL.name, url & " ---- validate_archiveis: api loading.gif")
    return false

  return false

#
# Validate archive.is, loc.gov, arquivo.pt .. any archive that returns 0-length when snapshot is missing
#
# fl = "wiki|api" and signifies where the URL was obtained from (wikitext or the API) - only needed for Archive.is
#
proc validate_other(url: var string, fl: varargs[string]): bool =

  var
    xmlin, flag = ""
    errC: int

  if len(fl) > 0:    
    flag = fl[0]

  if empty(url):
    return false
  if manual_soft404(url):
    return false

  # Tempoary outage of Iceland (Feb 28 2018)
  #if isvefsafn(url) and flag == "wiki":
  #  return true

  # Anything in the "sub2" list that has its own validate_ proc
  if isarchiveis(url):
    return validate_archiveis(url, flag) # currently only called when source of URL is wikitext
  if isnatarchivesuk(url):
    return validate_natarchivesuk(url)
  if isarchiveit(url):
    return validate_archiveit(url)
  if isbibalex(url):
    return validate_bibalex(url)
  if isnlaau(url):
    return validate_nlaau(url)
  if isfreezepage(url):
    return validate_freezepage(url)
  if isporto(url):
    return validate_porto(url)
  if islocgov(url):
    return validate_locgov(url)

  let command = "timeout 5m wget" & GX.wgetopts & "-q -O- " & shquote(url)
  sed(command, Debug.network)

  (xmlin, errC) = execCmdEx(command)

  if empty(xmlin):  # check for empty response ie. no snapshot
    libutils.sleep(2)
    (xmlin, errC) = execCmdEx(command)
    if empty(xmlin):
      if Debug.network: 
        sed("ERROR: Other archive returned 0-length", Debug.network)
      return false
  return true


#
# Single DIY memento query
#
proc diy_memento_single(apiurl, url: string, tag: int): string = 

    var
      jsonin,command,urlx = ""
      errC = 0
      field = newSeq[string](0)

    if apiurl !~ "archive[.]is[/]timemap":
      command = "timeout 5m wget" & GX.wgetopts & "-q -O- " & shquote(apiurl & url)
      sed(command, Debug.network)
      (jsonin, errC) = execCmdEx(command)

    if empty(jsonin) and apiurl ~ "archive[.]is[/]timemap":  
      (jsonin, errC) = archiveispage(apiurl & url)
    # Archive.is API doesn't like urlencoding .. except for "#" should be encoded
      if (empty(jsonin) or jsonin ~ "TimeMap does not exists") and (url ~ "[%]" or url ~ "[#]"): 
        urlx = urldecode(url)
        gsubs("#", "%23", urlx)
        (jsonin, errC) = archiveispage(apiurl & urlx)
        if contains(jsonin, "www.henley-putnam.edu/Portals/_default/Skins/henley/images/loading.gif"):
          sed("Archive.is returned 'loading.gif' (api 2)", Debug.network)
          (jsonin, errC) = archiveispage(apiurl & url)
          if contains(jsonin, "www.henley-putnam.edu/Portals/_default/Skins/henley/images/loading.gif"):
            sed("Archive.is returned 'loading.gif' (api 2)", Debug.network)
            sendlog(Project.syslog, CL.name, url & " ---- diy_memento_single: api loading.gif (api 2)")
      # archive.is IP block due to excessive usage - contact admin for whitelist 
      elif contains(jsonin, "www.henley-putnam.edu/Portals/_default/Skins/henley/images/loading.gif"):
        sed("Archive.is returned 'loading.gif' (api 1)", Debug.network)
        (jsonin, errC) = archiveispage(apiurl & url)
        if contains(jsonin, "www.henley-putnam.edu/Portals/_default/Skins/henley/images/loading.gif"):
          sed("Archive.is returned 'loading.gif' (api 1)", Debug.network)
          sendlog(Project.syslog, CL.name, url & " ---- diy_memento_single: api loading.gif (api 1)")

    if not empty(jsonin):
      var c = patsplit(jsonin, field, "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][^>]+[^>]")
      if c > 0:
        for j in 0..c-1:
          if field[j] !~ "[*]|mementoweb[.]org|archive[.]org|webcitation[.]org" and field[j] ~ "[/][0-9]{14}[/]":

            # Call appropriate validate_ proc 
            if isarchive(field[j], "sub2"):
              if not validate_other(field[j], "api"):  # Check first one only for 0-length
                break                                  # need additional soft-404 cheks here somehow
            elif isnlaau(field[j]):
              if not validate_nlaau(field[j]):
                break
            elif isfreezepage(field[j]):
              if not validate_freezepage(field[j]):
                break
            elif iswebcite(field[j]):
              if not validate_webcite(field[j]):
                break
            else:
              break

            if not manual_soft404(field[j]):
              var ts = urltimestamp(field[j])
              if ts ~ "^[0-9]{8,14}$":
                # Change from http->https? Also update in iab.awk
                if isarchiveis(field[j]) and field[j] ~ "^[Hh][Tt][Tt][Pp][:]":
                  gsub("^[Hh][Tt][Tt][Pp][:]", "https:", field[j])
                if isarchiveit(field[j]) and field[j] ~ "^[Hh][Tt][Tt][Pp][:]":
                  gsub("^[Hh][Tt][Tt][Pp][:]", "https:", field[j])
                WayLink[tag].altarch = field[j]   
                WayLink[tag].altarchencoded = field[j]   # don't change encoding, whatever it says 
                WayLink[tag].altarchdate = system.substr(ts, 0, 7)
                return "OK"        


# DIY search Memento API, bypassing Memento website cache and checking each service directly
#   http://timetravel.mementoweb.org/guide/api/#timemap-diy
#   http://mementoweb.org/depot/
#   http://mementoweb.org/depot/proxy/webarchives/

proc diy_memento(url: string, did_is_check: bool, tag: int): string = 

  var
    command, jsonin = ""
    wikiwix = true
    errC, is_number: int
    service = newSeq[string](0)

  insert(service, "http://wayback.archive-it.org/all/timemap/link/", 0) # Archive-It
  insert(service, "http://arquivo.pt/wayback/timemap/*/", 1)            # Portuguese Web Archive
  insert(service, "https://swap.stanford.edu/timemap/link/", 2)         # Stanford Web Archive
  insert(service, "http://wayback.vefsafn.is/wayback/timemap/link/", 3) # Icelandic Web Archive
  insert(service, "http://webarchive.loc.gov/all/timemap/link/", 4)     # Library of Congress
  insert(service, "http://webarchive.nationalarchives.gov.uk/timemap/", 5) # UK National Archives
  insert(service, "http://collections.internetmemory.org/nli/timemap/", 6) # National Library of Ireland (nli) - may-be others use different codes
  insert(service, "http://perma-archives.org/warc/timemap/*/", 7)       # Perma.cc Archive
  insert(service, "http://webarchive.proni.gov.uk/timemap/", 8)         # PRONI Web Archive
  insert(service, "http://webarchive.parliament.uk/timemap/", 9)        # UK Parliment Archive
  insert(service, "http://timetravel.mementoweb.org/sg/timemap/", 10)   # Web Archive Signapore
  insert(service, "http://timetravel.mementoweb.org/si/timemap/", 11)   # Slovenian Web Archive
  insert(service, "http://timetravel.mementoweb.org/can/timemap/", 12)  # Government of Canada
  insert(service, "http://timetravel.mementoweb.org/cat/timemap/", 13)  # Catalonian Web Archive
  insert(service, "http://timetravel.mementoweb.org/nara/timemap/", 14) # National Archives USA (webharvest.gov)
  insert(service, "http://digital.library.yorku.ca/wayback/timemap/link/", 15) # York University (Canada)

  # newwebarchives 

  # Archive.is - should always be last # .. update "is_number"

  is_number = 16

  if not did_is_check:                                                  # Don't check IS again if already in api_memento()
    insert(service, "http://archive.is/timemap/", is_number)                   
                   # ^^^^  should be http not https

  # insert(service, "http://timetravel.mementoweb.org/aueb/timemap/", 17) # Greece Web Archive # not working as of March 2017
  # insert(service, "http://timetravel.mementoweb.org/es/timemap/", 18)   # Estonian Web Archive # Blocked as of 2017 - check back later
  # insert(service, "http://timetravel.mementoweb.org/cr/timemap/", 19)   # Croatian Web Archive  # no timestamp format available

  for i in 0..len(service) - 1:

    if i == 6:     # too many soft-404s needs work
      continue
    if i == 8:     # down as of august 2018
      continue
    if i == 15:    # down as of september 2018
      continue

    if not Runme.memento:
      if i > 9 and i < 15:
        continue

    if diy_memento_single(service[i], url, tag) == "OK":
      return "OK"

  # See fixiats - restore original wikiwix URL, can't find a replacement
  if Runme.replacewikiwix and WayLink[tag].dummy == "wikiwix":
    var ts = urltimestamp(WayLink[tag].origiaurl)
    if ts ~ "^[0-9]{8,14}$":
      var ourl = WayLink[tag].origiaurl
      gsubs("https://web.archive.org/web/", "http://archive.wikiwix.com/cache/", ourl)
      WayLink[tag].altarch = ourl
      WayLink[tag].altarchencoded = ourl
      WayLink[tag].altarchdate = ts
      return "OK"
    
  # try wikiwix last - use IABot API first to avoid triggering WW API caching a non-existent page creating soft404s

  # red button
  wikiwix = false

  if wikiwix == true:
    command = "./iabget -a searchurldata -p \"urls=" & url & "\" -w"
    sed(command, Debug.network)  
    (jsonin, errC) = execCmdEx(command)
    if empty(strip(jsonin)) or strip(jsonin) == "Error: No results found.":
      command = "./iabget -a searchurldata -p \"urls=" & urldecode(url) & "\" -w"
      sed(command, Debug.network)  
      (jsonin, errC) = execCmdEx(command)
    # "hasarchive": true,
    if jsonin ~ "hasarchive\"[:][ ]true":
      gsubs("\\/", "/", jsonin)
      # "archive": "https:\/\/web.archive.org\/web\/20171108000000\/http:\/\/www.astronautix.com\/lvs\/blaant9b.htm"
      if match(jsonin, "archive\"[:][ ]*\"http[:]//archive[.]wikiwix[.]com[^\"]*[\"]", dest) > 0:
        awk.split(dest, b, "\"")
        var apiurl = b[2] & "&apiresponse=1"
        command = "timeout 5m wget" & GX.wgetopts & "-q -O- " & shquote(apiurl)
        sed(command, Debug.network)  
        (jsonin, errC) = execCmdEx(command)
        if awk.split(jsonin, a, "\"") > 14:
          if strip(a[13]) ~ "^[0-9]{4,14}$" and strip(a[3]) == "200":
            if not contains(a[13], awk.substr(todaysdateymd(),0,6) ):     # Skip if snapshot date = today because it is probably a soft-404 due to how WikiWix seems to
                                                                          # grab a snapshot real-time with the API call(!) then say it's available regardless of status
              var wurl = "http://archive.wikiwix.com/cache/" & strip(a[13]) & "/" & url
              if validate_wikiwix(wurl):
                if not manual_soft404(wurl):
                  WayLink[tag].altarch = wurl
                  WayLink[tag].altarchencoded = wurl
                  WayLink[tag].altarchdate = strip(a[13])
                  return "OK"
                else:
                  sendlog(Project.logwikiwixlong, CL.name, b[2] & "----" & "wwmiss1")
              else:
                sendlog(Project.logwikiwixlong, CL.name, b[2] & "----" & "wwmiss2")
          else:
            sendlog(Project.logwikiwixlong, CL.name, b[2] & "----" & "wwmiss3")

  return "none"

#
# Pick the best Alternative Archive from Memento list, bypassing Wayback snapshots
#  url should be encoded before passing
#  Sample JSON data: wget -q -O- "http://timetravel.mementoweb.org/api/json/20130115102033/http://cnn.com" | jq '. [ ]'
#
proc api_memento(url, date: string, tag: int): string =
  
  var 
    command, jsonin = ""
    errC: int
    did_is_check = false

  if not Runme.memento:
    return diy_memento(url, did_is_check, tag)

  command = "timeout 1m wget" & GX.wgetopts & "-q -O- " & shquote("http://timetravel.mementoweb.org/api/json/" & date & "/" & url) 

  sed(command, Debug.network)
  (jsonin, errC) = execCmdEx(command)

  if empty(jsonin) or jsonin ~ "(?i)([<][ ]*[!][ ]*doctype)":
    sed("Try 1: Memento API returned 0-length or invalid JSON data", Debug.network)
    if not Debug.network: 
      libutils.sleep(10)
    (jsonin, errC) = execCmdEx(command)
    if empty(jsonin) or jsonin ~ "(?i)([<][ ]*[!][ ]*doctype)":
      sed("Try 2: Memento API returned 0-length or invalid JSON data", Debug.network)
      if not Debug.network: 
        libutils.sleep(30)
      (jsonin, errC) = execCmdEx(command)
      if empty(jsonin) or jsonin ~ "(?i)([<][ ]*[!][ ]*doctype)":
        return diy_memento(url, did_is_check, tag)

  if jsonin ~ "^/bin/sh[:] 1[:] Syntax error":
    sed("(2) /bin/sh Syntax error for: " & command, Debug.network)
    sendlog(Project.syntaxerror, CL.name, command & " ---- (2)")
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
        if not isarchiveorg(muri) and not isarchiveis(muri) and muri ~ GX.shttp:
         
         if Runme.fixru and iswebcite(muri):
           continue
 
         if iswebcite(muri):
           q = awk.split(muri, p, "/")  # webcitation.org with a path < 5 characters is a broken URL
           if len(p[q - 1]) < 5:
             continue
           if not validate_webcite(url):
             continue
         else:
           if not isarchive(muri, "all"):
             sendlog(Project.syslog, CL.name, muri & " ---- " & "unrecognized archive service (2)")
             continue
           elif not validate_other(muri, "api"): # skip if page returns 0-length
             continue

         if not manual_soft404(muri) and not manual_soft404(urldecode(muri)) and not manual_soft404(url):
           WayLink[tag].altarch = urldecode(muri)
           if iswebcite(muri):                # longform URL per RfC 
             WayLink[tag].altarchencoded = uriparseEncodeurl(muri) & "?url=" & url
           else:
             WayLink[tag].altarchencoded = uriparseEncodeurl(muri) 
           WayLink[tag].altarchdate = mdate
           return "OK"

    # Query archive.is API directly if an archive.is exists in the Memento result which is often outdated but signals it might exist
    for i in split(snap):
      raw = fieldvalMO(MemLink, strip(i))
      if awk.split(raw, a, "[ ][|][ ]") == 2:
        muri = strip(a[0])
        mdate = strip(a[1])
        if isarchiveis(muri):
          if diy_memento_single("http://archive.is/timemap/", WayLink[tag].origurl, tag) == "OK":
            return "OK"
          else:
            did_is_check = true
          break  # only check once

#          if validate_archiveis(muri, "api"):
#            if not manual_soft404(muri):
#              if muri ~ "^[Hh][Tt][Tt][Pp][:]":
#                gsub("^[Hh][Tt][Tt][Pp][:]", "https:", muri)
#              WayLink[tag].altarch = muri   
#              WayLink[tag].altarchencoded = muri   # don't change encoding, .is uses whatever it says it has
#              WayLink[tag].altarchdate = mdate
#              return "OK"
 
  # last resort diy search             

  return diy_memento(url, did_is_check, tag)


#
# Create a timestamp to use based on accessdate retrieved from IABot API
#
# Not working because IABot API can't handle large number of requests freezes up
#
#proc createtimestamp(tag: int): string =

#  var
#    iabot,command = ""
#    errC, c = 0

#  if not dummydate(WayLink[tag].origdate):
#    if WayLink[tag].origdate != "none":
#      return WayLink[tag].origdate
#    else:
#      return ""
#  else:
#   command = "./iabget -a searchurldata -p \"urls=" & WayLink[tag].origurl & "\""
#   (iabot, errC) = execCmdEx(command)
#   if not empty(iabot):
#     c = awk.split(iabot, a, " ")
#     if c == 8:
#       gsubs("-", "", a[6])
#       a[6] = a[6] & "010101"
#       if len(a[6]) == 14:
#         return a[6]
#     else:
#       return WayLink[tag].origdate
#   else:
#     return WayLink[tag].origdate
    
#  return ""

#
# Create a file w/ API POST data.
#
#   API documentation: http://207.241.231.246:8120/usage (archived https://archive.is/6ZcDv)
#                      https://wwwb-app37.us.archive.org:8120/usage
#
proc createpostdata(postfile: string): bool {.discardable.} =

  var 
    request = ""
    ts = ""

  if existsFile(postfile):
    try:
      removeFile(postfile)
    except:
      "" >* postfile

  for tag in 0..GX.id:

    if WayLink[tag].origdate != "none" and WayLink[tag].origencoded != "none":
      ts = WayLink[tag].origdate
      request = "url=" & WayLink[tag].origencoded & "&closest=either&timestamp=" & ts & "&tag=" & $tag & "&statuscodes=200"      
    else:
      request = "url=" & WayLink[tag].origencoded & "&closest=either&timestamp=19700101&tag=" & $tag & "&statuscodes=200"      
    request >> postfile


#
# Create a JSON file containing empty (ie. unavailable) records for everything in postfile
#  This routes around intermitent problem with the API post method, and sets it up to allow for get method
#
proc createemptyjson(postfile: string): string =

  var s, ts, fp = ""

  s = "{\"results\": ["

  if existsFile(postfile):
    fp = readfile(postfile)
  else:
    return s

  awk.split(fp, sa, "\n")

  for i in 0..high(sa):
    match(sa[i], "&timestamp[=][0-9]{1,14}", ts)
    gsubs("&timestamp=", "", ts)
    gsubs("url=", "", sa[i])
    if awk.split(sa[i], sc, "&") > 0:
      if sc[0] ~ GX.shttp:
        s = s & "{\"url\": \"" & sc[0] & "\", \"timestamp\": \"" & ts & "\", \"archived_snapshots\": {}, \"tag\": \"" & $i & "\"}"
        if i != high(sa) - 1:
          s = s & ", "

  s = s & "]}"
  return s

#
# Fill WayLink[] with values        
#
proc fillway(tag: int, status, available, newiaurl, newurl: string, response: int, breakpoint: string): void =

  WayLink[tag].status = status
  WayLink[tag].available = available
  WayLink[tag].newiaurl = formatediaurl(newiaurl, "barelink")
  WayLink[tag].newurl = newurl
  WayLink[tag].response = response
  WayLink[tag].breakpoint = breakpoint

  if WayLink[tag].newiaurl != "none":          # Security check
    if not isarchiveorg(WayLink[tag].newiaurl):
      WayLink[tag].newiaurl = "none"
  if WayLink[tag].newurl == "":
    WayLink[tag].newurl = "none"


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
proc pageerror(body, url: string): string =

  var 
    c: int
    status = "none"

  c = awk.split(bodylead(body), a, "\n")

  for i in 0..c - 1:
    if a[i] ~ "(?i)(The machine that serves this file is down)":                                                   # archive.org and archive.is
      status = "bummer" 
      sendlog(Project.syslog, CL.name, " pageerror: The machine that serves this file is down ---- " & url)
    if a[i] ~ "(?i)(Page cannot be crawled or displayed due to robots[.]txt)" and not isarchiveis(url):            # archive.org only
      status = "robots"   
      sendlog(Project.syslog, CL.name, " pageerror: Page cannot be crawled or displayed due to robots.txt ---- " & url)
    if a[i] ~ "(?i)(Page can[ ]?not be displayed due to robots.txt)" and not isarchiveis(url):           
      status = "robots"   
      sendlog(Project.syslog, CL.name, " pageerror: Page cannot be displayed due to robots.txt ---- " & url)
    if a[i] ~ "(?i)(404[ ]{0,}[-][ ]{0,}Page cannot be found)":
      status = "404"
      sendlog(Project.syslog, CL.name, " pageerror: 404 - Page cannot be found ---- " & url)
    if a[i] ~ "(?i)(404[ ]{0,}[-][ ]{0,}File or directory not found)":
      status = "404"
      sendlog(Project.syslog, CL.name, " pageerror: 404 - File or directory not found ---- " & url)
    if a[i] ~ "(?i)(show[_]404)":
      status = "404"
      sendlog(Project.syslog, CL.name, " pageerror: show_404 ---- " & url)
    if a[i] ~ "(?i)(This URL has been excluded from the Wayback Machine)":             
      status = "excluded"    
      sendlog(Project.syslog, CL.name, " pageerror: This URL has been excluded from the Wayback Machine ---- " & url)
    if a[i] ~ "(?i)(Redirecting to[.][.][.])":
      status = "redirect"
      sendlog(Project.syslog, CL.name, " pageerror: Redirectings to... ---- " & url)
    if a[i] ~ "(?i)(This snapshot cannot be displayed due to an internal error)":
      status = "sorry"
      sendlog(Project.syslog, CL.name, " pageerror: This snapshot cannot be displayed due to an internal error ---- " & url)
    if a[i] ~ "(?i)(Wayback Machine doesn't have that page archived)":
      status = "notarchived"
      sendlog(Project.syslog, CL.name, " pageerror: Wayback Machine doesn't have that page archived ---- " & url)
    if a[i] ~ "(?i)(web[.]archive[.]org)" and a[i] ~ "(?i)(click here to proceed)":
      status = "clicktoproceed"
      sendlog(Project.syslog, CL.name, " pageerror: click here to proceed ---- " & url)

  return status

#
# Page is an IA info page of any kind.. (add more here as they are found)
#
proc iainfopage(body, url: string): bool =

  var c: int
  var status = false
  
  c = awk.split(bodylead(body), a, "\n")
  for i in 0..c - 1:
    if a[i] ~ "Your use of the Wayback Machine is subject to the Internet Archive":
      status = true
      sendlog(Project.syslog, CL.name, " iainfopage: Your use of the Wayback Machine is subject to the Internet Archive ---- " & url)
    if a[i] ~ "Redirecting to[.][.][.]":
      status = true
      sendlog(Project.syslog, CL.name, " iainfopage: Redirecting to... ---- " & url)
    if a[i] ~ "Click here to access the page to which you are being forwarded[.]":
      status = true    
      sendlog(Project.syslog, CL.name, " iainfopage: Click here to access the page to which you are being forwarded ---- " & url)
    if a[i] ~ "(?i)(Wayback Machine doesn't have that page archived)":
      status = true
      sendlog(Project.syslog, CL.name, " iainfopage: Wayback Machine doesn't have that page archived ---- " & url)
    if a[i] ~ "(?i)(This snapshot cannot be displayed due to an internal error)":
      status = true
      sendlog(Project.syslog, CL.name, " iainfopage: This snapshot cannot be displayed due to an internal error ---- " & url)
    if a[i] ~ "(?i)(This URL has been excluded from the Wayback Machine)":
      sendlog(Project.syslog, CL.name, " iainfopage: This URL has been excluded from the Wayback Machine ---- " & url)
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
proc iaredirect(body, url: string): bool =

  var c: int
  var status = false

  c = awk.split(bodylead(body), a, "\n")
  for i in 0..c - 1:
    if a[i] ~ "Got an HTTP 30[1-7]{1}[ ]response at crawl time":
      status = true
      sendlog(Project.syslog, CL.name, " iaredirect: Got an HTTP 301 response at crawl time ---- " & url)
    if a[i] ~ "Redirecting to[.][.][.]":
      status = true
      sendlog(Project.syslog, CL.name, " iaredirect: Redirecting to... ---- " & url)
    if a[i] ~ "Click here to access the page to which you are being forwarded[.]":
      status = true
      sendlog(Project.syslog, CL.name, " iaredirect: Click here to access the page to which you are being forwarded ---- " & url)
  return status


#
# See if HTML returned by headless request is OK (true) or not (false)
#
proc headlessok*(fp: string): bool =

  if len(fp) < 256 or fp ~ "(?i)([<]title[>][ ]*Page Load Error[ ]*[<][/]title[>])": # slimjs creates an error file about 1094 in length see /home/adminuser/phantomjs-2.1.1-linux-x86_64/bin/slimerror
    return false
  return true

#
# Given a URL and robots.txt file, return true if a JavaScript headless browser web-scrape validates it as a robots block
#
proc validate_robots(rfile, url: string): bool =

  let
    bodyfile = mktempname(GX.datadir & "wgetbody.")
    # putEnv("SLIMERJSLAUNCHER","/home/adminuser/firefox58/firefox") -- added to medicinit.nim
    #commandZombie  = "timeout 15m node /home/adminuser/phantomjs-2.1.1-linux-x86_64/bin/zombie.js '" & url & "' | head -c 100k > " & bodyfile
    commandPhantom = "timeout 15m /home/adminuser/phantomjs-2.1.1-linux-x86_64/bin/phantom.js '" & url & "' | head -c 100k > " & bodyfile
    commandFirefox = "timeout 15m /home/adminuser/node_modules/.bin/slimerjs --headless /home/adminuser/phantomjs-2.1.1-linux-x86_64/bin/slimsave.js '" & url & "' | head -c 100k > " & bodyfile
    #commandChrome  = "timeout 15m chrome --headless --disable-gpu --dump-dom --proxy-bypass-list= --proxy-server= --user-agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.50 Safari/537.36' '" & url & "' | head -c 100k > " & bodyfile

  var
    command = commandFirefox
    errS,fp = ""
    errC = 0

  if existsFile(rfile & ".BLOCKED"):
    return true
  elif existsFile(rfile & ".UNBLOCKED"):
    return false

  sed("Starting headless browser for " & url, Debug.network)
  (errS, errC) = execCmdEx(command)
  if existsFile(bodyfile):
    fp = readfile(bodyfile)
  else:
    (errS, errC) = execCmdEx(commandPhantom)
  if existsFile(bodyfile):
    fp = readfile(bodyfile)  
  sed("Ending headless browser (" & $len(fp) & ")", Debug.network)

  if not headlessok(fp):
    sed("Error: headless browser timeout", Debug.network)
    sendlog(Project.timeout, CL.name, getClockStr() & " ---- headless browser timeout ---- " & url)
    return false

  if pageerror(bodyfile, url) == "robots":
    "1" >* (rfile & ".BLOCKED")
    return true
  else:
    "1" >* (rfile & ".UNBLOCKED")

  return false

#
# Generate robots.txt storage filename based on domain name, accounting for Windows reserved filenames when using Windows drive
#  https://docs.microsoft.com/en-us/windows/desktop/FileIO/naming-a-file
#
proc fnres(whost: string): string =

  let
    re = "(?i)(^(CON|PRN|AUX|NUL|COM1|COM2|COM3|COM4|COM5|COM6|COM7|COM8|COM9|LPT1|LPT2|LPT3|LPT4|LPT5|LPT6|LPT7|LPT8|LPT9)[.])"
  var
    whost = whost

  if whost ~ re:
    awk.gsub(re, "", whost)
  return Project.robotsdir & whost  

#
# Is a given archive.org URL blocked by robots? 
#
#  If blocked return "true" otherwise return "false"
#
proc isiarobots(url: string): bool =

  var
    wurl,whost,fn,newurl,command,robotstxt,notblocked = ""
    errC = 0
    robexist: bool

  if not isarchiveorg(url):
    return false

  wurl = wayurlurl(url)
  whost = uriparseElement(wurl, "hostname")
  fn = fnres(quote(whost))

  if not empty(wurl) and not empty(whost):

    robexist = existsFile(fn)

    if robexist and getFileSize(fn) < 10:
      sed("Not blocked by robots? true (empty file exists)", Debug.network)
      return false

    if not robexist:
      # newurl = "https://web.archive.org/web/" & todaysdateymd() & "010101/" & whost & "/robots.txt"
      newurl = "http://" & whost & "/robots.txt"
      sed("Checking " & newurl, Debug.network)

      # wget doesn't work for some sites (spider blocks?). Using Lynx
      # command = "timeout 30s wget" & GX.wgetopts & "-O- -q " & shquote(newurl)
      command = "timeout 30s lynx " & GX.agentlynx & " --dump " & shquote(newurl)
      (robotstxt, errC) = execCmdEx(command)

      if len(robotstxt) < 10:
        robotstxt = ""
      # As of July 2018, Wayback only honors 'User-agent: ia_archiver' and robotsparser.js will honor 'User-agent: *' if it can't find ia_archiver, so we hack around this by explicit allow of ia_archiver
      if not empty(robotstxt) and robotstxt !~ "(?i)(User[-]agent[:][ ]*ia_archiver)":  
        # robotstxt = robotstxt & "\n\n" & "User-agent: ia_archiver\nAllow: /\n"
        robotstxt = ""
      robotstxt >* fn
      if empty(robotstxt):
        sed("Not blocked by robots? true (missing ia_archiver)", Debug.network)
        return false

    command = "node " & GX.home & "robotsparser.js " & shquote(fn) & " " & shquote(urldecode(url))

    (notblocked, errC) = execCmdEx(command) 
    notblocked = strip(notblocked)

    sed("Not blocked by robots? " & notblocked & " (node result)", Debug.network)

    if errC == 0:
      if notblocked == "true":
        return false
      elif notblocked == "false":  # URL is possibly blocked by robots.txt
        if validate_robots(fn, url):
          return true
        sed("robots.txt block not found during headless browser check", Debug.network)
        sendlog(Project.syslog, CL.name, url & " ---- robots.txt block not found during headless browser check")

  return false

#
#   Return web page status.
#
#   Return 1 if 2XX
#   Return 0 if 4xx etc..
#   Return -1 if timeout.
#   Return actual status code if flag="code"
#   If checking status of a page in which the API said 404 (or missing), set flag="404" to avoid false positives
#
proc webpagestatus(url: string, fl: varargs[string]): tuple[m:int, z:int] =

  var url = strip(url)
  var returnval = 0
  var responsecode, status, response = -1
  var head, flag, bodyfilename, pe, redirurl = ""

  if len(fl) > 0:
    flag = fl[0]
  else:
    flag = ""

 # scrape and parse robots.txt
  if isiarobots(url):
    result[0] = 0
    result[1] = 4031
    return

  (head, bodyfilename) = getheadbody(url, flag)

  # Check non-archive URLs for a redirect to the base domain name eg. http://www.bbgv.org/download.pdf -> http://www.bbgv.org
  # Needed so in-sync with policy of IABot's dead-link-checker
  if not isarchive(url, "all"):
    if awk.match(head, "(?i)[\\n][ ]*location[ ]*[:][^\n]*[^\n]?", dest) > 0:
      dest = strip(dest)
      gsub("(?i)^location[ ]*[:][ ]*","",dest)
      if dest ~ GX.shttp:
        gsub("/$", "", url)
        gsub("/$", "", dest)
        if empty(uriparseElement(dest, "path")) and not empty(uriparseElement(url, "path")):
          result[0] = 0
          result[1] = 301
          return

  responsecode = headerresponse(head)

  if empty(head) or responsecode == -1:
    sed("Headers time out", Debug.network)
    sendlog(Project.timeout, CL.name, getClockStr() & " ---- headers:" & url)
    returnval = -1

  if head ~ "^/bin/sh[:] 1[:] Syntax error":
    sed("(3) /bin/sh Syntax error for: " & url, Debug.network)
    sendlog(Project.syntaxerror, CL.name, url & " ---- (3)")
    returnval = -1

  elif responsecode != -1:
    if responsecode > 199 and responsecode < 300:

      if iaredirect(bodyfilename, url):
        flag = "404"

      #se("iainfopage = " & $iainfopage(bodyfilename))
      #se("iaredirect = " & $iaredirect(bodyfilename))
      #se("getredirurl = " & getredirurl(url, bodyfilename))

      if iainfopage(bodyfilename, url) and flag ~ "404":
        if iaredirect(bodyfilename, url) and GX.redirloop == 0:                # 302 redirect page .. follow it and verify header
          GX.redirloop = 1
          redirurl = getredirurl(url, bodyfilename)
          if awk.split(wayurlurl(redirurl), a, "[/]") == 4 and awk.split(wayurlurl(url), b, "[/]") != 4:
            returnval = 0
            GX.redirloop = 0
          elif redirurl ~ GX.shttp:
            (status, response) = webpagestatus(redirurl)
            if status == 1:                                           # recursive call
              sed("Found a working redirect: " & redirurl, Debug.network)
              (url & " -->-- " & redirurl) >> GX.datadir & "302redirs"
              returnval = 3
              responsecode = 200
              GX.redirloop = 0                                        # Global flag to stop endless loop
            else:
              returnval = 0
              responsecode = response
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
        (status, response) = webpagestatus(url)
        if status == 1:                                           # recursive call
          GX.unavailableloop = 0
          returnval = 1
          responsecode = 200
        else:
          GX.unavailableloop = 0
          returnval = 0
          responsecode = response
      elif isarchiveorg(url) and GX.unavailableloop == 1:
        result[0] = 0
        result[1] = -1
        return
      else:      
        returnval = 5
        responsecode = 503

    elif responsecode == 417: 
      sed("417 bot rate limit exceeded / cache busting detected", Debug.network)
      returnval = 0

    elif responsecode == 400: 
      sed("400 Invalid URI: noSlash", Debug.network)
      responsecode = 400
      returnval = 4

    # Sometimes a robots.txt block only shows up in the header not the body
    if responsecode == 403:
      if head ~ "(?i)(RobotAccessControlException[ ]*[:][ ]*Blocked By Robots)":
        var locationurl = headerlocation(head, "fullurl", "alltypes")
        if locationurl !~ "archive[.]org[/]save[/]":           # skip if a "Save this page" page
          sed("RobotAccessControlException", Debug.network)
          returnval = 0
          responsecode = 4031
          sendlog(Project.robotstxt, CL.name, url & " ---- RobotAccessControlException")
        else:
          returnval = 0
          responsecode = 4031
      #if head ~ "(?i)(AdministrativeAccessControlException[ ]*[:][ ]*Blocked Site Error)":
      #  returnval = 0
      #  responsecode = 403

   # Sometimes reports 200 but is actually a "Save this URL on the Wayback Machine" page
    if responsecode == 200:
      var locationurl = headerlocation(head, "fullurl", "alltypes")
      if locationurl ~ "archive[.]org[/]save[/]":
        sed("Save this URL on the Wayback Machine", Debug.network)
        returnval = 0
        responsecode = 404
        sendlog(Project.bogusapi, CL.name, url & " ---- Save this URL on the Wayback Machine")
       
    pe = pageerror(bodyfilename, url)

    if pe == "bummer":
      sed("Bummer page", Debug.network)
      sendlog(Project.bummer, CL.name, url & " ---- bummer")
      returnval = 1                               # Treat as a 200 response
      responsecode = 2001
    elif pe == "sorry":
      sed("Sorry. This snapshot cannot be displayed due to an internal error.", Debug.network)
      sendlog(Project.bummer, CL.name, url & " ---- sorry")
      returnval = 1                               # Treat as a 200 response
      responsecode = 500
    elif pe == "robots" and responsecode != 4031: # Already detected in header above
      sed("Page cannot be crawled or displayed due to robots.txt", Debug.network)
      returnval = 0
      responsecode = 4031                       
      sendlog(Project.robotstxt, CL.name, url & " ---- pageerror")
    elif pe == "excluded":
      sed("This URL has been excluded from the Wayback Machine", Debug.network)
      returnval = 0
      responsecode = 403
    elif pe == "404":
      sed("title:og header says 404 not found", Debug.network)
      returnval = 0
      responsecode = 404
    elif pe == "notarchived":
      sed("Hrm. Wayback Machine doesn't have that page archived.", Debug.network)
      returnval = 0
      responsecode = 404
    elif pe == "notarchived":
      sed("Frame: Click here to proceed", Debug.network)
      sendlog(Project.bummer, CL.name, url & " ---- Click here to proceed")
      returnval = 0
      responsecode = 404
    elif pe == "redirect" and returnval != 3:    # Only return this code if a double redirect (see recursive action above)
      sed("Double redirect.. ", Debug.network)
      sed("Return value " & $returnval, Debug.network)
      returnval = 0
      responsecode = 3021

  if not Debug.wgetlog:                     # delete wget.* files unless: Debug, or recursive call, or gx.imp
    if existsFile(bodyfilename) and GX.unavailableloop == 0 and GX.redirloop == 0 and empty(GX.imp):
      for file in walkFiles(GX.datadir & "wget*"):
        try:
          removeFile(file)
        except:
          continue

  result[0] = returnval
  result[1] = responsecode
  return


#
# Query API via GET method. Return a working IA URL or "none". Returns a 3-item tuple
#
#   result[0] = url
#   result[1] = status
#   result[2] = response
#
#  Wayback API: https://archive.org/help/wayback_api.php (old)
#               http://207.241.231.246:8120/usage (archived https://archive.is/6ZcDv)
#
proc queryapiget(url, timestamp: string): tuple[url: string, status: int, response: int] =

  let 
    tries = 3
  var 
    url = url
    urlapi, japi, japi2, urllog = ""
    j = 1
    errC1, errC2 = 0
    status, response = -1

 # default return 
  result[0] = "none"
  result[1] = -1
  result[2] = -1

  if url !~ GX.shttp:
    return result

  urllog = url
  if url ~ "[&]":
    gsub("[&]", "%26", url)

  urlapi = url & "&tag=1&closest=either&statuscodes=200&timestamp=" & timestamp

  let wgetapi = "timeout 5m wget" & GX.wgetopts & "--header=\"Wayback-Api-Version: 2\" --post-data=\"url=" & urlapi & "\" -q -O- " & shquote("http://archive.org/wayback/available")
 
  while j <= tries:

    japi = ""
    japi2 = ""

    sed("Starting API (get) (" & $(j) & ") for " & urlapi, Debug.network)

    (japi, errC1) = execCmdEx(wgetapi)
    if japi ~ "Error[:] no POST data":    # API bug intermittent. Treat as empty result.
      japi = ""
    libutils.sleep(2)
    (japi2, errC2) = execCmdEx(wgetapi)
    if japi2 ~ "Error[:] no POST data":  
      japi2 = ""

    sed("Ending API (get) (" & $len(japi) & "|" & $len(japi2) & ")", Debug.network)

    if( (empty(japi) or empty(japi2) ) and j != tries ):        # Problem retrieving API data, try again.
      libutils.sleep(2)
      j.inc
    elif j == tries:
      if empty(japi) and empty(japi2):
        sed("IA API (get) time out?", Debug.network)
        sed(wgetapi, Debug.network)
        sendlog(Project.timeout, CL.name, getClockStr() & " ---- " & urllog & " ---- queryapiget")
        return result 
      else:
        if len(japi2) > len(japi):
          japi = japi2
        japi >> GX.datadir & "japi-get.orig"
        break
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
    sed("(4) /bin/sh Syntax error for: " & wgetapi, Debug.network)
    sendlog(Project.syntaxerror, CL.name, wgetapi & " ---- (4)")
    return result

  if Debug.network: japi >> GX.datadir & "japi-get." & uriparseElement(url, "hostname")

  var newurl = japi2singleurl(japi)
  if newurl != "none" and newurl !~ "(?i)robots[.]txt$":             # Bug in API sometimes returns robots.txt file
    (status, response) = webpagestatus(newurl)
    result[1] = status
    result[2] = response
    if status == 1 or status == 3:
      gsub("^[Hh][Tt][Tt][Pp][Ss]?[:]", "https:", newurl)     # Convert to https
      result[0] = newurl      
    elif status == 5:
      sed("Step queryapiget: 503 SERVERS DOWN.", Debug.network)
      sendlog(Project.critical, CL.name, " 503_servers_down queryapiget")

  return result


#
# Check if it's time to recheck cannary URL or API 
#  Divide current second by CL.interval and if remainder is 0 return true
#
proc heartbeat(myInterval: string): bool =

    if CL.debug ~ "[y]|[Y]":  # Don't check while debugging.
      return false

    if empty(GX.imp):         # Always true if non-IMP
      return true

    var
      interval: float32
    interval = float32(parseInt(myInterval))

    if awk.split(getClockStr(), sec, "[:]") > 2:
      if awk.split($(float32(parseInt(sec[2])) / interval), rem, "[.]") > 1:
        if $rem[1] == "0":
          return true

    return false


#
# Do a wayback machine health check and return false if it's down
#  Only check once every [CL.interval] seconds (via heartbeat())
#
proc urlcannary(): bool =

    var 
      status, response = -1
      canurl = "https://web.archive.org/web/19961223105317/http://www.feedmag.com/"

    # Check a known working "canary" URL and abort if dead.
    if heartbeat(CL.interval):
      # sendlog(Project.syslog, CL.name, " heartbeat urlcannary")
      status = headerresponse(gethead(canurl, "one"))
      if status != 200:
        libutils.sleep(10)
        (status, response) = webpagestatus(canurl)
        if status != 1:    
          libutils.sleep(10)
          (status, response) = webpagestatus(canurl)
          if status != 1:
            return false

    return true

#
# Do an API health check and return false if it's down
#  Only check once every [CL.interval] seconds (via heartbeat())
#
proc apicannary(): bool =

    if CL.debug ~ "[y]|[Y]":  # Don't check while debugging.
      return true

    var 
      errC1 = 0
      japi, wgetapi = ""

    if heartbeat(CL.interval):
      # sendlog(Project.syslog, CL.name, " heartbeat apicannary")
      sed("Starting API Cannary (try 1)", Debug.network)
      wgetapi = "timeout 5m wget --header='Wayback-Api-Version: 2' --post-data='url=http%3A%2F%2Fwww%2Ethexfiles%2Ecom%2Fepisodes%2Fseason2%2F2x19%252Ehtml&closest=before&statuscodes=200&tag=&timestamp=20100101' -q -O- 'http://archive.org/wayback/available'"
      (japi, errC1) = execCmdEx(wgetapi)      
      if japi ~ "Error[:] no POST data":    # API bug intermittent. Treat as empty result.
        japi = ""
      if empty(japi):
        sed("Starting API Cannary (try 2)", Debug.network)
        libutils.sleep(5)
        (japi, errC1) = execCmdEx(wgetapi)
        if japi ~ "Error[:] no POST data":    
          japi = ""
        if empty(japi):
          sed("Starting API Cannary (try 3)", Debug.network)
          libutils.sleep(15)
          (japi, errC1) = execCmdEx(wgetapi)
          if japi ~ "Error[:] no POST data":    
            japi = ""
          if empty(japi):
            sed("Starting API Cannary (try 4)", Debug.network)
            libutils.sleep(25)
            (japi, errC1) = execCmdEx(wgetapi)
            if japi ~ "Error[:] no POST data":   
              japi = ""
            if empty(japi):
              sed("API Cannary time out", Debug.network)
              return false
      sed("Ending API Cannary", Debug.network)

    return true


# Include waytree.nim
include waytree


#
# Query Wayback API via POST method and and load answers into WayLink[]
#
#  Assumes process_article("getlinks", "xyz") has previously run loading WayLink.origiaurl, origurl, and origdate from Wikipedia article.
#
proc queryapipost(internalcount: int): bool =

  var 
    tries = 3
    j = 1
    errC1, errC2 = 0
    japi, japi2 = ""

  if not apicannary():
    sendlog(Project.critical, CL.name, " IA API down")
    return false

  let postfile = GX.datadir & "postfile"
  createpostdata(postfile)

  let wgetapi = "timeout 10m wget" & GX.wgetopts & "--header=\"Wayback-Api-Version: 2\" --post-file=\"" & postfile & "\" -q -O- " & shquote("http://archive.org/wayback/available")

  if internalcount > 0:

    while j <= tries:

      japi = ""
      japi2 = ""

      sed("Starting API (try " & $j & ")", Debug.network)
      
      (japi, errC1) = execCmdEx(wgetapi)
      if japi ~ "Error[:] no POST data":    # API bug intermittent. Treat as empty result.
        japi = ""

     # get API twice
      if not empty(GX.imp):
        if contains(japi, "\"archived_snapshots\": {}"):
          libutils.sleep(2)
          (japi2, errC2) = execCmdEx(wgetapi)
        else:
          japi2 = japi   # Only need to get once if the first is OK
          errC2 = errC1
      else:
        libutils.sleep(2)
        (japi2, errC2) = execCmdEx(wgetapi)
        if japi2 ~ "Error[:] no POST data":    # API bug intermittent. Treat as empty result.
          japi2 = ""

      sed("Ending API (" & $len(japi) & "|" & $len(japi2) & ")", Debug.network)

      if( (empty(japi) or empty(japi2) ) and j != tries ):        # Problem retrieving API data, try again.
        j.inc
      elif j == tries:                                                 # Sometimes API returns blank (0-length json) on large postloads. 
        if empty(japi) and empty(japi2):
          sed("IA API time out?", Debug.network)                       #  create a placeholder json file and punt upstream to get method
          sendlog(Project.timeout, CL.name, getClockStr() & " ---- queryapi")
          japi = createemptyjson(postfile)
          japi >* GX.datadir & "japi.orig"
          break
        else:
          if len(japi2) > len(japi):
            japi = japi2
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
      sed("(5) /bin/sh Syntax error for: " & wgetapi, Debug.network)
      sendlog(Project.syntaxerror, CL.name, wgetapi & " ---- (5)")
      return false

    var apicount = japi2waylink(japi)

    sed("\nAPI found " & $apicount & " records vs. " & $internalcount & " internal count records.", Debug.api)

    if apicount < internalcount:
      sendlog(Project.apimismatch, CL.name, $internalcount & "|" & $apicount)

    " " >* GX.datadir & "waylink.start"
    " " >* GX.datadir & "waylink.end"
    " " >* GX.datadir & "302redirs"

    if not urlcannary():
      sendlog(Project.critical, CL.name, " 503_servers_down Z1 ----" & "CANARY URL DEAD")
      return false

    # waytree.nim
    return waytree(apicount)

  else:
    sendlog(Project.critical, CL.name, " Unknown_Internal_Count")
    return false

  return false

