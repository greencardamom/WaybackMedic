import awk, libutils, wtemplate, strutils, times, json, osproc, os, re, random, parseopt, tables

from sequtils import deduplicate
from algorithm import sort

include medicinit
include network
include mediclibrary
include medicapi
include modules

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
# Inc changes and log 
#
#   Given this block of code:
#
#          incchanges(1, "fixencodebug3.1")
#          inc(GX.esformat)
#          sendlog(Project.syslog, CL.name, olddest & " ---- " & dest & " ---- fixencodebug3.1")
#
#   Convert to a single line:
#
#          inclog("fixencodebug3.1", GX.esformat, Project.syslog, olddest & " ---- " & dest & " ---- fixencodebug3.1")
#
#   Optional "noeditsum", "nochanges" and "nolog" can be combined seperated by space eg. "nochanges nolog"
#
proc inclog*(id: string, es: var int, log, logentry: string, fl: varargs[string]): int {.discardable.} =
  var
    flag = ""

  if len(fl) > 0:
    flag = fl[0]

  if flag !~ "noeditsum":
    inc(es)
  if flag !~ "nochanges":
    incchanges(1, id)
  if flag !~ "nolog":
    sendlog(log, CL.name, logentry)
  return 1

#
# Helper function for replacedeadlink() - checks date of {{dead link}}
#
proc replacedeadlink_helper(tl: string, pYear: int, pMonth: string): bool {.discardable.} =

  var
    deadate = ""
    iYear = 0

  if pYear < 2000:   # date check disabled
    return false

  if match(tl, GX.dead, dead) > 0:
    deadate = getarg("date", "clean", dead)
    if match(deadate, "[0-9]{4}", sYear) > 0:
      iYear = parseInt(sYear)
      if iYear == pYear:                              
        if deadate ~ pMonth:
          return true
      elif iYear < pYear:
        return true

  return false

#
# Replace URLs marked wtih {{dead link}} with a dummy Wayback timestamp 18990101080101
#
proc replacedeadlink(): bool {.discardable.} =

  if Runme.replacedeadlink != true:
    return

  var
    field, sep = newSeq[string](0)
    reCite, reBare, origurl, tl = ""
    c = 0

  var                           # Date or later of {{dead link}} to process. Set pYear to 0 to process all ie. ignore "|date="
    pYear = 0                   # Process {{dead link}} dated March 2017 or later
    pMonth = "Jan|Feb"          # Months to exclude during the pYear

  reCite = "(" & GX.cite2 & ")" & "[ \\n\\t.,;:-]{0,}" & GX.dead
  reBare = "[[]" & GX.space & "[Hh][Tt][Tt][Pp][^]]*[]]" & "[ \\n\\t.,;:-]{0,}" & GX.dead

  c = awk.patsplit(GX.articlework, field, reCite, sep)
  if c > 0:
    for i in 0..c-1:
      if match(field[i], GX.cite, tl) > 0:
        if replacedeadlink_helper(field[i], pYear, pMonth):  # check date of {{dead link}}
          continue
        if citeignore(tl):
          continue
        if isarg("archive-url", "missing", tl) and isarg("archive-date", "missing", tl) and isarg("url", "value", tl):
          origurl = getarg("url", "clean", tl)
          if not isarchive(origurl, "all"):
            if origurl ~ "^[/][/]":    # protocol relative URL
              origurl = "http:" & origurl
            gsubs(tl, replacearg(tl, "url", "https://web.archive.org/web/18990101080101/" & origurl, "replacedeadlink1"), field[i])
    GX.articlework = unpatsplit(field, sep)
  
  c = awk.patsplit(GX.articlework, field, reBare, sep)
  if c > 0:
    for i in 0..c-1:
      if replacedeadlink_helper(field[i], pYear, pMonth):  # check date of {{dead link}}  
        continue
      if match(field[i], "[Hh][Tt][Tt][Pp][^]]*[^]]", tl) > 0:
        if not isarchive(tl, "all"):
          if tl ~ "^[/][/]":
            tl = "http:" & tl
          gsubs(tl, "https://web.archive.org/web/18990101080101/" & tl, field[i])
    GX.articlework = unpatsplit(field, sep)

  return true


#
# Remove trailing "@" added by webcitelong.awk as a marker for bare URLs 
#
proc fixencodebug_helper(s: string): string =

  var
    s = s

  if iswebcite(s):
    if s ~ "[@][]]$":
      awk.sub("[@][]]$","",s)
      s = s & "]"
    elif s ~ "[@]$":
      awk.sub("[@]$","",s)

  return s

#
# See https://phabricator.wikimedia.org/T186417
#
proc fixencodebug(): bool {.discardable} =

  var
    field, sep = newSeq[string](0)
    c, newchange = 0
    url = ""

 # Fix citations
  c = patsplit(GX.articlework, field, GX.cite2, sep)
  if c > 0:
    for i in 0..c-1:
      if isarg("archive-url", "value", field[i]):
        url = getarg("archive-url", "clean", field[i])
        if iswebcite(url) and url ~ "[]]" and url ~ "(?i)([%]5B)":
          awk.split(url, a, "[\\]]")
          a[0] = fixencodebug_helper(a[0])
          field[i] = replacearg(field[i], "archive-url", a[0], "fixencodebug1")
          inclog("fixencodebug1", GX.esformat, Project.syslog, url & " ---- " & a[0] & " ---- fixencodebug1")
          inc(newchange)

    if newchange > 0:
      GX.articlework = unpatsplit(field, sep)
      newchange = 0

 # Fix webarchive
  c = patsplit(GX.articlework, field, "[{][ ]?[{]" & GX.space & "[Ww]ebarchive[^}]+[}][ ]?[}]", sep)
  if c > 0:
    for i in 0..c-1:
      if isarg("url", "value", field[i]):
        url = getarg("url", "clean", field[i])
        if iswebcite(url) and url ~ "[\\]]" and url ~ "(?i)([%]5B)":
          awk.split(url, a, "[\\]]")
          a[0] = fixencodebug_helper(a[0])
          field[i] = replacearg(field[i], "url", a[0], "fixencodebug2")
          inclog("fixencodebug2", GX.esformat, Project.syslog, url & " ---- " & a[0] & " ---- fixencodebug2")
          inc(newchange)

    if newchange > 0:
      GX.articlework = unpatsplit(field, sep)
      newchange = 0

 # THIS NEEDS WORK
 # Fix bareurl surrounded by [] if there is a text title and it's a webcite URL
  c = patsplit(GX.articlework, field, "[[]" & GX.space & GX.wcre & "[^]]*[]]", sep)
  if c > 0:
    for i in 0..c-1:
      if field[i] ~ "[@][]]$":  # Check for trailing @ added by webcitelong.awk as a flag
        if awk.match(GX.articlework, escapeRe(field[i]) & "[^ $<|}{\\n\\t]*[^ $<|}{\\n\\t]?", dest) > 0:
          var olddest = dest
          awk.sub("[@][]][^$]*[^$]?","",dest)
          dest = dest & "]"
          GX.articlework = replacetext(GX.articlework, olddest, dest, "fixencodebug3.1")
          inclog("fixencodebug3.1", GX.esformat, Project.syslog, olddest & " ---- " & dest & " ---- fixencodebug3.1")
          inc(newchange)
        else: # Unable to fix, remove trailing @
          GX.articlework = replacetext(GX.articlework, field[i], fixencodebug_helper(field[i]), "fixencodebug3.2")
          sendlog(Project.syslog, CL.name, field[i] & " ---- " & fixencodebug_helper(field[i]) & " ---- error fixencodebug3.3")


# Helper proc 
#
proc fixcommentarchive_helper(s1, s2: string, s3: var string, id: string): int =
  gsubs(s1, s2, s3)
  inclog(id, GX.esformat, Project.syslog, id)
  return 1

#
# Remove or open <!-- archiveurl/archivedate --> when inside a template
#
proc fixcommentarchive(): bool {.discardable} =

  var
    field, sep = newSeq[string](0)
    comments = @[""]
    c,d = 0  
    status, response = -1
    newcomm, deadstate, url, modelbar, locbar = ""
    embedded = "[{][ ]?[{][^{]*[{][ ]?[{]"  # check for embedded templates
    debug = false

  c = patsplit(GX.articlework, field, GX.cite2, sep)
  if c > 0:
    for i in 0..c-1:
      if field[i] ~ embedded:   # Can not reliably parse templates with embedded templates 
        sed("skip embedded for " & field[i], debug)
        continue
      if ifwikicomments(field[i]): 
        comments = getwikicomments(field[i])
        if seqlength(comments) > 0:
          for k, v in comments:
            sed("Processing: " & comments[k], debug)
            newcomm = removecommentmarkup(comments[k])
            sed("Newcomm: " & newcomm, debug)
            deadstate = "yes"
            if isarg("archive-url", "exists", newcomm) and isarg("archive-date", "exists", newcomm) and countsubstring(newcomm, "|") == 2 and isarchive(getarg("archive-url", "clean", newcomm), "all"):
              url = getarg("url", "clean", field[i])
              if url ~ "(?i)(^https?)":
                if isarg("archive-url", "missing", field[i]) or isarg("archive-url", "empty", field[i]):

                  if isargempty("archive-url", field[i]):
                    field[i] = replacearg(field[i], "archive-url", getarg("archive-url", "clean", newcomm), "fixcommentarchive1.1")
                    if isargempty("archive-url", field[i]):
                      continue
                    else:
                      incchanges(1, "fixcommentarchive2")
                      inc(d)
                  if isargempty("archive-date", field[i]):
                    field[i] = replacearg(field[i], "archive-date", getarg("archive-date", "clean", newcomm), "fixcommentarchive3.1")
                    if isargempty("archive-date", field[i]):
                      continue
                    else:
                      incchanges(1, "fixcommentarchive4")
                      inc(d)

                  if isarg("archive-url", "value", field[i]) and isarg("archive-date", "value", field[i]):
                    d = d + fixcommentarchive_helper(comments[k], "", field[i], "fixcommentarchive5.1")
                  elif isarg("archive-url", "missing", field[i]) and isarg("archive-date", "missing", field[i]):
                    d = d + fixcommentarchive_helper(comments[k], newcomm, field[i], "fixcommentarchive7.1")
                elif isarg("archive-url", "value", field[i]) and isarg("archive-date", "value", field[i]):
                  d = d + fixcommentarchive_helper(comments[k], "", field[i], "fixcommentarchive9.1")

                else:
                  sed("loop fell through: A", debug)

                if isarg("dead-url", "missing", field[i]) or isarg("dead-url", "empty", field[i]):
                  sed("Checking fixcommentarchive1.1.1", Debug.network)
                  (status, response) = webpagestatus(url, "one")
                  if status == 1:
                    deadstate = "no"
                  if isargempty("dead-url", field[i]):
                    field[i] = replacearg(field[i], "dead-url", deadstate, "fixcommentarchive11")
                    if isarg("dead-url", "value", field[i]):
                      incchanges(1, "fixcommentarchive12")
                      inc(d)
                  elif isarg("archive-url", "exists", field[i]) and isarg("archive-date", "exists", field[i]) and isarg("dead-url", "missing", field[i]): 
                    if isarg("url", "exists", field[i]):
                      modelbar = getarg(firstarg(field[i]), "bar", field[i])                 
                      locbar = getarg(notlastarg(field[i], "dead-url"), "bar", field[i]) 
                      if not empty(modelbar):
                        if not empty(modelfield(modelbar, "dead-url", "no")):
                          gsubs(locbar, locbar & modelfield(modelbar, "dead-url", deadstate), field[i])       
                          incchanges(1, "fixcommentarchive13")
                          inc(d)
              else:
                sed("no http in url", debug)

           # <!-- |archiveurl=empty |archivedate=exists --> 
            elif isargempty("archive-url", newcomm) and isarg("archive-date", "exists", newcomm) and countsubstring(newcomm, "|") == 2:
                d = d + fixcommentarchive_helper(comments[k], "", field[i], "fixcommentarchive14.1")
           # <!--|archivedate=empty --> 
            elif isargempty("archive-url", newcomm) and countsubstring(newcomm, "|") == 1:
                d = d + fixcommentarchive_helper(comments[k], "", field[i], "fixcommentarchive16.1")
           # <!--|archiveurl=http://blogspot.com |archivedate=exists--> |archiveurl=http://archive.org.. |archivedate=2012..
            elif isarg("archive-url", "value", newcomm) and not isarchive(getarg("archive-url", "clean", newcomm), "all") and isarg("archive-date", "exists", newcomm):
                if isarg("archive-url", "value", field[i]) and isarg("archive-date", "exists", field[i]):
                  d = d + fixcommentarchive_helper(comments[k], "", field[i], "fixcommentarchive18.1")
            else:
              sed("no match in comment", debug)

        else:
          sed("zero seqlength", debug)
    if d > 0:    
      GX.articlework = unpatsplit(field, sep)


#
# Fix URLs with https:/// problem caused by IABot
# Fix URLS with "https:///ttp%3A"
#
proc fix3slash(): string {.discardable.} =

  var
    field, sep = newSeq[string](0)
    c = 0  
    archiveurl, oldurl, url, re = ""

  c = patsplit(GX.articlework, field, GX.cite2, sep)
  if c > 0:
    for i in 0..c-1:
      if isarg("archive-url", "value", field[i]) and not citeignore(field[i]):
        archiveurl = getarg("archive-url", "clean", field[i])
        if archiveurl ~ "(?i)(https[:][/][/][/]ttp%3A)":
          oldurl = archiveurl
          gsub("(?i)(https[:]///ttp%3A)", "http:", archiveurl)
          field[i] = replacearg(field[i], "archive-url", archiveurl, "fix3slash2.1")
          inclog("fix3slash2.1", GX.esformat, Project.log3slash, oldurl & " ---- " & archiveurl & " ---- fix3slash2.1")
        elif archiveurl ~ "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][/]$" and archiveurl !~ "^[Hh][Tt][Tt][Pp][Ss]?[:][/][/][/]":
          if isarg("url", "value", field[i]):
            url = getarg("url", "clean", field[i])
            if not isarchive(url, "all"):
              oldurl = archiveurl
              gsub("[Hh][Tt][Tt][Pp][Ss]?[:][/][/][/]$", "", archiveurl)
              archiveurl = archiveurl & url
              field[i] = replacearg(field[i], "archive-url", archiveurl, "fix3slash1.1")
              inclog("fix3slash1.1", GX.esformat, Project.log3slash, oldurl & " ---- " & archiveurl & " ---- fix3slash1.1")
    GX.articlework = unpatsplit(field, sep)

  # For non-{{cite web}} links

  for g in 0..len(GX.service) - 1: # cycle through each service[g] (wayback, webcite, etc.)
    re = GX.service[g] & "https[:][/][/][/]ttp%3A"
    c = patsplit(GX.articlework, field, re, sep)
    if c > 0:
      for i in 0..c-1:
        oldurl = field[i]
        gsub("(?i)(https[:]///ttp%3A)", "http:", field[i])
        inclog("fix3slash3.1", GX.esformat, Project.log3slash, oldurl & " ---- " & field[i] & " ---- fix3slash3.1")        
      GX.articlework = unpatsplit(field, sep)

