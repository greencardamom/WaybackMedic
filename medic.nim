import awk, libutils, strutils, times, json, osproc, os, docopt
from math import randomize, random
include medicinit
include mediclibrary
include medicapi

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
# fixthespuriousone (Rev: B)
#   B: changed from "1=" to "[1-9]="
#
# Remove spurious "|1=" from cite templates
#    https://en.wikipedia.org/w/index.php?title=List_of_Square_Enix_video_games&curid=1919116&diff=704745846&oldid=703682254
#
proc fixthespuriousone(tl: string): string =
  var s = ""
  if match(tl, "[|][ ]?[1-9][ ]?=[ ]{0,}[^|}]", s) > 0:
    inc(GX.changes)
    sendlog(Project.logspurone, CL.name, "cite1")
    return replacetext(tl, s, "", "fixspuriousone1")
  return tl

#
# fixtrailingchar (Rev: A)
#
# Fix trailing char in url= created by user input error
#  See extra "," added to url https://en.wikipedia.org/w/index.php?title=Comanche_National_Grassland&type=revision&diff=707575983&oldid=655945746
#  Only needs to check wayback templates since those were imported by Cyberbot from bare URLs
#  Order: Must come before any web operations using the URL
#
proc fixtrailingchar(tl: string): string =

  var url, url2 = ""
  var tl = tl

  if datatype(tl,"wayback"):
    url = getargurl(tl)
    url2 = url
    if awk.substr(url, high(url), 1) ~ "[,]|[.]|[:]":
      tl = replacetext(tl, url, gsub("[,]$|[.]$|[:]$", "", url2), "fixtrailing1")
      inc(GX.changes)
      sendlog(Project.logtrail, CL.name, "wayback1")
      return tl
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

  if datatype(tl,"cite"):
    url = getargurl(tl)
    if url ~ "^http[s]{0,1}[%]3A[%]2F[%]2F":
      uxurl = uriparseEncodeurl(urldecode(url))         
      tl = replacetext(tl, url, uxurl, "fixencoded1")
      inc(GX.changes)
      sendlog(Project.logencode, CL.name, "cite1")
      return tl

  return tl

#
# fixemptywayback (Rev: A)
#
# Fix when a ref has an empty "{{wayback}}", with the intended url= portion misplaced at the start of the ref
#   Boko Haram insurgency: https://en.wikipedia.org/w/index.php?title=Boko_Haram_insurgency&type=revision&diff=709268607&oldid=708528456
#   Comac C919: https://en.wikipedia.org/w/index.php?title=Comac_C919&type=revision&diff=709236286&oldid=708889462
#
proc fixemptywayback(fullref: string): string =

  var url, date, df, dfout, s = ""
  var a = newSeq[string](0)
  var fullref = fullref

  match(fullref, "^[|]url=[^|]*[^|]", url)                    # ^|url=http..[ ]$
  if len(url) > 0 and count(fullref, "{{wayback}}") == 1:   
    if count(fullref, "{{wayback}}") == 1:                    # skip if bundeled
      if Debug.e: echo "url = " & url
      fullref = strip(removesection(fullref, 0, high(url), "fixemptywayback1") )
      if Debug.e: echo "fullref(1) = " & fullref
      match(fullref, "^[|]date=[^ ]*[ ]", date)               # ^|date=Jan..[ ]$
      if len(date) > 0:
        if Debug.e: echo "date = " & date
        fullref = strip(removesection(fullref, 0, high(date), "fixemptywayback2") )
        if Debug.e: echo "fullref(2) = " & fullref
        if match(fullref, "^[|]df=[yn][ ]", df) > 0:          # ^|df=y[ ]$
          fullref = strip(removesection(fullref, 0, high(df), "fixemptywayback3") )
          if Debug.e: echo "fullref(3) = " & fullref
          dfout = df
        else: 
          dfout = ""
        if Debug.e: echo "fullref(4) = " & fullref
        if patsplit(fullref, a, "{{[ ]{0,}wayback[ ]{0,}[|][^}]*[}][}]") == 1:    # Don't if bundeled ref
          match(fullref, "{{[ ]{0,}wayback[ ]{0,}[|][^}]*[}][}]", s)          
          fullref = replacetext(fullref, s, "", "fixemptywayback5")
        if patsplit(fullref, a, "{{[ ]{0,}dead link[ ]{0,}[|][^}]*[}][}]") == 1: # remove duplicate {{dead link |..}}
          match(fullref, "{{[ ]{0,}dead link[ ]{0,}[|][^}]*[}][}]", s)           
          fullref = replacetext(fullref, s, "", "fixemptywayback5")
        fullref = replacetext(fullref, "{{wayback}}", "{{wayback" & url & date & dfout & "}}", "fixemptywayback4")
        if Debug.e: echo "fullref(5) = " & fullref
        inc(GX.changes)
        sendlog(Project.logemptyway, CL.name, "way1")
        return fullref
    else:
      sendlog(Project.logemptyway, CL.name, "skipbundeled")
     
  return fullref

