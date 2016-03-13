#!/usr/local/bin/gawk -E

#
# Core functions for wayback medic
#
# The MIT License (MIT)
#
# Copyright (c) 2016 by User:Green Cardamom (at en.wikipedia.org)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#
#  Pass these variables
#   -n name = Wikipedia article name
#   -s sourcefile = wikipedia source file
#   -p id = project ID
#
#  Returns 0 if no changes, or 1..X number of changes
#
#  Sample run: medic -p "cb20151231-20160304.0001-0002" -n "South Gare" -s "/home/adminuser/wm/data/cb20151231-20160304.0001-0002/wm-0308135732/article.txt" 
#
#  Normally called by driver.awk but can be called standalone when debugging data
#
#  Coding conventions: Capitalized variables are global eg. Project[]
#

@include "init.awk"
@include "library.awk"
@include "getopt.awk"

BEGIN {

  Debug["network"] = 0    # Print debugging for networking
  Debug["s"] = 0          # Print debugging for replacetext() functions in library.awk
  Debug["e"] = 0          # Print debugging for fixemptywayback()

  while ((C = getopt(ARGC, ARGV, "hp:n:s:")) != -1) {
      opts++
      if(C == "p")                 #  -p <project>   Use project name. Optional, default in project.cfg
        id = verifypid(Optarg)
      if(C == "n")                 #  -n <name>      Name to process. Required.
        name = verifyval(Optarg)
      if(C == "s")                 #  -s <file>      Wiki sourcefile to process. Required.
        sourcefile = verifyval(Optarg)
      if(C == "h") {
        usage()
        exit
      }

  }
  if( id ~ /error/ || ! opts || name == ""  || sourcefile == "" ){
    usage()
    exit
  }

  checkexists(sourcefile, "medic.awk", "exit")            # Exit if sourcefile missing
  setProject(id)                                          # Load paths and project file names (library.awk)
  Datadir = dirname(sourcefile)

  main()

}
function usage() {

  print ""
  print "Medic - process a wikisource file."
  print ""
  print "Usage:"
  print "       -p <project>   Project name. Optional, defaults to project.cfg"
  print "       -n <name>      Name to process. Required"
  print "       -s <file>      Wiki sourcefile to process. Required"
  print "       -h             Help"
  print ""
}


#
# fixthespuriousone (Rev: B)
#   B: changed from "1=" to "[1-9]=" 
#
# Remove spurious "|1=" from cite templates
#    https://en.wikipedia.org/w/index.php?title=List_of_Square_Enix_video_games&curid=1919116&diff=704745846&oldid=703682254
#
function fixthespuriousone(tl) {

  if(match(tl, /[|][ ]?[1-9][ ]?=[ ]{0,2}[|}]/)) {
    Changes++
    sendto(Project["logspurone"], name, "cite1")
    return gensub(/[|][ ]?[1-9][ ]?=[ ]{0,2}/,"","g",tl)
  }
  return tl
}

#
# fixtrailingchar (Rev: A)
#
# Fix trailing char in url= created by user input error
#  See extra "," added to url https://en.wikipedia.org/w/index.php?title=Comanche_National_Grassland&type=revision&diff=707575983&oldid=655945746
#  Only needs to check wayback templates since those were imported by Cyberbot from bare URLs
#  Order: Must come before any web operations using the URL
#
function fixtrailingchar(tl,  url) {

  if(datatype(tl,"wayback")) {
    url = getargurl(tl)
    if( substr(url, length(url), 1) ~ /[,]|[.]/) {
      tl = replacetext(tl, url, gensub(/[,]$|[.]$/, "", "g", url))
      Changes++
      sendto(Project["logtrail"], name, "wayback1")
      return tl
    }
  }
  return tl
}

#
# fixemptywayback (Rev: A)
#
# Fix when a ref has an empty "{{wayback}}", with the intended url= portion misplaced at the start of the ref 
#   Boko Haram insurgency: https://en.wikipedia.org/w/index.php?title=Boko_Haram_insurgency&type=revision&diff=709268607&oldid=708528456
#   Comac C919: https://en.wikipedia.org/w/index.php?title=Comac_C919&type=revision&diff=709236286&oldid=708889462  
# 
function fixemptywayback(fullref) {

  match(fullref, /^[|]url=[^|]*[^|]/, url)          # ^|url=http..[ ]$
  if(length(url[0])) {
    if(Debug["e"]) print "url = " url[0]
    fullref = strip(removesection(fullref, 1, length(url[0])))
    if(Debug["e"]) print "fullref(1) = " fullref
    match(fullref, /^[|]date=[^ ]*[ ]/, date)       # ^|date=Jan..[ ]$
    if(length(date[0])) {
      if(Debug["e"]) print "date = " date[0]
      fullref = strip(removesection(fullref, 1, length(date[0])))
      if(Debug["e"]) print "fullref(2) = " fullref
      if(match(fullref, /^[|]df=[yn][ ]/, df)) {     # ^|df=y[ ]$
        fullref = strip(removesection(fullref, 1, length(df[0])))
        if(Debug["e"]) print "fullref(3) = " fullref
        dfout = df[0]
      }
      else dfout = ""      
      if(Debug["e"]) print "fullref(4) = " fullref
      fullref = replacetext(fullref, "{{wayback}}", "{{wayback" url[0] date[0] dfout "}}")
      if(Debug["e"]) print "fullref(5) = " fullref
      Changes++
      sendto(Project["logemptyway"], name, "way1")      
      return fullref
    }
  }
  
  return fullref

}