#
# Fix wayback URL missing a timestamp, invalid timestamp date, garbage chars, with "/save/" or "/save/_embed/", 
#   missing protocol in source URL, multiple arguments, truncated source URL, bad argument names, web-beta.archive.org
#
#  https://en.wikipedia.org/w/index.php?title=Sabriye_Tenberken&diff=prev&oldid=462608183
# Add a fake timestamp 18990101070101 which will get updated by fixbadstatus() and/or fixdatemismatch() 
#  It also serves as a flag for removal by verifyiats() if not fixed by the end
#
proc fixiats(): string {.discardable} =

     var
       field, field2, sep, sep2, service = newSeq[string](0)
       c,cc = 0
       j, d = 0
       newarticle, sand, ts, archiveurl, ndest = ""

   # Convert wikiwix to wik.archive.org keeping same snapshot date
   # see also fillway(), process_article() (in "getlinks" sections), diy_memento(), waytree() --> .dummy and garbagecheck()
   # this feature will convert existing wikiwix to other archives but leave it in place if no alternative found
   # similar can be done for other conversions
     if Runme.replacewikiwix:
       c = patsplit(GX.articlework, field, GX.wikiwixre & "[/]cache[/]", sep)
       if c > 0:
         for i in 0..c-1:
           field[i] = "https://wik.archive.org/web/"
         GX.articlework = unpatsplit(field,sep)

    # convert a specific URL off of webcitation to something else - see also api_memento()
     if Runme.fixru:
       c = patsplit(GX.articlework, field, GX.wcre & "[/][^?]*[?]url[=]http[:][/][/]textual[.]ru", sep)
       if c > 0:
         for i in 0..c-1:
           if awk.match(field[i], GX.wcre & "[/][^?]*[?]url[=]", dest) > 0:
             gsubs(dest, "https://web.archive.org/web/18990101070101/", field[i])
         GX.articlework = unpatsplit(field,sep)

   # Convert collections.europarchive.org

     gsubs("collections?[.]europarchive[.]org/(dnb|tna|ukparliament)/", "web.archive.org/web/" ,GX.articlework)
     gsubs("collections?[.]europarchive[.]org/nli/", "collections.internetmemory.org/nli/" ,GX.articlework)

   # Convert /save/

     gsubs("archive.org/save/_embed/", "archive.org/18990101070101/", GX.articlework)
     gsubs("archive.org/save/", "archive.org/18990101070101/", GX.articlework)

   # Fix templates with space in argument name: "|archive url" instead of "|archive-url"

     c = patsplit(GX.articlework, field, GX.cite2, sep)
     if c > 0:
       for i in 0..c-1:                # cycle through templates
         if match(field[i], "[|]" & GX.space & "archive[ ]url" & GX.space & "[=]", dest) > 0:
           ndest = dest
           gsub("archive[ ]url", "archive-url", ndest)
           gsubs(dest, ndest, field[i])
           j = j + inclog("fixiats8.1", GX.esformat, Project.logiats, dest & " ---- fix space in argument fixiats8.1")
         if match(field[i], "[|]" & GX.space & "archive[ ]date" & GX.space & "[=]", dest) > 0:
           ndest = dest
           gsub("archive[ ]date", "archive-date", ndest)
           gsubs(dest, ndest, field[i])
           j = j + inclog("fixiats8.2", GX.esformat, Project.logiats, dest & " ---- fix space in argument fixiats8.2")
         if match(field[i], "[|]" & GX.space & "dead[ ]url" & GX.space & "[=]", dest) > 0:
           ndest = dest
           gsub("dead[ ]url", "dead-url", ndest)
           gsubs(dest, ndest, field[i])
           j = j + inclog("fixiats8.3", GX.esformat, Project.logiats, dest & " ---- fix space in argument fixiats8.3")
       if j > 0:
         GX.articlework = unpatsplit(field,sep)
         j = 0

   # Fix |title={title} bug T203865

     while(match(GX.articlework, "title[ ]*[=][ ]*[{]title[}]", dest) > 0):
       sub(dest, replace(dest, "{title}", "Archived copy"), GX.articlework)
       inclog("fixiats11.1", GX.esformat, Project.logiats, "fix {title} bug fixiats11.1")

   # Try to fix truncated URL: |archiveurl=https://web.archive.org/web/20160603182848/https://

     c = patsplit(GX.articlework, field, GX.cite2, sep)
     if c > 0:
       for i in 0..c-1:                # cycle through templates
         if isarg("archive-url", "value", field[i]) and isarg("url", "value", field[i]):
           archiveurl = getarg("archive-url", "clean", field[i])
           if archiveurl ~ "^https?[:][/][/]web[.]archive[.]org[/]web[/][0-9]{14}/https?[:][/][/][ ]*$":
             sub("https?[:][/][/][ ]*$", "", archiveurl)
             field[i] = replacearg(field[i], "archive-url", archiveurl & getarg("url", "clean", field[i]), "fixiats7.1") 
             j = j + inclog("fixiats7.1", GX.esformat, Project.logiats, getarg("archive-url", "clean", field[i]) & " ---- fix truncated URL fixiats7.1") 
           elif archiveurl ~ "^https?[:][/][/]web[.]archive[.]org[/]web[/][0-9]{14}/[ ]*$":
             field[i] = replacearg(field[i], "archive-url", archiveurl & getarg("url", "clean", field[i]), "fixiats7.2") 
             j = j + inclog("fixiats7.2", GX.esformat, Project.logiats, getarg("archive-url", "clean", field[i]) & " ---- fix truncated URL fixiats7.2") 
       if j > 0:
         GX.articlework = unpatsplit(field,sep)
         j = 0

   # Remove "archive.org/19990101000000/_embed/"
     c = patsplit(GX.articlework, field, "archive[.]org[/][0-9]{4,14}[/]_embed[/]", sep)
     if c > 0:
       for i in 0..c-1:
         gsubs("/_embed", "", field[i])
       GX.articlework = unpatsplit(field,sep)
       GX.esformat = GX.esformat + c
       incchanges(c, "fixiats1")

   # Remove empty citation arguments which will confuse bot later
   # Log duplicates
   #  https://en.wikipedia.org/w/index.php?title=2010%E2%80%9311_Brentford_F.C._season&type=revision&diff=773996995&oldid=773703861

     insert(service, "archive[-]?url", 0)
     insert(service, "archive[-]?date", 1)
     insert(service, "dead[-]?url", 2)
     var counts = 0
     c = patsplit(GX.articlework, field, GX.cite2, sep)
     if c > 0:
       for i in 0..c-1:                # cycle through templates
         var found = 0
         for g in 0..high(service):    # cycle through arguments
           var hits = 0
           if not citeignore(field[i]):
             d = patsplit(field[i], field2, "(?i)([|][ ]*" & service[g] & "[^=]*[=][^|}]*[^|}])", sep2)
             if d > 1:
               for k in 0..d-1:          # cycle through duplicate args
                 if awk.split(field2[k], a, "[=]") > 1:
                   if len(strip(a[1])) > 1:
                     if d == 2 and k == 0 and getval(field2[0]) == getval(field2[1]): # remove dups if =val is the same in both, mainly caused by IABot bug July 2018
                       field2[0] = ""
                       inc(hits)
                     else:
                       continue
                   else:                 # delete empty args eg. "|archiveurl=|"
                     inc(hits)
                     field2[k] = $field2[k][high(field2[k])]  # keep last char because regex funky when "|deadurl=|"
                 else:
                   inc(hits)
                   field2[k] = $field2[k][high(field2[k])]
               field[i] = unpatsplit(field2,sep2)
           if hits > 0: 
             inc(found)
           if patsplit(field[i], field2, service[g], sep2) > 1:
             sendlog(Project.logiats, CL.name, field[i] & " ---- error Duplicate arguments (archiveurl|archivedate|deadurl)")
         if found > 0:
           inc(counts)
       if counts > 0:
         GX.articlework = unpatsplit(field,sep)
         GX.esformat = GX.esformat + counts
         incchanges(counts, "fixiats2")

   # Re-format Archive.is timestamps from http://archive.is/2012.07.23-114235 to http://archive.is/20120723114235
   # Convert to https
   # Convert &amp; to &

     c = awk.patsplit(GX.articlework, field, (GX.isre & "[^\\s\\]|}{<]*[^\\s\\]|}{<]"), sep)
     if c > 0:
       for i in 0..c-1:
         var k = awk.patsplit(field[i], field2, "/", sep2)
         for z in 0..k - 1:
           if sep2[z] ~ "^[0-9]{4}[.][0-9]{2}[.][0-9]{2}[-][0-9]{6}" and (z > 0 and sep2[z - 1] ~ "(?i)(archive[.])" ):
             gsub("[.]|[-]", "", sep2[z])
             incchanges(1, "fixiats3")
             break
         field[i] = unpatsplit(field2,sep2)
         gsub("^http[:]", "https:", field[i]) 
       GX.articlework = unpatsplit(field,sep)

   # Check for missing/empty |url but a full |archiveurl

     counts = 0
     c = patsplit(GX.articlework, field, GX.cite2, sep)
     if c > 0:
       for i in 0..c-1:                # cycle through templates
         if field[i] ~ "(?i)(cite tweet[ ]*[|])":  # {{cite tweet}} has no |url argument
           continue
         if isarg("archive-url", "value", field[i]):
           # if |url exists and empty and no |chapter-url or |map-url value
           if isargempty("url", field[i]) and not isarg("chapter-url", "value", field[i]) and not isarg("map-url", "value", field[i]):
             # fill |url with contents from |archiveurl .. it will get worked out in fixswitch()
             var urlclean = getarg("archive-url", "clean", field[i])
             if urlclean ~ "^http":
               field[i] = replacearg(field[i], "url", getarg("archive-url", "clean", field[i]), "fixiats9.1")
               inc(counts)
               sendlog(Project.logiats, CL.name, getarg("archive-url", "clean", field[i]) & " ---- add missing url (1)")

           # if |url doesn't exist and no |chapter-url or |map-url value
           elif isarg("url", "empty", field[i]) and isarg("url", "missing", field[i]) and not isarg("chapter-url", "value", field[i]) and not isarg("map-url", "value", field[i]):
             # Change |archiveurl to |url .. it will get worked out in fixswitch()
             var modelbar, urlcomplete, urlcompletenew, urlclean = ""
             urlclean = getarg("archive-url", "clean", field[i])
             if urlclean ~ "^http":
               if not dummydate(urlclean, "189908"):
                 modelbar = getarg(firstarg(field[i]), "bar", field[i]) # model field format on first argument in template
               else:
                 modelbar = getarg("archive-url", "bar", field[i])      # unless 1899..08 model on archive-url field itself to avoid minor edits
               urlcomplete = getarg("archive-url", "bar", field[i])     # note: using "complete" here can cause trouble w/ wikicomments
                                                                        # https://en.wikipedia.org/w/index.php?title=Aubrey%E2%80%93Maturin_series&diff=771877255&oldid=767934751
               urlcompletenew = modelfield(modelbar, "url", urlclean)
               gsubs(urlcomplete, urlcompletenew, field[i])            
               inc(counts)
               sendlog(Project.logiats, CL.name, urlclean & " ---- add missing url (2)")
       if counts > 0:
         GX.articlework = unpatsplit(field,sep)
         incchanges(1, "fixiats9")
         counts = 0

   # If |url= and |archiveurl= contain the same content (and not an archive), delete archiveurl
     counts = 0
     c = patsplit(GX.articlework, field, GX.cite2, sep)
     if c > 0:
       for i in 0..c-1:                # cycle through templates
         if isarg("archive-url", "value", field[i]) and isarg("url", "value", field[i]):
           if (getarg("archive-url", "clean", field[i]) == getarg("url", "clean", field[i])) and not isarchive(getarg("archive-url", "clean", field[i]), "all"):
             field[i] = gsubs(getarg("archive-url", "bar", field[i]), "", field[i])
             inc(counts)
       if counts > 0:
         GX.articlework = unpatsplit(field,sep)
         incchanges(counts, "fixiats10")
         counts = 0

   # Check for missing protocol in the source URL - Internet Archive

     c = awk.patsplit(GX.articlework, field, (GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][^\\s\\]|}{<]*[^\\s\\]|}{<]"), sep)
     if c > 0:
       d = 0
       for i in 0..c-1: 

         # If archive.org is element of an archive.is URL skip this step 
         # https://archive.is/20140113123819/http://web.archive.org/web/20080909055945/www.jbs.org/
         if contains(GX.articlework, "/" & field[i]):
           continue 

         # If archive.org is element of a WebCite URL skip this step 
         # http://www.webcitation.org/6lYuwBqDf?url=https://web.archive.org/web/20140301082752/http%3A//articles.philly.com
         if contains(GX.articlework, "?url=" & field[i]):
           continue 

         # Convert web-beta.archive.org to web.archive.org - added August 2018 bcause the beta site is closed
         if field[i] ~ "web[-]beta[.]archive[.]org":
           gsubs("web-beta.archive.org", "web.archive.org", field[i])
           inc(d)

         var origurl = field[i]
         var dest, dest2 = ""
         match(field[i], GX.iare, dest)
         gsub("^" & GX.iare, "", field[i])
         match(field[i], "^[/][Ww][Ee][Bb]", dest2)
         gsub("^[/][Ww][Ee][Bb]", "", field[i])
         dest = dest & dest2
         if field[i] ~ "^[/]index[.]php|^[/]search[.]php|^[/]web[.]php" or field[i] ~ "^[/]details[/]|^[/]serve[/]|^[/]download[/]|^[/]audio[/]|^[/]texts[/]|^[/]stream[/]|^[/]video[/]":
           field[i] = origurl
           continue
         cc = awk.patsplit(field[i], field2, "[/]", sep2)
         if cc == 0 and len(sep2) > 1:
           if sep2[1] ~ "https?%3A":
             gsub("%3A", ":", sep2[1])
             inc(d)
           if sep2[1] ~ "[.]" and sep2[1] !~ "[:]$|%3A":                                                   # https://web.archive.org/hk.com
             sep2[1] = "http://" & sep2[1]
             inc(d)
             sendlog(Project.logiats, CL.name, sep2[1] & " ---- add missing protocol source URL (1)")
         elif cc == 1 and len(sep2) > 0:
           if sep2[0] ~ "https?%3A":
             gsub("%3A", ":", sep2[0])
             inc(d)
           if sep2[0] ~ "[.]" and sep2[0] !~ "[:]$|%3A":                                                   # https://web.archive.org/hk.com/
             sep2[0] = "http://" & sep2[0]
             inc(d)
             sendlog(Project.logiats, CL.name, sep2[0] & " ---- add missing protocol source URL (2)")     
         elif cc == 1 and len(sep2) > 1:                                                                   # https://web.archive.org/web/hk.com
           if sep2[1] ~ "https?%3A":
             gsub("%3A", ":", sep2[1])
             inc(d)
           if sep2[1] ~ "[.]" and sep2[1] !~ "[:]$|%3A":
             sep2[1] = "http://" & sep2[1]
             inc(d)
             sendlog(Project.logiats, CL.name, sep2[1] & " ---- add missing protocol source URL (3)")
         elif cc > 1 and len(sep2) > 0:
           if sep2[0] ~ "^https?%3A":
             gsub("%3A", ":", sep2[0])
             inc(d)
           elif sep2[1] ~ "^https?%3A":
             gsub("%3A", ":", sep2[1])
             inc(d)
           if sep2[0] ~ "[.]" and sep2[0] !~ "[:]$|%3A":                                                   # https://web.archive.org/hk.com/path/
             sep2[0] = "http://" & sep2[0]
             inc(d)
             sendlog(Project.logiats, CL.name, sep2[0] & " ---- add missing protocol source URL (4)")
           elif len(sep2) > 1 and sep2[1] ~ "[.]" and sep2[1] !~ "[:]$|%3A":                               # https://web.archive.org/web/hk.com/path/
             sep2[1] = "http://" & sep2[1]
             inc(d)
             sendlog(Project.logiats, CL.name, sep2[1] & " ---- add missing protocol source URL (5)")
           elif len(sep2) > 2 and sep2[1] ~ "[0-9]{8,14}":                                                 # https://web.archive.org/web/19990903214230/hk.com..
             if sep2[2] ~ "(?i)^https?%3A%2F%2F":
               sub("(?i)%3A%2F%2F", "://", sep2[2])
               inc(d)
             if sep2[2] ~ "^https?%3A":
               gsub("%3A", ":", sep2[2])
               inc(d)
             if sep2[2] !~ "[:]$|%3A":
               if sep2[2] !~ "(?i)^http":        
                 sep2[2] = "http://" & sep2[2]
               inc(d)
               sendlog(Project.logiats, CL.name, sep2[2] & " ---- add missing protocol source URL (6)")

         field[i] = dest & unpatsplit(field2, sep2)
       if d > 0:
         GX.articlework = unpatsplit(field, sep)       
         GX.esformat = GX.esformat + d
         incchanges(d, "fixiats4")


   # Check for and remove any timestamps that contain garbage (_re, > 14 chars, < 8 chars, etc)

     c = awk.patsplit(GX.articlework, field, (GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][0-9]{1,14}[^\\s\\]|}{<]*[^\\s\\]|}{<]"), sep)
     if c > 0:
       for i in 0..c-1:
         if urlignore(field[i]):                # skip /items/ cases
           continue
         sand = ""
         ts = urltimestamp2(field[i])
         if ts ~ "[*|?]":                       # skip timestamp containing "*" or "?"
           continue
         if not empty(ts):
           cc = awk.split(ts, a, "")
           for j in 0..cc-1:                    # remove non-number chars 
             if a[j] ~ "[0-9]":
               sand = sand & a[j]
           if len(sand) > 14:                   # normalize length to at least 8 chars or even number of chars up to 14
             sand = substr(sand, 0, 13)         #  the validity of the date gets checked below
           elif len(sand) == 13:
             sand = substr(sand, 0, 11)
           elif len(sand) == 11:
             sand = substr(sand, 0, 9)
           elif len(sand) == 9:
             sand = substr(sand, 0, 7)
           elif len(sand) == 7:
             sand = substr(sand, 0, 5) & "01"
           elif len(sand) == 6:
             sand = sand & "01"
           elif len(sand) == 5:
             sand = substr(sand, 0, 3) & "0101"
           elif len(sand) == 4:
             sand = sand & "0101"
           elif len(sand) < 4:
             sand = "18990101070101"  
         else:
           sand = "18990101070101"   

         if not empty(sand) and sand != ts:
           if not empty(ts):
             field[i] = replacetext(field[i], ts, sand, "fixiats1")
#             inclog("fixiats5.1", GX.esformat, Project.logiats, field[i] & " ---- normalized the timestamp fixiats5.1")
# compiler bug keeps the above line from working when the below three lines are commented out
# try again after upgrading Nim
             inc(GX.esformat)
             incchanges(1, "fixiats5")
             sendlog(Project.logiats, CL.name, field[i] & " ---- normalized the timestamp")
           else:
             sendlog(Project.logiats, CL.name, field[i] & " ---- error Unable to determine timestamp1")
         elif empty(sand):
           sendlog(Project.logiats, CL.name, field[i] & " ---- error Unable to determine timestamp2")
         #else:
           #no problem
       GX.articlework = unpatsplit(field, sep)

   # Check for and remove any timestamps that are not valid date (month of 17 etc..). It will get filled back in later.

     c = awk.patsplit(GX.articlework, field, (GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][0-9]{8,14}[^\\s\\]|}{<]*[^\\s\\]|}{<]"), sep)
     if c > 0:
       for i in 0..c-1:
         ts = urltimestamp_wayback(strip(field[i]))
         if dummydate(ts, "1899"):
           continue
         if not validate_datestamp(ts) and ts !~ "[*|?]$":
           var orig = field[i]
           gsubs(ts & "/", "", field[i])
           sendlog(Project.logiats, CL.name, orig & " ---- " & field[i] & " ---- removed invalid date")
       GX.articlework = unpatsplit(field, sep)


   # Check for National Archives (UK) timestamps of "+" and convert to date it actually links to

     c = awk.patsplit(GX.articlework, field, (GX.natarchivesukre & "([/]tna)?[/][+][/][^\\s\\]|}{<]*[^\\s\\]|}{<]"), sep)
     if c > 0:
       for i in 0..c-1:
         var found = 0
         var origurl = field[i]
         var (head, bodyfilename) = getheadbody(field[i], "one")

         # web scrape method #1
         # scrollToDay(20110414095405);
         if match(readfile(bodyfilename), "scroll[Tt]o[Dd]ay[(][^)]*[)]", dest) > 0:
           if awk.split(dest, a, "[(]|[)]") > 1:
             a[1] = strip(a[1])
             if a[1] ~ "^[0-9]{8,14}$":
               gsubs("/+/", "/" & a[1] & "/", field[i])
               found = 1
         if found == 0: 
           # Memento header method #2
           # Link: <http://webarchive.nationalarchives.gov.uk/20120119194657/http:/...pdf>; rel="memento" 
           if match(head, "[Ll]ink[ ]*[:][ ]*[<][ ]*[Hh][Tt][Tt][Pp][^>]*[>][ ]*[;][ ]*rel[ ]*[=][ ]*\"memento\"", dest) > 0:
             if awk.split(dest, a, "[<]|[>]") > 1:
               if a[1] ~ GX.natarchivesukre:
                 var ts = urltimestamp(strip(a[1]))
                 if validate_datestamp(ts):
                   gsubs("/+/", "/" & ts & "/", field[i])
                   found = 1
         if found == 0:
           # web scrape method #3
           if match(readfile(bodyfilename), "timestamp[ ]*[:][ ]*\"[0-9]{8,14}\"[,]", dest) > 0:
             if awk.split(dest, a, "\"") > 1:
               a[1] = strip(a[1])
               if a[1] ~ "^[0-9]{8,14}$":
                 gsubs("/+/", "/" & a[1] & "/", field[i])
                 found = 1
         if found == 1:
           inclog("fixiats6.1", GX.esformat, Project.logiats, origurl & " ---- " & field[i] & " ---- removed + from National Archives (UK)") 
         
       GX.articlework = unpatsplit(field, sep)

   # Check for missing timestamps

     c = awk.patsplit(GX.articlework, field, (GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][Hh][Tt][Tt][Pp][^\\s\\]|}{<]*[^\\s\\]|}{<]"), sep)
     if c > 0:
       for i in 0..c-1:
         j = awk.split(field[i], a, "/")
         if j > 5:
           if a[0] ~ GX.shttp and a[3] ~ "^[Hh][Tt][Tt][Pp]|^[Ww][Ee][Bb]": # safety check to avoid out of bound array
             sand = ""
             for k in 0..j-1:
               if a[k] ~ ("^" & GX.iahre & "[.]?archive[.]org$") and a[k-2] ~ GX.shttp and a[k+1] !~ "^[Ww][Ee][Bb]$":
                 sand = sand & a[k] & "/18990101070101"
               elif a[k] ~ "^[Ww][Ee][Bb]$" and a[k-1] ~ ("^" & GX.iahre & "[.]?archive[.]org$") and a[k+1] ~ GX.shttp:
                 sand = sand & a[k] & "/18990101070101"
               else:
                 sand = sand & a[k]
               if k != j - 1:
                 sand = sand & "/"

             field[i] = sand

       newarticle = unpatsplit(field,sep)

     if newarticle != GX.articlework and len(newarticle) > 10:

       GX.articlework = newarticle

       # Turn on API, if otherwise disabled, when article contains "18990101070101"
       if contains(GX.articlework, "18990101070101") or contains(GX.articlework, "18990101080101"):  
         if not Runme.api: # requires API to complete 
           Runme.api = true

       # If API is not responding or down, leave a critical message and abort.
       if not apiCannary():
         "Error in fixiats() for " & CL.name & " : API down. Aborting with no changes to article." >* "/dev/stderr"
         sendlog(Project.critical, CL.name, "Error in fixiats() for " & CL.name & " : API down. Aborting with no changes to article.")
         try:
           removeFile("/tmp/" & GX.wid)
         except:
           "" >* "/tmp/" & GX.wid
         quit(QuitSuccess)

#
# Helper proc for fixswitchurl()
#  Move an archive with "*" for timestamp out of CS1|2 and into {{webarchive}}
#
proc fixswitchurl_helper(fieldi, re1: string): string =

    var
      fieldi = fieldi

    if getarg("url", "clean", fieldi) ~ re1 and not cbignorebareline(GX.articlework, fieldi):
      var oldurl = getarg("url", "clean", fieldi)
      var hold = oldurl
      gsub(re1, "", oldurl)
      fieldi = replacearg(fieldi, "url", uriparseEncodeurl(urldecode(oldurl)), "fixswitch1") 
      fieldi = fieldi & "{{webarchive |url=" & hold & " |date=* }}"
      inclog("fixswitchurl_helper1.1", GX.esformat, Project.logfixswitch, hold & " ---- logfixswitch4") 

    return fieldi

#
# Fix when archive.org URL is in the url= field 
#
# 4 types of conversions when url= is an archive.org
#
#   w/ no archiveurl + no archivedate = type1
#   w/ no archiveurl + archivedate    = type2
#   w/ archiveurl + no archivedate    = type3
#   w/ archiveurl + archivedate       = type4
#
# If no archivedate= available, create as 1899-01-10 and let fixdatemismatch() sort it out
#
proc fixswitchurl(): string {.discardable} =

     var
       field, sep = newSeq[string](0)
       c = 0
       urlfull,urlclean,urlcleanstrip,urlcomplete,newart,archiveurlbar,archiveurlclean,newdate,modelbar = ""

     # | publisher = web.archive.org
     let wag1 = "[|]" & GX.space & "[Pp][Uu][Bb][Ll][Ii][Ss][Hh][Ee][Rr]" & GX.space & "[=]" & GX.space & "[Ww][Ee][Bb][.][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg]" & GX.space
     let wag4 = "[|]" & GX.space & "[Pp][Uu][Bb][Ll][Ii][Ss][Hh][Ee][Rr]" & GX.space & "[=]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg]" & GX.space
     # | work = archive.org
     let wag2 = "[|]" & GX.space & "[Ww][Oo][Rr][Kk]" & GX.space & "[=]" & GX.space & "[Ww][Ee][Bb][.][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg]" & GX.space 
     let wag5 = "[|]" & GX.space & "[Ww][Oo][Rr][Kk]" & GX.space & "[=]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg]" & GX.space 
     # | website = archive.org
     let wag3 = "[|]" & GX.space & "[Ww][Ee][Bb][Ss][Ii][Tt][Ee]" & GX.space & "[=]" & GX.space & "[Ww][Ee][Bb][.][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg]" & GX.space 
     let wag6 = "[|]" & GX.space & "[Ww][Ee][Bb][Ss][Ii][Tt][Ee]" & GX.space & "[=]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg]" & GX.space 
     let wagall = wag1 & "|" & wag2 & "|" & wag3 & "|" & wag4 & "|" & wag5 & "|" & wag6

     c = patsplit(GX.articlework, field, GX.cite2, sep)
     if c > 0:
       for i in 0..c-1: # cycle through templates
         if citeignore(field[i]):
           continue
         if field[i] ~ "(?i)(cite tweet[ ]*[|])":  # {{cite tweet}} has no |url argument
           continue

         # Fix bug first: https://en.wikipedia.org/w/index.php?title=Manchester&type=revision&diff=739124701&oldid=738692510
         if getarg("url", "clean", field[i]) ~ "https?[:]/$":
           field[i] = replacearg(field[i], "url", getarg("archive-url", "clean", field[i]), "fixswitch1")

         # Fix if archive uses "*" for timestamp eg. archive.org/*/http.. 
         # newwebarchives
         var origtl = field[i]
         for g in 0..len(GX.service) - 1: # cycle through each service[g] (wayback, webcite, etc.)
           if g == 0:
             field[i] = fixswitchurl_helper(field[i], GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][*][/]")
           if g == 3: 
             field[i] = fixswitchurl_helper(field[i], GX.locgovre & "[/]?([WwAa]?[EeLl]?[BbLl]?|[Ll][Cc][Ww][Aa][0-9]{1,6})[/][*][/]")
           if g == 4:
             field[i] = fixswitchurl_helper(field[i], GX.portore & "[/]?[Ww]?[Aa]?[Yy]?[Bb]?[WwAa]?[EeCcLl]?[BbKkLl]?[/]?[Ww]?[Aa]?[Yy]?[Bb]?[WwAa]?[EeCcLl]?[BbKkLl]?[/][*][/]")
           if g == 5:
             field[i] = fixswitchurl_helper(field[i], GX.stanfordre  & "[/]?[Ww]?[Ee]?[Bb]?[/][*][/]")
           if g == 6:
             field[i] = fixswitchurl_helper(field[i], GX.archiveitre  & "[/]?[WwAa]?[EeLl]?[BbLl]?[/][*][/]")
           if g == 7:
             field[i] = fixswitchurl_helper(field[i], GX.bibalexre  & "[/]?[WwAa]?[EeLl]?[BbLl]?[/][*][/]")
           if g == 8:  
             field[i] = fixswitchurl_helper(field[i], GX.natarchivesukre & "([/]tna)?[/][*][/]")
           if g == 9:  
             field[i] = fixswitchurl_helper(field[i], GX.vefsafnre & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][*][/]")
           if g == 10:  
             field[i] = fixswitchurl_helper(field[i], GX.europare & "[/][Nn][Ll][Ii][/][*][/]")
           if g == 11:  
             field[i] = fixswitchurl_helper(field[i], GX.permaccre & "[/][Ww][Aa][Rr][Cc][/][*][/]")
           if g == 12:  
             field[i] = fixswitchurl_helper(field[i], GX.pronire  & "[/][*][/]")
           if g == 13:  
             field[i] = fixswitchurl_helper(field[i], GX.parliamentre  & "[/][*][/]")
           if g == 14:  
             field[i] = fixswitchurl_helper(field[i], GX.ukwebre  & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][Aa][Rr][Cc][Hh][Ii][Vv][Ee][/][*][/]")
           if g == 15:  
             field[i] = fixswitchurl_helper(field[i], GX.canadare  & "[*][/]")
           if g == 16:  
             field[i] = fixswitchurl_helper(field[i], GX.catalonre  & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][*][/]")
           if g == 17:  
             field[i] = fixswitchurl_helper(field[i], GX.singaporere  & "[*][/]")
           if g == 18:  
             field[i] = fixswitchurl_helper(field[i], GX.slovenere  & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][*][/]")
           if g == 20:  
             field[i] = fixswitchurl_helper(field[i], GX.webharvestre  & "[/][^/]*[/][*][/]")
           if g == 23:  
             field[i] = fixswitchurl_helper(field[i], GX.yorkre & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][*][/]")
           if g == 24:  
             field[i] = fixswitchurl_helper(field[i], GX.memoryre & "[/][Nn][Ll][Ii][/][*][/]")
           if g == 25:  
             field[i] = fixswitchurl_helper(field[i], GX.lacre & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][*][/]")

         if field[i] != origtl:
           continue

         if isarg("date", "value", field[i]):                     # Establish date format to use,, try date= format first..
           if dateformat(getarg("date","clean",field[i])) == "dmy":
             newdate = "1 January 1899"
           elif dateformat(getarg("date","clean",field[i])) == "mdy":
             newdate = "January 1, 1899"
           else:
             newdate = "1899-01-01"
         else:
           if isarg("access-date", "value", field[i]):            # ..then try access-date
             if dateformat(getarg("access-date","clean",field[i])) == "dmy":
               newdate = "1 January 1899"
             elif dateformat(getarg("access-date","clean",field[i])) == "mdy":
               newdate = "January 1, 1899"
             else:
               newdate = "1899-01-01"
           else:                                                  # default to iso
             newdate = "1899-01-01"

         for g in 0..len(GX.service) - 1: # cycle through each service[g] (wayback, webcite, etc.)

           var fullservice = "[|]" & GX.space & "[Uu][Rr][Ll]" & GX.space & "[=]" & GX.space & GX.service[g]

           # deal with archive.org URLs containing doubles+
           urlclean = getarg("url", "clean", field[i])
           if g == 0:
             urlcleanstrip = stripwayurlurl(urlclean)
           else:
             urlcleanstrip = urlclean

           if field[i] ~ fullservice: 
             if g == 21:                                          # Skip NLA Australia false positives
               if urlclean ~ "[.][Pp][Dd][Ff]|[.][Dd][Oo][Cc]|[.][Tt][Xx][Tt]|[Aa]ria[_]?awards?":
                 continue
             if urlurl(urlclean) !~ GX.shttp:                     # eg. a webcite URL with no "?url=http". Unable to fixswitch.
               if empty(urlurl(urlclean)):
                 sendlog(Project.logfixswitch, CL.name, urlclean & "  ---- warning : unable to fixswitch due to empty source URL ---- logfixswitch3")
                 continue

           # type1 and type2

           if isarg("archive-url","missing",field[i]) and field[i] ~ fullservice and field[i] !~ "archive[.]org/[0-9]{1,14}/items/" and not cbignorebareline(GX.articlework, field[i]) and GX.imp != "ModDel":

             if not dummydate(urlclean, "189908"):
               modelbar = getarg(firstarg(field[i]), "bar", field[i]) # model field format on first argument in template
             else:
               modelbar = getarg("url", "bar", field[i])              # unless 1899..08 model on url field itself to avoid minor edits
             urlcomplete = getarg("url", "bar", field[i])             # note: using "complete" here can cause trouble w/ wikicomments
                                                                      # https://en.wikipedia.org/w/index.php?title=Aubrey%E2%80%93Maturin_series&diff=771877255&oldid=767934751
             
             # change url= from archive to source URL
             var urlcompletenew = ""
             urlcompletenew = modelfield(modelbar, "url", formatedorigurl(urlurl(urlcleanstrip)))
             gsubs(urlcomplete, urlcompletenew, field[i])            

             # create new argument archiveurl using value of original url=  ie. urlclean
             if not empty(modelfield(modelbar, "archive-url", urlclean)):
               var archivebarnew = modelfield(modelbar, "archive-url", urlclean) 
               gsubs(urlcompletenew, urlcompletenew & archivebarnew, field[i])

               if isarg("archive-date", "missing" ,field[i]):                    # type 1
                 if not empty(modelfield(modelbar, "archive-date", "1899-01-01")):
                   gsubs(archivebarnew, archivebarnew & modelfield(modelbar, "archive-date", newdate), field[i])
               if isargempty("archive-date", field[i]):
                 field[i] = replacearg(field[i], "archive-date", "1899-01-01", "fixswitch1")
             
               if isarg("dead-url", "missing" ,field[i]):                 
                 if not empty(modelfield(modelbar, "dead-url", "yes")):
                   gsubs(archivebarnew, archivebarnew & modelfield(modelbar, "dead-url", "yes"), field[i])
               if isargempty("dead-url", field[i]):            
                 field[i] = replacearg(field[i], "dead-url", "yes", "fixswitch1")     

               if field[i] ~ wagall:
                 gsub(wagall,"",field[i])

               if not dummydate(urlclean, "189908"): 
                 inclog("fixswitchurl1.1", GX.esformat, Project.logfixswitch, urlclean & " ---- " & getarg("archive-url", "clean", field[i]) & " ---- logfixswitch1.1") 

           # type3 and type4

           elif isarg("archive-url", "exists", field[i]) and field[i] ~ fullservice and not cbignorebareline(GX.articlework, field[i]) and GX.imp != "ModDel":

             var archivebarnew = ""

             modelbar = getarg(firstarg(field[i]), "bar", field[i])
             urlfull = getarg("url", "full", field[i])
             urlcomplete = getarg("url", "bar", field[i])            # see note above about using "complete" vs "bar"
             archiveurlbar = getarg("archive-url", "bar", field[i])
             archiveurlclean = getarg("archive-url", "clean", field[i])

             if not empty(modelbar) and not empty(archiveurlbar):

               # replace url=http:/archive.org/2016/http://yahoo.com -> url=http://yahoo.com
               field[i] = replacearg(field[i], "url", formatedorigurl(urlurl(urlcleanstrip)), "fixswitch3.1")

               # replace archiveurl=http:/archive.org/2016/http://dodo.com -> http:/archive.org/2016/http://yahoo.com ie. clobber the old content of archiveurl
               archivebarnew = modelfield(modelbar, "archive-url", urlclean)
               gsubs(archiveurlbar, archivebarnew, field[i])

               if isarg("archive-date", "missing" ,field[i]):                    # type 3
                 if not empty(modelfield(modelbar, "archive-date", "1899-01-01")):
                   gsubs(archivebarnew, archivebarnew & modelfield(modelbar, "archive-date", newdate), field[i])
               if isargempty("archive-date", field[i]):
                 field[i] = replacearg(field[i], "archive-date", "1899-01-01", "fixswitch3.2")

               if isarg("dead-url", "missing" ,field[i]):                 
                 if not empty(modelfield(modelbar, "dead-url", "yes")):
                   gsubs(archivebarnew, archivebarnew & modelfield(modelbar, "dead-url", "yes"), field[i])
               if isargempty("dead-url", field[i]):                 
                 field[i] = replacearg(field[i], "dead-url", "yes", "fixswitch3.3")     

               if field[i] ~ wagall:
                 gsub(wagall,"",field[i])

               inclog("fixswitchurl2.1", GX.esformat, Project.logfixswitch, archiveurlclean & " ---- " & getarg("archive-url", "clean", field[i]) & " ---- logfixswitch2.1") 

       newart = unpatsplit(field, sep)

     if(len(newart) > 10 and GX.articlework != newart):
       GX.articlework = newart
       if not Runme.api:          # requires API to complete 
         Runme.api = true