#
# fixemptyarchive (Rev: B)
#   B: overhauled. No longer tries to find a new URL.
#
# Fix where archiveurl= is empty (or url= in wayback template)
#   If url= is not working, remove empty archiveurl/date and leave dead link sans cbignore
#
proc fixemptyarchive(tl: string): string =

  var url, urlencoded = ""
  var status: int

  if datatype(tl,"cite") and tl ~ "archive[-]{0,1}url[ ]{0,}=[ ]{0,}[}|]":
    url = getargurl(tl)
    urlencoded = uriparseEncodeurl(urldecode(url))

    if urlencoded ~ "^http":

      if Debug.network: "Checking fixemptyarchive step 1" >* "/dev/stderr"
      status = webpagestatus(url)
      if status == 1 or status == 3:              # Leave empty arguments in place if url= is working
        return tl

      if Debug.network: "Checking fixemptyarchive step 2" >* "/dev/stderr"
      status = webpagestatus(urlencoded)
      if status == 1 or status == 3:              # Try again with encoding
        return tl

      if Debug.network: "Checking fixemptyarchive step 3" >* "/dev/stderr"
      libutils.sleep(2)
      status = webpagestatus(url)
      if status == 1 or status == 3:              # Try third time after pause
        return tl

      inc(GX.changes)                             # Remove the empty arguments and leave a dead link tag
      sendlog(Project.logemptyarch, CL.name, "cite1")
      return removearchive(tl, "fixemptyarchive1", "nocbignore")

 # Wayback templates

  if datatype(tl,"wayback") and tl ~ "[|][ ]{0,}url[ ]{0,}=[ ]{0,}[|}]":
    inc(GX.changes)
    sendlog(Project.logemptyarch, CL.name, "wayback1")
    return tl

  return tl