#
# fixmissingprotocol (Rev: A)
#
# Add protocol https if missing from cite archiveurl or wayback url
#  eg. |archiveurl=web.archive.org  -->  |archiveurl=https://web.archive.org
# Add "web" prefix 
#  eg. archiveurl=archive.org -> archiveurl=https://web.archive.org
#
# https RFC https://en.wikipedia.org/wiki/Wikipedia:VPR/Archive_127#RfC:_Should_we_convert_existing_Google_and_Internet_Archive_links_to_HTTPS.3F 
#
function fixmissingprotocol(tl) {

  if(datatype(tl,"cite")) {
    if(tl ~ /archive[-]{0,1}url[ ]{0,2}=[ ]{0,2}web/) {
      Changes++
      sub(/archive[-]{0,1}url[ ]{0,2}=[ ]{0,2}web/,"archiveurl=https://web",tl)
      sendto(Project["logmissprot"], name, "cite1")
      return tl
    }
    if(tl ~ /archive[-]{0,1}url[ ]{0,2}=[ ]{0,2}wayback/) {
      Changes++
      sub(/archive[-]{0,1}url[ ]{0,2}=[ ]{0,2}wayback/,"archiveurl=https://web",tl)
      sendto(Project["logmissprot"], name, "cite3")
      return tl
    }
    if(tl ~ /archive[-]{0,1}url[ ]{0,2}=[ ]{0,2}archive/) {
      Changes++
      sub(/archive[-]{0,1}url[ ]{0,2}=[ ]{0,2}archive/,"archiveurl=https://web.archive",tl)
      sendto(Project["logmissprot"], name, "cite2")
      return tl
    }
  }

  if(datatype(tl,"wayback")) {
    if(tl !~ /[|][ ]{0,2}url[ ]{0,2}=[ ]{0,2}[Hh][Tt][Tt][Pp]/ && tl !~ /[|][ ]{0,2}url[ ]{0,2}=[ ]{0,2}[}|]/ && tl ~ /[|][ ]{0,2}url[ ]{0,2}=/) {
      Changes++
      sub(/[|][ ]{0,2}url[ ]{0,2}=[ ]{0,2}/,"|url=http://",tl)
      sendto(Project["logmissprot"], name, "wayback1")
      return tl
    }
  }

  if(datatype(tl, "barelink")) {
    if(tl ~ /^https?[:]\/\/archive/) {
      Changes++
      sub(/^https?[:]\/\/archive/, "https://web.archive", tl)
      sendto(Project["logmissprot"], name, "barelink1")
      return tl
    }
    else if(tl ~ /^http[:]\/\/web.archive/) {
      Changes++
      sub(/^http[:]/, "https:", tl)
      sendto(Project["logmissprot"], name, "barelink2")
      return tl
    }
    else if(tl ~ /^http[:]\/\/wayback.archive/) {
      Changes++
      sub(/^http[:]/, "https:", tl)
      sendto(Project["logmissprot"], name, "barelink3")
      return tl
    }
  }

  return tl

}