#
# Delete {{dead link}}'s that follow the given "archive.org/details/" URL 
#
proc fixdeadtl_details(url: string): string =

    var
      body, head, bodyfilename = ""
      c, d = 0
      field, field2, sep, sep2 = newSeq[string](0)

    c = patsplit(GX.articlework, field, GX.dead, sep)
    if c > 0:
      for i in 0..c-1:
        if empty(sep[i]) and i == 0:  # if {{dead link}} at start of ref check the first URL after it
          d = patsplit(sep[i+1], field2, "[Hh][Tt][Tt][Pp][^\\s\\]}{<]*[^\\s\\]}{<]", sep2)
          if d > 0:
            if field2[0] ~ escapeRe(url):
              (head, bodyfilename) = getheadbody(url, "one")
              body = readfile(bodyfilename)
              if not empty(body):
                field[0] = ""
                inclog("fixdeadtl_details1", GX.esformat, Project.logstraydt, field2[0] & " --- fixdeadtl_details1", "noeditsum") 
          sep[i+1] = unpatsplit(field2, sep2)
        else:        
          d = patsplit(sep[i], field2, "[Hh][Tt][Tt][Pp][^\\s\\]}{<]*[^\\s\\]}{<]", sep2)
          if d > 0:
            if field2[d-1] ~ escapeRe(url):
              (head, bodyfilename) = getheadbody(url, "one")
              body = readfile(bodyfilename)
              if not empty(body):
                field[i] = ""        
                inclog("fixdeadtl_details2", GX.esformat, Project.logstraydt, field2[d-1] & " --- fixdeadtl_details2", "noeditsum") 
          sep[i] = unpatsplit(field2, sep2)
      GX.articlework = unpatsplit(field, sep)

    return GX.articlework

#
# Fix dead links to "/items/" by replacing with work URL
#  https://en.wikipedia.org/w/index.php?title=Clanculus_corallinus&type=revision&diff=765304281&oldid=765179600
#
proc fixitems(): bool {.discardable} =

  if Runme.fixitems != true:
    return

  var 
    field, sep, bank = newSeq[string](0)
    c, d = 0
    filename, head, bodyfilename, body, download, details = ""
    newart = GX.articlework

         # http://ia700307.us.archive.org/4/items/manualofconcholo111tryo/manualofconcholo111tryo.pdf 
  let re = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/]ia[^.]+[.][^.]+[.]archive[.]org[/][0-9]{1,3}[/]items[/][^\\s\\]|}{<]*[^\\s\\]|}{<]"
  c = patsplit(GX.articlework, field, re, sep)
  if c > 0:
    for i in 0..c-1:
      sendlog(Project.allitems, CL.name, field[i])
      var ok = 0
      if urlignore(field[i]):  # skip special cases
        continue

# Uncomment this to replace dead /items/ links only. Comment out to replace all instances of /items/
#
#      var status, response: int
#      for k in 0..1:
#        sed("Checking fixitems step " & $k, Debug.network)
#        (status, response) = webpagestatus(field[i], "one")
#        if status == 1 or status == 3: # page working
#          ok = 1
#          break

      if ok == 0:
        let orig = field[i]

        match(field[i], "[/]items[/][^/]*[^/]", workid)  # get workid
        gsub("^[/]items[/]","",workid)

        d = awk.split(field[i], fileid, "[/]")
        if d > 1:
          filename = fileid[d-1]
        else:
          continue

        download = "https://archive.org/download/" & workid & "/" & filename
        details  = "https://archive.org/details/" & workid

        # Edit policy: 
        #   "/download/" for all .mp3/mp4/.ogg/.gif/.jpg .. and for .pdf if page has no preview
        #   "/details/" everything else

        if filename ~ "[.][Pp][Dd][Ff]$":
          (head, bodyfilename) = getheadbody("https://archive.org/details/" & workid)
          body = readfile(bodyfilename)
          if not empty(body):
            if body ~ "[Nn]o[ ][Pp]review[ ][Aa]vailable":
              field[i] = download
            else:
              field[i] = details
          else:
            field[i] = details
        elif filename ~ "(?i)([.]ogg$|[.]mp[34]$|[.]gif$|[.]jpg$|[.]m3u$|[.]gz$|[.]zip$|[.]png$|[.]afpk$)":
          field[i] = download
        else:
          field[i] = details
        add(bank, field[i])
        inclog("fixitems1.1", GX.esformat, Project.logfixitems, orig & " ---- " & field[i]) 

    newart = unpatsplit(field, sep)

  if(len(newart) > 10 and GX.articlework != newart):
    GX.articlework = newart
    let bank2 = deduplicate(bank)
    for i in 0..len(bank2)-1:
      GX.articlework = fixdeadtl_details(bank[i])