#
# fixbadstatus (Rev: A)
#
# Replace Wayback URLs reporting non-200 status. Update archivedate if changed.
#  tl is the contents of the template
#  optional "fullref" string ie. everything between <ref></ref>, or everything between [] (external link)
#
proc fixbadstatus(ttl: string, fr: varargs[string]): string =

  var tl = ttl
  var url, urlarch, newurl, newdate, olddate, waybackdate, k, str = ""
  var i = 0
  var fullref = ""
  
  if fr.len > 0:
    if fr[0] == nil:
      fullref = ""
    else:
      fullref = fr[0]

  if datatype(tl,"cite"):

    urlarch = getargarchive(tl, "url", "clean")
    if isarchiveorg(urlarch):
      newurl = api(urlarch)
      if newurl != "none" and isarchiveorg(newurl):
        if skindeep(newurl, urlarch):                                         # Stays the same
          return tl           
        else:                                                                 # Modify the snapshot date
          if urltimestamp(urlarch) != urltimestamp(newurl):
            newdate = urldate(newurl, getargarchive(tl, "date"))
            tl = replacetext(tl, urlarch, newurl, "fixbadstatuscite1")
            tl = replacetext(tl, getargarchive(tl,"date"), newdate, "fixbadstatuscite2")
            inc(GX.changes)
            sendlog(Project.log404, CL.name, "cite-modify")
            sendlog(Project.newiadate, CL.name, getargurl(tl) & " " & urltimestamp(urlarch) & " " & urltimestamp(newurl))
            return tl
          else:
            return tl
      elif newurl != "none" and not isarchiveorg(newurl):                     # Change to alt archive
        newdate = altarchfield(newurl, "altarchdate")
        var olddateclean = getargarchive(tl, "date", "clean")
        olddate = getargarchive(tl, "date")
        newdate = replacetext(olddate, olddateclean, timestamp2date(newdate), "fixbadstatuscite4.1")
        tl = replacetext(tl, urlarch, newurl, "fixbadstatuscite3")
        tl = replacetext(tl, olddate, newdate, "fixbadstatuscite4")
        inc(GX.changes)
        sendlog(Project.log404, CL.name, "cite-modifyaltarch")
        sendlog(Project.newaltarch, CL.name, getargurl(tl) & " " & urltimestamp(urlarch) & " " & newurl & " " & newdate)
        return tl
      else:                                                                   # Delete
        inc(GX.changes)
        sendlog(Project.log404, CL.name, "cite-delete")
        sendlogwayrm(Project.wayrm, CL.name, urlarch, tl)
        return removearchive(tl, "fixbadstatuscite5")
    else:
      sendlog(Project.log404, CL.name, "citeErrorB")
      return tl

  elif datatype(tl,"wayback"):

    url = getargurl(tl)
    waybackdate = getargwayback(tl,"date")
    urlarch = formatediaurl("https://web.archive.org/web/" & waybackdate & "/" & url, "barelink")

    if len(url) > 10 and url ~ "^http" and isarchiveorg(urlarch) and isanumber(waybackdate):
      newurl = api(urlarch)
      if newurl != "none" and isarchiveorg(newurl):
        if skindeep(newurl, urlarch):                                                     # Stays the same
          return tl
        else:                                                                             # Modify the snapshot date
          if waybackdate != urltimestamp(newurl):
            tl = replacetext(tl, waybackdate, urltimestamp(newurl), "fixbadstatuswayback1")
            inc(GX.changes)
            sendlog(Project.log404, CL.name, "wayback-modify")
            sendlog(Project.newiadate, CL.name, url & " " & waybackdate & " " & urltimestamp(newurl))
          return tl

      if newurl != "none" and not isarchiveorg(newurl):                                   # Change to Alternative archive
        if match(tl, "[{][ ]{0,}[Ww]ayback[ ]{0,}", k) > 0:
          str = "[" & altarchfield(newurl, "altarchencoded") & " Archived copy] at " & servicename(newurl) & " (" & timestamp2date(altarchfield(newurl, "altarchdate")) & ")."
          tl = replacetext(tl, tl, str, "fixbadstatuswayback2")
          inc(GX.changes)
          sendlog(Project.log404, CL.name, "wayback-replaced-altarch")         
          sendlog(Project.newaltarch, CL.name, url & " " & waybackdate & " " & newurl & " " & altarchfield(newurl, "altarchdate"))
        return tl          
      else:
        i = countsubstring(fullref, url)
        if i == 2:                                      # Delete wayback template / it follows an existing URL so replace with dead link only
          inc(GX.changes)
          sendlog(Project.log404, CL.name, "wayback-delete1")
          sendlog(Project.cbignore, CL.name, "wayback-delete1")
          sendlogwayrm(Project.wayrm, CL.name, urlarch, tl)   
          if fullref ~ "[{][{][Dd]ead[ ]link[ ]{0,}[|]":        # Check for duplicate {{dead link}}
            return "{{cbignore|bot=medic}}"
          else:
            return "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"
        elif i == 1:                                    # Delete wayback template / replace with cite web (wayback template is standlone)
          inc(GX.changes)
          sendlog(Project.log404, CL.name, "wayback-delete2")
          sendlog(Project.cbignore, CL.name, "wayback-delete2")
          sendlogwayrm(Project.wayrm, CL.name, urlarch, tl)
          if fullref ~ "[{][{][Dd]ead[ ]link[ ]{0,}[|]":        # Check for duplicate {{dead link}}
            return buildciteweb(url, getargwayback(tl,"title")) & "{{cbignore|bot=medic}}"
          else:
            return buildciteweb(url, getargwayback(tl,"title")) & "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"
        else:                                           # Bundled refs - leave alone and collect for future work
          inc(GX.changes)
          sendlog(Project.log404, CL.name, "waybackErrorA")
          return tl
    else:
      sendlog(Project.log404, CL.name, "waybackErrorB")
      return tl

  elif datatype(tl,"barelink"):

    newurl = api(tl)

    if newurl !~ "none" and isarchiveorg(newurl):
      if skindeep(newurl, tl):                                              # Stays the same
        return fullref
      else:                                                                 
        if urltimestamp(tl) != urltimestamp(newurl):                        # Modify the snapshot date
          inc(GX.changes)
          fullref = replacetext(fullref, tl, newurl, "fixbadstatusbare1")
          sendlog(Project.log404, CL.name, "barelink-modify")
          sendlog(Project.newiadate, CL.name, wayurlurl(tl) & " " & urltimestamp(tl) & " " & urltimestamp(newurl))
          return fullref
        else:
          return fullref
    if newurl != "none" and not isarchiveorg(newurl):                       # Change to Alternative archive
      fullref = replacetext(fullref, tl, newurl, "fixbadstatusbare2")
      inc(GX.changes)
      sendlog(Project.log404, CL.name, "barelink-replace-altarch")
      sendlog(Project.newaltarch, CL.name, wayurlurl(tl) & " " & urltimestamp(tl) & " " & newurl & " " & altarchfield(newurl, "altarchdate") )
      return fullref
    else:                                                   # Replace with original URL, leave a deadlink tag only if none exists on same line.
      str = "no"
      url = gsub("^https[:]//web[.]archive[.]org/web/[0-9]{1,14}/", "", formatediaurl(tl, "barelink"))
      if url ~ "^http" and len(url) > 9 and url !~ "[ ]":
        inc(GX.changes)
        if deadlinkbareline(GX.articlework, fullref) or fullref ~ "{{[ ]{0,}[Dd]ead link[ ]{0,}": str = "yes"
        fullref = replacetext(fullref, tl, url, "fixbadstatusbare3") # Replace URL inside the []
        if str == "no":
          fullref = fullref & "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"
        else:
          fullref = fullref & "{{cbignore|bot=medic}}"
        sendlog(Project.log404, CL.name, "barelink-delete")
        sendlogwayrm(Project.wayrm, CL.name, tl, url)
        return fullref
      else:
        sendlog(Project.log404, CL.name, "barelinkErrorA")
        return fullref
  else:
    # sendlog(Project.log404, CL.name, "unknownErrorA")
    return tl

  return tl