#
# fixemptyarchive (Rev: A)
#
# Fix where archiveurl= is empty (or url= in wayback template)
#   Replace with new url link and new date
#
function fixemptyarchive(tl,   k,url,newurl,wstatus) {

  if( datatype(tl,"cite") && tl ~ /archive[-]{0,1}url=[ ]{0,2}[|}]/) {      
    url = getargurl(tl)
    if(length(url) > 10 && url ~ /^http/) {
      if( webpagestatus(url) == 1) {               # Leave empty arguments in place if url= is working 
        return tl
      }
      newurl = waybackapi(url, getargarchivedatestamp(tl))
      if(newurl ~ /none/) {
        Changes++
        sendto(Project["logemptyarch"], name, "cite1")
        return removearchive(tl)
      }
      else {
        sub(/archive[-]{0,1}url[ ]{0,2}=[ ]{0,2}/, "archiveurl=" newurl, tl)      
        newdate = urldate(newurl, getargarchive(tl,"date") )
        tl = replacetext(tl, getargarchive(tl,"date"), newdate)
        Changes++
        sendto(Project["logemptyarch"], name, "cite2")
        return tl
      }
    }
    else {
      Changes++
      sendto(Project["logemptyarch"], name, "cite3")
      return removearchive(tl)
    }
  }

 # Wayback templates

  if(datatype(tl,"wayback") && tl ~ /[|][ ]{0,2}url[ ]{0,2}=[ ]{0,2}[|}]/ ) {
    Changes++
    sendto(Project["logemptyarch"], name, "wayback1")
    return tl
  }

  return tl
}