#
# Final check cleanup and log of some missed fixes 
#
proc garbagecheck(): bool {.discardable} =

    var 
      field, sep = newSeq[string](0)
      c, d = 0
      s, robotstext, arturl, newart = ""

   # Cleanup missed wik.archive.org see fixiatis()
    if Runme.replacewikiwix:
      gsubs("https://wik.archive.org/web/", "http://archive.wikiwix.com/cache/", GX.articlework)

   # Remove "18990101080101" from cite templates
    c = patsplit(GX.articlework, field, GX.cite2, sep)
    if c > 0:
      for i in 0..c-1: # cycle through templates
        if citeignore(field[i]):
          continue
        if dummydate(getarg("archive-url", "clean", field[i]), "189908"):
          field[i] = removearchive(field[i], "garbagecheck_remove1", "nodeadlink", "nocbignore")
      GX.articlework = unpatsplit(field, sep)

   # fixiats and fixswitchurl
    if contains(stripwikicomments(GX.articlework), "18990101070101") or contains(stripwikicomments(GX.articlework), "18990101080101") or contains(stripwikicomments(GX.articlework), "19700101000000"):

      # For 1899 and 1970 dates:
      #   Change timestamp to "*" if it's blocked by robots and remove archivedate=
      #   Log as " error " if it's not blocked by robots and remove 18990101070101 entirely. 
      #   The reason is the API could not find a snapshot date to replace 1899 with, but best to keep links blocked by robots 

      let re2 = "(1899|1970)"

      # 18990101070101 | 18990101080101 | 19700101000000
      let re1 = re2 & "01010[870]0[10]0[10]"

      c = patsplit(GX.articlework, field, GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/]" & re1 & "[/]" & "[^\\s\\]|}{<]*[^\\s\\]|}{<]", sep)

      if c > 0 and existsFile(Project.meta & "robotstext"):

        robotstext = readfile(Project.meta & "robotstext")

        if not empty(robotstext):

          d = awk.split(robotstext, a, "\n")
          if d > 0:

            for i in 0..c-1: # loop through article URLs
              s = "no"
              if awk.split(field[i], p, re1) > 0:    # robotstext log file must contain an entry with 1899 .. be careful as sometimes it logs with a different date depending location of where webpagestatus() was called.. so it logs double to make sure
                arturl = GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][0-9]{4,14}" & re.escapeRe(p[1])
              else:
                continue
              for j in 0..d-1: # loop through log URLs

                if awk.split(a[j], b, "[ ]?[-][-][-][-][ ]?") > 1:

                  if formatediaurl( strip( removeport80(b[1])), "barelink") ~ removeport80(arturl):                  
                    s = "yes"
                    if GX.articlework ~ ("[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Uu][Rr][Ll]" & GX.space & "[=]" & GX.space & escapeRe(field[i])):
                      sendlog(Project.logiats, CL.name, " error : contains 18990101070101|1970010101000000 has robots.txt but is CS1 - deleting: " & field[i])
                      field[i] = ""
                    else:
                      sendlog(Project.logiats, CL.name, " warning : contains 18990101070101|1970010101000000 but has robots.txt - setting to * for: " & field[i])
                      gsub(re1, "*", field[i])
                    break

              if s == "no":
                if not dummydate(field[i], "189908"):
                  sendlog(Project.logiats, CL.name, " error : contains 18990101070101|1970010101000000 for unknown reason - search article for " & field[i])
                gsub("/?[Ww]?[Ee]?[Bb]?/" & re1, "", field[i])

            newart = unpatsplit(field,sep)
            GX.articlework = newart

      gsub("/?[Ww]?[Ee]?[Bb]?/" & re1, "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & re2 & "[-]01[-]01" & "[ ]{0,}[\\n]{0,}", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "January[ ]1[,][ ]" & re2 & "[ ]{0,}[\\n]{0,}", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "1[ ]January[ ]" & re2 & "[ ]{0,}[\\n]{0,}", "", GX.articlework)

  # Remove for sure
    if contains(GX.articlework, "18990101070101") or contains(GX.articlework, "1899-01-01") or contains(GX.articlework, "1 January 1899") or contains(GX.articlework, "January 1, 1899"):
      gsub("/?[Ww]?[Ee]?[Bb]?/18990101070101", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "1899[-]01[-]01" & "[ ]{0,}[\\n]{0,}", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "January[ ]1[,][ ]1899" & "[ ]{0,}[\\n]{0,}", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "1[ ]January[ ]1899" & "[ ]{0,}[\\n]{0,}", "", GX.articlework)

    if contains(GX.articlework, "18990101080101") or contains(GX.articlework, "1899-01-01") or contains(GX.articlework, "1 January 1899") or contains(GX.articlework, "January 1, 1899"):
      gsub("/?[Ww]?[Ee]?[Bb]?/18990101080101", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "1899[-]01[-]01" & "[ ]{0,}[\\n]{0,}", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "January[ ]1[,][ ]1899" & "[ ]{0,}[\\n]{0,}", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "1[ ]January[ ]1899" & "[ ]{0,}[\\n]{0,}", "", GX.articlework)

    if contains(GX.articlework, "/19700101000000/") or GX.articlework ~ ("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "1970[-]01[-]01" & GX.space):
      gsub("/?[Ww]?[Ee]?[Bb]?/19700101000000", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "1970[-]01[-]01[ ]" & "[ ]{0,}[\\n]{0,}", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "January[ ]1[,][ ]1970" & "[ ]{0,}[\\n]{0,}", "", GX.articlework)
      gsub("[ \\t]?[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space & "1[ ]January[ ]1970" & "[ ]{0,}[\\n]{0,}", "", GX.articlework)
      sendlog(Project.logiats, CL.name, " error : contains 19700101000000 for unknown reason - search article")

    # Remove empty archive-url and dead-url created by replacedeadtl() and removed above
    c = patsplit(GX.articlework, field, GX.cite, sep)
    if c > 0:
      for i in 0..c-1:
        if citeignore(field[i]):
          continue
        if isargempty("archive-url", field[i]):
          gsub("[|]" & GX.space & "archive[-]?url" & GX.space & "[=]" & GX.space, "", field[i])
          if isargempty("archive-date", field[i]):
            gsub("[|]" & GX.space & "archive[-]?date" & GX.space & "[=]" & GX.space, "", field[i])
          if getarg("dead-url", "clean", field[i]) == "yes":
            gsub("[|]" & GX.space & "dead-url" & GX.space & "[=]" & GX.space & "yes" & GX.space, "", field[i])
            inclog("garbagecheck_rmemptyarch1", GX.esformat, Project.logemptyarch, "stray deadurl=yes", "noeditsum nochanges")
        if isarg("archive-date", "exists", field[i]) and isarg("archive-url", "missing", field[i]):
          gsubs(getarg("archive-date", "complete", field[i]), "", field[i]) 
        if isarg("dead-url", "exists", field[i]) and isarg("archive-url", "missing", field[i]):
          gsubs(getarg("dead-url", "complete", field[i]), "", field[i]) 
          inclog("garbagecheck_rmemptyarch2", GX.esformat, Project.logemptyarch, "stray deadurl=", "noeditsum nochanges")
      GX.articlework = unpatsplit(field, sep)

    # Remove https://web.archive.org/http://www cases caused by {{cbignore}} blocking ability to save 1899 cases
    c = patsplit(GX.articlework, field, "https[:][/][/]web[.]archive[.]org[/][Hh][Tt][Tt][Pp][^\\s\\]|}{<]*[^\\s\\]|}{<]", sep)
    if c > 0:
      for i in 0..c-1:
        gsub("^https[:][/][/]web[.]archive[.]org[/]", "", field[i])
      GX.articlework = unpatsplit(field, sep)

  # fixwam
    if contains(GX.articlework, "{{wayback"):
      sendlog(Project.logwam, CL.name, " error : contains {{wayback}} - search article for {{wayback ")
    if contains(GX.articlework, "{{webcite"):
      sendlog(Project.logwam, CL.name, " error : contains {{webcite}} - search article for {{webcite ")
     
  # fixemptyarchive
    if contains(GX.articlework, "archivedate=January 1, 1970"):
      sendlog(Project.logemptyarch, CL.name, " error : contains 1970 date - search article for archivedate=January 1, 1970")
 
  # logiats nationalarchives "+" timestamp
    if GX.articlework ~ (GX.natarchivesukre & "[/][+][/][Hh][Tt][Tt][Pp]"):
      sendlog(Project.logiats, CL.name, " error : contains webarchive.nationalarchives.gov.uk with a + timestamp")

  # fix3slash
    if contains(GX.articlework, "https:///"):
      sendlog(Project.log3slash, CL.name, " error : contains https:/// search artcile for it")
    if contains(GX.articlework, "http:///"):
      sendlog(Project.log3slash, CL.name, " error : contains http:/// search artcile for it")

#
# Delete {{dead link}}'s that follow a URL which is an archive service
#  By "follow" meaning the last URL before the {{dead link}}, ignoring any other non-URL text in between
#
proc fixdeadtl(fullref: string): string =

    var
      c, d = 0
      fullref = fullref
      field, field2, sep, sep2 = newSeq[string](0)

    for k in 0..1: # run twice to catch adjacent dead links 
      c = patsplit(fullref, field, GX.deadcbignore, sep)
      for i in 0..c-1:
        if empty(sep[i]) and i == 0:  # if {{dead link}} at start of ref check the first URL after it
          d = patsplit(sep[i+1], field2, "[Hh][Tt][Tt][Pp][^\\s\\]}{<|]*[^\\s\\]}{<|]", sep2)
          if d > 0:
            if isarchive(field2[0], "all") and not dummydate(field2[d-1]):
              field[0] = ""
              inclog("fixdeadtl1.1", GX.esremoved, Project.logstraydt, field2[0] & " --- fixdeadtl1") 
          sep[i+1] = unpatsplit(field2, sep2)
        else:                            # if {{dead link}} follows an archive URL
          d = patsplit(sep[i], field2, "[Hh][Tt][Tt][Pp][^\\s\\]}{<|]*[^\\s\\]}{<|]", sep2)
          if d > 0:
            if isarchive(field2[d-1], "all") and not dummydate(field2[d-1]): # skip dummies as we'll remove {{dead link}} later otherwise has problem with bundled cites
              field[i] = ""        
              inclog("fixdeadtl2.1", GX.esremoved, Project.logstraydt, field2[d-1] & " --- fixdeadtl2.1") 

          sep[i] = unpatsplit(field2, sep2)
      fullref = unpatsplit(field, sep)

  # If a {{dead link}} lays in-between a URL and it's matching {{webarchive}} 
  # https://en.wikipedia.org/w/index.php?title=Wigan_Warriors&diff=prev&oldid=766237628

    c = patsplit(fullref, field, GX.deadcbignore, sep)
    if c > 0 and len(sep) > c:
      for i in 0..c-1:
        d = patsplit(sep[i + 1], field2, "[{][ ]?[{]" & GX.space & "[Ww]ebarchive[^}]+[}][ ]?[}]", sep2)
        if d > 0:
          var waurl = getarg("url", "clean", field2[0])                                        # first {{webarchive}} to the right of the {{dead link}}
          match(sep[0], "[Hh][Tt][Tt][Pp][^\\s\\]}{<|]*[^\\s\\]}{<|]", dest)
          if urlequal(dest, urlurl(waurl)):
            field[i] = ""
            inclog("fixdeadtl3.1", GX.esremoved, Project.logstraydt, waurl & " --- fixdeadtl2.1") 
      fullref = unpatsplit(field, sep)

    return fullref 

#
# Fix duplicate {{webarchive}} outside a ref - it doesn't fix it just logs it might exist - need to monitor logs and manually fix in article 
#
proc fixdoublewebarchiveoutside(): string {.discardable.} =

      var 
        ix = -1
        c, j, d, e = 0
        articlenoref, orig, url, url2, = ""
        field, field2, sep, sep2 = newSeq[string](0)

    # Remove references from article

      articlenoref = GX.articlework
      articlenoref = stripwikicommentsref(articlenoref)  # Remove wikicomments in case <ref></ref> is embeded in a comment
      gsub("<ref[^>]*/[ ]{0,}>", "", articlenoref)                                               # remove <ref name=string />    
      c = awk.split(articlenoref, articlenorefb, "<ref[^>]*>")             # remove <ref></ref>
      for i in 1..c-1:
        ix = index(articlenorefb[i], "</ref>")
        if ix > -1:
          gsubs(substr(articlenorefb[i], 0, ix), "", articlenoref)

      d = patsplit(articlenoref, field, "\n", sep)
      e = len(sep)
      for g in 0..e-1:
        j = 0
        orig = sep[g] 
        c = patsplit(sep[g], field2, "[{][ ]?[{]" & GX.space & "[Ww]ebarchive[^}]+[}][ ]?[}]", sep2)
        for i in countdown(c-1, 0):
          url = getarg("url", "clean", field2[i])
          inc(j)
          for m in countdown((c-1)-j, 0):
            url2 = getarg("url", "clean", field2[m])
            if url == url2:
              sendlog(Project.logdoublewebarchive, CL.name, url & " ---- fixdoublewebarchiveoutside")

#
# Fix duplicate {{webarchive}} in a ref 
#
proc fixdoublewebarchive(fullref, flag: string): string =

    var 
      field, field2, sep, sep2 = newSeq[string](0)
      c, j, z = 0
      url, url2 = ""
      fullref = fullref
      
  # Remove duplicate {{webarchive}}

    if flag == "cite":

      c = patsplit(fullref, field, "[{][ ]?[{]" & GX.space & "[Ww]ebarchive[^}]+[}][ ]?[}]", sep)
      if c > 0:
        for i in countdown(c-1, 0):
          url = getarg("url", "clean", field[i])
          inc(j)
          for m in countdown((c-1)-j, 0):
            url2 = getarg("url", "clean", field[m])
            if urlequal(url, url2):                             # same service domain and source url
              field[i] = ""
              inc(z)        
              sendlog(Project.logdoublewebarchive, CL.name, url & " ---- fixdoublewebarchive1")
            elif urlequal( urlurl(url), urlurl(url2) ):           # different service domain same source url
              field[i] = ""
              inc(z)        
              sendlog(Project.logdoublewebarchive, CL.name, url & " ---- fixdoublewebarchive2")

        fullref = unpatsplit(field,sep)
      
  # Remove {{webarchive}} if a preceeding {{cite}} template contains the same |archiveurl

    if flag == "cite":

      c = patsplit(fullref, field, "[{][ ]?[{]" & GX.space & "[Ww]ebarchive[^}]+[}][ ]?[}]", sep)
      if c > 0:
        for i in 0..c-1:
          if isarg("format", "value", field[i]):
            continue
          j = patsplit(sep[i], field2, GX.cite, sep2)
          if j > 0:
            if citeignore(field2[j-1]):
              continue
            url = getarg("url", "clean", field[i])
            if urlequal(url, getarg("archive-url", "clean", field2[j-1])):
              field[i] = ""
              inc(z)
              sendlog(Project.logdoublewebarchive, CL.name, url & " ---- fixdoublewebarchive3")
        fullref = unpatsplit(field,sep)
 
  # Remove {{webarchive}} if a preceeding [bare link] contains an archive URL that is same, or same source URL

    if flag == "barelink":

      c = patsplit(fullref, field, "[{][ ]?[{]" & GX.space & "[Ww]ebarchive[^}]+[}][ ]?[}]", sep)
      if c > 0:
        for i in 0..c-1:
          var wurlbase = getarg("url", "clean", field[i])
          if wurlbase == "":
            continue
          if isarg("format", "value", field[i]):
            continue
          var wurlsource = tolowerAscii(urlurl(wurlbase))
          if wurlsource == "":
            continue
          var j = patsplit(sep[i], field2, "[[]" & GX.space & "[Hh][Tt][Tt][Pp][^]]*[]]", sep2)
          if j > 0 and isarchive(stripfullel(field2[j-1]), "all"):
            var burlbase = stripfullel(field2[j-1])
            if burlbase == "":
              continue
            var burlsource = tolowerAscii(urlurl(burlbase))
            if burlsource == "":
              continue
            if urlequal(burlbase, wurlbase) or urlequal(burlsource, wurlsource):
              field[i] = ""
              inc(z)
              sendlog(Project.logdoublewebarchive, CL.name, url & " ---- fixdoublewebarchive4")
        fullref = unpatsplit(field,sep)

    if z > 0:
      inc(GX.esremoved)
      incchanges(1, "fixdoublewebarchive")

    return fullref


#
# Fix a special reference mangled a certain way
#  https://en.wikipedia.org/w/index.php?title=Barnizal&diff=prev&oldid=763919601
#
proc fixnowikiway(): string {.discardable.} =

     let s1 = "<ref name=inec>[http://www.contraloria.gob.pa/inec/archivos/P3601Cuadro11.xls \"Cuadro 11 (Superficie, población y densidad de población en la República...)\" [Table 11 (Area, population, and population density in the Republic...)<nowiki>] {{wayback|url=http://www.contraloria.gob.pa/inec/archivos/P3601Cuadro11.xls |date=20160304030354 }}</nowiki>] (.xls)."
     let r1 = "<ref name=inec>[http://www.contraloria.gob.pa/inec/archivos/P3601Cuadro11.xls \"Cuadro 11 (Superficie, población y densidad de población en la República...)\"] {{webarchive|url=https://web.archive.org/web/20160304030354/http://www.contraloria.gob.pa/inec/archivos/P3601Cuadro11.xls |date=2016-03-04 }} Table 11 (Area, population, and population density in the Republic...) (.xls)."

     if contains(GX.articlework, s1):
       gsubs(s1, r1, Gx.articlework)
       inclog("fixnowikiway1.1", GX.esformat, Project.lognowikiway, "fixnowikiway1.1") 

#
# Remove embedded {{cite web}} in a {{webarchive}}
#  https://en.wikipedia.org/w/index.php?title=Leeds&diff=prev&oldid=763366265
#
proc fixembwebarchive(): string {.discardable.} =

     var
       field = newSeq[string](0)
       sep = newSeq[string](0)
       c = 0
       newart = ""

     # match on {{webarchive
     let re1 = "[{][ ]?[{]" & GX.space & "[Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee]"

     # match on {{cite..}}
     let re2 = "[{][ ]?[{]" & GX.space & "[Cc][Ii][Tt][Ee][^}]*[}][ ]?[}]"

     # match on {{webarchive |url=http://<whatever>.archive.org/20160101010101/{{cite .. }}
     let re3 = re1 & GX.space & "[|]" & GX.space & "[Uu][Rr][Ll]" & GX.space & "[=]" & GX.space & GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][0-9]{8,14}[/]" & re2

  # Remove embedded {{cite web}} in a {{webarchive}}

     # {{webarchive |url=https://web.archive.org/web/20110814071837/{{cite web .. }}
     c = patsplit(GX.articlework, field, re3, sep)
     if c > 0:
       for i in 0..c-1:
         match(field[i], re2, a) 
         gsubs(a, "", field[i])                            # delete embeded {{cite..}}
         field[i] = field[i] & getarg("url", "clean", a)   # replace with value of |url from deleted cite
         inclog("fixembwebarchive1.1", GX.esformat, Project.logembwebarchive, "fixembwebarchive1.1") 
       newart = unpatsplit(field, sep)       
       if(len(newart) > 10 and GX.articlework != newart):
         GX.articlework = newart

#
# Remove embedded {{webarchive}} inside a cite template (run after fixwam() has converted everything to {{webarchive}})
#   https://en.wikipedia.org/w/index.php?title=Capital_Crescent_Trail&type=revision&diff=749487141&oldid=748127223
# Remove embedded {{cite web}} inside a cite template
#  https://en.wikipedia.org/w/index.php?title=Gary_Mandy&type=revision&diff=758922525&oldid=728298854
# Also, remove mangled webarchive with invalid url= 
#   https://en.wikipedia.org/w/index.php?title=Eric_Roberts&type=revision&diff=756608316&oldid=756569292
#
# https://phabricator.wikimedia.org/T154884
#
proc fixembway(): string {.discardable} =

     var
       field, field2 = newSeq[string](0)
       sep, sep2 = newSeq[string](0)
       c = 0
       d = 0
       count = 0
       newart, safe = ""

     # match on citation templates
     # let re = "[{][{][ ]{0,}[Cc]ite[^}]+}}|[{][{][ ]{0,}[Cc]ita[^}]+}}|[{][{][ ]{0,}[Vv]cite[^}]+}}|[{][{][ ]{0,}[Vv]ancite[^}]+}}|[{][{][ ]{0,}[Hh]arvrefcol[^}]+}}|[{][{][ ]{0,}[Cc]itation[^}]+}}"

     # match on {..|
     let re4 = "[{][^|]*[^|]"

     # match on {{webarchive/wayback/webcite
     let re6 = "[{][ ]?[{]" & GX.space & "[Ww]?[Ee]?[Bb]?[WwAa][EeAaRr][BbYyCc][CcBbHh][AaIi][TtCcVv][KkEe]"

     # match on {{webarchive/wayback/webcite|url=http://<whatever>.archive.org/
     let re2 = re6 & GX.space & "[|]" & GX.space & "[Uu][Rr][Ll]" & GX.space & "[=]" & GX.space & GX.iare & "[/]"

     # match on {{webarchive/wayback/webcite|url=http://<whatever>.archive.org/web/20160707000000/http://<whatever>.archive.org/http:/ |
     let re7 = re2 & "[/]?[Ww]?[Ee]?[Bb]?[/]?[0-9*]{1,14}[/]" & GX.iare & "[/][Hh][Tt][Tt][Pp][Ss]?[:][/][ ]{0,}[|]"

     # match on {{dead link
     let re8 = "[{][ ]?[{]" & GX.space & "[Dd][Ee][Aa][Dd][ -]?[Ll][Ii][Nn][Kk]"

     # match on _{{cite..}}
     let re5 = GX.space & "[{][ ]?[{]" & GX.space & "[Cc][Ii][Tt][Ee][^}]*[}][ ]?[}]"

     # match on |url={{cite .. }}
     let re3 = "[|]" & GX.space & "[Aa]?[Rr]?[Cc]?[Hh]?[Ii]?[Vv]?[Ee]?[-]?[Uu][Rr][Ll]" & GX.space & "[=]" & re5

     # match on |archiveurl=http://web.archive.org/web/20160101000000{{cite .. }}
     let re9 = "[|]" & GX.space & "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Uu][Rr][Ll]" & GX.space & "[=]" & GX.space & GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][0-9]{8,14}[/]" & re5


  # Find and log template names causing |url={{cite .. }} problems so they can be added to IABot's on-wiki configuration page
  #  https://en.wikipedia.org/wiki/User:InternetArchiveBot/Dead-links.js

     c = patsplit(GX.articlework, field, GX.cite2, sep)
     if c > 0:
       for i in 0..c-1:
         if field[i] ~ re3:
           match(field[i], re4, a)
           if not empty(a):
             gsub("^[{]{1,2}","",a)
             sendlog(Project.logembway, CL.name, " " & strip(a) & " ---- fixembway4")

  # Remove embedded {{cite web}} in another {{cite web}} at the |url= location

     # |url={{cite .. }}
     c = patsplit(GX.articlework, field, re3, sep)
     if c > 0:
       for i in 0..c-1:
         match(field[i], re5, a) 
         gsubs(a, "", field[i])               # delete embeded {{cite..}}
         field[i] = field[i] & getarg("url", "clean", a)   # replace with value of |archiveurl from deleted cite
         inclog("fixembway1.1", GX.esformat, Project.logembway, "fixembway3") 
       newart = unpatsplit(field, sep)       
       if(len(newart) > 10 and GX.articlework != newart):
         GX.articlework = newart

  # Remove embedded {{cite web}} in another {{cite web}} at the |archiveurl= location

     c = patsplit(GX.articlework, field, re9, sep)
     if c > 0:
       for i in 0..c-1:
         match(field[i], re5, a) 
         gsubs(a, "", field[i])               # delete embeded {{cite..}}
         gsubs(GX.space & GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][0-9]{8,14}[/]", "", field[i]) # delete truncated wayback link
         field[i] = field[i] & getarg("archive-url", "clean", a)   # replace with value of |archive-url from deleted cite
         inclog("fixembway2.1", GX.esformat, Project.logembway, "fixembway7") 
       newart = unpatsplit(field, sep)       
       if(len(newart) > 10 and GX.articlework != newart):
         GX.articlework = newart

  # Remove embedded {{webarchive}} in a {{cite web}}

     c = patsplit(GX.articlework, field, re6 & "[^}]*[}][ ]?[}]", sep)
     if c > 0:
       for i in 0..c-1:
         awk.gsub("^[{][ ]?[{]", "AaWaybackMedicFixembway", field[i])
         awk.gsub("[}][ ]?[}]$", "ZzWaybackMedicFixembway", field[i])

       newart = unpatsplit(field, sep)

       d = patsplit(newart, field2, GX.cite2, sep2)
       if d > 0:
         for i in 0..d-1:
           if citeignore(field2[i]):
             continue
           if field2[i] ~ "AaWaybackMedicFixembway":
             var s = awk.index(field2[i], "AaWaybackMedicFixembway")
             if s != 0:
               s = s - 1
             var e = awk.index(field2[i], "ZzWaybackMedicFixembway") + 23
             if e <= len(field2[i]) - 1:
               safe = system.substr(field2[i], 0, s) & system.substr(field2[i], e, len(field2[i]) - 1)
               if len(safe) > 10:

                 field2[i] = safe
                 inc(count)
                 sendlog(Project.logembway, CL.name, "fixembway2")

                 match(field2[i], re4, a)  
                 if not empty(a):
                   gsub("^[{]{1,2}","",a)
                   sendlog(Project.logembway, CL.name, " " & strip(a) & " ---- fixembway7")

       if count > 0:
         newart = unpatsplit(field2, sep2)     

       gsubs("ZzWaybackMedicFixembway", "}}", newart)
       gsubs("AaWaybackMedicFixembway", "{{", newart)

       if(len(newart) > 10 and GX.articlework != newart):
         GX.articlework = newart
         GX.esformat = GX.esformat + count
         incchanges(count, "fixembway3")

  # Move embedded {{dead link}} in a {{cite web}}

     c = patsplit(GX.articlework, field, re8 & "[^}]*[}][ ]?[}]", sep)
     if c > 0:
       for i in 0..c-1:
         awk.gsub("^[{][ ]?[{]", "AaWaybackMedicFixembway", field[i])
         awk.gsub("[}][ ]?[}]$", "ZzWaybackMedicFixembway", field[i])

       newart = unpatsplit(field, sep)

       d = patsplit(newart, field2, GX.cite2, sep2)
       if d > 0:
         for i in 0..d-1:
           if citeignore(field2[i]):
             continue
           if field2[i] ~ "AaWaybackMedicFixembway":
             var s = awk.index(field2[i], "AaWaybackMedicFixembway")
             if s != 0:
               s = s - 1
             var e = awk.index(field2[i], "ZzWaybackMedicFixembway") + 22
             if e <= len(field2[i]) - 1:
               var tl = system.substr(field2[i], s + 1, e)
               safe = system.substr(field2[i], 0, s) & system.substr(field2[i], e + 1, len(field2[i]) - 1)
               if len(safe) > 10:
                 field2[i] = safe & tl
                 inc(count)
                 sendlog(Project.logembway, CL.name, "fixembway6")

       if count > 0:
         newart = unpatsplit(field2, sep2)     

       gsubs("ZzWaybackMedicFixembway", "}}", newart)
       gsubs("AaWaybackMedicFixembway", "{{", newart)
       if(len(newart) > 10 and GX.articlework != newart):
         GX.articlework = newart
         GX.esformat = GX.esformat + count
         incchanges(count, "fixembway4")

  # Find and log any remaining cases that need manual intervention, they were unable to be fixed automatically

     c = patsplit(GX.articlework, field, GX.cite, sep)
     if c > 0:
       for i in 0..c-1:
         if field[i] ~ re3:
           match(field[i], re4, a)
           if not empty(a):
             gsub("^[{]{1,2}","",a)
             sendlog(Project.logembway, CL.name, " " & strip(a) & " ---- fixembway5")

  # Remove mangled webarchive with invalid url=

     c = patsplit(GX.articlework, field, re6 & "[^}]*[}][ ]?[}]", sep)
     if c > 0:
       for i in 0..c-1:
         var cre1 = re2 & "[Hh][Tt][Tt][Pp][Ss]?[:][/]" & GX.space & "[|]" & "[^}]*[}][ ]?[}]"
         var cre2 = re7 & "[^}]*[}][ ]?[}]"
         if field[i] ~ cre1 or field[i] ~ cre2:
           field[i] = ""
           inclog("fixembway5.1", GX.esformat, Project.logembway, "fixembway1") 
       newart = unpatsplit(field, sep)
       if GX.articlework != newart and len(newart) > 10:
         GX.articlework = newart

#
# fixthespuriousone (Rev: B)
#   B: changed from "1=" to "[1-9]="
#   C: added "<" to regex 
#
# Remove spurious "|1=" from cite templates
#    https://en.wikipedia.org/w/index.php?title=List_of_Square_Enix_video_games&curid=1919116&diff=704745846&oldid=703682254
#
proc fixthespuriousone(tl: string): string =

  if Runme.fixthespuriousone != true:
    return tl

  if awk.match(tl, "[|]" & GX.space & "[1-9]{1,2}" & GX.space & "[=]" & GX.space & "[^|}<]*", s) > 0:
    if not empty(s):
      if awk.split(s, a, "[=]") == 2:
        if len(strip(a[1])) == 0:
          inclog("fixthespuriousone1.1", GX.esformat, Project.logspurone, "fixthespuriousone1.1")  # was incorrectly loged as "cite1" before Feb 7 2018
          return replacetext(tl, s, "", "fixspuriousone1.1")

  return tl

#
# fixencodedurl (Rev: A)  
#
# Fix when a url= is encoded incorrectly in a cite template.
#  eg. http%3A%2F%2Fwww.advocate.com%2FArts_and_Entertainment%2FPeople%2F70_Is_the_New_40%2F
#  https://en.wikipedia.org/w/index.php?title=Jim_Morris_%28bodybuilder%29&type=revision&diff=709196054&oldid=703186121
#
proc fixencodedurl(tl: string): string =

  var url, uxurl = ""
  var tl = tl

  if Runme.fixencodedurl != true:
    return tl

  if datatype(tl,"cite"):
    url = getarg("url", "clean", tl)
    if url ~ "^[Hh][Tt][Tt][Pp][Ss]{0,1}[%]3A[%]2F[%]2F":
      uxurl = uriparseEncodeurl(urldecode(url))         
      tl = replacearg(tl, "url", uxurl, "fixencoded1")
      inclog("fixencodedurl1.1", GX.esrescued, Project.logencode, url & " " & uxurl & " ---- fixencodedurl1.1") 
      return tl

  return tl

#
# Helper function for fixemptyarchive()
#
proc fixemptyarchive_remove(tl: string, addedarg: int): string = 

  var
    tl = tl
  let 
    re1 = "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]" & GX.space & "[=]" & GX.space
    re2 = "January[ ]1[,][ ]1970"
    re3 = "1[ ]January[ ]1970"
    re4 = "1970[-]01[-]01"
    re5 = re1 & re2 & "|" & re1 & re3 & "|" & re1 & re4 

  # if  .. archiveurl= |archivedate=January 1, 1970 ..

  if tl ~ re5:
   # Remove the empty arguments if 1970 date. No dead link since it is working.
    inclog("fixemptyarchive_remove1", GX.esremoved, Project.logemptyarch, " ---- fixemptyarchive_remove1") 
    return removearchive(tl, "fixemptyarchive_remove1", "nodeadlink", "nocbignore")

  elif addedarg == 1:
   # Remove the empty arguments if they are empty and one was recently added by fixemptyarchive()
    inclog("fixemptyarchive_remove2", GX.esremoved, Project.logemptyarch, " ---- fixemptyarchive_remove2") 
    return removearchive(tl, "fixemptyarchive_remove2", "nodeadlink", "nocbignore")

  else:                                         # Else keep them
    return tl

#
# fixemptyarchive (Rev: B)
#   B: overhauled. No longer tries to find a new URL.
#
# Fix where archive-url= and/or archivedate is empty or missing
#   If url= is not working, add an archiveurl with timestamp 1970 and send off to API 
#   If url= is working, remove the archiveurl/archivedate/deadurl arguments
#
proc fixemptyarchive(tl, target: string): string =

  var
    tl = tl 
    url, urlencoded, urlarch, newdate, deadstatus, cbstatus, modelbar, locbar = ""
    status, response = -1
    addedarg = 0
    embedded = "[{][ ]?[{][^{]*[{][ ]?[{]"  # check for embedded templates

  if Runme.fixemptyarchive != true:
    return tl

  # Function can't reliably parse templates with embeded templates eg. |date={{date|2016-06-06}}
  # https://en.wikipedia.org/w/index.php?title=History_of_tropical_cyclone-spawned_tornadoes&type=revision&diff=782020949&oldid=781609746  

  # For cite temlates, add a missing archiveurl field
  #   note: datatype() requires existence of both archivedate and archiveurl fields .. so add them first if missing.

  if isarg("archive-date", "exists", tl) and isarg("archive-url", "missing", tl) and tl !~ embedded:
    modelbar = getarg(firstarg(tl), "bar", tl)                               # model field format on first argument in template
    locbar = getarg(notlastarg(tl, "archive-url"), "bar", tl) 
    if isarg("url", "exists", tl):
      if isarg("archive-date", "value", tl):                                 # archive-date has content
        if not empty(modelfield(modelbar, "archive-url", " ")):
          gsubs(locbar, locbar & modelfield(modelbar, "archive-url", " "), tl)       
          addedarg = 1
      else:                                                                  # archive-date has no content
        if getarg("archive-date", "complete", tl) !~ "[<][ ]?[!][ ]?[-][-]": # skip if field contains wikicomment eg. archivedate=<!-- comment -->
          if not empty(modelfield(modelbar, "archive-url", " ")):
            gsubs(locbar, locbar & modelfield(modelbar, "archive-url", " "), tl)       
            addedarg = 1

  # Add a missing archivedate field
  #   note: datatype() requires existence of both archivedate and archiveurl fields .. so add them first if missing.

  if isarg("archive-url", "exists", tl) and isarg("archive-date", "missing", tl) and tl !~ embedded: 
    if not isarchive(getarg("archive-url", "clean", tl), "sub3"):        # for 14-digit type URLs only
      return tl
    if isarg("url", "exists", tl):
      modelbar = getarg(firstarg(tl), "bar", tl)                
      locbar = getarg(notlastarg(tl, "archive-date"), "bar", tl) 
      urlarch = getarg("archive-url", "clean", tl)
      if not empty(urlarch):                                             # archiveurl exists but has non-empty value
        newdate = urldate(urlarch, getarg("date", "clean", tl), "")                     
        if newdate != "error":
          if not empty(modelfield(modelbar, "archive-date", newdate)):
            gsubs(locbar, locbar & modelfield(modelbar, "archive-date", newdate), tl)  
            addedarg = 1
            inclog("fixemptyarchive1", GX.esformat, Project.logemptyarch, urlarch & " ---- nonempty archiveurl value", "noeditsum") 
        else:
          sendlog(Project.logemptyarch, CL.name, " error unknown altarchive date in fixemptyarchive ---- " & urlarch)
          return tl
      else:                                                            # archiveurl exists but has empty value
        if getarg("archive-url", "complete", tl) !~ "[<][ ]?[!][ ]?[-][-]": # skip if field contains wikicomment eg. archiveurl=<!-- comment -->
          if not empty(modelfield(modelbar, "archive-date", " ")):
            gsubs(locbar, locbar & modelfield(modelbar, "archive-date", " "), tl)       
            addedarg = 1
            inclog("fixemptyarchive2", GX.esformat, Project.logemptyarch, "empty archiveurl value", "noeditsum") 

  # Add a missing dead-url field

  if isarg("archive-url", "exists", tl) and isarg("archive-date", "exists", tl) and isarg("dead-url", "missing", tl) and addedarg == 1 and tl !~ embedded: 
    if isarg("url", "exists", tl):
      modelbar = getarg(firstarg(tl), "bar", tl)                 
      locbar = getarg(notlastarg(tl, "dead-url"), "bar", tl) 
      if not empty(modelbar):
        if not empty(modelfield(modelbar, "dead-url", "no")):
          gsubs(locbar, locbar & modelfield(modelbar, "dead-url", "no"), tl)       
          addedarg = 1
                       
  # If archiveurl=<empty> and url=<empty|missing>
  if datatype(tl,"cite") and isargempty("archive-url", tl) and (isarg("url", "empty", tl) or isarg("url", "missing", tl)):
    inclog("fixemptyarchive3", GX.esremoved, Project.logemptyarch, "empty archiveurl and url value") 
    return fixemptyarchive_remove(tl, addedarg)

  if datatype(tl,"cite") and isargempty("archive-url", tl):

    url = getarg("url", "clean", tl)
    urlencoded = uriparseEncodeurl(urldecode(url))

    if urlencoded ~ GX.shttp:

      sed("Checking fixemptyarchive step 1", Debug.network)
      (status, response) = webpagestatus(url, "one")
      if status == 1 or status == 3:              # Leave empty arguments in place if url= is working (unless addedarg = 1 then remove both)
        return fixemptyarchive_remove(tl, addedarg)

      sed("Checking fixemptyarchive step 2", Debug.network)
      (status, response) = webpagestatus(urlencoded, "one")
      if status == 1 or status == 3:              # Try again with encoding
        return fixemptyarchive_remove(tl, addedarg)

      sed("Checking fixemptyarchive step 3", Debug.network)
      libutils.sleep(2)
      (status, response) = webpagestatus(url, "one")
      if status == 1 or status == 3:              # Try third time after pause
        return fixemptyarchive_remove(tl, addedarg)

      # Try to get new via API by flagging as 1970
      if isargempty("archive-date", tl) or getarg("archive-date", "clean", tl) ~ "1970|1899":
        tl = replacearg(tl, "archive-url", "https://web.archive.org/web/19700101000000/" & urlencoded, "fixemptyarch2")
        tl = replacearg(tl, "archive-date", "1970-01-01", "fixemptyarch1")
        if isarg("dead-url", "missing", tl): # add missing argument
          var locbar = getarg(notlastarg(tl, "dead-url"), "bar", tl)
          gsubs(locbar, locbar & modelfield(getarg(firstarg(tl), "bar", tl), "dead-url", "yes"), tl)       
        else:
          tl = replacearg(tl, "dead-url", "yes", "fixemptyarch4")
        if not Runme.api: # requires API to complete 
          Runme.api = true
        inclog("fixemptyarchive4", GX.esremoved, Project.logemptyarch, url & " ---- reset to 1970") 
        return tl
      else:  # a valid date in archivedate
        var ts = getargarchivedatestamp(tl)
        if validate_datestamp(ts):
          if len(ts) == 8:
            ts = ts & "010101"

          tl = replacearg(tl, "archive-url", "https://web.archive.org/web/" & ts  & "/" & urlencoded, "fixemptyarch3")
          if isarg("dead-url", "exists", tl):
            tl = replacearg(tl, "dead-url", "yes", "fixemptyarch3.2")
          else:                                                        # add dead-url
            modelbar = getarg(firstarg(tl), "bar", tl)                 
            locbar = getarg(notlastarg(tl, "dead-url"), "bar", tl) 
            if not empty(modelbar):
              if not empty(modelfield(modelbar, "dead-url", "yes")):
                gsubs(locbar, locbar & modelfield(modelbar, "dead-url", "yes"), tl)       
          if not Runme.api: # requires API to complete 
            Runme.api = true
          inclog("fixemptyarchive5", GX.esremoved, Project.logemptyarch, url & " ---- reset to archivedate value") 
          return tl

      # cleanup
      if isarg("archive-url", "empty", tl):
       # Remove the empty arguments and leave a dead link tag
        # Does tl already contain a {{dead link}} and/or {{cbignore}}?
        if target !~ "outside" and tl ~ GX.dead:
          deadstatus = "nodeadlink"
        if target !~ "outside" and tl ~ GX.cbignore:
          cbstatus = "nocbignore"
        elif target ~ "outside" and deadlinkbareline(GX.articlework, tl):
          deadstatus = "nodeadlink"
        elif target ~ "outside" and cbignorebareline(GX.articlework, tl):
          cbstatus = "nocbignore"
        inclog("fixemptyarchive6", GX.esremoved, Project.logemptyarch, url & " ---- logemptyarch1") 
        return removearchive(tl, "fixemptyarchive1", deadstatus, cbstatus)

    # If empty archivedate value, but archiveurl has content, then add date from archiveurl
    #  If template contains an embedded template eg. {{cite web|url=..{{dead link}} | date=..}}
    #    ..skip it because I don't have code to reliably parse embeded templates and otherwise could lead to double archivedate= fields
    #    See User_talk:GreenC_bot#Duplicate_arguments.3F (August 31 2016)

  if isargempty("archive-date", tl) and isarg("archive-url", "value", tl) and isarg("url", "exists", tl):
    urlarch = getarg("archive-url", "clean", tl)
    if isarchive(urlarch, "sub3") and tl !~ embedded:
      newdate = urldate(urlarch, getarg("access-date", "clean", tl), "")
      if newdate != "error":
        tl = replacearg(tl, "archive-date", newdate, "fixemptyarchive1")
        inclog("fixemptyarchive7", GX.esformat, Project.logemptyarch, urlarch & " ---- logemptyarch2", "noeditsum") 
        return tl

  return tl

#
# Fix empty or missing arguments in webarchive template
#
#
proc fixemptywebarchive(tl: string): string =

  var
    urlarch, modelbar, newdate, titl, m = ""
    tl = tl
    i = 0

  if isarg("archive-url", "exists", tl) and isarg("url", "missing", tl):  
    awk.sub("archive[-]?url", "url", tl)
  if isarg("archive-date", "exists", tl) and isarg("date", "missing", tl):
    awk.sub("archive[-]?date", "date", tl)

  if isarg("url", "missing", tl) and isarg("url1", "missing", tl):
    sendlog(Project.logemptyarch, CL.name, " error missing url in fixemptywebarchive1")
    return tl

  m = ",1,2,3,4,5,6,7,8,9,10"
  i = awk.split(m,n,",")
  for j in 0..i-1:
    if isarg("url" & n[j], "exists", tl) and (isarg("date" & n[j], "missing", tl) or isarg("date" & n[j], "empty", tl)): 
      urlarch = getarg("url" & n[j], "clean", tl)
      modelbar = getarg("url" & n[j], "complete", tl) 
      if not empty(urlarch):                                             # url arg exists and has non-empty value
        newdate = urldate(urlarch, "", "")                     
        if newdate != "error":
          if not empty(modelfield(modelbar, "date" & n[j], newdate)):
            if isarg("date" & n[j], "missing", tl):
              gsubs(modelbar, modelbar & modelfield(modelbar, "date" & n[j], newdate), tl)  
            elif isargempty("date" & n[j], tl):
              tl = replacearg(tl, "date" & n[j], newdate, "fixemptywebarchive1")
            inclog("fixemptywebarchive1.1", GX.esformat, Project.logemptyarch, urlarch & " ---- logemptywebarch1.1", "noeditsum") 

           # remove "(archived 2010-01-01)" from title string added by a certain user
            if isarg("title" & n[j], "value", tl):
              titl = getarg("title" & n[j], "clean", tl)
              if titl ~ "[(][ ]*[Aa]rchived[ ][^)]*[)]":
                awk.gsub("[(][ ]*[Aa]rchived[ ][^)]*[)]", "", titl)
                tl = replacearg(tl, "title" & n[j], titl, "fixemptywebarchive2")

          else:
            sendlog(Project.logemptyarch, CL.name, " error modelfield unknown in fixemptywebarchive3 ---- " & urlarch)
            return tl
        else:
          sendlog(Project.logemptyarch, CL.name, " error newdate unknown in fixemptywebarchive4 ---- " & urlarch)
          return tl
      else:                                                            # url arg exists but has empty value
        sendlog(Project.logemptyarch, CL.name, " error empty url in fixemptywebarchive5")
        return tl

  return tl

#
# fixdatemismatch (Rev: A)
#
# Fix where snapshot date doesn't match archivedate in citation or webarchive templates
#
proc fixdatemismatch(ttl: string): string =

  var
    tl = ttl
    archiveurl, archiveurldate, archivedate, numericstatus = ""

  if Runme.fixdatemismatch != true:
    return tl
  
  if datatype(tl,"cite"):

    archiveurl = getarg("archive-url", "clean", tl)
    archivedate = getarg("archive-date", "clean", tl)

    if archivedate ~ "[{][{]":  # skip embedded date template
      return tl

    # newwebarchives 
    if isarchive(archiveurl, "sub2"):

      if not empty(dateformat(archivedate)):
        var ts = urltimestamp(archiveurl)
        if ts ~ "^[0-9]{8,14}$":
          var dummy = "https://web.archive.org/web/" & ts & "/https://wikipedia.org"
          archiveurldate = urldate(dummy, archivedate, archivedate)
          if archiveurldate != "error":
            if archiveurldate != archivedate:
              tl = replacearg(tl, "archive-date", archiveurldate, "fixdatemismatch8.1")
              inclog("fixdatemismatch8.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch8.1") 
              return tl

    elif isnlaau(archiveurl):

      if not empty(dateformat(archivedate)):
        archiveurldate = nlaautodate(archiveurl, archivedate)
        if archiveurldate !~ "error":
          if archiveurldate != archivedate:
            tl = replacearg(tl, "archive-date", archiveurldate, "fixdatemismatch11.1")
            inclog("fixdatemismatch11.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch11.1") 
            return tl
        elif archiveurldate == "error":
          sendlog(Project.logdatemismatch, CL.name, archiveurl & " ---- error : unknown date in NLA.GOV.AU")
          return tl
        else:
          return tl
            
    elif iswebcite(archiveurl):

      if not empty(dateformat(archivedate)):
        archiveurldate = base62todate(archiveurl, dateformat(archivedate))
        if archiveurldate !~ "error|nobase62":
          if archiveurldate != archivedate:
            tl = replacearg(tl, "archive-date", archiveurldate, "fixdatemismatch5.1")
            inclog("fixdatemismatch5.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch5.1") 
            return tl
        elif archiveurldate == "error":
          sendlog(Project.logdatemismatch, CL.name, archiveurl & " ---- error : base62 date unknown")
          return tl
        else:
          return tl

    elif isfreezepage(archiveurl):

      if not empty(dateformat(archivedate)):
        archiveurldate = freezedate(archiveurl, dateformat(archivedate))
        if archiveurldate !~ "error":
          if archiveurldate != archivedate:
            tl = replacearg(tl, "archive-date", archiveurldate, "fixdatemismatch9.1")
            inclog("fixdatemismatch9.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch9.1") 
            return tl
        elif archiveurldate == "error":
          sendlog(Project.logdatemismatch, CL.name, archiveurl & " ---- error : freezepage date unknown")
          return tl
        else:
          return tl

    elif isarchiveorg(archiveurl):    

      var archiveurlts = strip(urltimestamp(archiveurl))                  # Re-set timestamp to value of |archivedate= if timestamp is 18990101070101 (see fixiats())
                                                                          #   this is a reverse of normal process.. set timestamp <= archivedate, instea of =>
      if archiveurlts ~ "^1[89][97][90]" and not empty(archivedate):  
        var ts = getargarchivedatestamp(tl)
        if ts !~ "^1[89][97][90]" and not empty(ts):
          tl = replacetext(tl, archiveurlts, ts & "000000", "fixdatemismatch1.1")
          # inc(GX.esformat) # will sometimes result in a double-count if also changed by fixbadstatus() - see workaround at end of process_article()
          inclog("fixdatemismatch1.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archiveurlts & "----" & ts & "----logdatemismatch1.1", "noeditsum") 
          return tl

      archiveurldate = urldate(archiveurl, archivedate, "")

      if archiveurldate == "error":  # either because of error or dates match up (no error)
        return tl

      numericstatus = isnumericdate(archivedate)

      if numericstatus == "alphanumeric":

        if verifydate(archiveurldate) and archiveurldate != archivedate:

          if GX.datetype == "dmy" and dateformat(archiveurldate) == "mdy":
            archiveurldate = redateformat(archiveurldate,"dmy")

          tl = replacearg(tl, "archive-date", archiveurldate, "fixdatemismatch2.1")
          inclog("fixdatemismatch2.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch2.1") 
          return tl

      elif numericstatus == "numeric":
        archiveurldate = timestamp2numericdate(urltimestamp(archiveurl))
        if isnumericdate(archiveurldate) == "numeric":
          if archiveurldate != archivedate:
            tl = replacearg(tl, "archive-date", archiveurldate, "fixdatemismatch3.1")
            inclog("fixdatemismatch3.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch3.1") 
            return tl
      else:
        return tl
      
  if datatype(tl,"webarchive"):

    archiveurl = getarg("url", "clean", tl)
    archivedate = getarg("date", "clean", tl)
    if archivedate ~ "[{][{]":  # skip embedded date template
      return tl

    # newwebarchives 
    if isarchive(archiveurl, "sub2"):

      if not empty(dateformat(archivedate)):
        var ts = urltimestamp(archiveurl)
        if ts ~ "^[0-9]{8,14}$":
          var dummy = "https://web.archive.org/web/" & ts & "/https://wikipedia.org"
          archiveurldate = urldate(dummy, archivedate, archivedate)
          if archiveurldate != "error":
            if archiveurldate != archivedate:
              tl = replacearg(tl, "date", archiveurldate, "fixdatemismatch7.1")
              inclog("fixdatemismatch7.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch7.1") 
              return tl

    elif isnlaau(archiveurl):

      if not empty(dateformat(archivedate)):
        archiveurldate = nlaautodate(archiveurl, archivedate)
        if archiveurldate !~ "error":
          if archiveurldate != archivedate:
            tl = replacearg(tl, "date", archiveurldate, "fixdatemismatch12.1")
            inclog("fixdatemismatch12.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch12.1") 
            return tl
        elif archiveurldate == "error":
          sendlog(Project.logdatemismatch, CL.name, archiveurl & " ---- error : unknown date in NLA.GOV.AU")
          return tl
        else:
          return tl

    elif iswebcite(archiveurl):

      if not empty(dateformat(archivedate)):
        archiveurldate = base62todate(archiveurl, dateformat(archivedate))
        if archiveurldate !~ "error|nobase62":
          if archiveurldate != archivedate:
            tl = replacearg(tl, "date", archiveurldate, "fixdatemismatch6.1")
            inclog("fixdatemismatch6.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch6.1") 
            return tl
        elif archiveurldate == "error":
          sendlog(Project.logdatemismatch, CL.name, archiveurl & " ---- error : base62 unknown")
          return tl
        else:
          return tl

    elif isfreezepage(archiveurl):

      if not empty(dateformat(archivedate)):
        archiveurldate = freezedate(archiveurl, dateformat(archivedate))
        if archiveurldate !~ "error":
          if archiveurldate != archivedate:
            tl = replacearg(tl, "date", archiveurldate, "fixdatemismatch10.1")
            inclog("fixdatemismatch10.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch10.1") 
            return tl
        elif archiveurldate == "error":
          sendlog(Project.logdatemismatch, CL.name, archiveurl & " ---- error : freezepage date unknown")
          return tl
        else:
          return tl

    elif isarchiveorg(archiveurl):

      archiveurldate = urldate(archiveurl, archivedate, archivedate)
      if archiveurldate == "error":
        return tl

      numericstatus = isnumericdate(archivedate)

      if numericstatus == "alphanumeric":

        if verifydate(archiveurldate) and archiveurldate != archivedate:

          if GX.datetype == "dmy" and dateformat(archiveurldate) == "mdy":
            archiveurldate = redateformat(archiveurldate,"dmy")

          tl = replacearg(tl, "date", archiveurldate, "fixdatemismatch4.1")
          inclog("fixdatemismatch4.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch4.1") 
          return tl

      elif numericstatus == "numeric":
        archiveurldate = timestamp2numericdate(urltimestamp(archiveurl))
        if isnumericdate(archiveurldate) == "numeric":
          if archiveurldate != archivedate:
            tl = replacearg(tl, "date", archiveurldate, "fixdatemismatch5.1")
            inclog("fixdatemismatch5.1", GX.esformat, Project.logdatemismatch, archiveurl & "----" & archivedate & "----" & archiveurldate & "----logdatemismatch5.1") 
            return tl
      else:
        return tl
      
  return tl

#
# Fix double archive URLs (see examples below)
#
proc fixdoubleurl(ttl: string, fr: varargs[string]): string =

  var
    tl = ttl
    urlarch, fullref, newurl, suburl = ""

  if Runme.fixdoubleurl != true:
    return tl

  if fr.len > 0:
    if fr[0] == nil:
      fullref = ""
    else:
      fullref = fr[0]

  if datatype(tl,"cite"):

    urlarch = getarg("archive-url", "clean", tl)

    #  Example: https://en.wikipedia.org/w/index.php?title=Mandolin&type=revision&diff=735320558&oldid=735121217

    suburl = wayurlurl(urlarch)
    gsubs("/https%3A","/https:", suburl); gsubs("/http%3A","/http:", suburl)
    while true:
      if wayurlurl(suburl) == suburl:  # guard against endless loop caused by missing suburl value
        break
      if isarchiveorg(suburl):
        gsubs(":80/:80/", ":80/", suburl)
        newurl = wayurlurl(suburl)
        if not isarchiveorg(newurl):
          tl = replacearg(tl, "archive-url", suburl, "fixdoubleurl1")
          inclog("fixdoubleurl1.1", GX.esrescued, Project.logdoubleurl, urlarch & " ---- " & newurl & " ---- fixdoubleurl1.1") 
          return tl
        suburl = newurl
      else:
        break

  elif datatype(tl,"barelink"):

    # Example: https://en.wikipedia.org/w/index.php?title=Nostratic_languages&action=historysubmit&type=revision&diff=735322583&oldid=734415290

    suburl = wayurlurl(tl)
    gsubs("/https%3A","/https:", suburl); gsubs("/http%3A","/http:", suburl)
    while true:
      if wayurlurl(suburl) == suburl:  # guard against endless loop caused by missing suburl value
        break
      if isarchiveorg(suburl):
        gsubs(":80/:80/", ":80/", suburl)
        newurl = wayurlurl(suburl)
        if not isarchiveorg(newurl):
          inclog("fixdoubleurl2.1", GX.esrescued, Project.logdoubleurl, tl & " ---- " & suburl & " ---- fixdoubleurl2.1") 
          return replacetext(fullref, tl, suburl, "fixdoubleurl2")
        suburl = newurl
      else:
        break

  if not empty(fullref):
    return fullref
  else:
    return tl


#
# Fix archive.is encoding caused by IABot in Phab T164172
#
proc fixiasencode(urlarch, tl, fullref, caller: string): string =

        var
          tl = tl
          fullref = fullref
          debug, newurl, parseencoded = ""
 
        debug = "fixiasencode-" & caller

        # fix IABot urlencoding an XML-encoded URL (it should not be urlencoded and should be XML decoded)
        var encoded = convertxml(urldecode(urlarch))
        if isarchiveis(urlarch) and urldecode(urlarch) != encoded:
          parseencoded = uriparseEncodeurl(encoded)
          if validate_other(parseencoded, "wiki"):
            if caller != "barelink":
              tl = replacearg(tl, "archive-url", parseencoded, debug & ".1")
            else:
              fullref = replacetext(fullref, tl, parseencoded, debug & ".1")
            inclog("fixiasencode1.1", GX.esformat, Project.logbadstatusother, urlarch & " ---- " & parseencoded & " ---- " & debug & ".1") 
            if caller != "barelink":
              return tl
            else:
              return fullref

        # fix IABot not encoding '#' -> %23 during conversion from short to long form
        #  https://en.wikipedia.org/w/index.php?title=Jedd_Gyorko&type=revision&diff=776379056&oldid=775850840
        if isarchiveis(urlarch) and urlarch ~ "[#]":
          newurl = urlarch
          gsub("[#]", "%23", newurl)
          if validate_other(newurl, "wiki"):
            if caller != "barelink":
              tl = replacearg(tl, "archive-url", newurl, debug & ".2")
            else:
              fullref = replacetext(fullref, tl, uriparseEncodeurl(encoded), debug & ".2")
            inclog("fixiasencode2.1", GX.esformat, Project.logbadstatusother, urlarch & " ---- " & newurl  & " ---- " & debug & ".2") 
            if caller != "barelink":
              return tl
            else:
              return fullref

        # fix IABot encoding '=' -> %3D during conversion from short to long form
        if isarchiveis(urlarch) and urlarch ~ "%3D":
          newurl = urlarch
          gsub("%3D", "=", newurl)
          if validate_other(newurl, "wiki"):
            if caller != "barelink":
              tl = replacearg(tl, "archive-url", newurl, debug & ".3")
            else:
              fullref = replacetext(fullref, tl, uriparseEncodeurl(encoded), debug & ".3")
            inclog("fixiasencode3.1", GX.esformat, Project.logbadstatusother, urlarch & " ---- " & newurl  & " ---- " & debug & ".3") 
            if caller != "barelink":
              return tl
            else:
              return fullref

        # fix IABot encoding '+' -> %2B during conversion from short to long form
        if isarchiveis(urlarch) and urlarch ~ "%2B":
          newurl = urlarch
          gsub("%2B", "+", newurl)
          if validate_other(newurl, "wiki"):
            if caller != "barelink":
              tl = replacearg(tl, "archive-url", newurl, debug & ".5")
            else:
              fullref = replacetext(fullref, tl, uriparseEncodeurl(encoded), debug & ".5")
            inclog("fixiasencode5.1", GX.esformat, Project.logbadstatusother, urlarch & " ---- " & newurl  & " ---- " & debug & ".5") 
            if caller != "barelink":
              return tl
            else:
              return fullref

        # fix IABot encoding '+' -> %20 during conversion from short to long form
        if isarchiveis(urlarch) and urlarch ~ "%20":
          newurl = urlarch
          gsub("%20", "+", newurl)
          if validate_other(newurl, "wiki"):
            if caller != "barelink":
              tl = replacearg(tl, "archive-url", newurl, debug & ".6")
            else:
              fullref = replacetext(fullref, tl, uriparseEncodeurl(encoded), debug & ".6")
            inclog("fixiasencode6.1", GX.esformat, Project.logbadstatusother, urlarch & " ---- " & newurl  & " ---- " & debug & ".6") 
            if caller != "barelink":
              return tl
            else:
              return fullref

        # Try replace the source URL in the archive.is URL with the url= from the cite template
        if caller == "cite" and isarchiveis(urlarch) and urlarch !~ "archive[.]org" and urlarch ~ "[/][0-9]{8,14}[/]":
          newurl = urlarch
          var sourceurlis = wayurlurl(urlarch)
          var sourceurl = getarg("url", "clean", tl)
          if not empty(sourceurl) and not empty(sourceurlis) and (tolowerAscii(sourceurl) != tolowerAscii(sourceurlis)):
            gsubs(sourceurlis, sourceurl, newurl)
            if validate_other(newurl, "wiki"):
              tl = replacearg(tl, "archive-url", newurl, debug & ".4")
              inclog("fixiasencode4.1", GX.esformat, Project.logbadstatusother, urlarch & " ---- " & newurl  & " ---- " & debug & ".4") 
              return tl

        if caller != "barelink":
          return tl
        else:
          return fullref


#
# fixbadstatusother (webcite, archiveis, etc..)
#
# Replace non-Wayback archive URLs reporting non-200 status with dummy IA links
#  tl is the contents of the template (or the barelink)
#  optional "fullref" string ie. everything between <ref></ref>, or everything between [] (external link)
#
proc fixbadstatusother(tl, target: string, fr: varargs[string]): string =

  var
    tl = tl
    fullref, urlarch, urlarchorig, url, newurl, newtl, newfullref, newdate = ""
    urlstatus = true
    status, response = 0

  # newwebarchives

  if Runme.fixbadstatus != true:
    return tl

  if fr.len > 0:
    if fr[0] == nil:
      fullref = ""
    else:
      fullref = fr[0]

  if datatype(tl,"cite"):

    urlarch = getarg("archive-url", "clean", tl)
    urlarchorig = urlarch

    if iswebcite(urlarch):
      urlstatus = validate_webciteid(urlarch) 
    elif isfreezepage(urlarch):
      urlstatus = validate_freezepage(urlarch)  
    elif isnlaau(urlarch):
      urlstatus = validate_nlaau(urlarch)  
    elif isbibalex(urlarch):
      urlstatus = validate_bibalex(urlarch)  
    elif isporto(urlarch):
      urlstatus = validate_porto(urlarch)  
    elif isarchive(urlarch, "sub2"):
      urlstatus = validate_other(urlarch, "wiki")      # Page scrape
    else:
      return tl

    if not urlstatus: 
      url = getarg("url", "clean", tl)
      if url ~ GX.shttp and not isarchive(url, "all"):

        # Fix archive.is URL encoding problems caused by Phab T164172
        newtl = fixiasencode(urlarch, tl, fullref, "cite")
        if tl != newtl:
          return newtl
 
        sed("badstatusother 1: replace with 1970 wayback: " & urlarch, Debug.network)
        tl = replacearg(tl, "archive-url", "https://web.archive.org/web/19700101000000/" & url, "fixbadstatusother1")

        if isarg("archive-date", "missing", tl):
          var locbar = getarg(notlastarg(tl, "archive-date"), "bar", tl)
          gsubs(locbar, locbar & modelfield(getarg(firstarg(tl), "bar", tl), "archive-date", "1970-01-01"), tl)
        else:
          var newdate = date2format("1970-01-01", dateformat(getarg("archive-date", "clean", tl))) # preserve existing date format
          if not empty(newdate):
            tl = replacearg(tl, "archive-date", newdate, "fixbadstatusother1.3")
          else:
            tl = replacearg(tl, "archive-date", "1970-01-01", "fixbadstatusother1.4")

        if isarg("dead-url", "missing", tl):
          var deadstatus = "yes"
          for i in 0..1:
            sed("Checking fixbadstatusother step " & $i, Debug.network)
            (status, response) = webpagestatus(url, "one")
            if status == 1 or status == 3:           
              deadstatus = "no"          
          var locbar = getarg(notlastarg(tl, "dead-url"), "bar", tl)
          gsubs(locbar, locbar & modelfield(getarg(firstarg(tl), "bar", tl), "dead-url", deadstatus), tl)
        else:
          var deadclean = getarg("dead-url", "clean", tl)
          if empty(deadclean) or deadclean ~ "^[Y|y]":
            deadclean = "yes"
          else:
            deadclean = "no"
          tl = replacearg(tl, "dead-url", deadclean, "fixbadstatusother1.5")

        inclog("fixbadstatusother1.6", GX.esformat, Project.logbadstatusother, urlarch & " ---- logbadstatusother1.6", "noeditsum") 
        if not Runme.api:
          Runme.api = true
        return tl

      else:                                 # url not working and can't find replacement (very rare condition)
        sed("badstatusother 6: delete archive-url: " & urlarch, Debug.network)
        gsubs(getarg("archive-url", "complete", tl), "", tl)
        gsubs(getarg("archive-date", "complete", tl), "", tl)
        gsubs(getarg("dead-url", "complete", tl), "", tl)
        inclog("logbadstatusother2.1", GX.esremoved, Project.logbadstatusother, " error : url not working and can't find replacement : " & urlarch & " ---- logbadstatusother1.7") 
        return tl

    elif urlarch != urlarchorig:         # url changed due to a redirect found in validate_xxx()
      newdate = urldate(urlarch, getarg("archive-date", "clean", tl), getarg("archive-date", "clean", tl) )
      if newdate != "error":
        tl = replacearg(tl, "archive-url", urlarch, "fixbadstatusother1.8")
        tl = replacearg(tl, "archive-date", newdate, "fixbadstatusother1.9")
        inclog("logbadstatusother10.1", GX.esrescued, Project.log404, "logbadstatusother1.11") 

    return tl

  elif datatype(tl,"webarchive"):

    urlarch = getarg("url", "clean", tl)
    urlarchorig = urlarch

    if iswebcite(urlarch):
      urlstatus = validate_webciteid(urlarch)  # API call
      newurl = urlurl(urlarch)
    elif isfreezepage(urlarch):
      urlstatus = validate_freezepage(urlarch)  
      newurl = urlurl(urlarch)
    elif isnlaau(urlarch):
      urlstatus = validate_nlaau(urlarch)  
      newurl = urlurl(urlarch)
    elif isbibalex(urlarch):
      urlstatus = validate_bibalex(urlarch)  
      newurl = urlurl(urlarch)
    elif isporto(urlarch):
      urlstatus = validate_porto(urlarch)  
      newurl = urlurl(urlarch)
    elif isarchive(urlarch, "sub2"):
      urlstatus = validate_other(urlarch, "wiki")      # Page scrape 
      newurl = urlurl(urlarch)
    else:
      return tl

    if not urlstatus: 
      if newurl ~ GX.shttp:

        # Fix archive.is URL encoding problems caused by Phab T164172
        newtl = fixiasencode(urlarch, tl, fullref, "webarchive")
        if tl != newtl:
          return newtl

        sed("badstatusother 2: replace with 1970 wayback: " & urlarch, Debug.network)
        tl = replacearg(tl, "url", "https://web.archive.org/web/19700101000000/" & newurl, "fixbadstatusother2.3")
        if isarg("date", "missing", tl):
          gsubs(getarg("url", "bar", tl), getarg("url", "bar", tl) & modelfield(getarg(firstarg(tl), "bar", tl), "date", "1970-01-01"), tl)
        else:
          var newdate = date2format("1970-01-01", dateformat(getarg("date", "clean", tl)))  # preserve existing date format
          if not empty(newdate):
            tl = replacearg(tl, "archive-date", newdate, "fixbadstatusother2.4")
          else:
            tl = replacearg(tl, "archive-date", "1970-01-01", "fixbadstatusother2.5")
        inclog("fixbadstatusother2.6", GX.esformat, Project.logbadstatusother, urlarch & " ---- logbadstatusother2.6", "noeditsum") 
        if not Runme.api:
          Runme.api = true
        return tl
      else:
        sed("badstatusother 5: delete {{webarchive}}: " & urlarch, Debug.network)
        inclog("logbadstatusother4.1", GX.esremoved, Project.logbadstatusother, urlarch & " ---- logbadstatusother2.7") 
        return ""                     # delete the {{webarchive}}

    elif urlarch != urlarchorig:         # url changed due to a redirect found in validate_xxx()
      tl = replacearg(tl, "url", urlarch, "fixbadstatuswebarchive1")
      tl = fixdatemismatch(tl)
      incchanges(1, "fixbadstatus5")
      inc(GX.esrescued)

    return tl

  elif datatype(tl,"barelink"):

    urlarchorig = tl

    if iswebcite(tl):
      urlstatus = validate_webciteid(tl)  # API call
      newurl = urlurl(tl)
    elif isfreezepage(tl):
      urlstatus = validate_freezepage(tl)  
      newurl = urlurl(tl)
    elif isnlaau(tl):
      urlstatus = validate_nlaau(tl)  
      newurl = urlurl(tl)
    elif isbibalex(tl):
      urlstatus = validate_bibalex(tl)  
      newurl = urlurl(tl)
    elif isporto(tl):
      urlstatus = validate_porto(tl)  
      newurl = urlurl(tl)
    elif isarchive(tl, "sub2"):
      urlstatus = validate_other(tl, "wiki")  
      newurl = urlurl(tl)
    else:
      return tl
          
    if not urlstatus: 
      if newurl ~ GX.shttp and not isarchive(newurl, "all"):

        # Fix archive.is URL encoding problems caused by Phab T164172
        newfullref = fixiasencode(urlarch, tl, fullref, "barelink")
        if fullref != newfullref:
          return newfullref

        sed("badstatusother 3: replace with 1970 wayback: " & tl, Debug.network)
        var newiaurl = "https://web.archive.org/web/19700101000000/" & newurl
        fullref = replacetext(fullref, tl, newiaurl, "fixbadstatusother3.3")
        if not Runme.api: Runme.api = true
        inclog("fixbadstatusother3.4", GX.esformat, Project.logbadstatusother, tl & " ---- logbadstatusother3.4", "noeditsum") 
        return fullref

      else: 

        # Fix ref's like this where the webcite doesn't work. Obtain new source URL from a preceeding bare link. Doesn't work if > 2 URLs in fullref.
        # <ref>Ward, Mike. "[http://www.statesman.com/news/texas-politics/are-trusty-camps-a-weak-link-in-texas-616918.html Are trusty camps a weak link in Texas prison security?]." ([http://www.webcitation.org/5pb5t98qp Archive])''[[Austin American-Statesman]]''. Saturday April 24, 2010. Updated on Sunday April 25, 2010. Retrieved on May 9, 2010.</ref>
        if target ~ "inside":
          var field = newSeq[string](0)
          var p = patsplit(fullref, field, "[Hh][Tt][Tt][Pp][Ss]?[:][^\\s\\]|}{<]*[^\\s\\]|}{<]")
          if p == 2:  
            for q in 0..p-1:
              if isarchive(field[q], "all"):
                continue
              else:
                sed("badstatusother 4: replace with 1970 wayback: " & urlarch, Debug.network)
                var newiaurl = "https://web.archive.org/web/19700101000000/" & field[q]
                fullref = replacetext(fullref, tl, newiaurl, "fixbadstatusother3.5")
                inclog("fixbadstatusother3.6", GX.esformat, Project.logbadstatusother, tl & " ---- logbadstatusother3.6", "noeditsum") 
                if not Runme.api: Runme.api = true
                return fullref
        elif target ~ "outside":
          var r = awk.split(GX.articlework, a, "\n")
          for i in 0..r-1:
            if a[i] ~ escapeRe(tl):
              var field = newSeq[string](0)
              var p = patsplit(a[i], field, "[Hh][Tt][Tt][Pp][Ss]?[:][^\\s\\]|}{<]*[^\\s\\]|}{<]")
              if p == 2:
                for q in 0..p-1:
                  if isarchive(field[q], "all"):
                    continue
                  else:
                    sed("badstatusother 4: replace with 1970 wayback: " & urlarch, Debug.network)
                    var newiaurl = "https://web.archive.org/web/19700101000000/" & field[q]
                    fullref = replacetext(fullref, tl, newiaurl, "fixbadstatusother3.7")
                    inclog("fixbadstatusother3.8", GX.esformat, Project.logbadstatusother, tl & " ---- logbadstatusother3.8", "noeditsum") 
                    if not Runme.api: Runme.api = true
                    return fullref

        # Add {{dead}} to end of link [] in case of multi-cite ref
        if target ~ "inside":

          var dead, cbignore = "no"
          if fullref ~ GX.dead:  
            dead = "yes"
          if fullref ~ GX.cbignore:  
            cbignore = "yes"        

          var field, sep = newSeq[string](0)
          var p = awk.patsplit(fullref, field, "[[][^]]*[]]", sep)
          if p > 0:
            for i in 0..p-1:
              if field[i] ~ escapeRe(tl):
                incchanges(1, "logbadstatusother8")
                inc(GX.esformat)
                if dead == "no" and cbignore == "no":
                  field[i] = field[i] & "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"
                elif dead == "yes" and cbignore == "no":
                  field[i] = field[i] & "{{cbignore|bot=medic}}"
                elif dead == "no" and cbignore == "yes":
                  field[i] = field[i] & "{{dead link|date=" & todaysdate() & "|bot=medic}}"

            fullref = unpatsplit(field, sep)
            sendlog(Project.logbadstatusother, CL.name, tl & " ---- logbadstatusother3.9")
            return fullref

        if target ~ "outside":

          var dead, cbignore = "no"
          if deadlinkbareline(GX.articlework, fullref):  
            dead = "yes"
          if cbignorebareline(GX.articlework, fullref):  
            cbignore = "yes"

          if dead == "no" and cbignore == "no":
            fullref = fullref & "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"
          elif dead == "yes" and cbignore == "no":
            fullref = fullref & "{{cbignore|bot=medic}}"
          elif dead == "no" and cbignore == "yes":
            fullref = fullref & "{{dead link|date=" & todaysdate() & "|bot=medic}}"

          inclog("logbadstatusother9.1", GX.esformat, Project.logbadstatusother, tl & " ---- logbadstatusother3.10") 
          return fullref

        sendlog(Project.logbadstatusother, CL.name, " error : url not working and can't find replacement : " & tl & " ---- logbadstatusother3.11")

    elif tl != urlarchorig:         # url changed due to a redirect found in validate_xxx()
      fullref = replacetext(fullref, urlarchorig, tl, "fixbadstatusother3.12")
      inclog("logbadstatusother3.11", GX.esrescued, Project.log404, "logbadstatusother3.13") 

    return fullref

  if not datatype(tl,"barelink"):
    return tl
  else:
    return fullref

#
# fixbadstatus (Rev: A)
#
# Replace Wayback URLs reporting non-200 status. Update archivedate if changed.
#  tl is the contents of the template
#  "fullref" string ie. everything between <ref></ref>, or everything between [] (external link)
#  target is value of target from process_article()
#
proc fixbadstatus(tl, fullref, target: string): string =

  var
    tl = tl
    fullref = fullref
    url, urlarch, urlencoded, newurl, newdate, olddate, waybackdate, k, deadstatus, cbstatus = ""
    i, ii = 0
    tag = -1
    status, response = -1 
    trailgarb = "Step A6[.]7[.][0-9]{1,2}[.][0-9]{1,2}[:]"
 
  if Runme.fixbadstatus != true:
    return tl

  if datatype(tl,"cite"):

    urlarch = getarg("archive-url", "clean", tl)

    if isarchiveorg(urlarch):

      (newurl, tag) = api(urlarch)

      if newurl != "none" and isarchiveorg(newurl):
        if skindeep(newurl, urlarch):                                         # Stays the same (always false)
          return tl           
        else:                                                                 # Modify the snapshot date
          if urltimestamp(urlarch) != urltimestamp(newurl):
            if GX.imp == "Add":
              if wayback_soft404(newurl):
                return tl
            newdate = urldate(newurl, getarg("archive-date", "clean", tl), getarg("archive-date", "clean", tl) )
            if newdate != "error":
              tl = replacearg(tl, "archive-url", newurl, "fixbadstatuscite1.0.1")
              tl = replacearg(tl, "archive-date", newdate, "fixbadstatuscite1.0.2")

              if WayLink[tag].breakpoint ~ trailgarb:           # See waytree_trailgarb()
                tl = replacearg(tl, "url", WayLink[tag].newurl, "fixbadstatuscite1.0.3")
                sed("Checking fixbadstatuscite1", Debug.network)
                (status, response) = webpagestatus(wayurlurl(WayLink[tag].newurl), "one")
                if status == 1 or status == 3:              
                  tl = replacearg(tl, "dead-url", "no", "fixbadstatuscite1.0.4")

              inclog("fixbadstatus1.1", GX.esrescued, Project.log404, "cite-modify") 
              if urltimestamp(urlarch) ~ "^1[89][97][90]":                    # See replacedeadtl() and fixiats() 
                sendlog(Project.newialink, CL.name, newurl & " ---- logbadstatus1")
              else: 
                sendlog(Project.newiadate, CL.name, urlarch & " ----" & newurl & " ----cite-modify")
            return tl
          elif urlarch != WayLink[tag].formated:                              # Modify skindeep formating (https, /web/, etc)
            if WayLink[tag].formated ~ GX.shttp:
              tl = replacearg(tl, "archive-url", WayLink[tag].formated, "fixbadstatuscite1.1")

              if WayLink[tag].breakpoint ~ trailgarb:           # See waytree_trailgarb()
                tl = replacearg(tl, "url", WayLink[tag].newurl, "fixbadstatuscite1.0.5")
                sed("Checking fixbadstatuscite1", Debug.network)
                (status, response) = webpagestatus(wayurlurl(WayLink[tag].newurl), "one")
                if status == 1 or status == 3:              
                  tl = replacearg(tl, "dead-url", "no", "fixbadstatuscite1.0.6")

#             gsubs(urlarch, WayLink[tag].formated, GX.articlework)                  # Multiple cases hack - don't do this it overwrites articlework 
                                                                                     # eliminating previous changes above
              inclog("fixbadstatus2.1", GX.esformat, Project.logskindeep, getarg("url", "clean", tl) & " " & urlarch & " " & WayLink[tag].formated) 
              return tl
            else:
              return tl
          else:
            return tl
      elif newurl != "none" and not isarchiveorg(newurl):                     # Change to alt archive
        newdate = timestamp2date(altarchfield(newurl, "altarchdate"), getarg("archive-date", "clean", tl))
        tl = replacearg(tl, "archive-date", newdate, "fixbadstatuscite4")
        tl = replacearg(tl, "archive-url", newurl, "fixbadstatuscite3")
        inclog("fixbadstatus3.1", GX.esrescued, Project.log404, "cite-modifyaltarch") 
        sendlog(Project.newaltarch, CL.name, getarg("url", "clean", tl) & " " & urltimestamp(urlarch) & " " & newurl & " " & newdate)
        if not isarchive(newurl, "all"):
          sendlog(Project.syslog, CL.name, newurl & " ---- " & "unrecognized archive service (1)")
        return tl

      else:                                                                   # Delete

        if contains(urlarch, "{") or contains(urlarch, "}"):                  # Abort these for now .. parsing problems URL gets mangled
          return tl

        if not dummydate(urltimestamp(urlarch), "189908"):                    # See replacedeadtl() 
          inclog("fixbadstatus4.1", GX.esremoved, Project.log404, "cite-delete") 
          sendlogwayrm(Project.wayrm, CL.name, urlarch, tl)
          
        url = getarg("url", "clean", tl)

              # Only check url and potentially leave a {{dead link}} if deadurl is anything but "yes" 
              # If yes, automatically leave {{dead link}} without checking
              # The issue is soft-404 errors .. damned if you do, damned if you don't (check the URL)

        # Does tl already contain a {{dead link}} and/or {{cbignore}}?
        if target !~ "outside" and fullref ~ GX.dead:
          deadstatus = "nodeadlink"
        if target !~ "outside" and fullref ~ GX.cbignore:
          cbstatus = "nocbignore"
        elif target ~ "outside" and deadlinkbareline(GX.articlework, tl):
          deadstatus = "nodeadlink"
        elif target ~ "outside" and cbignorebareline(GX.articlework, tl):
          cbstatus = "nocbignore"

        if url ~ GX.shttp:   

          if getarg("dead-url", "clean", tl) ~ "^[Yy]" and not dummydate(tl): 
            return removearchive(tl, "fixbadstatuscite9", deadstatus, cbstatus)

          # Known sites that usually return soft 404
          if url ~ "findarticles[.]com|lemonde[.]fr|bilbao[.]net|channelnewsasia[.]com|news[.]com[.]au|blogs[.]telegraph[.]co[.]uk":
            return removearchive(tl, "fixbadstatuscite8", deadstatus, cbstatus)

          urlencoded = uriparseEncodeurl(urldecode(url))             

          sed("Checking fixbadstatus step 1", Debug.network)
          (status, response) = webpagestatus(url, "one")
          if status == 1 or status == 3:  
            if not dummydate(urltimestamp(urlarch), "189908"):         
              sendlog(Project.logdeadurl, CL.name & "----" & url, "fixbadstatuscite5")
            return removearchive(tl, "fixbadstatuscite5", "nodeadlink", "nocbignore")   

          sed("Checking fixbadstatus step 2", Debug.network)
          (status, response) = webpagestatus(urlencoded, "one")
          if status == 1 or status == 3:              # Try again with encoding
            if not dummydate(urltimestamp(urlarch), "189908"):
              sendlog(Project.logdeadurl, CL.name & "----" & url, "fixbadstatuscite6")
            return removearchive(tl, "fixbadstatuscite6", "nodeadlink", "nocbignore")

        return removearchive(tl, "fixbadstatuscite7", deadstatus, cbstatus)

    else:
      sendlog(Project.log404, CL.name, urlarch & " ---- citeErrorB")
      return tl

  elif datatype(tl,"webarchive"):

    urlarch = getarg("url", "clean", tl)
    if isarchiveorg(urlarch): 
      url = wayurlurl(urlarch)
      waybackdate = urltimestamp(urlarch)
    else:
      return tl
    if contains(urlarch, "{") or contains(urlarch, "}"):                                 # Abort for now, parsing problems
      return tl

    if isarchiveorg(urlarch):
      (newurl, tag) = api(urlarch)
      if newurl != "none" and isarchiveorg(newurl):
        if skindeep(newurl, urlarch):                                                     # Stays the same
          return tl
        else:                                                                             # Modify the snapshot date
          if waybackdate != urltimestamp(newurl):
            tl = replacearg(tl, "url", newurl, "fixbadstatuswebarchive1")
            tl = fixdatemismatch(tl)
            inclog("fixbadstatus5.1", GX.esrescued, Project.log404, "webarchive-modify") 
            if waybackdate !~ "^1[89][97][90]": # see fixats()
              sendlog(Project.newiadate, CL.name, urlarch & " ----" & newurl & " ----webarchive-modify")
            else:
              sendlog(Project.newialink, CL.name, newurl & " ---- webarchive-modify")
          return tl

      if newurl != "none" and not isarchiveorg(newurl):                                   # Change to Alternative archive
        if match(tl, "[{]" & GX.space & "[Ww]ebarchive[ ]{0,}", k) > 0:
          olddate = getarg("date", "clean", tl)
          tl = replacearg(tl, "date", timestamp2date(altarchfield(newurl, "altarchdate"), olddate), "fixbadstatuswebarchive2")
          tl = replacearg(tl, "url", newurl, "fixbadstatuswebarchive3")
          inclog("fixbadstatus6.1", GX.esrescued, Project.log404, "webarchive-replaced-altarch") 
          sendlog(Project.newaltarch, CL.name, url & " " & waybackdate & " " & newurl & " " & altarchfield(newurl, "altarchdate"))
          if not isarchive(newurl, "all"):
            sendlog(Project.syslog, CL.name, newurl & " ---- " & "unrecognized archive service (2)")
        return tl          
      else: 
        i  = countsubstringregex(fullref, "[{][ ]?[{][^}]*[}][ ]?[}]|[[][ ]?[Hh][Tt][Tt][Pp][Ss]?[:]") # if ref contains > 1 template or 1 template + 1 [http.. 
        ii = countsubstringregex(tl, "[|]" & GX.space & "url[2-9]" & GX.space & "[=]")         # leave alone if > 1 |urlX= argument

        if i > 1 and ii == 0:                                   # Delete webarchive template / it follows an existing URL so replace with dead link only
          inclog("fixbadstatus7.1", GX.esremoved, Project.log404, "webarchive-delete1") 
          sendlog(Project.cbignore, CL.name, "webarchive-delete1")
          sendlogwayrm(Project.wayrm, CL.name, urlarch, tl)   
          if fullref ~ GX.dead and fullref !~ GX.cbignore:                # Check for duplicate {{dead link}}
            return "{{cbignore|bot=medic}}"
          elif fullref ~ GX.dead and fullref ~ GX.cbignore:              
            return ""
          elif fullref !~ GX.dead and fullref ~ GX.cbignore:              
            return "{{dead link|date=" & todaysdate() & "|bot=medic}}"
          else:
            return "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"
        elif i == 1 and ii == 0:                                # Delete webarchive template / replace with cite web (webarchive template is standlone)
          inclog("fixbadstatus8.1", GX.esremoved, Project.log404, "webarchive-delete2") 
          sendlog(Project.cbignore, CL.name, "webarchive-delete2")
          sendlogwayrm(Project.wayrm, CL.name, urlarch, tl)
          if fullref ~ GX.dead and fullref !~ GX.cbignore:              # Check for duplicate {{dead link}}
            return buildciteweb(url, getarg("title", "clean", tl)) & "{{cbignore|bot=medic}}"
          if fullref ~ GX.dead and fullref ~ GX.cbignore:
            return buildciteweb(url, getarg("title", "clean", tl))
          if fullref !~ GX.dead and fullref ~ GX.cbignore:
            return buildciteweb(url, getarg("title", "clean", tl)) & "{{dead link|date=" & todaysdate() & "|bot=medic}}"
          else:
            return buildciteweb(url, getarg("title", "clean", tl)) & "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"
        elif ii > 0:                                            # {{webarchive |urlX= |urlX=}} .. leave alone        
          inclog("webarchiveErrorC", GX.esformat, Project.log404, url & " ---- webarchiveErrorC", "noeditsum") 
          return tl
        else:                                                   # Bundled refs - leave alone and collect for future work
          inclog("webarchiveErrorA", GX.esformat, Project.log404, url & " ---- webarchiveErrorA", "noeditsum") 
          return tl
    else:
      sendlog(Project.log404, CL.name, urlarch & " ---- webarchiveErrorB")
      return tl

  elif datatype(tl,"barelink"):

    # Garbage data see example: https://en.wikipedia.org/w/index.php?title=Nostratic_languages&action=historysubmit&type=revision&diff=735322583&oldid=734415290
    #  Skip it
    if isarchiveorg(wayurlurl(tl)):
      sendlog(Project.logdoubleurl, CL.name, tl)
      return fullref

    (newurl, tag) = api(tl)

    if newurl != "none" and isarchiveorg(newurl):
      if skindeep(newurl, tl):                                              # Stays the same
        return fullref
      else:                                                                 
        if urltimestamp(tl) != urltimestamp(newurl) and WayLink[tag].breakpoint !~ trailgarb:     # Modify the snapshot date

          fullref = replacetext(fullref, tl, newurl, "fixbadstatusbare1.0.1")

          inclog("fixbadstatus11.1", GX.esrescued, Project.log404, "barelink-modify") 
          if urltimestamp(tl) !~ "^1[89][97][90]": # See fixiats()
            sendlog(Project.newiadate, CL.name, tl & " ----" & newurl & " ----barelink-modify")
          else:
            sendlog(Project.newialink, CL.name, newurl & " ---- barelink-modify")
          return fullref

        elif tl != WayLink[tag].formated:                                   # Modify skindeep formating (https, /web/, etc)
          if WayLink[tag].formated ~ GX.shttp:

            if WayLink[tag].breakpoint !~ trailgarb:
              fullref = replacetext(fullref, tl, WayLink[tag].formated, "fixbadstatusbare1.1.1")  # GSUB
            else:
              if WayLink[tag].breakpoint !~ "Step A6[.]7[.][4578]{1}[.][0-9]{1,2}[:]":
                fullref = replacetext(fullref, tl, WayLink[tag].formated, "fixbadstatusbare1.1.3")  # GSUB
              else:                                                           # see waytree_trailgarb() for what this is about
                fullref = replacetext(fullref, tl, WayLink[tag].formated & " " & WayLink[tag].fragment, "fixbadstatusbare1.1.4")  # GSUB              
                GX.nospace = false

              if target ~ "inside":  # inside only; no support for outside at the moment :(
                sed("Checking fixbadstatusbare1.1.5", Debug.network)
                (status, response) = webpagestatus(wayurlurl(WayLink[tag].formated), "one")
                if status == 1 or status == 3:              
                  fullref = fixdeadtl(fullref) # remove {{dead link}}
                  fullref = replacetext(fullref, WayLink[tag].formated, wayurlurl(WayLink[tag].formated), "fixbadstatusbare1.1.6")  # GSUB

            inclog("fixbadstatus12.1", GX.esformat, Project.logskindeep, wayurlurl(tl) & " " & tl & " " & WayLink[tag].formated) 
            return fullref
          else:
            return fullref
        else:
          return fullref
    if newurl != "none" and not isarchiveorg(newurl):                       # Change to Alternative archive
      fullref = replacetext(fullref, tl, newurl, "fixbadstatusbare2")
      inclog("fixbadstatus13.1", GX.esrescued, Project.log404, "barelink-replace-altarch") 
      sendlog(Project.newaltarch, CL.name, wayurlurl(tl) & " " & urltimestamp(tl) & " " & newurl & " " & altarchfield(newurl, "altarchdate") )
      if not isarchive(newurl, "all"):
        sendlog(Project.syslog, CL.name, newurl & " ---- " & "unrecognized archive service (3)")
      return fullref

    else:                                                                   # Replace with original URL, leave a deadlink tag only if none exists on same line.

      if contains(tl, "{") or contains(tl, "}"):                            # Abort for now, parsing problems
        return fullref

      tag = apitag(formatediaurl(tl, "barelink"))
      if tag == -1:
        sendlog(Project.log404, CL.name, tl & " ---- barelinkErrorD")
        return fullref
      url = WayLink[tag].origurl
      if noprotocol(url):
        url = "http://" & url
      if len(url) < 10 or url ~ "[ ]":
        sendlog(Project.log404, CL.name, tl & " ---- barelinkErrorC")
        return fullref

      # Add {{dead}} to end of [] in case of multi-cite ref
      if target ~ "inside":
        var dead, cbignore = "no"
        if fullref ~ GX.dead:  
          dead = "yes"
        if fullref ~ GX.cbignore:  
          cbignore = "yes"        
        var field, sep = newSeq[string](0)
        var p = awk.patsplit(fullref, field, "[[][^]]*[]]", sep)
        if p > 0:
          for i in 0..p-1:
            if field[i] ~ escapeRe(tl):
              var newfield = replacetext(field[i], tl, url, "barelink-delete1")
              if dead == "no" and cbignore == "no":
                field[i] = newfield & "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"
              elif dead == "yes" and cbignore == "no":
                if not dummydate(tl, "189908"): 
                  field[i] = newfield & "{{cbignore|bot=medic}}"
                else:
                  field[i] = newfield
              elif dead == "no" and cbignore == "yes":
                field[i] = newfield & "{{dead link|date=" & todaysdate() & "|bot=medic}}"
              else:
                field[i] = newfield
              incchanges(1, "fixbadstatus14")
              inc(GX.esformat)
          fullref = unpatsplit(field, sep)
          if not dummydate(tl, "189908"):
            inclog("fixbadstatus15.1", GX.esformat, Project.log404, tl & " ---- barelink-delete1") 
            sendlogwayrm(Project.wayrm, CL.name, tl, url)
          return fullref

      elif target ~ "outside":
        var newfullref = replacetext(fullref, tl, url, "barelink-delete2")

        var dead, cbignore = "no"
        if deadlinkbareline(GX.articlework, fullref):  
          dead = "yes"
        if cbignorebareline(GX.articlework, fullref):  
          cbignore = "yes"

        if dead == "no" and cbignore == "no":
          fullref = newfullref & "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"
        elif dead == "yes" and cbignore == "no":
          if not dummydate(tl, "189908"): 
            fullref = newfullref & "{{cbignore|bot=medic}}"
          else:
            fullref = newfullref
        elif dead == "no" and cbignore == "yes":
          fullref = newfullref & "{{dead link|date=" & todaysdate() & "|bot=medic}}"
        else:
          fullref = newfullref

        if not dummydate(tl, "189908"): 
          inclog("fixbadstatus16.1", GX.esformat, Project.log404, tl & " ---- barelink-delete2") 
          sendlogwayrm(Project.wayrm, CL.name, tl, url)
        return fullref

      else:
        sendlog(Project.log404, CL.name, tl & " ---- barelinkErrorA")
        return fullref
  else:
    sendlog(Project.log404, CL.name, tl & " ---- unknownErrorA")
    return tl

  return tl

#
# Populate WayLink with data parsed from article
#   fillarray(url, cat [, date])
#    cat = "normal" or "build"
#     If cat build, also pass date
#
proc fillarray(url, cat: string, date: varargs[string]): bool {.discardable} =

  var
    url = url

  if isarchiveorg(url):

    inc(GX.id)             # New ID
    newWayLink(GX.id)      # Create link object

    # See fixiats
    if Runme.replacewikiwix and url ~ "^https://wik.archive":
      gsubs("//wik.archive", "//web.archive", url)
      WayLink[GX.id].dummy = "wikiwix"

    if cat == "normal":
      WayLink[GX.id].origiaurl = url                                   # http://archive.org/web/20061009134445/http://timelines.ws:80/countries/AFGHAN_B_2005.HTML
      WayLink[GX.id].formated = formatediaurl(url, "barelink")         # https://web.archive.org/web/20061009134445/http://timelines.ws/countries...
      WayLink[GX.id].origurl = wayurlurl(url)                          # http://timelines.ws:80/countries/AFGHAN_B_2005.HTML
      WayLink[GX.id].origdate = strip(urltimestamp(url))               # 20061009134445
      WayLink[GX.id].mtag = GX.id
  
    if cat == "build":
      WayLink[GX.id].origiaurl = "https://web.archive.org/web/" & strip(date[0]) & "/" & url
      WayLink[GX.id].formated = formatediaurl(WayLink[GX.id].origiaurl, "barelink")
      WayLink[GX.id].origurl = url    
      WayLink[GX.id].origdate = date[0]
      WayLink[GX.id].mtag = GX.id
                      
    if WayLink[GX.id].origiaurl.len < 1:
      WayLink[GX.id].origiaurl = "none" 
    if WayLink[GX.id].formated.len < 1:
      WayLink[GX.id].formated = "none" 
    if WayLink[GX.id].origurl.len < 1: 
      WayLink[GX.id].origurl = "none" 
    if WayLink[GX.id].origdate.len < 1:
      WayLink[GX.id].origdate = "197001010001" 

   # Create origencoded
    var eurl = "none"
    if WayLink[GX.id].origurl !~ GX.shttp:
      eurl = formatedorigurl(WayLink[GX.id].origurl)
    else:
      eurl = WayLink[GX.id].origurl

    if WayLink[GX.id].origurl != "none":
      WayLink[GX.id].origencoded = uriparseEncodeurl(urldecode(eurl))
    else:
      WayLink[GX.id].origencoded = "none"

    if not dummydate(WayLink[GX.id].origiaurl, "189908"):
      sendlog(Project.wayall, CL.name, WayLink[GX.id].origiaurl)     # Log all URLs to file. 

  elif iswebcite(url):
    sendlog(Project.allwebcite, CL.name, url)    

  elif isarchiveis(url):
    sendlog(Project.allarchiveis, CL.name, url)    

  elif islocgov(url):
    sendlog(Project.alllocgov, CL.name, url)    

  elif isporto(url):
    sendlog(Project.allporto, CL.name, url)    

  elif isstanford(url):
    sendlog(Project.allstanford, CL.name, url)    

  elif isarchiveit(url):
    sendlog(Project.allarchiveit, CL.name, url)    

  elif isbibalex(url):
    sendlog(Project.allbibalex, CL.name, url)    

  elif isnatarchivesuk(url):
    sendlog(Project.allnatarchivesuk, CL.name, url)    

  elif isvefsafn(url):
    sendlog(Project.allvefsafn, CL.name, url)    

  elif iseuropa(url):
    sendlog(Project.alleuropa, CL.name, url)    

  elif ismemory(url):
    sendlog(Project.allmemory, CL.name, url)    

  elif ispermacc(url):
    sendlog(Project.allpermacc, CL.name, url)    

  elif isproni(url):
    sendlog(Project.allproni, CL.name, url)    

  elif isparliament(url):
    sendlog(Project.allparliament, CL.name, url)    

  elif isukweb(url):
    sendlog(Project.allukweb, CL.name, url)    

  elif iscanada(url):
    sendlog(Project.allcanada, CL.name, url)    

  elif iscatalon(url):
    sendlog(Project.allcatalon, CL.name, url)    

  elif issingapore(url):
    sendlog(Project.allsingapore, CL.name, url)    

  elif isslovene(url):
    sendlog(Project.allslovene, CL.name, url)    

  elif isfreezepage(url):
    sendlog(Project.allfreezepage, CL.name, url)    

  elif iswebharvest(url):
    sendlog(Project.allwebharvest, CL.name, url)    

  elif isnlaau(url):
    sendlog(Project.allnlaau, CL.name, url)    

  elif iswikiwix(url):
    sendlog(Project.allwikiwix, CL.name, url)    

  elif isyork(url):
    sendlog(Project.allyork, CL.name, url)    

  elif islac(url):
    sendlog(Project.alllac, CL.name, url)    

  # newwebarchives

#
# Parse and process article. Action to perform is defined by "action". Type of links to process is defined by "target".
#
#   action = "format"   .. run the fix routines that are purely page formating (run first)
#   action = "preformat".. special case to get fixdeadtl() to run prior to replacedeadtl()
#   action = "getlinks" .. add Wayback Machine links found to the internal WayLink[] array (run second)
#   action = "process"  .. run the fix routines that access the Wayback API (run last)
#
#   target = "bareinside"        .. Bare links inside ref pairs
#   target = "citeinside"        .. Citation templates inside ref pairs
#   target = "webarchiveinside"  .. Webarchive template inside ref pairs
#   target = "webarchiveoutside" .. Webarchive template outside ref pairs
#   target = "citeoutside"       .. Citation templates outside ref pairs
#   target = "bareoutside"       .. Bare links outside ref pairs
#
proc process_article(action, target: string) = 

  var 
    inrescued = GX.esrescued
    inremoved = GX.esremoved
    informat  = GX.esformat
    inchanges = GX.changes
    rere = ""

  if action !~ "getlinks|process|format" :
    "Error in process_article() for action " & action & ": no right action defined." >* "/dev/stderr"
    return
  if(target !~ "citeinside|citeoutside|webarchiveinside|webarchiveoutside|bareoutside|bareinside" ):
    "Error in process_article() for target " & target & ": no right target defined." >* "/dev/stderr"
    return
 
  # match archive.org surrounded by []
  let reWayback = "[[]" & GX.space & GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][0-9*]{1,14}[/][^]]*[]]" 
  # match webcitation.org surrounded by []
  let reWebcite = "[[]" & GX.space & GX.wcre & "[^]]*[]]"
  # match archive.is surrounded by []
  let reArchiveis = "[[]" & GX.space & GX.isre & "[^]]*[]]"
  let reLocgov = "[[]" & GX.space & GX.locgovre & "[^]]*[]]"
  let rePorto = "[[]" & GX.space & GX.portore & "[^]]*[]]"
  let reStanford = "[[]" & GX.space & GX.stanfordre & "[^]]*[]]"
  let reArchiveit = "[[]" & GX.space & GX.archiveitre & "[^]]*[]]"
  let reBibalex = "[[]" & GX.space & GX.bibalexre & "[^]]*[]]"
  let reNatarchivesuk = "[[]" & GX.space & GX.natarchivesukre & "[^]]*[]]"
  let reVefsafn = "[[]" & GX.space & GX.vefsafnre & "[^]]*[]]"
  let reEuropa = "[[]" & GX.space & GX.europare & "[^]]*[]]"
  let reMemory = "[[]" & GX.space & GX.memoryre & "[^]]*[]]"
  let rePermacc = "[[]" & GX.space & GX.permaccre & "[^]]*[]]"
  let reProni = "[[]" & GX.space & GX.pronire & "[^]]*[]]"
  let reParliament = "[[]" & GX.space & GX.parliamentre & "[^]]*[]]"
  let reUkweb = "[[]" & GX.space & GX.ukwebre & "[^]]*[]]"
  let reCanada = "[[]" & GX.space & GX.canadare & "[^]]*[]]"
  let reCatalon = "[[]" & GX.space & GX.catalonre & "[^]]*[]]"
  let reSingapore = "[[]" & GX.space & GX.singaporere & "[^]]*[]]"
  let reSlovene = "[[]" & GX.space & GX.slovenere & "[^]]*[]]"
  let reFreezepage = "[[]" & GX.space & GX.freezepagere & "[^]]*[]]"
  let reWebharvest = "[[]" & GX.space & GX.webharvestre & "[^]]*[]]"
  let reNlaau = "[[]" & GX.space & GX.nlaaure & "[^]]*[]]"
  let reWikiwix = "[[]" & GX.space & GX.wikiwixre & "[^]]*[]]"
  let reYork = "[[]" & GX.space & GX.yorkre & "[^]]*[]]"
  let reLac = "[[]" & GX.space & GX.lacre & "[^]]*[]]"

  # newwebarchives

 # Cite or Webarchive templates inside ref pairs

  if(target ~ "citeinside|webarchiveinside|bareinside"):

    if Proc.citeinsidec == -1:
      Proc.citeinsideb = newSeq[string](0)
      Proc.citeinsidec = awk.split(GX.articlework, Proc.citeinsideb, "<ref[^>]*>")

    if Proc.citeinsidec > 1:

      for i in 0..Proc.citeinsidec - 1:
        if(len(Proc.citeinsideb[i]) > 1):


          var tl, k = ""
          var endref = index(Proc.citeinsideb[i], "</ref>") 

          if(endref > 1):

            k = substr(Proc.citeinsideb[i], 0, endref - 1)
            
            if dummydate(k, "1970") and not Runme.api:
              Runme.api = true

