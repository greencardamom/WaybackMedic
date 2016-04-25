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
# Log (append) a line in a database
#
#  If you need more than 2 columns (ie. name|msg) then format msg with separators in the string itself.
#    If flag="noclose" don't close the file (flush buffer) after write. Useful when making many
#      concurrent writes, particularly running under GNU parallel.
#    If flag="space" use space as separator
#
proc sendlog*(database, name, msg: string): bool {.discardable.} =

  var safed = database
  var safen = name
  var safem = msg
  var sep = "----"
  gsub("\"","\42",safed)
  gsub("\"","\42",safen)
  gsub("\"","\42",safem)

  if(len(safem) > 0):
    safen & sep & safem >> database 
  else:
    safen >> database

#
# Today's date ie. "March 2016"
#
proc todaysdate(): string =
  return format(parse(getDateStr(), "yyyy-MM-dd"), "MMMM yyyy")

#
# Determine date type - set global Datetype = dmy or mdy
#   Search for {{use dmy dates..} or {{use mdy dates..}
#   default mdy
#
proc setdatetype() =

  var articlec = splitawk(GX.article, articles, "\n")

  for i in 0..articlec - 1:
    if articles[i] ~ "[{]{0,}[{][ ]{0,}[Uu]se [Dd][Mm][Yy] [Dd]ates":
      GX.datetype = "dmy"
      break
    if articles[i] ~ "[{]{0,}[{][ ]{0,}[Uu]se [Mm][Dd][Yy] [Dd]ates":
      GX.datetype = "mdy"
      break

#
# Given an alt archive website url (eg. archive.is, webcite.org etc)
#  return the field value designated by "field" argument
#
proc altarchfield(url, field: string): string =
  for link in WayLink:
    if countsubstring(link.altarch, url) > 0:
      return fieldvalLO(link, field)
  return ""


#
# Given a url, return its archival service name in wikisource markup.
#
proc servicename*(url: string): string =

  var oout = "(Unknown)<!--bot generated title-->"
  var safe = url
  gsub("^https?[:]//","",safe)

  if match(safe,"archive[.]today") > 0:
    oout = "[[Archive.is]]"

  elif match(safe,"archive[.]is") > 0:
    oout = "[[Archive.is]]"

  elif match(safe,"archive[.]org") > 0:
    oout = "[[Internet Archive]]"

  elif match(safe,"archive[-]it") > 0:
    oout = "[[Archive-It]]"

  elif match(safe,"bibalex[.]org") > 0:
    oout = "[[Bibliotheca_Alexandrina#Internet_Archive_partnership|Bibliotheca Alexandrina]]"

  elif match(safe,"collectionscanada") > 0:
    oout = "Canadian Government Web Archive"

  elif match(safe,"haw[.]nsk") > 0:
    oout = "the Croatian Web Archive (HAW)"

  elif match(safe,"nlib[.]ee") > 0:
    oout = "the Estonian Web Archive"

  elif match(safe,"vefsafn[.]is") > 0:
    oout = "the Icelandic Web Archive"

  elif match(safe,"loc[.]gov") > 0:
    oout = "the [[Library of Congress]]"

  elif match(safe,"webharvest[.]gov") > 0:
    oout = "the [[National Archives and Records Administration]]"

  elif match(safe,"arquivo[.]pt") > 0:
    oout = "the [[Portugese Web Archive]]"

  elif match(safe,"proni[.]gov") > 0:
    oout = "the [[Public Record Office of Northern Ireland]]"

  elif match(safe,"uni[-]lj[.]si") > 0:
    oout = "the Slovenian Web Archive"

  elif match(safe,"stanford[.]edu") > 0:
    oout = "the [[Stanford University Libraries|Stanford Web Archive]]"

  elif match(safe,"nationalarchives[.]gov[.]uk") > 0:
    oout = "the [[UK Government Web Archive]]"

  elif match(safe,"parliament[.]uk") > 0:
    oout = "the UK Parliament's Web Archive"

  elif match(safe,"webarchive[.]org[.]uk") > 0:
    oout = "the UK Web Archive"

  elif match(safe,"nlb[.]gov[.]sg") > 0:
    oout = "Web Archive Singapore"

  elif match(safe,"webcitation[.]org") > 0:
    oout = "[[WebCite]]"

  if oout ~ "Unknown":
    sendlog(Project.servicename, CL.name, url)

  return oout