#
# fixbadstatus (Rev: A)
#
# Replace Wayback URLs reporting non-200 status. Update archivedate if changed.
#  tl is the contents of the template 
#  optional "fullref" string ie. everything between <ref></ref>
#
function fixbadstatus(tl, fullref,    urlarch,url,newurl,newdate,waybackdate) {

  if(datatype(tl,"cite")) {
    urlarch = getargarchive(tl,"url")
    if(length(urlarch) > 15) {
      sub(/archive[-]{0,1}url[ ]{0,2}=[ ]{0,2}/,"",urlarch)
      if(urlarch ~ /^http/) {
        if( webpagestatus(urlarch) != 0)    
          return tl
        else {
          url = getargurl(tl)
          if(length(url) > 10 && url ~ /^http/) {
            newurl = waybackapi(url, getargarchivedatestamp(tl))
            if(newurl ~ /none/) {
              Changes++
              sendto(Project["log404"], name, "cite1")
              return removearchive(tl)
            }
            else {
              tl = replacetext(tl, urlarch, newurl)
              newdate = urldate(newurl, getargarchive(tl,"date") )
              tl = replacetext(tl, getargarchive(tl,"date"), newdate)
              Changes++
              sendto(Project["log404"], name, "cite2")
              return tl
            }
          }
          else {
            sendto(Project["log404"], name, "citeA")
            return removearchive(tl)
          }
        }
      }
      else {
        sendto(Project["log404"], name, "citeB")
        return tl
      }
    }
    else {
      sendto(Project["log404"], name, "citeC")
      return tl
    }
  }
  else if(datatype(tl,"wayback")) {
    url = getargurl(tl)
    waybackdate = getargwayback(tl,"date")
    if(length(url) > 10 && url ~ /^http/ && length(waybackdate) > 3 && isanumber(waybackdate) ) {
      urlarch = "https://web.archive.org/web/" waybackdate "/" url
      if( webpagestatus(urlarch) != 0) {
        return tl
      }
      else {
        newurl = waybackapi(url, waybackdate)
        if(newurl ~ /none/) {
          if(int(countsubstring(fullref, url)) < 3) {                  
           Changes++
           sendto(Project["log404"], name, "wayback1")
           sendto(Project["cbignore"], name, "wayback1")
           return "{{dead link |date=" todaysdate() "}}{{cbignore|id=medic}}"
          }
          else {                                                        # Log bundled refs and collect for future work
            Changes++
            sendto(Project["log404"], name, "waybackA")
            return tl
          }
        }
        else {
          tl = replacetext(tl, waybackdate, urldatestamp(newurl))
          Changes++
          sendto(Project["log404"], name, "wayback2")
          return tl
        }
      }
    }
    else {
      sendto(Project["log404"], name, "waybackB")
      return tl
    }
  }
  else if(datatype(tl,"barelink")) {
    if( webpagestatus(tl) != 0)   
      return tl
    else {
      url = gensub(/^https?[:]\/\/web[.]archive[.]org\/web\/[0-9]{8,30}\//,"","g",tl) # Assumes fixmissingprotocol() already run
      if(url ~ /^http/ && length(url) > 9 && url !~ /[ ]/) {
        newurl = waybackapi(url, urldatestamp(tl))
        if(newurl ~ /none/) {
          Changes++
          tl = replacetext(tl, tl, url)                        # No way to add {{cbignore}} - must be done manually. Check logs post run.
          sendto(Project["log404"], name, "barelink1")
          return tl
        }
        else {
          Changes++
          tl = replacetext(tl, tl, newurl)
          sendto(Project["log404"], name, "barelink2")
          return tl
        }
      }
      else {
        sendto(Project["log404"], name, "barelinkA")
        return tl
      }
    }
  }
  else {
    # sendto(Project["log404"], name, "unknownA")
    return tl
  }

  return tl	

}

#
# Given a URL and (optional) timestamp, find the best Wayback URL.
#  Verify status code since Wayback API sometimes returns 404 pages. If bad status, try again without timestamp.
#
#  Wayback API: https://archive.org/help/wayback_api.php (old)
#               http://207.241.231.246:8120/usage (archived https://archive.is/6ZcDv)
#
function waybackapi(url, timestamp,        k,a,jsonin,urlapi,newurl,j,tries,response) {

  tries = 3

  if(url ~ /'/) gsub(/'/,"%27",url)    # shell escape literal string 

  if(length(timestamp))
    urlapi = "https://archive.org/wayback/available?url=" url "&timestamp=" timestamp
  else
    urlapi = "https://archive.org/wayback/available?url=" url 

  while(j < tries) {
    sleep(2)
    if(Debug["network"]) print "Starting API (1) for " urlapi
    jsonin = http2var(urlapi)
    response = apiresponse(jsonin)
    if(Debug["network"]) print "Ending API (" length(jsonin) ")" 
    if(length(jsonin) == 0 || response ~ /none/) {
      j++
    }
    else if(j == tries) {
      if(Debug["network"]) print "IA API time out"
      sendto(Project["timeout"], name, "iaapi")
      return "none"
    }
    else 
      break
  }

  if(response ~ /available/) {
    # "url":"http://web.archive.org/web/20060101064348/http://www.example.com:80/",
    match(jsonin, /"url":"[^\"]*[^\"]/, k)
    if( length(k[0]) ) {
      split( strip(k[0]), a, "\"")
      if( strip(a[4]) ~ /^http/) {
        if( webpagestatus(strip(a[4])) == 1 ) {
          sub(/^http[:]/, "https:", a[4])     # Convert to https
          return strip(a[4])
        }
        else {
          if(length(timestamp)) {             # Try again without timestamp 
            newurl = waybackapi(url)
            if(newurl !~ /none/)
              return newurl
          }
          else {                               
            if(Debug["network"]) print "IA API bogus recommendation"
            sendto(Project["bogusapi"], name, strip(a[4]))
            return "none"
          }
        }
      }
    }
  }  
  else if(response ~ /unavailable/) {
    if(length(timestamp)) {             # Try again without timestamp 
      newurl = waybackapi(url)
      if(newurl !~ /none/)
        return newurl
    }
  }
  return "none"
}
#
# API response
#
function apiresponse(jsonin) {

  if(jsonin ~ /"available"[:]true/)
    return "available"
  else if(jsonin ~ /{"archived_snapshots"[:][{][}][}]/)
    return "unavailable"
  else
    return "none"
}

#
# Return 1 if page has a 2XX response status. 
#   Return -1 if timeout. Return 0 if 4xx etc..
#
function webpagestatus(url,  head,j,tries,command,response,tempfile) {

  tries = 3  # Number of times to try IA 

  if(url ~ /'/) gsub(/'/,"%27",url)    # shell escape literal string 

  tempfile = mktemp("wget.XXXXXX","f")

  # Headers go to stderr, body to stdout. 
  # content-on-error needed to see output of body during a 403/4 which is redirected to a temp file. 
  command = Exe["wget"] " --content-on-error -SO- -q --retry-connrefused --waitretry=1 --read-timeout=2 --timeout=5 --tries=1 --no-dns-cache --no-check-certificate --user-agent=\"" Agent "\" '" url "' 2>&1 > " tempfile

  while(j < tries) {
    sleep(2)
    if(Debug["network"]) print "Starting headers (" j + 1 ") for " url
    head = sys2var(command)
    close(tempfile)
    response = headerresponse(head)
    if(Debug["network"]) print "Ending headers (" length(head) " / " response ")"
    if(length(head) == 0 || response ~ /none/) 
      j++
    else 
      break
  }
  if(j == tries) {
    if(Debug["network"]) print "Headers time out"
    sendto(Project["timeout"], name, "header")
    return -1
  }

  if(response !~ /none/ && int(response) != 0 && response != "") {
    if( int(response) > 199 && int(response) < 300) 
      return 1
    if( bummerpage(tempfile) ~ /bummer/)  
      return 1                            # Treat as a 200 response 
  }

  return 0

}
#
# Header response code (200 is OK, 403 is permission denied etc..)
#
function headerresponse(head,  a,b,c,i,j,cache) {

  delete cache
  c = split(head, a, "\n")
  while(i++ < c) {
    if(a[i] ~ /^[ ]{0,5}HTTP\/1[.]1/) { 
      split(a[i],b," ")
      if(int(strip(b[2])) > 1) 
        cache[++j] = strip(b[2])
    }
  }

  if( int(cache[length(cache)]) > 0)   { # Get the last HTTP response 
    if( int(cache[length(cache)]) != 200 && Debug["network"]) 
      print head > "/dev/stderr"
    return int(cache[length(cache)])
  }

  return "none"

}
#
# Page is a bummer. IA returned: "The machine that serves this file is down. We're working on it."
#
function bummerpage(body,  cache,c,a,i,result) {

  delete cache
  result = "none"
  c = split(readfile(body), a, "\n")
  while(i++ < c) {
    if(a[i] ~ /The machine that serves this file is down/) {
      result = "bummer"
    }
  }
  if(checkexists(body)) 
    sys2var( Exe["rm"] " -r -- " body)
  return result
}

#
# Remove deadurl, archiveurl & archivedate from template and add {{cbignore}} and {{dead link}}
#
function removearchive(tl) {

  tl = replacetext(tl, strip(getargarchive(tl, "dead", "bar")), "")
  tl = replacetext(tl, strip(getargarchive(tl, "url", "bar")), "")
  tl = replacetext(tl, strip(getargarchive(tl, "date", "bar")), "")
  tl = tl "{{dead link |date=" todaysdate() "}}{{cbignore|id=medic}}"
  sendto(Project["cbignore"], name, "removearchive1")
  return tl
}

#
# Return 1 if "tl" is of type "name" (wayback|cite|barelink)
#  eg. datatype(tl, "wayback")
#
function datatype(tl, name,    safe) {

  safe = stripwikicomments(tl)
  if(name ~ /wayback/) {
    if(safe ~ /[Ww]ayback[ ]{0,2}[|]/ && safe ~ /[|][ ]{0,2}[Uu][Rr][Ll][ ]{0,2}=/ && safe ~ /[|][ ]{0,2}[Dd]ate[ ]{0,2}=/) 
      return 1
  }
  if(name ~ /cite/) {
    if(safe ~ /[Aa]rchive[-]{0,1}url[ ]{0,2}=[ ]{0,2}/ && safe ~ /[Aa]rchive[-]{0,1}date[ ]{0,2}=/) 
      return 1
  }
  if(name ~ /barelink/) {
    if(safe ~ /^https?[:]\/\/w?e?b?[.]?archive[.]org\/web\/[0-9]{8,20}\//)
      return 1
    if(safe ~ /^https?[:]\/\/wayback[.]archive[.]org\/web\/[0-9]{8,20}\//)
      return 1
  }

  return 0
}

#
# Given a citation or wayback template, return the url= argument 
#  if command = "full" also include the "url=" portion retaining original spacing
#
function getargurl(tl, command,     k,safe) {

  match(tl, /[|][ ]{0,2}[Uu][Rr][Ll][ ]{0,2}=[^|}]*[^|}]/, k)                         
  safe = strip(stripwikicomments(strip(k[0])))
  if( length(safe) > 10 && substr(safe,1,1) ~ /[|]/) {
    if(command ~ /full/) 
      sub(/^[|][ ]{0,2}/,"",safe)
    else
      sub(/^[|][ ]{0,2}[Uu][Rr][Ll][ ]{0,2}=[ ]{0,2}/,"",safe)
    return safe
  }
  return
}

#
# Given a citation template, return the archivedate in timestamp format (YYYYMMDD) (not including archivedate=)
#
function getargarchivedatestamp(tl,  k,stamp) {

  if(tl ~ /archive[-]{0,1}url[ ]{0,2}=/) {
    match(tl, /archive[-]{0,1}date[ ]{0,2}=[^|}]*[^|}]/, k)
    if(length(k[0]) > 15) {
      sub(/archive[-]{0,1}date[ ]{0,2}=/, "", k[0])
      k[0] = stripwikicomments(strip(k[0]))
      stamp = strip( sys2var(Exe["date"] " --date=\"" strip(k[0]) "\" +'%Y%m%d'") )
      if( length(stamp) && isanumber(stamp) ) 
        return stamp
    }
  }
}