#
# Populate WayLink with data parsed from article
#   fillarray(url, cat [, date])
#    cat = "normal" or "build"
#     If cat build, also pass date
#
proc fillarray(url, cat: string, date: varargs[string]): bool {.discardable} =

  inc(GX.id)             # New ID
  newWayLink(GX.id)      # Create link object

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
  if WayLink[GX.id].origurl !~ "^http":
    eurl = formatedorigurl(WayLink[GX.id].origurl)
  else:
    eurl = WayLink[GX.id].origurl

  if WayLink[GX.id].origurl != "none":
    WayLink[GX.id].origencoded = uriparseEncodeurl(urldecode(eurl))
  else:
    WayLink[GX.id].origencoded = "none"

#
# Parse and process article. Action to perform is defined by "action". Type of links to process is defined by "target".
#
#   action = "format"   .. run the fix routines that are purely page formating (run first)
#   action = "getlinks" .. add Wayback Machine links found in the article to the WayLink[] array (run second)
#   action = "process"  .. run the fix routines that access the Wayback API (run last)
#
#   target = "citeinside"     .. Citation templates inside ref pairs
#   target = "citeoutside"    .. Citation templates outside ref pairs
#   target = "waybackinside"  .. Wayback template inside ref pairs
#   target = "waybackoutside" .. Wayback templates outside ref pairs
#   target = "bareoutside"    .. Bare links outside ref pairs
#
proc process_article(action, target: string) = 

  if action != "getlinks" and action != "process" and action != "format" :
    "Error in process_article() for action " & action & ": no right action defined." >* "/dev/stderr"
    return
  if(target != "citeinside" and target != "citeoutside" and target != "waybackinside" and target != "waybackoutside" and target != "bareoutside"):
    "Error in process_article() for target " & target & ": no right target defined." >* "/dev/stderr"
    return

  let re = "[{][ ]{0,}[Cc]ite[^}]+}|[{][ ]{0,}[Cc]ita[^}]+}|[{][ ]{0,}[Vv]cite[^}]+}|[{][ ]{0,}[Vv]ancite[^}]+}|[{][ ]{0,}[Hh]arvrefcol[^}]+}|[{][ ]{0,}[Cc]itation[^}]+}"

 # Cite or Wayback templates inside ref pairs

  if(target == "citeinside" or target == "waybackinside"):

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
            
          # Cite templates
            if( k ~ "archive[-]{0,1}url[ ]{0,}[=]" and target == "citeinside" and not cbignore(k) and bundled(k) == 0 ):
              var d = ""
              match(k, re, d)
              tl = "{" & d & "}"
              var orig = tl
              var url = strip(getargarchive(tl, "url", "clean"))
              if isarchiveorg(url):
                if action == "format":
                  tl = fixthespuriousone(tl)
                  tl = fixencodedurl(tl)
                  if orig != tl and len(tl) > 2:
                    GX.articlework = replacefullref(k, orig, tl, "citeinside1")
                    Proc.citeinsideb[i] = replacetext(Proc.citeinsideb[i], orig, tl, "citeinside1.1")
                elif action == "getlinks":
                  fillarray(strip(url), "normal")
                elif action == "process":
                  tl = fixbadstatus(tl)
                  if orig != tl and len(tl) > 2:
                    GX.articlework = replacefullref(k, orig, tl, "citeinside2")
              elif url == "" and action == "format":
                tl = fixemptyarchive(tl)
                if orig != tl and len(tl) > 2:
                  GX.articlework = replacefullref(k, orig, tl, "citeinside3")
                  Proc.citeinsideb[i] = replacetext(Proc.citeinsideb[i], orig, tl, "citeinside3.1")

          # Wayback template special operation
            elif k ~ "[{][{][Ww]ayback[}][}]" and target == "citeinside":   # Operationa on full reference string
              if action == "format":
                var orig = k
                k = fixemptywayback(k)
                if orig != k and len(k) > 2:
                  GX.articlework = replacefullref(orig, orig, k, "waybackinside1")
                  Proc.citeinsideb[i] = replacetext(Proc.citeinsideb[i], orig, tl, "waybackinside1.1")

                                                 # Operations on wayback template string 
            elif k ~ "[Ww]ayback[ ]{0,}[|]" and not cbignore(k) and bundled(k) == 0 and target == "waybackinside":
              var d = ""
              match(k, "{[ ]{0,}[Ww]ayback[^}]+}", d)
              tl = "{" & d & "}"
              var orig = tl
              var url = getargwayback(tl, "url")         
              if url ~ "^http":
                if action == "format":
                  tl = fixtrailingchar(tl)
                  tl = fixencodedurl(tl)
                  tl = fixemptyarchive(tl)
                  if orig != tl and len(tl) > 2:
                    GX.articlework = replacefullref(k, orig, tl, "waybackinside2")
                    Proc.citeinsideb[i] = replacetext(Proc.citeinsideb[i], orig, tl, "waybackinside2.1")
                elif action == "getlinks":
                  var date = getargwayback(tl, "date")
                  if isanumber(date):
                    fillarray(strip(url), "build", strip(date))
                elif action == "process":
                  tl = fixbadstatus(tl, k)
                  if orig != tl and len(tl) > 2:
                    GX.articlework = replacefullref(k, orig, tl, "waybackinside3")

 # Cite/Wayback templates or Barelink outside ref pairs

  if target ~ "citeoutside|waybackoutside|bareoutside":

    if Proc.articlenorefc == -1:
      var ix = -1
      Proc.articlenorefb = newSeq[string](0)
      Proc.articlenoref = GX.articlework
      Proc.articlenoref = stripwikicomments(Proc.articlenoref)  # Remove wikicomments in case <ref></ref> is embeded in a comment
      gsub("<ref[^>]*/[ ]{0,}>", "", Proc.articlenoref)                                               # remove <ref name=string />    
      Proc.articlenorefc = awk.split(Proc.articlenoref, Proc.articlenorefb, "<ref[^>]*>")             # remove <ref></ref>
      for i in 1..Proc.articlenorefc - 1:
        ix = index(Proc.articlenorefb[i], "</ref>")
        if ix > -1:
          Proc.articlenoref = replace(Proc.articlenoref, substr(Proc.articlenorefb[i], 0, ix), "")

   # Cite templates outside ref pairs
    if target == "citeoutside":

      if Proc.citeoutsidec == -1: 
        Proc.citeoutsideb = newSeq[string](0)
        Proc.citeoutsidec = awk.split(Proc.articlenoref, Proc.citeoutsideb, "[{][{]")

      if Proc.citeoutsidec > 1:

        for i in 0..Proc.citeoutsidec - 1:

          var tl, k, d, orig = ""

          if Proc.citeoutsideb[i] == "" or Proc.citeoutsideb[i] == nil: continue

          k = substr(Proc.citeoutsideb[i], 0, index(Proc.citeoutsideb[i], "}}") - 1)

          if k ~ "archive[-]{0,1}url[ ]{0,}[=]" and not cbignorebareline(GX.articlework, k):
            k = "{{" & k & "}}"
            match(k, re, d)
            tl = "{" & d & "}"
            orig = tl
            var url = getargarchive(tl, "url", "clean")
            if url ~ "^http" and isarchiveorg(url):
              if action == "format":
                tl = fixthespuriousone(tl)
                tl = fixencodedurl(tl)
                tl = fixemptyarchive(tl)
                if orig != tl and len(tl) > 2:
                  GX.articlework = replacetext(GX.articlework,orig,tl, "processoutside2")
                  Proc.citeoutsideb[i] = replacetext(Proc.citeoutsideb[i], orig, tl, "processoutside2.1")
              elif action == "getlinks":
                fillarray(strip(url), "normal")
              elif action == "process":
                tl = fixbadstatus(tl)
                if orig != tl and len(tl) > 2:
                  GX.articlework = replacetext(GX.articlework, orig, tl, "processoutside3")

   # Bare links outside ref pairs ( for links encased in [] )
    if target == "bareoutside":

      if Proc.bareoutsidec == -1:
        Proc.bareoutsideb = newSeq[string](0)
        Proc.bareoutsidec = patsplit(Proc.articlenoref, Proc.bareoutsideb, "[[][ ]{0,}https?[:]//w?[we]?[wb]?[.]?archive[.]org/?w?e?b?/[0-9]{1,14}/[^]]*[]]")

      if Proc.bareoutsidec > 0:

        var tl, orig, origfullel, newfullel = ""

        for i in 0..Proc.bareoutsidec - 1:
          if Proc.bareoutsideb[i] == "" or Proc.bareoutsideb[i] == nil: continue

          tl = strip(substr(Proc.bareoutsideb[i], 1, high(Proc.bareoutsideb[i]) - 1) )  # Remove "[]"
          if awk.split(tl, a, " ") > 0:  # Remove extlnk description string
            tl = a[0]
          orig = tl

          if tl ~ "^http" and tl !~ "[ ]" and len(tl) > 24 and not cbignorebareline(GX.articlework, tl) and isarchiveorg(tl):
            if action == "format":
              tl = fixtrailingchar(tl)
              tl = fixencodedurl(tl)
              tl = fixemptyarchive(tl)
              if orig != tl and len(tl) > 2:
                GX.articlework = replacetext(GX.articlework, orig, tl, "processoutside4")
                Proc.bareoutsideb[i] = replacetext(Proc.bareoutsideb[i], orig, tl, "processoutside4.1")
            elif action == "getlinks":
              fillarray(strip(tl), "normal")
            elif action == "process":
              origfullel = Proc.bareoutsideb[i]
              newfullel = fixbadstatus(tl, origfullel)
              if origfullel != newfullel and len(newfullel) > 2:
                GX.articlework = replacetext(GX.articlework, origfullel, newfullel, "processoutside5")