#
# Build a cite web template given url (required), date (optional)
#
proc buildciteweb*(url: string, title: varargs[string]): string =

  var ntitle = ""

  if title.len == 0:
    ntitle = "|title=Unknown"
  else:
    if title[0] == nil:
      ntitle = "|title=Unknown"
    else:
      ntitle = "|title=" & title[0]

  return "{{cite web |url=" & url & " " & ntitle & " |dead-url=yes |accessdate=" & todaysdate() & "}}"

#
# Given a citation template, return the archivedate in timestamp format (YYYYMMDD) (not including archivedate=)
#  . if unable to parse a given date, return 19700101
#  . if archivedate is blank or missing, return ""
#
proc getargarchivedatestamp*(tl: string): string =
  var k, safe = ""
  if tl ~ "archive[-]{0,1}url[ ]{0,}=":
    match(tl, "archive[-]{0,1}date[ ]{0,}=[^|}]*[^|}]", k)
    safe = stripwikicomments(k)
    if safe.len > 15:
      gsub("archive[-]{0,1}date[ ]{0,}=", "", safe)
      let cmd = "date --date=\"" & safe & "\" +'%Y%m%d'"            # date (GNU coreutils) 8.21
      let (outp, errC) = execCmdEx(cmd) 
      if errC == 0:
        return strip(outp)
      else:
        return "19700101"
  return ""


#
# Given a timestamp, return in Datetype format (dmy or mdy).
#
proc timestamp2date(dateinput: string): string =

  if dateinput !~ "^[0-9]{8}$":
    return dateinput
  var parseddate = parse(dateinput, "yyyyMMdd") # Check for invalid data 
  if $parseddate ~ "[?][?][?]":
    return dateinput

  var newdate = ""

  if GX.datetype == "dmy":
    newdate = format(parse(dateinput, "yyyyMMdd"), "d MMMM yyyy")
  else:
    newdate = format(parse(dateinput, "yyyyMMdd"), "MMMM d, yyyy")

  if newdate.len > 0:
    return newdate
  else:
    return ""

  return ""

#
# Given a archive.org url, return its datestamp in Datetype format (dmy or mdy). Return includes "archivedate="
#  Otherwise, return curdate
#  eg. 20080101 -> January 1, 2008 (if global Datetype=mdy)
#
proc urldate(url, curdate: string): string =

  var dateinput = ""
  var re = "^web$"

  if curdate == nil: 
    var curdate = ""
  if url == nil: 
    return curdate

  var c = splitawk(url, a, "/")   
  for i in 0..c - 1:
    if a[i] ~ re and i != c - 1:

      dateinput = substr(a[i+1], 0, 3) & substr(a[i+1], 4, 5) & substr(a[i+1], 6, 7)

      if dateinput !~ "^[0-9]{8}$":
        return curdate
      var parseddate = parse(dateinput, "yyyyMMdd") # Check for invalid date
      if $parseddate ~ "[?][?][?]":
        return curdate

      if GX.datetype == "dmy":
        var newdate = format(parse(dateinput, "yyyyMMdd"), "d MMMM yyyy")
        if newdate.len > 0:
          return "archivedate=" & newdate
      else:
        var newdate = format(parse(dateinput, "yyyyMMdd"), "MMMM d, yyyy")
        if newdate.len > 0:
          return "archivedate=" & newdate

  return curdate


#
# Given a citation or wayback template, return the url= argument
#  if command = "full" also include the "url=" portion retaining original spacing
#
proc getargurl(tl: string, comm: varargs[string]): string =

  var k, safe, command = ""

  if comm.len > 0:
    command = comm[0]

  match(tl, "[|][ ]{0,}[Uu][Rr][Ll][ ]{0,}=[^|}]*[^|}]", k)
  safe = stripwikicomments(k)
  if safe.len > 10 and safe[0] == '|':
    if command == "full":
      gsub("^[|][ ]{0,}", "", safe)
      return safe
    else:
      gsub("^[|][ ]{0,}[Uu][Rr][Ll][ ]{0,}=[ ]{0,}","",safe)
      return strip(safe)

  return ""