#
# Given a wayback template, return the title, date or url arg content
#  tl = contents of template
#  arg = "url" or "date" or "title"
#
function getargwayback(tl, arg,    k,safe,re) {

  re = "[|][ ]{0,2}" arg "[ ]{0,2}=[^|}]*[^|}]"   # If field exists and has content
  match(tl, re, k)
  safe = strip(stripwikicomments(strip(k[0])))
  if(length(safe) && substr(safe,1,1) ~ /[|]/) {
    re = "^[|][ ]{0,2}" arg "[ ]{0,2}=[ ]{0,2}"
    sub(re,"",safe)
    return strip(safe)
  }
}

#
# Given a citation template, return the archiveurl or archivedate (including the "archiveurl=" or "archivedate=" )
#  tl = template contents string
#  arg = argument to return (deadurl|url|date)
#  magic = "bar" (include the leading "|" in return string)
#  N.B. wiki comments (<!-- -->) are removed from the returned string
#
function getargarchive(tl, arg, magic,    k,s,re,subre,safe) {

  if(arg ~ /url/)
    subre = "archive[-]{0,1}url"
  else if(arg ~ /date/)
    subre = "archive[-]{0,1}date"
  else if(arg ~ /dead/)
    subre = "dead[-]{0,1}url"
  else
    return tl

  if(magic ~ /bar/) 
    re = "[|][ ]{0,2}" subre "[ ]{0,2}=[^|}]*[^|}]"  # If field has content
  else
    re = subre "[ ]{0,2}=[^|}]*[^|}]"

  match(tl, re, k)
  if(length(k[0])) { 
    safe = strip(stripwikicomments(k[0]))
    return safe
  }

  if(magic ~ /bar/) 
    re = "[|][ ]{0,2}" subre "[ ]{0,2}=[ ]{0,2}[|}]"  # If field is empty
  else
    re = subre "[ ]{0,2}=[ ]{0,2}[|}]"

  if(match(tl, re, k)) {  # if right side of = is blank
    s = substr(strip(k[0]), 1, length(strip(k[0])) - 1)
    return strip(s)
  }
}