# ________________________________________________________________ Main

setup(CL.project)
setdatetype()

  # Fix pure formating problems               
process_article("format", "bareoutside")
process_article("format", "citeoutside")
process_article("format", "waybackinside")
process_article("format", "citeinside")


  # Parse for IA links
process_article("getlinks", "bareoutside")
process_article("getlinks", "citeoutside")
process_article("getlinks", "waybackinside")
process_article("getlinks", "citeinside")

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
  sendlog(Project.wayall, CL.name, WayLink[i].origiaurl)     # Print all Wayback URLs to file. Comment out during debugging.

if GX.numfound > 0:
  if queryapipost(GX.numfound):                              # Entry to medicapi.nim
    process_article("process", "bareoutside")
    process_article("process", "citeoutside")
    process_article("process", "waybackinside")
    process_article("process", "citeinside")                 # N.B.: this must be last?
  else:
    "Error in queryAPI() for " & CL.name & " : bad data. Skipped process_article(\"process\", ____)" >* "/dev/stderr"
    sendlog(Project.critical, CL.name, "queryapipost")

if GX.article != GX.articlework:  # Only save if there was a change to the article
  GX.articlework >* GX.datadir & "article.waybackmedic.txt"

echo GX.changes
removeFile("/tmp/" & GX.wid)
quit(QuitSuccess)