#            echo "*DB K = " & k
#            echo " *DB cbignore = " & $cbignore(k)
#            echo " *DB target = " & target
#            echo " *DB bundled = " & $bundled(k)

            # fix double {{webarchive}} and double {{dead link}} first
            if k ~ ("[Ww]ebarchive" & GX.space & "[|]") and not cbignore(k) and target == "webarchiveinside" and action ~ "format":
              var orig = k
              tl = fixdeadtl(orig)
              tl = fixdoublewebarchive(tl, "cite")
              if orig != tl and len(tl) > 2:
                Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], orig, tl, "citeinside0.1", "limited")
                GX.articlework = replacefullref(k, orig, tl, "citeinside0")
                k = tl   

          # Cite templates
            if( k ~ ("[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]{0,1}([Uu][Rr][Ll]|[Dd][Aa][Tt][Ee])" & GX.space & "[=]") and target == "citeinside" and not cbignore(k) and bundled(k) == 0 ):
              var d = ""
              match(k, GX.cite, d)
              tl = "{" & d & "}"
              var orig = tl
              var url = getarg("archive-url", "clean", tl)
              if citeignore(tl) or urlignore(url):
                url = "http://example.com"
              if isarchiveorg(url):
                if action == "format":
                  tl = fixthespuriousone(tl)
                  tl = fixencodedurl(tl)
                  tl = fixdoubleurl(tl)
                  tl = fixemptyarchive(tl, target)
                  tl = fixdatemismatch(tl) 
                  if orig != tl and len(tl) > 2:
                    GX.articlework = replacefullref(k, orig, tl, "citeinside1")
                    Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], orig, tl, "citeinside1.1", "limited")
                    k = replacefullref(k, orig, tl, "citeinside1.2", "limited")
                elif action == "getlinks":
                  fillarray(strip(url), "normal")
                  if Runme.replacewikiwix and url ~ "wik.archive.org":
                    var ourl = url
                    gsubs("wik.archive.org", "web.archive.org", url)
                    GX.articlework = replacefullref(k, ourl, url, "citeinside1.3")
                    Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], ourl, url, "citeinside1.4", "limited")
                    k = replacefullref(k, ourl, url, "citeinside1.5", "limited")
                elif action == "process":
                  tl = fixbadstatus(tl, k, target)
                  if orig != tl and len(tl) > 2:
                    GX.articlework = replacefullref(k, orig, tl, "citeinside2")
                    Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], orig, tl, "citeinside2.1", "limited")
                    k = replacefullref(k, orig, tl, "citeinside2.2", "limited")
                    var newk = fixdeadtl(k)
                    newk = fixdoublewebarchive(newk, "cite")
                    if k != newk and len(newk) > 2:
                      GX.articlework = replacefullref(k, k, newk, "citeinside2.3")
                      Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], k, newk, "citeinside2.4", "limited")
                      k = replacefullref(k, k, newk, "citeinside2.5", "limited")
              elif isarchive(url, "sub1"):
                if action == "format":
                  tl = fixemptyarchive(tl, target)
                  tl = fixbadstatusother(tl, target) 
                  tl = fixdatemismatch(tl)
                  if orig != tl and not empty(tl):
                    GX.articlework = replacefullref(k, orig, tl, "citeinside4")
                    Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], orig, tl, "citeinside4.1", "limited")
                    k = replacefullref(k, orig, tl, "citeinside4.2", "limited")
                elif action == "getlinks":
                  fillarray(strip(url), "normal")
              elif url == "" and action == "format":
                tl = fixthespuriousone(tl)
                tl = fixencodedurl(tl)
                tl = fixdoubleurl(tl)
                tl = fixemptyarchive(tl, target)
                tl = fixdatemismatch(tl) 
                if orig != tl and len(tl) > 2:
                  GX.articlework = replacefullref(k, orig, tl, "citeinside3")
                  Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], orig, tl, "citeinside3.1", "limited")
                  k = replacefullref(k, orig, tl, "citeinside3.2", "limited")

                                                 # Operations on webarchive template inside ref
            if k ~ ("[Ww]ebarchive" & GX.space & "[|]") and not cbignore(k) and bundled(k) == 0 and target == "webarchiveinside":
              var d = ""
              match(k, "[{]" & GX.space & "[Ww]ebarchive[^}]+}", d)
              tl = "{" & d & "}"
              var orig = tl
              var url = getarg("url", "clean", tl)        
              if isarchiveorg(url):
                if action == "format":
                  tl = fixemptywebarchive(tl)
                  tl = fixdatemismatch(tl) 
                  if orig != tl and len(tl) > 2:
                    GX.articlework = replacefullref(k, orig, tl, "webarchiveinside1")
                    Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], orig, tl, "webarchiveinside1.1", "limited")
                    k = replacefullref(k, orig, tl, "webarchiveinside1.2", "limited")
                if action == "getlinks":
                  fillarray(url, "normal")
                  if Runme.replacewikiwix and url ~ "wik.archive.org":
                    var ourl = url
                    gsubs("wik.archive.org", "web.archive.org", url)
                    GX.articlework = replacefullref(k, ourl, url, "webarchiveinside1.3")
                    Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], ourl, url, "webarchiveinside1.4", "limited")
                    k = replacefullref(k, ourl, url, "webarchiveinside1.5", "limited")
                elif action == "process":
                  tl = fixbadstatus(tl, k, target)
                  if orig != tl and len(tl) > 2:
                    GX.articlework = replacefullref(k, orig, tl, "webarchiveinside2")
                    Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], orig, tl, "webarchiveinside1.1", "limited")
                    k = replacefullref(k, orig, tl, "webarchiveinside2.1", "limited")
              elif isarchive(url, "sub1"):
                if action == "format":
                  tl = fixemptywebarchive(tl)
                  tl = fixbadstatusother(tl, target)   # might return 0-length OK
                  tl = fixdatemismatch(tl)
                  if orig != tl:
                    GX.articlework = replacefullref(k, orig, tl, "webarchiveinside4")
                    Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], orig, tl, "webarchiveinside4.1", "limited")
                    k = replacefullref(k, orig, tl, "webarchiveinside4.2", "limited")
                elif action == "getlinks":
                  fillarray(url, "normal")
              elif url == "" and action == "format":
                tl = fixemptywebarchive(tl)
                tl = fixdatemismatch(tl) 
                if orig != tl and len(tl) > 2:
                  GX.articlework = replacefullref(k, orig, tl, "webarchiveinside3")
                  Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], orig, tl, "citeinside3.1", "limited")
                  k = replacefullref(k, orig, tl, "webarchiveinside3.2", "limited")

                                                 # Operations on archive.org barelinks inside ref pairs (surrounded by [])
            if k ~ reWayback and not cbignore(k) and target == "bareinside":
              var 
                c = 0
                field = newSeq[string](0)
                sep = newSeq[string](0)
                origfullel = k

              c = patsplit(k, field, reWayback, sep)
              if c > 0:
                for j in 0..c-1:
                  tl = stripfullel(field[j])
                  if urlignore(tl):
                    continue
                  if isarchiveorg(tl):
                    if action == "format":
                      var newfullel = fixdoubleurl(tl, origfullel)
                      if origfullel != newfullel and len(newfullel) > 2:
                        GX.articlework = replacetext(GX.articlework, origfullel, newfullel, "bareinside1")
                        Proc.citeinsideb[i] = replacetext(Proc.citeinsideb[i], origfullel, newfullel, "bareinside1.1")
                        k = replacetext(k, origfullel, newfullel, "bareinside1.2")
                        origfullel = newfullel
                    elif action == "getlinks":
                      fillarray(strip(tl), "normal")
                      if Runme.replacewikiwix and tl ~ "wik.archive.org":
                        var ourl = strip(tl)
                        gsubs("wik.archive.org", "web.archive.org", tl)
                        GX.articlework = replacetext(GX.articlework, ourl, strip(tl), "bareinside1.3")
                        Proc.citeinsideb[i] = replacetext(Proc.citeinsideb[i], ourl, strip(tl), "bareinside1.4")
                        k = replacetext(k, ourl, strip(tl), "bareinside1.5")
                    elif action == "process":
                      var newfullel = fixbadstatus(tl, origfullel, target)
                      if origfullel != newfullel and len(newfullel) > 2:
                        GX.articlework = replacetext(GX.articlework, origfullel, newfullel, "bareinside2")
                        Proc.citeinsideb[i] = replacetext(Proc.citeinsideb[i], origfullel, newfullel, "bareinside2.1")
                        k = replacetext(k, origfullel, newfullel, "bareinside2.2")
                        origfullel = newfullel
                        var newk = fixdoublewebarchive(origfullel, "barelink")
                        if k != newk and len(newk) > 2:
                          GX.articlework = replacefullref(k, k, newk, "bareinside2.3")
                          Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], k, newk, "bareinside2.4", "limited")
                          k = replacefullref(k, k, newk, "bareinside2.5", "limited")
                          origfullel = k


                                                 # Operations on other barelinks inside ref pairs (surrounded by [])
            for r in 0..24:
              if r == 0:
                rere = reWebcite            
              elif r == 1:
                rere = reArchiveis
              elif r == 2:
                rere = reLocgov
              elif r == 3:
                rere = rePorto
              elif r == 4:
                rere = reStanford
              elif r == 5:
                rere = reArchiveit
              elif r == 6:
                rere = reBibalex
              elif r == 7:
                rere = reNatarchivesuk
              elif r == 8:
                rere = reVefsafn
              elif r == 9:
                rere = reEuropa
              elif r == 10:
                rere = rePermacc
              elif r == 11:
                rere = reProni
              elif r == 12:
                rere = reParliament
              elif r == 13:
                rere = reUkweb
              elif r == 14:
                rere = reCanada
              elif r == 15:
                rere = reCatalon
              elif r == 16:
                rere = reSingapore
              elif r == 17:
                rere = reSlovene
              elif r == 18:
                rere = reFreezepage
              elif r == 19:
                rere = reWebharvest
              elif r == 20:
                rere = reNlaau
              elif r == 21:
                rere = reWikiwix
              elif r == 22:
                rere = reYork
              elif r == 23:
                rere = reMemory
              elif r == 24:
                rere = reLac

              # newwebarchives (update in two places above, name and count at top of loop)

              if k ~ rere and not cbignore(k) and target == "bareinside":
                var 
                  c = 0
                  field = newSeq[string](0)
                  sep = newSeq[string](0)
                  origfullel = k

                c = patsplit(k, field, rere, sep)
                if c > 0:
                  for j in 0..c-1:
                    tl = stripfullel(field[j])
                    if isarchive(tl, "sub1"):
                      if action == "format":
                        var newfullel = fixbadstatusother(tl, target, origfullel)
                        if origfullel != newfullel and len(newfullel) > 2:
                          GX.articlework = replacetext(GX.articlework, origfullel, newfullel, "bareinsidewebcite1")
                          Proc.citeinsideb[i] = replacetext(Proc.citeinsideb[i], origfullel, newfullel, "bareinsidewebcite1.1")
                          k = replacetext(k, origfullel, newfullel, "bareinsidewebcite1.2")
                          origfullel = newfullel
                          var newk = fixdoublewebarchive(origfullel, "barelink")
                          if k != newk and len(newk) > 2:
                            GX.articlework = replacefullref(k, k, newk, "bareinside2.3")
                            Proc.citeinsideb[i] = replacefullref(Proc.citeinsideb[i], k, newk, "bareinside2.4", "limited")
                            k = replacefullref(k, k, newk, "bareinside2.5", "limited")
                            origfullel = k
                      elif action == "getlinks":
                        fillarray(strip(tl), "normal")
  

 # Cite/Wayback templates or Barelink outside ref pairs

  if target ~ "citeoutside|waybackoutside|webarchiveoutside|bareoutside":

    if Proc.articlenorefc == -1:
      var ix = -1
      Proc.articlenorefb = newSeq[string](0)
      Proc.articlenoref = GX.articlework
      Proc.articlenoref = stripwikicommentsref(Proc.articlenoref)  # Remove wikicomments in case <ref></ref> is embeded in a comment
      gsub("<ref[^>]*/[ ]{0,}>", "", Proc.articlenoref)                                               # remove <ref name=string />    
      Proc.articlenorefc = awk.split(Proc.articlenoref, Proc.articlenorefb, "<ref[^>]*>")             # remove <ref></ref>
      for i in 1..Proc.articlenorefc - 1:
        ix = index(Proc.articlenorefb[i], "</ref>")
        if ix > -1:
          gsubs(substr(Proc.articlenorefb[i], 0, ix), "", Proc.articlenoref)

   # Webarchive templates outside ref pairs
    if target == "webarchiveoutside":

      if Proc.weboutsidec == -1: 
        Proc.weboutsideb = newSeq[string](0)
        Proc.weboutsidec = awk.split(Proc.articlenoref, Proc.weboutsideb, "[{][ ]?[{]")

      if Proc.weboutsidec > 1:

        for i in 0..Proc.weboutsidec - 1:

          var 
            tl, k = ""

          if Proc.weboutsideb[i] == "" or Proc.weboutsideb[i] == nil: continue

          if Proc.weboutsideb[i] !~ "^[{][ ]?[{]":
            Proc.weboutsideb[i] = "{{" & Proc.weboutsideb[i] # readd removed by split above

          k = substr(Proc.weboutsideb[i], 0, index(Proc.weboutsideb[i], "}}") - 1)

          if dummydate(k, "1970") and not Runme.api:
            Runme.api = true
          
                                                 # Operations on webarchive template string 
          if k ~ ("[Ww]ebarchive" & GX.space & "[|]") and not cbignore(k) and bundled(k) == 0 and target == "webarchiveoutside":
            k = "{{" & k & "}}"
            match(k, "[{]" & GX.space & "[Ww]ebarchive[^}]+}", d)
            tl = "{" & d & "}"
            var orig = tl
            var url = getarg("url", "clean", tl)
            if isarchiveorg(url):
              if action == "format":
                tl = fixemptywebarchive(tl)
                tl = fixdatemismatch(tl) 
                if orig != tl and len(tl) > 2:
                  GX.articlework = replacetext(GX.articlework, orig, tl, "webarchiveoutside1")                # gsub
                  Proc.weboutsideb[i] = replacetext(Proc.weboutsideb[i], orig, tl, "webarchiveoutside1.1")    # gsub
              if action == "getlinks":
                fillarray(url, "normal")
                if Runme.replacewikiwix and url ~ "wik.archive.org":
                  var ourl = url
                  gsubs("wik.archive.org", "web.archive.org", url)
                  GX.articlework = replacetext(GX.articlework, ourl, url, "webarchiveoutside1.3")
                  Proc.weboutsideb[i] = replacetext(Proc.weboutsideb[i], ourl, url, "webarchiveoutside1.4")
              elif action == "process":
                tl = fixbadstatus(tl, k, target)
                if orig != tl and len(tl) > 2:
                  GX.articlework = replacetext(GX.articlework, orig, tl, "webarchiveoutside2")                # gsub for "webarchiveoutside1-2"
                  Proc.weboutsideb[i] = replacetext(Proc.weboutsideb[i], orig, tl, "webarchiveoutside2.1")
            elif isarchive(url, "sub1"):
              if action == "format":
                tl = fixemptywebarchive(tl)
                tl = fixbadstatusother(tl, target)  # can be 0-length OK
                tl = fixdatemismatch(tl)
                if orig != tl:
                  GX.articlework = replacetext(GX.articlework, orig, tl, "webarchiveoutside4")
                  Proc.weboutsideb[i] = replacetext(Proc.weboutsideb[i], orig, tl, "webarchiveoutside4.1")
              elif action == "getlinks":
                fillarray(url, "normal")
            elif url == "" and action == "format":
              tl = fixemptywebarchive(tl)
              tl = fixdatemismatch(tl) 
              if orig != tl and len(tl) > 2:
                GX.articlework = replacetext(GX.articlework, orig, tl, "webarchiveoutside3.1")                # gsub
                Proc.weboutsideb[i] = replacetext(Proc.weboutsideb[i], orig, tl, "webarchiveoutside3.2")      # gsub


   # Cite templates outside ref pairs
    if target == "citeoutside":
  
      if Proc.citeoutsidec == -1: 
        Proc.citeoutsideb = newSeq[string](0)
        Proc.citeoutsidec = awk.split(Proc.articlenoref, Proc.citeoutsideb, "[{][ ]?[{]")

      if Proc.citeoutsidec > 1:

        for i in 0..Proc.citeoutsidec - 1:

          var 
            tl, k, d, orig, url = ""

          if Proc.citeoutsideb[i] == "" or Proc.citeoutsideb[i] == nil: continue

          if Proc.citeoutsideb[i] !~ "^[{][ ]?[{]":
            Proc.citeoutsideb[i] = "{{" & Proc.citeoutsideb[i] # readd removed by split above

          k = substr(Proc.citeoutsideb[i], 0, index(Proc.citeoutsideb[i], "}}") - 1)