#
# Given a citation template, return the archiveurl or archivedate (including the "archiveurl=" or "archivedate=" )
#  tl = template contents string
#  arg = argument to return (deadurl|url|date)
#  magic = "bar" (include the leading "|" in return string)
#        = "clean" don't include the "archiveurl=" portion just the field value
#  N.B. wiki comments (<!-- -->) are removed from the returned string
#
proc getargarchive*(tl, arg: string, mag: varargs [string]): string =

  var debug = false

  var tl = tl
  var magic, subre, re, k, s = ""

  if mag.len > 0: 
    if mag[0] == "bar":
      magic = "bar"
    if mag[0] == "clean":
      magic = "clean"
    if mag[0] == nil:
      magic = ""

  if arg == "url":
    subre = "archive[-]{0,1}url"
  elif arg == "date":
    subre = "archive[-]{0,1}date"
  elif arg == "dead":
    subre = "dead[-]{0,1}url"
  else:
    return tl

  if magic == "bar":
    re = "[|][ ]{0,}" & subre & "[ ]{0,}=[^|}]*[^|}]"            # Field has content
  else:
    re = subre & "[ ]{0,}=[^|}]*[^|}]"    

  if match(tl, re, k) > 0:
    if magic == "clean":
      re = subre & "[ ]{0,}[=][ ]{0,}"
      gsub(re, "", k)
      return stripwikicomments(k)
    else:
      return stripwikicomments(k)
  
  if magic == "bar":
    re = "[|][ ]{0,}" & subre & "[ ]{0,}=[ ]{0,}[|}]"            # Field is empty
  else:
    re = subre & "[ ]{0,}=[ ]{0,}[|}]"

  if match(tl, re, k) > 0:            # right side of = is blank
    if magic == "clean":
      return ""
    s = substrawk(strip(k), 0, len(strip(k)) - 1)

    if debug: "s = " & s >* "/dev/stderr"

    return stripwikicomments(s)
  
  return ""

#                  
# Remove deadurl, archiveurl & archivedate from template and add {{cbignore}} and {{dead link}}
#
#  flag="nocbignore" means don't add it
#                  
proc removearchive(tl, caller: string, fl: varargs[string]): string =

  var debug = false

  var tl = tl
  var flag = ""
  if len(fl) > 0:
    if fl[0] == nil:
      flag = ""
    else:
      flag = fl[0]

  if debug: "removearchive (0) = " & caller >* "/dev/stderr"
  if debug: "removearchive (1) = " & tl >* "/dev/stderr"
  tl = replacetext(tl, getargarchive(tl, "dead", "bar"), "", caller)
  if debug: "removearchive (2) = " & tl >* "/dev/stderr"
  tl = replacetext(tl, getargarchive(tl, "url", "bar"), "", caller)
  if debug: "removearchive (3) = " & tl >* "/dev/stderr"
  tl = replacetext(tl, getargarchive(tl, "date", "bar"), "", caller)
  if debug: "removearchive (4) = " & tl >* "/dev/stderr"
  if flag == "nocbignore":
    tl = tl & "{{dead link|date=" & todaysdate() & "|bot=medic}}"
  else:
    tl = tl & "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"
  if debug: "removearchive (5) = " & tl >* "/dev/stderr"
  sendlog(Project.cbignore, CL.name, "removearchive1")
  return tl

#
# Return true if ref (or string) contains {{cbignore}} template.
#  Does not look outside <ref></ref> pair
#
proc cbignore*(s: string): bool =
  if toLower(s) !~ "cbignore":
    return false
  return true