#
# Given an archive.org URL, return the date stamp portion
#
function urldatestamp(url,  a,c,i) {

  c = split(url, a, "/")
  while(i++ < c) {
    if(a[i] ~ /^web$/) {
      i++
      return strip(a[i])
    }
  }
}

#
# Given an archive.org url (wayback), return its datestamp in Datetype format (dmy or mdy). Return includes "archivedate="
#  Otherwise, return curdate
#  eg. 20080101 -> January 1, 2008 (if global Datetype=mdy)
#
function urldate(url, curdate,   a,c,i,dateinput) {

  c = split(url, a, "/")
  while(i++ < c) {
    if(a[i] ~ /^web$/) {
      i++
      dateinput = substr(a[i], 1, 4) "-" substr(a[i], 5, 2) "-" substr(a[i], 7, 2)
      if(Datetype ~ /dmy/) 
        return "archivedate=" sys2var(Exe["date"] " --date=\"" strip(dateinput) "\" +'%-d %B %Y'")
      else 
        return "archivedate=" sys2var(Exe["date"] " --date=\"" strip(dateinput) "\" +'%B %-d, %Y'")
    }
  }
  return curdate
}

#
# Today's date ie. "March 2016"
#
function todaysdate() {
  return sys2var(Exe["date"] " +'%B %Y'")
}

#
# Determine date type - set global Datetype = dmy or mdy
#   Search for {{use dmy dates..} or {{use mdy dates..}
#   default mdy
#
function setdatetype(  i) {
  Datetype = "mdy"
  while(i++ < ArticleC) {
    if(ArticleS[i] ~ /[{]{0,2}[{][ ]{0,2}[Uu]se [Dd][Mm][Yy] [Dd]ates/)
      Datetype = "dmy"
    if(ArticleS[i] ~ /[{]{0,2}[{][ ]{0,2}[Uu]se [Mm][Dd][Yy] [Dd]ates/)
      Datetype = "mdy"
  }
}

#
# Return 0 if ref is not WP:BUNDELED (ie. more than one cite inside a <ref></ref>)
#  Only works if ref contains "archiveurl=" and/or "wayback|" otherwise return 4
#
function bundled(ref,  a,c,d) {

  c = split(ref, a, /archiveurl=/)   # Filter out any using "archive-url" since Cyberbot doesn't use that
  if(c > 2) return 2
  d = split(ref, a, /[Ww]ayback[ ]{0,2}[|]/)
  if(d > 2) return 3

  if(c < 2 && d < 2) return 4

  return 0
}

#
# Return 1 if ref (or string) contains {{cbignore}} template.
#  Does not look outside <ref></ref> pair
#
function cbignore(ref) {
  if(tolower(ref) !~ /cbignore/)
    return 0

  return 1
}

#
# Return 1 if same \n separarted line as "lk" contains {{cbignore}} template.
#  Does not look after line breaks
#
function cbignorebarelink(lk,  i) {

  while(i++ < ArticleC) {
    if(ArticleS[i] ~ lk) {
      if(tolower(ArticleS[i]) !~ /cbignore/)
        return 0
    }
  }
  return 1
}

#
# Process citation templates outside <ref></ref> pairs
#
function process_templatesoutside(   articlenoref,c,i,b,k,orig,tl) {

  # Create version of article with ref's deleted (retaining the actual <ref></ref> pairs)
   articlenoref = Article
   gsub(/<ref[^>]*\/[ ]{0,2}>/,"",articlenoref)  # remove <ref name=string />
   c = split(articlenoref, b, "<ref[^>]*>")      # remove <ref></ref>
   i = 0
   while(i++ < c) 
     articlenoref = replacetext(articlenoref, substr(b[i], 1, match(b[i], "</ref>") - 1), "")
     #gsub(regesc2(substr(b[i], 1, match(b[i], "</ref>") - 1)), "", articlenoref)

  # Find/fix cite templates remaining
   c = split(articlenoref, b, /[{][ ]{0,2}[{]/) 
   i = 0
   while(i++ < c) {
     k = substr(b[i], 1, match(b[i], /[}][ ]{0,2}[}]/) - 1)
     if(k ~ /archiveurl=/ && ! cbignore(b[i]) ) {
       k = "{" k "}" 
       match(k, /{[ ]{0,2}[Cc]ite[^}]+}|{[ ]{0,2}[Cc]ita[^}]+}|{[ ]{0,2}[Vv]cite[^}]+}|{[ ]{0,2}[Vv]ancite[^}]+}|{[ ]{0,2}[Hh]arvrefcol[^}]+}|{[ ]{0,2}[Cc]itation[^}]+}/, d) 
       orig = tl = d[0] "}"

       tl = fixmissingprotocol(tl)   
       tl = fixemptyarchive(tl)
       tl = fixbadstatus(tl) 
       tl = fixthespuriousone(tl)

       if(orig != tl) {
         ArticleWork = replacetext(ArticleWork,orig,tl)
       }
     }
   }
}