#          echo "*MAIN = " & Proc.citeoutsideb[i]
#          echo " *DB K = " & k
#          echo " *DB cbignore = " & $cbignore(k)
#          echo " *DB target = " & target
#          echo " *DB bundled = " & $bundled(k)

          if dummydate(k, "1970") and not Runme.api:
            Runme.api = true

          if k ~ ("[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]{0,1}([Uu][Rr][Ll]|[Dd][Aa][Tt][Ee])" & GX.space & "[=]") and not cbignorebareline(GX.articlework, k):
            k = "{{" & k & "}}"
            match(k, GX.cite, d)
            tl = "{" & d & "}"
            orig = tl
            url = getarg("archive-url", "clean", tl)
            if citeignore(tl) or urlignore(url):
              url = "http://example.com"
            if isarchiveorg(url):
              if action == "format":
                tl = fixthespuriousone(tl)
                tl = fixencodedurl(tl)
                tl = fixemptyarchive(tl, target)
                tl = fixdoubleurl(tl)
                tl = fixdatemismatch(tl)
                if orig != tl and len(tl) > 2:
                  GX.articlework = replacetext(GX.articlework, orig, tl, "processoutside2")                # gsub
                  Proc.citeoutsideb[i] = replacetext(Proc.citeoutsideb[i], orig, tl, "processoutside2.1")  # gsub
              elif action == "getlinks":
                fillarray(url, "normal")
                if Runme.replacewikiwix and url ~ "wik.archive.org":
                  var ourl = url
                  gsubs("wik.archive.org", "web.archive.org", url)
                  GX.articlework = replacetext(GX.articlework, ourl, url, "processoutside1.1")
                  Proc.citeoutsideb[i] = replacetext(Proc.citeoutsideb[i], ourl, url, "processoutside1.2")
              elif action == "process":
                tl = fixbadstatus(tl, k, target)
                if orig != tl and len(tl) > 2:
                  GX.articlework = replacetext(GX.articlework, orig, tl, "processoutside3")                # gsub for "processoutside2-3" 
                  Proc.citeoutsideb[i] = replacetext(Proc.citeoutsideb[i], orig, tl, "processoutside3.1")  # gsub
            elif isarchive(url, "sub1"):
              if action == "format":
                tl = fixemptyarchive(tl, target)
                tl = fixbadstatusother(tl, target)
                tl = fixdatemismatch(tl)
                if orig != tl and len(tl) > 2:
                  GX.articlework = replacetext(GX.articlework, orig, tl, "processoutside6")                # gsub
                  Proc.citeoutsideb[i] = replacetext(Proc.citeoutsideb[i], orig, tl, "processoutside6.1")  # gsub
              elif action == "getlinks":
                fillarray(url, "normal")
            elif url == "" and action == "format":
              tl = fixthespuriousone(tl)
              tl = fixencodedurl(tl)
              tl = fixdoubleurl(tl)                
              tl = fixemptyarchive(tl, target)
              tl = fixdatemismatch(tl) 
              if orig != tl and len(tl) > 2:
                GX.articlework = replacetext(GX.articlework, orig, tl, "processoutside4.1")
                Proc.citeoutsideb[i] = replacetext(Proc.citeoutsideb[i], orig, tl, "processoutside4.2")


   # Bare links outside ref pairs ( for links encased in [] )
    if target == "bareoutside":

      if Proc.bareoutsidec == -1:
        Proc.bareoutsideb = newSeq[string](0)
        Proc.bareoutsidec = awk.patsplit(Proc.articlenoref, Proc.bareoutsideb, (reWayback & "|" & reWebcite & "|" & reArchiveis & "|" & reLocgov & "|" & rePorto & "|" & reStanford & "|" & reArchiveit & "|" & reBibalex & "|" & reNatarchivesuk & "|" & reVefsafn & "|" & reEuropa & "|" & rePermacc & "|" & reProni & "|" & reParliament & "|" & reUkweb & "|" & reCanada & "|" & reCatalon & "|" & reSingapore & "|" & reSlovene & "|" & reWebharvest & "|" & reFreezepage & "|" & reNlaau & "|" & reWikiwix & "|" & reYork & "|" & reMemory & "|" & reLac) )