#
# Return true if same "\n" separarted line in article matching "lk" contains {{cbignore}} template.
#  Does not look beyond the line break
#  Pass copy of the article you want to check (such as ArticleWork)
#
proc cbignorebareline*(article, lk: string): bool =
  var c = splitawk(article, a, "\n")
  for i in 0..c - 1:
    if countsubstring(a[i], lk) > 0:
      if tolower(a[i]) ~ "cbignore":
        return true
  return false

#
# Return true if same "\n" separarted line in article matching "lk" contains {{dead linl}} template.
#  Does not look beyond the line break
#  Pass copy of the article you want to check (such as ArticleWork)
#
proc deadlinkbareline*(article, lk: string): bool =
  var c = splitawk(article, a, "\n")
  for i in 0..c - 1:
    if countsubstring(a[i], lk) > 0:
      if tolower(a[i]) ~ "{{[ ]{0,}[Dd]ead link[ ]{0,}":
        return true
  return false

#
# Return 0 if ref is not WP:BUNDELED (ie. more than one cite inside a <ref></ref>)
#  Only works if ref contains "archiveurl=" and/or "wayback|" otherwise return 4
#
proc bundled*(s: string): int =

  var c = splitawk(s, a, "archive[-]{0,1}url[ ]{0,}=")
  if c > 2: 
    return 2
  var d = splitawk(s, a, "[Ww]ayback[ ]{0,}[|]")
  if d > 2: 
    return 3

  if c < 2 and d < 2:
    return 4

  return 0

#
# Given an archive.org URL, return the date stamp portion
#  https://archive.org/web/20061009134445/http://timelines.ws/countries/AFGHAN_B_2005.HTML ->
#   20061009134445
#
proc urltimestamp*(url: string): string =
  
  var c = splitawk(url, a, "/")
  for i in 0..c - 1:
    if a[i].len > 0:
      if a[i] ~ "^web$":
        return a[i + 1]
      if a[i] ~ "^[0-9*?]*$":   
        return a[i] 
  return "" 

#               
# Given an archive.org URL, return the original url portion
#  http://archive.org/web/20061009134445/http://timelines.ws/countries/AFGHAN_B_2005.HTML ->
#   http://timelines.ws/countries/AFGHAN_B_2005.HTML
#
proc wayurlurl*(url: string): string =
  var date = urltimestamp(url)
  if date.len > 0:
    var inx = index(url, date)
    if inx >= 0:
      return removesection(url, 0, inx + len(date), "wayurlurl")
  return url

#
# Return true if URL is for archive.org 
#
proc isarchiveorg*(url: string): bool =
  var safe = url
  gsub("^https?[:]//", "", safe)  
  gsub("^web[.]|^www[.]|^wayback[.]", "", safe)
  if safe ~ "^archive[.]org":
    if urltimestamp(safe) !~ "[*|?]":
      return true
  return false

#
# Given a wayback template, return the title, date or url arg content (not including arg=)
#  tl = contents of template
#  arg = "url" or "date" or "title"
#
proc getargwayback*(tl, arg: string): string =

  var re = "[|][ ]{0,}" & arg & "[ ]{0,}=[^|}]*[^|}]"   # If field exists and has content
  var k, safe = ""
  match(tl, re, k)                 
  safe = stripwikicomments(k)     
  if len(safe) > 0 and safe[0] == '|': 
    re = "^[|][ ]{0,}" & arg & "[ ]{0,}=[ ]{0,}"
    gsub(re,"",safe)
    return strip(safe)

  return ""