#
# Process wayback templates outside <ref></ref> pairs
#
function process_waybackoutside(   articlenoref,c,i,b,k,orig,tl) {

  # Create version of article with ref's deleted (retaining the actual <ref></ref> pairs)
   articlenoref = Article
   gsub(/<ref[^>]*\/[ ]{0,2}>/,"",articlenoref)  # remove <ref name=string />
   c = split(articlenoref, b, "<ref[^>]*>")      # remove <ref></ref>
   i = 0
   while(i++ < c) 
     articlenoref = replacetext(articlenoref, substr(b[i], 1, match(b[i], "</ref>") - 1), "")
     #gsub(regesc2(substr(b[i], 1, match(b[i], "</ref>") - 1)), "", articlenoref)

  # Find/fix wayback templates remaining
   c = split(articlenoref, b, /[{][ ]{0,2}[{]/) 
   i = 0
   while(i++ < c) {
     k = substr(b[i], 1, match(b[i], /[}][ ]{0,2}[}]/) - 1)
     if(k ~ /^[ ]{0,2}[Ww]ayback[ ]{0,2}[|]/ && ! cbignore(b[i]) ) {
       orig = tl = k 
       tl = fixmissingprotocol(tl)   
       tl = fixemptyarchive(tl)
       tl = fixtrailingchar(tl)
       tl = fixbadstatus(tl) 
       if(orig != tl) {
         ArticleWork = replacetext(ArticleWork,orig,tl)
       }
     }
   }
}

#
# Process wayback templates inside <ref></ref> pairs
#
function process_waybackinside(   c,b,i,k,d,tl,orig) {

   c = split(ArticleWork, b, "<ref[^>]*>")
   i = 1
   while(i++ < c) {
     tl = k = ""
     delete d
     k = substr(b[i], 1, match(b[i], "</ref>") - 1)
     if(k ~ /[{][{]wayback[}][}]/ && k ~ /[|]url/ ) {   
       orig = k
       k = fixemptywayback(k)                            # Comes first
       if(orig != k)
         ArticleWork = replacetext(ArticleWork,orig,k)
     }
     if(k ~ /[Ww]ayback[ ]{0,2}[|]/ && ! cbignore(b[i]) && ! bundled(k) ) {   
       match(k, /{[ ]{0,2}[Ww]ayback[^}]+}/, d) 
       orig = tl = "{" d[0] "}"
       tl = fixmissingprotocol(tl)   
       tl = fixemptyarchive(tl)
       tl = fixtrailingchar(tl)
       tl = fixbadstatus(tl,k)
       if(orig != tl) {
         ArticleWork = replacetext(ArticleWork,orig,tl)
       }
     }
   }
}