# newwebarchives

      if Proc.bareoutsidec > 0:

        var tl, orig, origfullel, newfullel = ""
  
        for i in 0..Proc.bareoutsidec - 1:
         
          if Proc.bareoutsideb[i] == "" or Proc.bareoutsideb[i] == nil: continue

          tl = stripfullel(Proc.bareoutsideb[i])  # remove "[]" and title from external link
          orig = tl

          if dummydate(tl, "1970") and not Runme.api:
            Runme.api = true

          if tl ~ GX.shttp and tl !~ "[ ]" and len(tl) > 24 and not cbignorebareline(GX.articlework, tl) and not urlignore(tl):
            if isarchiveorg(tl):
              if action == "format":
                origfullel = Proc.bareoutsideb[i]
                newfullel = fixdoubleurl(tl, origfullel)
                if origfullel != newfullel and len(newfullel) > 2:
                  GX.articlework = replacetext(GX.articlework, origfullel, newfullel, "processoutside5")
                  Proc.bareoutsideb[i] = replacetext(Proc.bareoutsideb[i], origfullel, newfullel, "processoutside5.1") 
              elif action == "getlinks":
                fillarray(strip(tl), "normal") 
                if Runme.replacewikiwix and strip(tl) ~ "wik.archive.org":
                  var ourl = strip(tl)
                  gsubs("wik.archive.org", "web.archive.org", tl)
                  GX.articlework = replacetext(GX.articlework, ourl, tl, "processoutside5.2")
                  Proc.bareoutsideb[i] = replacetext(Proc.bareoutsideb[i], ourl, tl, "processoutside5.3")
              elif action == "process":
                origfullel = Proc.bareoutsideb[i]
                newfullel = fixbadstatus(tl, origfullel, target)
                if origfullel != newfullel and len(newfullel) > 10:
                  GX.articlework = replacetext(GX.articlework, origfullel, newfullel, "processoutside6")        # gsub for "processoutside5" 
                  Proc.bareoutsideb[i] = replacetext(Proc.bareoutsideb[i], origfullel, newfullel, "processoutside6.1") 
            elif isarchive(tl, "sub1"):
              if action == "format":
                origfullel = Proc.bareoutsideb[i]
                newfullel = fixbadstatusother(tl, target, origfullel)
                if origfullel != newfullel and len(newfullel) > 2:
                  GX.articlework = replacetext(GX.articlework, origfullel, newfullel, "processoutside7")
                  Proc.bareoutsideb[i] = replacetext(Proc.bareoutsideb[i], origfullel, newfullel, "processoutside7.1") 
              elif action == "getlinks":
                fillarray(strip(tl), "normal")

  # Make sure at least one gets updated if there was a change
  if GX.changes > inchanges and (GX.esrescued == inrescued and GX.esremoved == inremoved and GX.esformat == informat): 
    inc(GX.esformat)