#
# formatediaurl(string, cat)
#  cat = cite|wayback|bareurl
#
# Re-format IA URL into a regular format
#
proc formatediaurl*(tl, cat: string): string =

  var url, newurl, ttl = ""
  var tl = tl  

  if cat == "cite":
    if tl ~ "archive[-]{0,1}url[ ]{0,}=[ ]{0,}web":
      sub("archive[-]{0,1}url[ ]{0,}=[ ]{0,}web","archiveurl=https://web",tl)
    if tl ~ "archive[-]{0,1}url[ ]{0,}=[ ]{0,}wayback":
      sub("archive[-]{0,1}url[ ]{0,}=[ ]{0,}wayback","archiveurl=https://web",tl)
    if tl ~ "archive[-]{0,1}url[ ]{0,}=[ ]{0,}archive":
      sub("archive[-]{0,1}url[ ]{0,}=[ ]{0,}archive","archiveurl=https://web.archive",tl)
    url = getargarchive(tl, "url", "clean")
    newurl = formatediaurl(url, "barelink")   # recurse
    if countsubstring(url, newurl) < 1:
      tl = replacetext(ttl, url, newurl, "formatediaurl1")
      return strip(tl)

    return strip(tl)

  if cat == "wayback":
    if tl !~ "[|][ ]{0,}url[ ]{0,}=[ ]{0,}[Hh][Tt][Tt][Pp]" and tl !~ "[|][ ]{0,}url[ ]{0,}=[ ]{0,}[}|]" and tl ~ "[|][ ]{0,}url[ ]{0,}=":
      sub("[|][ ]{0,}url[ ]{0,}=[ ]{0,}","|url=http://",tl)
      return strip(tl)

  if cat == "barelink":
    if tl ~ "^https?[:]//archive":
      gsub("^https?[:]//archive", "https://web.archive", tl)
    elif tl ~ "^https?[:]//w[we][wb][.]archive":
      gsub("^http[:]//w[we][wb][.]archive", "https://web.archive", tl)
    elif tl ~ "^http[:]//wayback[.]archive":
      gsub("^http[:]//wayback[.]archive", "https://web.archive", tl)
    sub("[:]80/","/",tl)
    if tl ~ "^https[:]//web.archive.org/[0-9]{1,14}/":      # Insert /web/ into path if not already
      var a, c = ""
      match(tl, "^https[:]//web.archive.org/[0-9]{1,14}/", a)
      splitawk(a, b, "/")
      c = "https://web.archive.org/web/" & b[3] & "/"
      gsub(a, c, tl)
    return strip(tl)

  return ""

#
# Format a non-IA URL into a regular format
# 
proc formatedorigurl*(url: string): string =

  if url ~ "^none":
    return "none"

  var safe = url
  if safe ~ "^http[s]?[:]//":
    return safe        
  elif safe ~ "^//":         
    gsub("^//","http://",safe)          
    return strip(safe)       
  else:
    return "http://" & strip(safe)    # Assume the best..

  return ""

#
# Given a full ref string, replace old string with new string. Also remove duplicate dead link or cbignore templates.
#   'caller' is a debugging string.
#   'op' = "limited" means only update/return the fullref not the whole article
#
proc replacefullref*(fullref, old, new, caller: string): string =

  var origfullref = fullref
  var re1, re2, newfullref = ""
  var c = 0

  
 # Remove {{dead link}} .. but only if one in ref, and one in new text
  re1 = "[{][ ]{0,}[{][ ]{0,}[Dd]ead[ ]{0,}[Ll]ink"
  re2 = re1 & "[^}]*[}][ ]{0,}[}]"
  c = splitawk(new, a, re1)                
  if c == 2:
    c = splitawk(fullref, a, re1)
    if c == 2:
      sub(re2,"",fullref)

 # Remove {{cbignore}} .. but only if one in ref, and one in new text
  re1 = "[{][ ]{0,}[{][ ]{0,}[Cc][Bb][Ii][Gg][Nn][Oo][Rr][Ee]"
  re2 = re1 & "[^}]*[}][ ]{0,}[}]"
  c = splitawk(new, a, re1)
  if c == 2:
    c = splitawk(fullref, a, re1)
    if c == 2:
      sub(re2,"",fullref)

  newfullref = replacetext(fullref, old, new, "replacefullref1-" & caller)
  return replacetext(GX.articlework, origfullref, newfullref, "replacefullref2-" & caller)