#
# Process bare links outside <ref></ref> pairs
#
function process_barelinksoutside(   articlenoref,c,i,b,orig,tl) {

  # Create version of article with ref's deleted (retaining the actual <ref></ref> pairs)
   articlenoref = Article
   gsub(/<ref[^>]*\/[ ]{0,2}>/,"",articlenoref)  # remove <ref name=string />
   c = split(articlenoref, b, "<ref[^>]*>")      # remove <ref></ref>
   i = 0
   while(i++ < c) 
     articlenoref = replacetext(articlenoref, substr(b[i], 1, match(b[i], "</ref>") - 1), "")
     #gsub(regesc2(substr(b[i], 1, match(b[i], "</ref>") - 1)), "", articlenoref)

  # Find/fix bare links remaining
   c = patsplit(articlenoref, b, /[\[][ ]?https?[:]\/\/w?e?b?[.]?archive[.]org\/web\/[0-9]{8,20}\/[^ \]]*[^ \]]/)
   i = 0
   while(i++ < c) {
     orig = tl = b[i]
     tl = strip(substr(b[i], 2, length(b[i])))
     if(tl ~ /^http/ && tl !~ /[ ]/ && length(tl) > 34 && ! cbignorebarelink(tl) ) {
       tl = fixmissingprotocol(tl)   
       tl = fixbadstatus(tl) 
       tl = "[" tl
       if(orig != tl) {
         ArticleWork = replacetext(ArticleWork,orig,tl)
       }
     }
   }
}

#
# Process citation templates inside <ref></ref> pairs
#
function process_templatesinside(   c,b,i,k,d,tl,orig) {

   c = split(ArticleWork, b, "<ref[^>]*>")
   i = 1
   while(i++ < c) {
     tl = k = ""
     delete d
     k = substr(b[i], 1, match(b[i], "</ref>") - 1)

#  print "k (" bundled(k) ")(" cbignore(b[i]) ") = " k

     if(k ~ /archiveurl=/ && ! cbignore(b[i]) && ! bundled(k) ) {   
       match(k, /[{][ ]{0,1}[{][ ]{0,2}[Cc]ite[^}]+}|{[ ]{0,2}[Cc]ita[^}]+}|{[ ]{0,2}[Vv]cite[^}]+}|{[ ]{0,2}[Vv]ancite[^}]+}|{[ ]{0,2}[Hh]arvrefcol[^}]+}|{[ ]{0,2}[Cc]itation[^}]+}/, d) 
       orig = tl = d[0] "}"
       tl = fixmissingprotocol(tl)   
       tl = fixemptyarchive(tl)
#print "tl = " tl
       tl = fixbadstatus(tl) 
       tl = fixthespuriousone(tl)
       if(orig != tl) {
         ArticleWork = replacetext(ArticleWork,orig,tl)
       }
     }
   }
}

#
# Document the fixes and revisions made for this project and run
#
function documentation( a,c,i) {

  if(!checkexists(Project["docfixes"])) {
    print "Documentation for Wayback Medic project " Project["id"] "\n" >> Project["docfixes"]
    print "File descriptions:" >> Project["docfixes"]
    print "        index     =    Database index file" >> Project["docfixes"]
    print "        auth      =    List of articles processed" >> Project["docfixes"]
    print "        timeout   =    Server timeout log. The IA API or Wayback Machine" >> Project["docfixes"]
    print "        bogusapi  =    IA API returned a bogus recommendation (eg. 404/403)" >> Project["docfixes"]
    print "        manual    =    Articles that need manual processing. Search medic.awk for Project[\"manual\"] for reasons." >> Project["docfixes"]
    print "        log*      =    Log files for fixes made" >> Project["docfixes"]
    print "" >> Project["docfixes"]
    print " # Function names (Revision) for this project:" >> Project["docfixes"]
    print "" >> Project["docfixes"]

    c = split(readfile(Exe["medic"]), a, "\n")
    while(i++ < c) {
      if(a[i] ~ /[(]Rev[:][ ][A-Z]/) 
        print " " a[i]  >> Project["docfixes"]
    }
    close(Project["docfixes"])
  }

}


function main() {

   Article = readfile(sourcefile)
   ArticleC = split(Article, ArticleS, "\n")
   ArticleWork = Article

   documentation()
   setdatetype()

   Changes = 0

#      process_waybackoutside()   # None exist for Cyberbot IABot - be careful when running this outside as it will delete original ref

   process_barelinksoutside()
   process_templatesoutside()
   process_waybackinside()
   process_templatesinside()  # N.B.: this must be last 

   if(Article != ArticleWork) { # Only print if there was a change to the article's text
     print ArticleWork > Datadir "article.waybackmedic.txt"
     close(Datadir "article.waybackmedic.txt")
   }
   
   print Changes
   exit

}

