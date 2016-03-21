#
# Internet Archive/Wayback API functions for wayback medic
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

@include "library.awk"

#
# Query Wayback API via POST method and and load answers into WayLink[]
#
#  Assumes process_article("getlinks", "xyz") has previously run loading WayLink ["origiaurl"],["origurl"],"[origdate"] from Wikipedia data.
#
function queryapipost(internalcount,    postfile,postdir,command,i,c,csv,c2,csv2,a,a2,b,tag,returnval,tries,j,url,out,z,originalcount) {

  tries = 3
  returnval = 1

  postdir = createpostdata()
  postfile = postdir "/postdata" 

                             # Awk has bad JSON options so we convert to CSV then into an array.
  if(internalcount > 0) {    # Download JSON from API with wget, convert to CSV with jq, convert to array a[] with qsplit(), load global WayLink[][] from a[]'s data                
    j = 1 
    while(j < tries + 1) { 

      if(Debug["network"]) print "Starting API (try " j ")" 

      csv = sys2var(Exe["wget"] " --header=\"Wayback-Api-Version: 2\" --post-file=\"" postfile "\" -q -O- \"http://archive.org/wayback/available\" | " Exe["jq"] " -r '. [] | map(.url, .tag, .archived_snapshots.closest.url, .archived_snapshots.closest.status, .archived_snapshots.closest.available) |@csv' " )
      c = qsplit(csv, a)

      sleep(2)           # Trust/verify

      csv2 = sys2var(Exe["wget"] " --header=\"Wayback-Api-Version: 2\" --post-file=\"" postfile "\" -q -O- \"http://archive.org/wayback/available\" | " Exe["jq"] " -r '. [] | map(.url, .tag, .archived_snapshots.closest.url, .archived_snapshots.closest.status, .archived_snapshots.closest.available) |@csv' " )
      c2 = qsplit(csv2, a2)      

      if(Debug["network"]) print "Ending API (" length(csv) "/" c "|" length(csv2) "/" c2 ")"

      if(length(csv) == 0 || c == 0 || length(csv2) == 0 || c2 == 0) {                       # Problem retrieving API data, try again.
        j++
      }
      else if(j == tries) {                                                                  # Give up after x tries.
        if(Debug["network"]) print "IA API time out?" > "/dev/stderr"
        sendlog(Project["timeout"], name, "queryapi")
        return 0
      }
      else if(length(csv) != length(csv2) || c != c2) {                                      # Mismatch in 2 requests. Pick the largest and exit.
        if(c2 > c) {
          delete a
          csv = csv2
          c = qsplit(csv2, a)
        }
        break
      }
      else                                                                                   # 2 requests match. exit.
        break
    }
      
    if(Debug["api"]) print "csv1 = " csv
    print csv1 > Datadir "csv"
    close(Datadir "csv")

    if(c >= 5) {      

      count = originalcount = makecount(c)

      if(Debug["api"]) print "\nAPI found " count " records vs. " internalcount " internal count records."

      if(count < internalcount) {     # Records missing from API results. Add them to csv
        for(tag in WayLink) {
          i = z = 0
          while(i++ < count) {
            if(a[(i * 5) - 3] ~ regesc2(tag))  z = 1
          }
          if(!z) 
            out = out "\"" WayLink[tag]["origurl"] "\",\"" WayLink[tag]["tag"] "\",,,,"
        }
        if(length(out)) {
          delete a
          csv2 = csv
          sub(/,$/,"",out)         # Remove trailing comma (5 commas per record excep last record has 4)
          csv = strip(csv2 "," out)
          c = qsplit(csv, a)       
          count = makecount(c)
        }
        else
          print "Error in queryapipost(), unable to determine new csv (" name ")" > "/dev/stderr"
      }

     # Debug
      gsub(/'/, "'\\''", csv)
      gsub(/’/, "'\\’'", csv)
      if(Debug["api"]) print "New record count " count "\n"
      if(Debug["api"]) print "csv2 = '" csv "'" 
      print "'" strip(csv) "'"  > Datadir "csv"
      printf "" > Datadir "waylink.start"
      printf "" > Datadir "waylink.end"
      close(Datadir "csv")
      close(Datadir "waylink.start")
      close(Datadir "waylink.end")

      i = 0
      while( i++ < count ) {

        tag = a[(i * 5) - 3] 
                    
        #                status       available     newiaurl         newurl
        fillway(tag, a[(i * 5) - 1],  a[i * 5],  a[(i * 5) - 2],  a[(i * 5) - 4])

        WayLink[tag]["tag"] == "" ? WayLink[tag]["tag"] = "none" : ""
        WayLink[tag]["status"] == "" ? WayLink[tag]["status"] = "0" : ""
        WayLink[tag]["available"] == "" ? WayLink[tag]["available"] = "false" : ""
        WayLink[tag]["newiaurl"] == "" ? WayLink[tag]["newiaurl"] = "none" : ""
        WayLink[tag]["newurl"] == "" ? WayLink[tag]["newurl"] = "none" : ""

        debugarray(tag, "waylink.start")        

        if(WayLink[tag]["status"] ~ /^2/) {                          # API reports 2xx
          if( WayLink[tag]["newiaurl"] !~ /none/ && WayLink[tag]["tag"] !~ /none/ ) {
            if(webpagestatus(WayLink[tag]["newiaurl"]) != 1) {       # Page headers verified *not* 200
              if(Debug["api"]) print " _____________[RED FLAG (A1)]_______________"
              sendlog(Project["bogusapi"], WayLink[tag]["newiaurl"], "A1")
              fillway(tag, "0", "false", "none", "none")
            }
          }
          else {
            fillway(tag, "0", "false", "none", "none")
            if(Debug["api"]) print " _____________[RED FLAG (A2)]_______________"
          }
        }
        if(WayLink[tag]["status"] ~ /^404$|^0$/) {                   # API reports 404 or missing 
          if( WayLink[tag]["origiaurl"] !~ /none/ && WayLink[tag]["tag"] !~ /none/ ) {
            if(webpagestatus(WayLink[tag]["origiaurl"], "404") == 1) {      # Page headers verify as 200 
              if(Debug["api"]) print " _____________[RED FLAG (A3)]_______________"
              if(i <= originalcount) 
                sendlog(Project["bogusapi"], WayLink[tag]["origiaurl"], "A3")
              fillway(tag, "200", "true", WayLink[tag]["origiaurl"], WayLink[tag]["origurl"])
            }
            else {
              url = queryapiget(WayLink[tag]["origurl"])             # Try again with earliest date 1970101
              if(url !~ /none/ && url ~ /^http/) {
                if(webpagestatus(url) == 1) {                        # Page headers verify 200 
                  if(Debug["api"]) print " _____________[RED FLAG (A4)]_______________"
                  if(i <= originalcount) 
                    sendlog(Project["bogusapi"], url, "A4")
                  fillway(tag, "200", "true", url, WayLink[tag]["origurl"]) 
                }
              }
            }
          }
        }
        if(Debug["api"]) debugarray(tag)        # optionaly print to screen
        debugarray(tag, "waylink.end")          # always to file
      }
    }
    else 
      returnval = 0
  } 

  if(checkexists(postfile)) {
    if(!Debug["api"])
      sys2var( Exe["rm"] " -r -- " postdir )
  }

  return returnval
}

#
# Query API via GET method. Return a working IA URL or "none"
#
#  If no timestamp passed, use 1970 and best match after.
#
#  Wayback API: https://archive.org/help/wayback_api.php (old)
#               http://207.241.231.246:8120/usage (archived https://archive.is/6ZcDv)
#
function queryapiget(url, timestamp,        k,a,jsonin,urlapi,newurl,j,tries,response,command,csv,c,b,csv2,c2,b2,i,count,float) {

  tries = 3
  if(url !~ /^http/) return "none"
  if(url ~ /'/) gsub(/'/,"%27",url)    # shell escape literal string
  if(!timestamp) timestamp = "none"

  if(timestamp ~ /none/)
    urlapi = url "&closest=after&statuscodes=200&statuscodes=203&statuscodes=206&statuscodes=404&timestamp=19700102"
  else
    urlapi = url "&closest=after&statuscodes=200&statuscodes=203&statuscodes=206&statuscodes=404&timestamp=" timestamp

  command = Exe["wget"] " --header=\"Wayback-Api-Version: 2\" --post-data=\"url=" urlapi "\" -q -O- --retry-connrefused --waitretry=1 --read-timeout=15 --timeout=15 --tries=1 --no-dns-cache --no-check-certificate --user-agent=\"" Agent "\" http://archive.org/wayback/available | " Exe["jq"] " -r '. [] | map(.url, .tag, .archived_snapshots.closest.url, .archived_snapshots.closest.status, .archived_snapshots.closest.available) |@csv' "

  # if(Debug["network"]) print "Command: " command

  while(j < tries) {
    sleep(2)
    if(Debug["network"]) print "Starting API (get) (" j+1 ") for " urlapi
    csv = sys2var(command)
    c = qsplit(csv, b)
    sleep(2)
    csv2 = sys2var(command)
    c2 = qsplit(csv2, b2)
    if(Debug["network"]) print "Ending API (get) (" length(csv) "/" c "|" length(csv2) "/" c2 ")"
    if(length(csv) == 0 || c == 0 || length(csv2) == 0 || c2 == 0 || length(csv) != length(csv2) || c != c2) {  # Problem with API data, try again.
      j++
    }
    else if(j == tries) {
      if(Debug["network"]) print "API time out (get)"
      sendlog(Project["timeout"], name, "queryapiget")
      return "none"
    }
    else
      break
  }

  if(c != 5) return "none"

  if(length(strip(b[3]))) {
    if(webpagestatus(strip(b[3])) == 1) {
      sub(/^http[:]/, "https:", b[3])     # Convert to https
      return strip(b[3])
    }
  }

  return "none"
}

#
#   Return web page status.
#
#   Return 1 if 2XX
#   Return 0 if 4xx etc..
#   Return -1 if timeout. 
#   Return actual status code if flag="code"
#   If checking status of a page in which the API said 404 (or missing), set flag="404" to avoid false positives
#
function webpagestatus(url, flag,    head,j,tries,command,response,tempfile,returnval,redirurl) {

  tries = 3  # Number of times to retry IA API

  returnval = 0

  if(url ~ /'/) gsub(/'/,"%27",url)    # shell escape literal string

  tempfile = mktemp("wget.XXXXXX","f")

  # Headers go to stderr, body to stdout.
  # content-on-error needed to see output of body during a 403/4 which is redirected to a temp file.
  command = Exe["wget"] " --content-on-error -SO- -q --retry-connrefused --tries=5 --waitretry=20 --timeout=30 --no-dns-cache --no-check-certificate --user-agent=\"" Agent "\" '" url "' 2>&1 > " tempfile

  while(j < tries) {
    sleep(2)
    if(Debug["network"]) print "Starting headers (" j + 1 ") for " url
    head = sys2var(command)
#print "\n____________________________\n"
#print command
#print readfile(tempfile)
#print "\n____________________________\n"
    close(tempfile)
    responsecode = headerresponse(head)
    if(Debug["network"]) print "Ending headers (" length(head) " / " responsecode ")"
    if(length(head) == 0 || responsecode ~ /none/)
      j++
    else
      break
  }
  if(j == tries) {
    if(Debug["network"]) print "Headers time out"
    sendlog(Project["timeout"], name, "headers:" url)
    returnval = -1
  }
  else if(responsecode !~ /none/ && responsecode != 0 && responsecode != "") {
    if( int(responsecode) > 199 && int(responsecode) < 300) {
      if( iainfopage(tempfile) && flag ~ /404/) {
        if( iaredirect(tempfile) && ! Redirloop) {                # 302 redirect page .. follow it and verify header
          Redirloop = 1
          redirurl = getredirurl(tempfile)
          if(redirurl ~ /^http/) {
            if(webpagestatus(redirurl) == 1) {                    # recursive call
              returnval = 1
              responsecode = 200
              Redirloop = 0                                       # Global flag to stop endless loop
            }
            else {
              returnval = 0
              Redirloop = 0
            }
          }
          else {
            returnval = 0
            Redirloop = 0
          }
        }
        else
          returnval = 0
      }
      else {
        returnval = 1
      }
    }
    if( bummerpage(tempfile) ~ /bummer/) {
      if(Debug["network"]) print "Bummer page"
      sendlog(Project["bummer"], name, url)
      returnval = 1                            # Treat as a 200 response
      responsecode = 200
    }
  }

  if(checkexists(tempfile))
    sys2var( Exe["rm"] " -r -- " tempfile)

  if(flag ~ /code/)
    return responsecode
  else
    return returnval
}

#
# Create a file containing API POST data.
#
#   API documentation: http://207.241.231.246:8120/usage (archived https://archive.is/6ZcDv)
#                      https://wwwb-app37.us.archive.org:8120/usage
#
function createpostdata(  postfile,postdir,tag,request) {

  if(length(WayLink)) {
    postdir = mktemp("/tmp/post.XXXXXX", "d")
    if(postdir !~ /^\/tmp\/post[.][0-9A-Za-z]{6}$/) {
      postdir = mktemp("/tmp/post.XXXXXX", "d")
      if(postdir !~ /^\/tmp\/post[.][0-9A-Za-z]{6}$/) {
        print "Error in createpostdata: unable to create temp directory " postdir > "/dev/stderr"
        return
      }
    }
    postfile = postdir "/postdata"
  }
  else
    return

  for(tag in WayLink) {
    if( WayLink[tag]["origdate"] !~ /none/ ) 
      request = "url=" WayLink[tag]["origurl"] "&closest=either&timestamp=" WayLink[tag]["origdate"] "&tag=" tag "&statuscodes=404&statuscodes=200&statuscodes=203&statuscodes=206"
    else 
      request = "url=" WayLink[tag]["origurl"] "&closest=after&timestamp=19000101&tag=" tag "&statuscodes=404&statuscodes=200&statuscodes=203&statuscodes=206"

    print request >> postfile
  }
  close(postfile)
  return postdir
}

#
# Given url (as ["origiaurl"] or ["formated"]), return best working wayback URL (in formated condition). 
#   Otherwise return "none" if none available.
#
function waybackapi(url,   tag) {

  for(tag in WayLink) {

    if( countsubstring(WayLink[tag]["origiaurl"], url) == 1 || countsubstring(WayLink[tag]["formated"], url) == 1 ) {
      if(WayLink[tag]["status"] ~ /^2/ && isarchiveorg(WayLink[tag]["newiaurl"]) ) {
        return WayLink[tag]["newiaurl"]
      }
      else if(WayLink[tag]["status"] ~ /^2/ && isarchiveorg(WayLink[tag]["formated"]) ) {
        return WayLink[tag]["formated"]
      }
      else
        return "none"
    }
  }
  return "none"
}

#
# Header response code (200 is OK, 403 is permission denied etc..)
#  Return the code, otherwise "none"
#
function headerresponse(head,  a,b,c,i,j,cache) {

  delete cache
  c = split(head, a, "\n")
  while(i++ < c) {
    if(a[i] ~ /^[ ]{0,5}HTTP\/1[.]1/) {
      split(a[i],b," ")
      if(int(strip(b[2])) > 1) {
        cache[++j] = strip(b[2])
      }
    }
  }

  if( int(cache[length(cache)]) > 0)   { # Get the last HTTP response
#    if( int(cache[length(cache)]) != 200 && Debug["network"])
#      print head > "/dev/stderr"
    return cache[length(cache)]
  }
  return "none"
}


#
# Find the redirect URL from body of IA 302 info page
#  Since using scrape, try 2 methods in case page formatting changes.
#
function getredirurl(filename,   k,a,body) {
  
  if(checkexists(filename)) 
    body = readfile(filename)
  else 
    return

  gsub("\n"," ",body)
  gsub("\r"," ",body)
  gsub("\t"," ",body)

  # Method 1
  # <p class="impatient"><a href="/web/20090205165059/http://news.bbc.co.uk/sport2/hi/cricket/7485935.stm">

  if(match(body,/[<][ ]{0,}[Pp][ ]{1,}[Cc][Ll][Aa][Ss]{2}[ ]{0,}[=][ ]{0,}\"[ ]{0,}[Ii]mpatient[ ]{0,}\"[ ]{0,}>[ ]{0,}[<][ ]{0,}[Aa][ ]{1,}[Hh][Rr][Ee][Ff][ ]{0,}[=][ ]{0,}\"[^\"]*\"/, k)) {
    if(split(k[0], a, "\"") == 5) 
      return "https://web.archive.org" strip(a[4])
  }

  # Method 2
  # function go() { document.location.href = "\/web\/20090205165059\/http:\/\/news.bbc.co.uk\/sport2\/hi\/cricket\/7485935.stm"

  if(match(body, /function[ ]{1,}go[(][)][ ]{0,}[{][ ]{0,}document[.]location[.]href[ ]{0,}[=][ ]{0,}\"[^\"]*\"/,k)) {
     if(split(k[0], a, "\"") == 3) {
       gsub(/\\\//,"/",a[2])
       return "https://web.archive.org" strip(a[2])
     }
  }
}

#
# Page is an IA info page of any kind.. (add more here as they are found)
#
function iainfopage(body,  c,a,i,result) {

  result = 0
  c = split(readfile(body), a, "\n")
  while(i++ < c) {
    if(a[i] ~ /Your use of the Wayback Machine is subject to the Internet Archive/)
      result = 1    
    if(a[i] ~ /Wayback Machine doesn't have that page archived/)
      result = 1
    if(a[i] ~ /Redirecting to[.][.][.]/)
      result = 1
  }
  return result
}

#
# Page is an IA redirect page 
#
# Example 200 page that is a redirect to a dead page
#  http://web.archive.org/web/20120512133959/http://www.nileslibrary.org:2065/pqdweb?index=405&did=575152532&SrchMode=1&sid=2&Fmt=10&VInst=PROD&VType=PQD&RQT=309&VName=HNP&TS=1250223809&clientId=68442
# Example 200 page that is a redirect to a working page and the API says this URL has no snapshots available
#  http://web.archive.org/web/20090205165059/http://news.bbc.co.uk/sport1/hi/cricket/7485935.stm
#
function iaredirect(body,  c,a,i,result) {

  result = 0
  c = split(readfile(body), a, "\n")
  while(i++ < c) {
    if(a[i] ~ /Got an HTTP 302 response at crawl time/)
      result = 1
    if(a[i] ~ /Redirecting to[.][.][.]/)
      result = 1
  }
  return result
}

#
# Page is a bummer. IA returned: "The machine that serves this file is down. We're working on it."
#
function bummerpage(body,  c,a,i,result) {

  result = "none"
  c = split(readfile(body), a, "\n")
  while(i++ < c) {
    if(a[i] ~ /The machine that serves this file is down/) {
      result = "bummer"
    }
  }
  return result
}

#
# Print contents of array for debugging
#  If flag="filename" print to filename otherwise to screen
#
function debugarray(tag, flag,   out) {

          if(length(flag))
            out = Datadir flag
          else
            out = "/dev/stderr"

          print "  WayLink[" tag "][\"origiaurl\"] = " WayLink[tag]["origiaurl"] >> out
          print "  WayLink[" tag "][\"formated\"] = " WayLink[tag]["formated"] >> out
          print "  WayLink[" tag "][\"origurl\"] = " WayLink[tag]["origurl"] >> out
          print "  WayLink[" tag "][\"origdate\"] = " WayLink[tag]["origdate"] >> out
          print "  WayLink[" tag "][\"newurl\"] = " WayLink[tag]["newurl"] >> out
          print "  WayLink[" tag "][\"tag\"] = " WayLink[tag]["tag"] >> out
          print "  WayLink[" tag "][\"newiaurl\"] = " WayLink[tag]["newiaurl"] >> out
          print "  WayLink[" tag "][\"status\"] = " WayLink[tag]["status"] >> out
          print "  WayLink[" tag "][\"available\"] = " WayLink[tag]["available"] >> out
          print "--" >> out
}

#
# Given a number, return the factor of 5 with no remainder. If there is a remainder, there is an error in the data.
#
function makecount(c,  float,b,count) {
      float = c / 5         
      if(split(float, b, ".") >= 2 || ! float ) {
        count = b[1]
        print "Possible error in makecount, bad API data? (" name ")" > "/dev/stderr"
      }
      else
        count = float
      return count
}

#
# Fill WayLink[] with values
#
function fillway(tag, status, available, newiaurl, newurl) {
  WayLink[tag]["status"] = status
  WayLink[tag]["available"] = available
  WayLink[tag]["newiaurl"] = formatediaurl(newiaurl, "barelink")
  WayLink[tag]["newurl"] = newurl

  if( WayLink[tag]["newiaurl"] !~ /none/)          # Security check
    if( ! isarchiveorg(WayLink[tag]["newiaurl"])) 
      WayLink[tag]["newiaurl"] == "none"
}