#
# Return true if "tl" is of type "name" (wayback|cite|barelink)
#
proc datatype*(tl, name: string): bool =
  var safe = stripwikicomments(tl)
  if name == "wayback":
    if safe ~ "[Ww]ayback[ ]{0,}[|]" and safe ~ "[|][ ]{0,}[Uu][Rr][Ll][ ]{0,}=" and safe ~ "[|][ ]{0,}[Dd]ate[ ]{0,}=":
      return true
  if name == "cite":
    if safe ~ "[Aa]rchive[-]{0,1}url[ ]{0,}=[ ]{0,}" and safe ~ "[Aa]rchive[-]{0,1}date[ ]{0,}=":
      return true
  if name == "barelink":
    if safe ~ "^https?[:]//w?[we]?[wb]?[.]?archive[.]org/w?e?b?/?[0-9]{1,14}/":
      return true
    if safe ~ "^https?[:]//wayback[.]archive[.]org/web/[0-9]{1,14}/":
      return true
  return false

#
# Log (append) a line to Project[wayrmfull] 
# 
proc sendlogwayrm(database, name, msg, tl: string) =

  name & "----" & msg >> database
  "\n" & name & ":" >> Project.wayrmfull             

  if datatype(tl, "cite"):
    "<ref>" & tl & "</ref>" >> Project.wayrmfull
  elif datatype(tl, "wayback"):
    let iaurl = "https://web.archive.org/web/" & getargwayback(tl,"date") & "/" & uriparseEncodeurl(urldecode(getargwayback(tl,"url")))
    "<ref>" & tl & "</ref> (" & iaurl & ")" >> Project.wayrmfull
  elif datatype(tl, "barelink"):
    "<ref>[" & tl & " Link]</ref>" >> Project.wayrmfull

#
# skindeep(url1, url2)
#             
#  Return true if the difference between url1 and 2 is "skin deep"
#  ie. the only diff is https and/or :80 and/or archive.org/web/ and/or web.archive.org .. return 1
#      
proc skindeep*(url1, url2: string): bool =

  var safe1 = url1
  var safe2 = url2

  gsub("^https","http", safe1); gsub("^https","http", safe2)
  sub("[:]80/","/",safe1); sub("[:]80/","/",safe2)
  sub("archive[.]org/web/","archive.org/", safe1); sub("archive[.]org/web/","archive.org/", safe2)
  sub("http[:]//web[.]archive[.]org", "http://archive.org", safe1); sub("http[:]//web[.]archive[.]org", "http://archive.org", safe2)

  if countsubstring(safe1, safe2) > 0:
    return true

  return false

#
# Print contents of WayLink for debugging
#  If flag="filename" print to filename
#
proc debugarray(tag: int, filename: string): void =

    "  WayLink[" & $tag & "],origiaurl = " & WayLink[tag].origiaurl >> filename
    "  WayLink[" & $tag & "].formated = " & WayLink[tag].formated >> filename
    "  WayLink[" & $tag & "].origurl = " & WayLink[tag].origurl >> filename
    "  WayLink[" & $tag & "].origencoded = " & WayLink[tag].origencoded >> filename
    "  WayLink[" & $tag & "].origdate = " & WayLink[tag].origdate >> filename
    "  WayLink[" & $tag & "].newurl = " & WayLink[tag].newurl >> filename
    "  WayLink[" & $tag & "].newiaurl = " & WayLink[tag].newiaurl >> filename
    "  WayLink[" & $tag & "].altarch = " & WayLink[tag].altarch >> filename
    "  WayLink[" & $tag & "].altarchencoded = " & WayLink[tag].altarchencoded >> filename
    "  WayLink[" & $tag & "].altarchdate = " & WayLink[tag].altarchdate >> filename
    "  WayLink[" & $tag & "].mtag = " & $WayLink[tag].mtag >> filename
    "  WayLink[" & $tag & "].status = " & WayLink[tag].status >> filename
    "  WayLink[" & $tag & "].available = " & WayLink[tag].available >> filename
    "--" >> filename        

#
# Returns a unique temporary name.                                 
#  example: mktemp("/home/wgetbody.") -> /home/wgetbody.rzMKkkNz
#
#
proc mktempname*(prefix: string): string =                                           

  let len = 8
  randomize()
  const
    MAX_RETRIES = 999 
    CHARSET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

  var name = newString(len)
  for x in 0..MAX_RETRIES:
    for i in 0..len-1:
      name[i] = CHARSET[random(CHARSET.len-1)]

  result = prefix & name              


