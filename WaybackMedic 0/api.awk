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
function queryapipost(internalcount,    postfile,postdir,command,i,c,csv,c2,csv2,a,a2,b,tag,returnval,tries,j,url,out,z,originalcount,status) {

  tries = 3
  returnval = 1

  postfile = Datadir "postfile" 
  createpostdata(postfile)

                             # Awk has bad JSON options so we convert to CSV then into an array.
  if(internalcount > 0) {    # Download JSON from API with wget, convert to CSV with jq, convert to array a[] with qsplit(), load global WayLink[][] from a[]'s data                
    j = 1 
    while(j < tries + 1) { 

      if(Debug["network"]) print "Starting API (try " j ")" 

      csv = sys2var(Exe["wget"] Wget_opts "--header=\"Wayback-Api-Version: 2\" --post-file=\"" postfile "\" -q -O- \"http://archive.org/wayback/available\" | " Exe["jq"] " -r '. [] | map(.url, .tag, .archived_snapshots.closest.url, .archived_snapshots.closest.status, .archived_snapshots.closest.available) |@csv' " )
      c = qsplit(csv, a)

      sleep(2)           # Trust/verify

      csv2 = sys2var(Exe["wget"] Wget_opts "--header=\"Wayback-Api-Version: 2\" --post-file=\"" postfile "\" -q -O- \"http://archive.org/wayback/available\" | " Exe["jq"] " -r '. [] | map(.url, .tag, .archived_snapshots.closest.url, .archived_snapshots.closest.status, .archived_snapshots.closest.available) |@csv' " )
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
        sendlog(Project["jsonmismatch"], name, "queryapipost")
        gsub(/'|’/, "'\\''", csv)
        gsub(/'|’/, "'\\''", csv2)
        print "'" strip(csv) "'"  > Datadir "csv.orig"
        print "'" strip(csv2) "'"  > Datadir "csv2.orig"
        close(Datadir "csv.orig")
        close(Datadir "csv2.orig")
        if( length(csv2) > length(csv) || int(c2) > int(c) ) {
          delete a
          csv = csv2
          c = qsplit(csv2, a)
        }
        break
      }
      else                                                                                   # 2 requests match. exit.
        break
    }
      
    if(Debug["api"]) print "csv = " csv

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
            out = out "\"" WayLink[tag]["origencoded"] "\",\"" WayLink[tag]["tag"] "\",,,,"
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

        sendlog(Project["apimismatch"], name, internalcount "|" count)
      }

     # Debug stuff
      gsub(/'|’/, "'\\''", csv)
      if(Debug["api"]) print "New record count " count "\n"
      if(Debug["api"]) print "csv = '" csv "'" 
      print "'" strip(csv) "'"  > Datadir "csv"
      printf "" > Datadir "waylink.start"
      printf "" > Datadir "waylink.end"
      if(checkexists(Datadir "csv-get.orig"))
        printf "" > Datadir "csv-get.orig"
      if(checkexists(Datadir "csv-get2.orig"))
        printf "" > Datadir "csv-get2.orig"
      close(Datadir "csv")
      close(Datadir "waylink.start")
      close(Datadir "waylink.end")
      close(Datadir "csv-get.orig")
      close(Datadir "csv-get.orig2")

      i = 0
      while( i++ < count ) {

        tag = a[(i * 5) - 3] 
                    
        #                status       available     newiaurl         newurl
        fillway(tag, a[(i * 5) - 1],  a[i * 5],  a[(i * 5) - 2],  a[(i * 5) - 4])

        WayLink[tag]["tag"] == "" ? WayLink[tag]["tag"] = "none" : ""
        WayLink[tag]["status"] == "" ? WayLink[tag]["status"] = "0" : ""
        WayLink[tag]["available"] == "" ? WayLink[tag]["available"] = "false" : ""
        WayLink[tag]["available"] == "true" ? WayLink[tag]["available"] = "wayback" : ""
        WayLink[tag]["newiaurl"] == "" ? WayLink[tag]["newiaurl"] = "none" : ""
        WayLink[tag]["newurl"] == "" ? WayLink[tag]["newurl"] = "none" : ""

        debugarray(tag, "waylink.start")        

        if(WayLink[tag]["status"] ~ /^2/) {                          # API reports 2xx
          if( WayLink[tag]["newiaurl"] !~ /none/ && WayLink[tag]["tag"] !~ /none/ ) {
            status = webpagestatus(WayLink[tag]["newiaurl"])
            if(status == 5) {
              if(Debug["network"]) print "Step A1: 503 SERVERS DOWN."
              sendlog(Project["critical"], name, " 503_servers_down A1")
              return 0
            }
            else if(status != 1 && status != 3) {                         # Page headers *not* 200 .. sleep and try again.. 
              sleep(10)                                                   #  Condition A1 occured in 400 of 10000 checks. Timeout etc. try again
              status = webpagestatus(WayLink[tag]["newiaurl"])
              if(status != 1 && status != 3) {
                if(Debug["network"]) print "Step A1: NOT FOUND. Page headers verified *not* 200"
                sendlog(Project["bogusapi"], name, WayLink[tag]["newiaurl"] " A1")
                fillway(tag, "0", "false", "none", "none")
              }
              if(status == 5) {
                if(Debug["network"]) print "Step A1: 503 SERVERS DOWN."
                sendlog(Project["critical"], name, " 503_servers_down A1")
                return 0
              }
            }
          }
          else {
            fillway(tag, "0", "false", "none", "none")
            if(Debug["network"]) print "Step A2: NOT FOUND. Unknown."

          }
        }
        if(WayLink[tag]["status"] ~ /^404$|^0$/) {                   # API reports 404 or missing 
          if(Debug["network"]) print "Step 1: API reports 404 or missing"
          if( WayLink[tag]["origiaurl"] !~ /none/ && WayLink[tag]["tag"] !~ /none/ ) {
            if(Debug["network"]) print "Step 2: Verified origiaurl is not none."
            status = webpagestatus(WayLink[tag]["origiaurl"], "404")
            if(status == 1) {                                        # Page headers verify as 200 
              if(Debug["network"]) print "Step A3: FOUND. Page headers verify as 200"
              if(i <= originalcount) 
                sendlog(Project["bogusapi"], name, WayLink[tag]["origiaurl"] " A3")
              fillway(tag, "200", "wayback", WayLink[tag]["origiaurl"], WayLink[tag]["origurl"])
            }
            else if(status == 3) {                                   # Page redirect 302 to a working page of unknown status (soft 404? working?) 
              if(Debug["network"]) print "Step A4: FOUND. 302 to a working page of unknown status"
              if(i <= originalcount) 
                sendlog(Project["bogusapi"], name, WayLink[tag]["origiaurl"] " A4")
              fillway(tag, "200", "wayback", wildcard(WayLink[tag]["origiaurl"]), WayLink[tag]["origurl"])
            }
            else if(status == 5) {
              if(Debug["network"]) print "Step A4: 503 SERVERS DOWN."
              sendlog(Project["critical"], name, " 503_servers_down A4")
              return 0
            }
            else {
              if(Debug["network"]) print "Step 3: Try again with earliest date 1970101 using original URL"
              url = queryapiget(WayLink[tag]["origencoded"])             # Try again with earliest date 1970101 using original URL
              if(url !~ /none/ && url ~ /^http/) {
                if(Debug["network"]) print "Step 4: url verified not none."
                status = webpagestatus(url)
                if(status == 1) {                                    # Page headers verify 200 
                  if(Debug["network"]) print "Step A5: FOUND. Page headers verify 200"
                  if(i <= originalcount) 
                    sendlog(Project["bogusapi"], name, url " A5")
                  fillway(tag, "200", "wayback", url, WayLink[tag]["origurl"]) 
                }
                else if(status == 3) {                               # Page redirect 302 to a working page of unknown status (soft 404? working?)
                  if(Debug["network"]) print "Step A6: FOUND. 302 to a working page of unknown status"
                  if(i <= originalcount) 
                    sendlog(Project["bogusapi"], name, url " A6")
                  fillway(tag, "200", "wayback", wildcard(url), WayLink[tag]["origurl"]) 
                }
                else if(status == 5) {
                  if(Debug["network"]) print "Step A6: 503 SERVERS DOWN."
                  sendlog(Project["critical"], name, " 503_servers_down A6")
                  return 0
                }
              }
            }
          }  

          # Try alt archives via Memento
                             
          if( WayLink[tag]["status"] ~ /^404$|^0$/ && WayLink[tag]["tag"] !~ /none/ ) {
            if(Debug["network"]) print "Step 5: Try alt archives via Memento API"
            if(api_memento(WayLink[tag]["origencoded"], WayLink[tag]["origdate"], tag) ~ /OK/) {
              status = webpagestatus(WayLink[tag]["altarchencoded"])
              if(status == 1) {
                if(Debug["network"]) print "Step A7: FOUND. Alt archive"
                WayLink[tag]["status"] = "200"
                WayLink[tag]["available"] = "altarch"
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
function queryapiget(url, timestamp,        urlapi,j,tries,command,csv,c,b,csv2,c2,b2,status) {

  tries = 3
  if(url !~ /^http/) return "none"
  if(!timestamp) timestamp = "none"

  if(timestamp ~ /none/)
    urlapi = url "&closest=after&statuscodes=200&statuscodes=203&statuscodes=206&statuscodes=404&timestamp=19700102"
  else
    urlapi = url "&closest=either&statuscodes=200&statuscodes=203&statuscodes=206&statuscodes=404&timestamp=" timestamp

  command = Exe["wget"] Wget_opts "--header=\"Wayback-Api-Version: 2\" --post-data=\"url=" urlapi "\" -q -O- http://archive.org/wayback/available | " Exe["jq"] " -r '. [] | map(.url, .tag, .archived_snapshots.closest.url, .archived_snapshots.closest.status, .archived_snapshots.closest.available) |@csv' "

  # if(Debug["network"]) print "Command: " command

  while(j < tries) {
    if(Debug["network"]) print "Starting API (get) (" j+1 ") for " urlapi
    csv = sys2var(command)
    c = qsplit(csv, b)
    sleep(2)
    csv2 = sys2var(command)
    c2 = qsplit(csv2, b2)
    if(Debug["network"]) print "Ending API (get) (" length(csv) "/" c "|" length(csv2) "/" c2 ")"
    if(length(csv) == 0 || c == 0 || length(csv2) == 0 || c2 == 0) {                       # Problem retrieving API data, try again.
      j++
      sleep(2)
    }
    else if(j == tries) {
      if(Debug["network"]) print "API time out (get)"
      sendlog(Project["timeout"], name, "queryapiget")
      return "none"
    }
    else if(length(csv) != length(csv2) || c != c2) {                                      # Mismatch in 2 requests. Pick the largest and exit.
      sendlog(Project["jsonmismatch"], name, "queryapiget")
      gsub(/'|’/, "'\\''", csv)
      gsub(/'|’/, "'\\''", csv2)
      print "'" strip(csv) "'"  >> Datadir "csv-get.orig"
      print "'" strip(csv2) "'"  >> Datadir "csv2-get.orig"
      close(Datadir "csv-get.orig")
      close(Datadir "csv2-get.orig")
      if( length(csv2) > length(csv) || int(c2) > int(c) ) {
        delete b
        csv = csv2
        c = qsplit(csv2, b)
      }
      break
    }
    else                                                                                   # 2 requests match. exit.
      break
  }

  if(c != 5) return "none"

  if(length(strip(b[3]))) {
    status = webpagestatus(strip(b[3]))
    if(status == 1 || status == 3) {
      sub(/^http[:]/, "https:", b[3])     # Convert to https
      return strip(b[3])
    }
    else if(status == 5) {
      if(Debug["network"]) print "Step queryapiget: 503 SERVERS DOWN."
      sendlog(Project["critical"], name, " 503_servers_down queryapiget")
      return "none"
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
function webpagestatus(url, flag,    head,j,tries,command,response,wgetbody,wgethead,returnval,redirurl,pe) {

  tries = 3  # Number of times to retry IA API

  returnval = 0

  if(url ~ /'/) gsub(/'/,"%27",url)    # shell escape literal string

  wgetbody = mktemp(Datadir "wgetbody.XXXXXX", "f")

  # Headers go to stderr, body to stdout.
  # content-on-error needed to see output of body during a 403/4 which is redirected to a temp file.

  command = Exe["wget"] Wget_opts "--content-on-error -SO- -q '" url "' 2>&1 > " wgetbody

  while(j < tries) {

    if(Debug["network"]) print "Starting headers (" j + 1 ") for " url
    if(Debug["wgetlog"]) wgethead = mktemp(Datadir "wgethead.XXXXXX", "f")

    head = sys2var(command)
    close(wgetbody)

    responsecode = headerresponse(head)

    if(Debug["network"]) print "Ending headers (" length(head) " / " responsecode ")"
    if(Debug["wgetlog"]) {
      print head > wgethead
      close(wgethead)
    }

    if(length(head) == 0 || responsecode ~ /none/) {
      j++
      sleep(2)
    }
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
      if( iainfopage(wgetbody) && flag ~ /404/) {
        if( iaredirect(wgetbody) && ! Redirloop) {                # 302 redirect page .. follow it and verify header
          Redirloop = 1
          redirurl = getredirurl(url, wgetbody)
          if(redirurl ~ /^http/) {
            if(webpagestatus(redirurl) == 1) {                    # recursive call
              returnval = 3
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
    else if(responsecode == 503 || responsecode == 504 || responsecode == 417) {   # 417 bot rate exceeded
      returnval = 5
      responsecode = 503
    }
    pe = pageerror(wgetbody)
    if( pe ~ /bummer/) {
      if(Debug["network"]) print "Bummer page"
      sendlog(Project["bummer"], name, url)
      returnval = 1                            # Treat as a 200 response
      responsecode = 200
    }
    else if( pe ~ /robots/) {
      if(Debug["network"]) print "Page cannot be crawled or displayed due to robots.txt"
      returnval = 0
      responsecode = 403
    }
    else if( pe ~ /excluded/) {
      if(Debug["network"]) print "This URL has been excluded from the Wayback Machine"
      returnval = 0
      responsecode = 403
    }
    else if( pe ~ /404/) {
      if(Debug["network"]) print "title:og header says 404 not found"
      returnval = 0
      responsecode = 404
    }
  }

  if(! Debug["wgetlog"]) {                     # delete wget.* files unless Debug 
    if(checkexists(wgetbody))    
      sys2var(Exe["rm"] " -r -- " Datadir "wget*" )
  }

  if(flag ~ /code/)
    return responsecode
  else
    return returnval
}

#
# Create a file w/ API POST data.
#
#   API documentation: http://207.241.231.246:8120/usage (archived https://archive.is/6ZcDv)
#                      https://wwwb-app37.us.archive.org:8120/usage
#
function createpostdata(postfile,   tag,request) {

  if(checkexists(postfile))
    sys2var(Exe["rm"] " -- " postfile)

  for(tag in WayLink) {
    if( WayLink[tag]["origdate"] !~ /none/ && WayLink[tag]["origencoded"] !~ /none/ ) 
      request = "url=" WayLink[tag]["origencoded"] "&closest=either&timestamp=" WayLink[tag]["origdate"] "&tag=" tag "&statuscodes=404&statuscodes=200&statuscodes=203&statuscodes=206"
    else 
      request = "url=" WayLink[tag]["origencoded"] "&closest=after&timestamp=19700101&tag=" tag "&statuscodes=404&statuscodes=200&statuscodes=203&statuscodes=206"

    print request >> postfile
  }
  close(postfile)
}

#
# Given url (as ["origiaurl"] or ["formated"]), return best working wayback or altarch URL (in formated condition). 
#   Otherwise return "none"
#
function api(url,   tag) {

  for(tag in WayLink) {

    if( countsubstring(WayLink[tag]["origiaurl"], url) == 1 || countsubstring(WayLink[tag]["formated"], url) == 1 ) {
      if(WayLink[tag]["status"] ~ /^2/ ) {
        if(isarchiveorg(WayLink[tag]["newiaurl"]) && WayLink[tag]["available"] ~ /wayback/ ) {
          return WayLink[tag]["newiaurl"]
        }
        else if(isarchiveorg(WayLink[tag]["formated"]) && WayLink[tag]["available"] ~ /wayback/ ) {
          return WayLink[tag]["formated"]
        }
        else if(WayLink[tag]["available"] ~ /altarch/ ) {
          return WayLink[tag]["altarch"]
        }
        else
          return "none"
      }
      else
        return "none"
    }
  }
  return "none"
}

#
# Pick the best Alternative Archive from Memento list, bypassing Wayback snapshots         
#  url should be encoded before passing 
#  Sample JSON data: wget -q -O- "http://timetravel.mementoweb.org/api/json/20130115102033/http://cnn.com" | jq '. [ ]'
#
function api_memento(url, date, tag,     snap,c,a,i,re,k,d,b,e,f,m,n,p,q,stamp,command) {

  command = Exe["wget"] Wget_opts "-q -O- \"http://timetravel.mementoweb.org/api/json/" date "/" url "\" | " Exe["jq"] " -r '. []'" 
  if(Debug["network"]) print command

  jsonin = sys2var(command)
  if(!length(jsonin)) {
    sleep(2)
    jsonin = sys2var(command)
    if(!length(jsonin)) {
      if(Debug["network"]) print "ERROR: Memento returned 0-length API"
      return "none"
    }
  }

  print jsonin "\n----" >> Datadir "mementoapi.json"

  snap = "closest|prev|first"                          # Check in this order
  c = split(snap, a, "|")
  while(i++ < c) {
    re = "\"" a[i] "\"[:][ ]{0,}[{][^}]*[}]"
    if(match(jsonin, re, k)) {
      # url's
      split(strip(k[0]), b, /\[|\]/)
      d = qsplit(strip(b[2]), e)
      if(d > 0) {
        f = 0
        while(f++ < d) {
          e[f] = strip(e[f])
          if( ! isarchiveorg(e[f]) && e[f] ~ /^http/ && e[f] !~ /archive[.]is\// )  { # Not archive.org or archive.is

           # webcitation.org with a path < 9 characters is a broken URL
            if(e[f] ~ /webcitation[.]org/) {
              q = split(e[f], p, "/")
              if(length(p[q]) < 5) 
                break
            }   

           # "datetime":"2000-06-20T18:02:59Z"
            match(strip(k[0]), /"datetime"[:][ ]{0,}"[^\"]*"/,m)
            split(strip(m[0]), n, "\"")
            stamp = sys2var(Exe["date"] " --date=\"" strip(n[4]) "\" +'%Y%m%d%H%M%S'")

            WayLink[tag]["altarch"] = urldecodepython(e[f])                     
            WayLink[tag]["altarchencoded"] = uriparseEncodeurl(e[f])  
            WayLink[tag]["altarchdate"] = stamp
            return "OK"
          }
        }
      }
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
function getredirurl(origurl, filename,   k,a,b,body,path,origpath,url,newurl) {
  
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
      url = strip(a[4])
  }

  # Method 2
  # function go() { document.location.href = "\/web\/20090205165059\/http:\/\/news.bbc.co.uk\/sport2\/hi\/cricket\/7485935.stm"

  if( !length(url) && match(body, /function[ ]{1,}go[(][)][ ]{0,}[{][ ]{0,}document[.]location[.]href[ ]{0,}[=][ ]{0,}\"[^\"]*\"/,k)) {
     if(split(k[0], a, "\"") == 3) {
       gsub(/\\\//,"/",a[2])
       url = strip(a[2])
     }
  }

  url = convertxml(url)
  url = "https://web.archive.org"  url
  newurl = wayurlurl(url)

  if(isarchiveorg(origurl)) 
    origurl = wayurlurl(origurl)
    
  if(newurl ~ /^http/ && origurl ~ /^http/ && length(newurl) < length(origurl)) {    # Basic filters soft-404
    path = uriparseElement(newurl, "path")
    origpath = uriparseElement(origurl, "path")
    if(length(path) < 2) {                                                                # If path is empty, probably a home page
      if(Debug["network"]) print "Redir URL failed check 1. Path " path " too short."
      return ""
    }
    if(path ~ /[Nn][Oo][Tt][^Ff]*[Ff][Oo][Uu][Nn][Dd]/) {
      if(Debug["network"]) print "Redir URL failed check 2"
      return ""
    }
    if(path ~ /[^0-9]404[^0-9]|[^a-zA-Z][Ee]rror[^a-zA-Z]|[^a-zA-Z][Uu]nknown[^a-zA-Z]/) {
      if(Debug["network"]) print "Redir URL failed check 3"
      return ""
    }
    if(substr(newurl,length(newurl),1) ~ /\// && substr(url,length(newurl),1) !~ /\//) { # If last char of new URL is / 
      if(Debug["network"]) print "Redir URL failed check 4"
      return ""
    }
    if(split(path, b, "/") == 2 && split(origpath, b, "/") > 2) {                        
      if(Debug["network"]) print "Redir URL failed check 5: path is too short"
      return ""
    }
  }
  
  return url

}

#
# Page is an IA info page of any kind.. (add more here as they are found)
#
function iainfopage(body,  c,a,i,result) {

  result = 0
  c = split(bodylead(body), a, "\n")
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
  c = split(bodylead(body), a, "\n")
  while(i++ < c) {
    if(a[i] ~ /Got an HTTP 302 response at crawl time/)
      result = 1
    if(a[i] ~ /Redirecting to[.][.][.]/)
      result = 1
  }
  return result
}

#
# Page is a bummer or robots or etc.
#
function pageerror(body,  c,a,i,result) {

  result = "none"
  c = split(bodylead(body), a, "\n")
  while(i++ < c) {
    if(a[i] ~ /The machine that serves this file is down/)                          # archive.org and archive.is
      result = "bummer"
    if(a[i] ~ /Page cannot be crawled or displayed due to robots.txt/)              # archive.org and archive.is
      result = "robots"
    if(a[i] ~ /meta property[=]["]og[:]title["] content[=]["]404 Not Found["]/)     # archive.is
      result = "404"
    if(a[i] ~ /404[ ]{0,}-[ ]{0,}Page cannot be found/)
      result = "404"
    if(a[i] ~ /show[_]404/)
      result = "404"
    if(a[i] ~ /This URL has been excluded from the Wayback Machine/)
      result = "excluded"
  }
  return result
}

#
# Return first X lines of wget body file .. presume interesting info there -- rest is content.
#  prevent large files (mp4s etc) from killing swap 
#
function bodylead(bodypath,    s,i,out) {

  while ((getline s < bodypath ) > 0) {
    i++
    out = out "\n" s
    if(i > 1000)
      break
  }
  close(bodypath)
  return out
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
          print "  WayLink[" tag "][\"origencoded\"] = " WayLink[tag]["origencoded"] >> out
          print "  WayLink[" tag "][\"origdate\"] = " WayLink[tag]["origdate"] >> out
          print "  WayLink[" tag "][\"newurl\"] = " WayLink[tag]["newurl"] >> out
          print "  WayLink[" tag "][\"newiaurl\"] = " WayLink[tag]["newiaurl"] >> out
          print "  WayLink[" tag "][\"altarch\"] = " WayLink[tag]["altarch"] >> out
          print "  WayLink[" tag "][\"altarchencoded\"] = " WayLink[tag]["altarchencoded"] >> out
          print "  WayLink[" tag "][\"altarchdate\"] = " WayLink[tag]["altarchdate"] >> out
          print "  WayLink[" tag "][\"tag\"] = " WayLink[tag]["tag"] >> out
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
      WayLink[tag]["newiaurl"] = "none"
}

#
# Convert a IA URL date to wildcard "*"
#
# eg. http://web.archive.org/web/20110606140102/http://www.haaretz.com/
#     http://web.archive.org/web/*/http://www.haaretz.com/
#
function wildcard(url,   a,c,i,safe) {

  return url   # Disabled for now. Unclear this is a good idea it will confuse other bots, and editors.

  safe = url
  c = split(safe, a, "/")
  while(i++ < c) {
    if(length(a[i])) {
      if(a[i] ~ /^web$/) {
        i++
        date = strip(a[i])
        break
      }
      if(a[i] ~ /^[0-9]*$/) {
        date = strip(a[i])
        break
      }
    }
  }
  if(length(date)) {
    re = "/" date "/"
    sub(re, "/*/", safe)
  }  
  return safe


}