# ________________________________________________________________ Main

setup(CL.project)
setdatetype()
sed("Starting " & CL.name, Debug.network)

 # Check WebCite API is up by checking known good page

if CL.debug !~ "[y]|[Y]":  # Don't check while debugging.
  if contains(GX.articlework, "webcitation.org"):
    if not validate_webciteid("http://www.webcitation.org/5x46YiH58"):
      libutils.sleep(8)
      if not validate_webciteid("http://www.webcitation.org/5x46YiH58"):
        GX.webciteok = false
        sendlog(Project.critical, CL.name, " WebCite API is down.")  

emtem(GX.articlework, "log")                # log any embedded templates
var deadcountstart = deadcount()

  # Whole-article fixes 

GX.articlework = encodemag(GX.articlework)  # encode magic characters before nim procs


  # nim procs                               # Note: any proces in this subsection need GX.articlework >* GX.workfile so subsequent modules see changes made

fixnowikiway()                              # run before fixwam()
fixcommentarchive()                         # run before fixwebcitlong()
GX.articlework = decodemag(GX.articlework)  # decode magic before modules
GX.articlework >* GX.datadir & "workarticle.txt"

  # awk external modules

fixciteaddl() 
fixwebcitlong(Runme.webcitlongverify) 
fixwikiwixlong() 
fixfreezelong() 
fixarchiveis() 
fixstraydt()                                # run after fixwebcitlong() and fixarchiveis()
fixwam()
GX.articlework = encodemag(GX.articlework)  # encode magic characters before nim procs

  # nim procs

# fixwikiwix()
fixencodebug()                              # run after fixwebcitlong()
fix3slash()
fixitems()
fixdoublewebarchiveoutside()
fixembwebarchive()
fixembway()
replacedeadlink()                           # run before fixiats()
fixiats()                                   # run after fixembway()
fixswitchurl()                              # run after fixiats()

  # Parser fixes

process_article("format", "bareoutside")
process_article("format", "citeoutside")
process_article("format", "webarchiveoutside")
process_article("format", "webarchiveinside")
process_article("format", "citeinside")
process_article("format", "bareinside")

if Runme.api == true:

 # Parse for IA links
  process_article("getlinks", "bareoutside")
  process_article("getlinks", "citeoutside")
  process_article("getlinks", "webarchiveoutside")
  process_article("getlinks", "webarchiveinside")
  process_article("getlinks", "citeinside")
  process_article("getlinks", "bareinside")

  for i in 0..GX.id:
    inc(GX.numfound)
    if Debug.api and GX.numfound == 1: "\nFound [" & $(GX.id + 1) & "] links:\n" >* "/dev/stderr"
    if Debug.api:
      "  WayLink[" & $i & "].origiaurl = " & WayLink[i].origiaurl >* "/dev/stderr"
      "  WayLink[" & $i & "].origencoded = " & WayLink[i].origencoded >* "/dev/stderr"
      "  WayLink[" & $i & "].origdate = " & WayLink[i].origdate >* "/dev/stderr"
      "  WayLink[" & $i & "].altarch = " & WayLink[i].altarch >* "/dev/stderr"
      "  WayLink[" & $i & "].altarchencoded = " & WayLink[i].altarchencoded >* "/dev/stderr"
      "--" >* "/dev/stderr"

  if GX.numfound > 0:
    if queryapipost(GX.numfound):                              # Entry to medicapi.nim
      process_article("process", "webarchiveinside")
      process_article("process", "bareinside")
      process_article("process", "citeoutside")
      process_article("process", "webarchiveoutside")
      process_article("process", "citeinside")                 # N.B.: this must be last?
      process_article("process", "bareoutside")                # this goes global replace of bare links and is most dangerous
    else:
      "Error in queryAPI() for " & CL.name & " : bad data. Aborting with no changes to article." >* "/dev/stderr"
      try:
        removeFile("/tmp/" & GX.wid)
      except:
        "" >* "/tmp/" & GX.wid
      quit(QuitSuccess)

garbagecheck()

# Run some proces again to clear any {{dead link}} strays created by WM, etc.
GX.articlework = decodemag(GX.articlework)  
GX.articlework >* GX.datadir & "workarticle.txt"
"----" >> GX.datadir & "debug"
"step 1" >> GX.datadir & "debug"
fixwebcitlong(false) 
"step 2" >> GX.datadir & "debug"
fixstraydt()   
"step 3" >> GX.datadir & "debug"

if not empty(GX.imp):
  "----------------" >> GX.datadir & "apilog"

# Only save if there was a change to the article
if strip(GX.article) != strip(GX.articlework):                               

  "step 4" >> GX.datadir & "debug"

  if nospacebug():
    "step 5" >> GX.datadir & "debug"
    strip(GX.articlework) >* GX.datadir & "article.waybackmedic.txt"
    var deadcountend = deadcount()
    if deadcountstart > 0 and deadcountend < deadcountstart:       # count of permanent dead-link rescued
      sendlog(Project.syslog, CL.name, $deadcountstart & "----" & $deadcountend & "----" & $(deadcountstart - deadcountend) & "----" & "deadcount")
    "step 6" >> GX.datadir & "debug"
    if CL.debug ~ "[y]|[Y]":                                       # re-add to "discover" since it was removed by clearlogs()
      if not isindiscovered(CL.name):                              # ..but only if it's "article.txt" .. don't want to upload test.X results
        if CL.sourcefile ~ "article[.]txt$":
          CL.name >> Project.discovered
        else:
          echo "Test run. Not saved in discovered (article.txt only)"
    if GX.changes < 1:                                             # Echo > 0 changes regardless of change count
      incchanges(1, "main1")
    echo GX.changes
  else:
    "step 7" >> GX.datadir & "debug"
    sendlog(Project.syslog, CL.name, "nospacebug")
    if fileExists(GX.datadir & "article.waybackmedic.txt"):
      moveFile(GX.datadir & "article.waybackmedic.txt", GX.datadir & "article.waybackmedic.txt.old")
    echo "0"

else:

  "step 8" >> GX.datadir & "debug"
  if GX.changes > 0:                                           
    "step 9" >> GX.datadir & "debug"
    sendlog(Project.phantom, CL.name, "medic.nim: " & $GX.changes & " " & editsummary() )
  if fileExists(GX.datadir & "article.waybackmedic.txt"):
    moveFile(GX.datadir & "article.waybackmedic.txt", GX.datadir & "article.waybackmedic.txt.old")
  echo "0"

"step 10" >> GX.datadir & "debug"
editsummary() >* GX.datadir & "editsummary"
try:
  removeFile("/tmp/" & GX.wid)
except:
  quit(QuitSuccess)

quit(QuitSuccess)
