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
# Core proc called by others to manage results of page status
#
#  Note: Any changes to step #'s need to be reflected here, in fixbadstatus() (trailgarb) and in awk statistics
#
proc runStatus(tup: tuple[url: string, status: int, response: int], step: string, tag: int): bool {.discardable} =

  var
    step = step
    msg, forf = ""
    log = "bogusapi"

  if step == "A6.8.1.1":
    msg = "Removed double encoding via webpagestatus"
  elif step == "A6.8.4.1":
    msg = "Removed double encoding via API"
  elif step == "A6.7.1.1":
    msg = "Trailing garbage character removed"
  elif step == "A6.7.4.1":
    msg = "Trailing garbage x2 single-quote characters removed"
  elif step == "A6.7.7.1":
    msg = "Trailing garbage double-quote character removed"
  elif step == "A6.7.10.1":
    msg = "Trailing garbage %XX removed"
  elif step == "A6.7.13.1":
    msg = "Trailing garbage letter removed"
  elif step == "A1.3.2.1":
    msg = "FOUND. Earliest date 1970101 using original URL"
  elif step == "A6.6.1.1":
    msg = "FOUND. &amp;|&amp%3B to & conversion in path"
  elif step == "A6.6.4.1":
    msg = "FOUND. &amp;|&amp%3B to & conversion in query"
  elif step == "A6.6.7.1":
    msg = "FOUND. &amp;|&amp%3B to & conversion in path+query"
  elif step == "A6.5.1.1":
    msg = "FOUND. %20 to + conversion in path worked"
  elif step == "A6.5.4.1":
    msg = "FOUND. %20 to + conversion in query worked"
  elif step == "A6.5.7.1":
    msg = "FOUND. %20 to + conversion in path+query worked"
  elif step == "A6.5.10.1":
    msg = "FOUND. + to %20 conversion in path worked"
  elif step == "A6.5.13.1":
    msg = "FOUND. + to %20 conversion in query worked"
  elif step == "A6.5.16.1":
    msg = "FOUND. + to %20 conversion in path+query worked"
  elif step == "A6.9.1.1":
    msg = "FOUND. HTML character conversion"
  else:
    return false

  if msg !~ "FOUND":
    forf = "FIXED. "

  if tup.status == 1:             
    sed("Step " & step & ": " & forf & msg, Debug.network)
    fillway(tag, "200", "wayback", tup.url, formatedorigurl(wayurlurl(tup.url)), tup.response, "Step " & step & ": " & forf & msg)
    WayLink[tag].formated = formatediaurl(tup.url, "barelink")
    if log == "bogusapi":
      sendlog(Project.bogusapi, CL.name, WayLink[tag].origiaurl & " ---- " & tup.url & " " & step)
    return true
  elif tup.status == 3:
    step = incstep(step)             
    sed("Step " & step & ": " & forf & msg & ". 302 to working page of unknown status", Debug.network)
    fillway(tag, "200", "wayback", tup.url, formatedorigurl(wayurlurl(tup.url)), tup.response, "Step " & step & ": " & forf & "302 to working page of unknown status. " & msg)
    WayLink[tag].formated = formatediaurl(tup.url, "barelink")
    if log == "bogusapi":
      sendlog(Project.bogusapi, CL.name, WayLink[tag].origiaurl & " ---- " & tup.url & " " & step)
    return true
  elif tup.status == 5:
    step = incstep(incstep(step))
    sed("Step " & step & ": 503 SERVERS DOWN.", Debug.network)
    sendlog(Project.critical, CL.name, " 503_servers_down " & step & " ----" & WayLink[tag].origencoded)
    
  return false


#
# Try to fix double encoding (%253A = %3A)
#
proc waytree_x2encoding(tag: int): bool {.discardable.} =

    var
      url = urldecode(WayLink[tag].origiaurl)
      status, response = -1
      tup: tuple[url: string, status: int, response: int]

    sed("Step 6.8: Try remove double encoding", Debug.network)

   # Try direct link first 
    if WayLink[tag].origiaurl ~ "[%]25" and not dummydate(WayLink[tag].origiaurl) and urltimestamp_wayback(url) !~ "000000":
      sed("Step 6.8.1.0: Remove double encoding via webpagestatus", Debug.network)
      (status, response) = webpagestatus(url, "404")
      tup = (url: url, status: status, response: response)
      if runStatus(tup, "A6.8.1.1", tag):                      # Log files: 6.8.1->3 or 6.8.1.1->6.8.1.3 followed by $
        return true
   
   # Then try API
    if WayLink[tag].origiaurl ~ "[%]25":
      sed("Step 6.8.4.0: Remove double encoding via queryapiget", Debug.network)
      tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  # Try again with altered url
      if isarchiveorg(tup.url) and not dummydate(tup.url):
        if runStatus(tup, "A6.8.4.1", tag):                     # Log files: 6.8.4->6 or 6.8.4.1->6.8.4.3
          return true

    return false

#
# Try remove trailing garbage characters
#
proc waytree_trailgarb(tag: int): bool {.discardable} =

    var
      url = WayLink[tag].origiaurl
      tup: tuple[url: string, status: int, response: int]

    sed("Step 6.7: Try remove trailing garbage characters", Debug.network)

   # http://buck.com/stuff.htlm.
    if WayLink[tag].origiaurl ~ "(?i)([.]|[,]|[-]|[:]|[;]|[´])$":
      sub("(?i)([.]|[,]|[-]|[:]|[;]|[´])$", "", url)
      sed("Step 6.7.1.0: Remove trailing single-char queryapiget", Debug.network)
      tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  # Try again with altered url
      if isarchiveorg(tup.url) and not dummydate(tup.url):   
        return runStatus(tup, "A6.7.1.1", tag)                 # Log files: 6.7.1->3 or 6.7.1.1->6.7.1.3

   # http://buck.com/stuff.htlm''stuff
    elif WayLink[tag].origiaurl ~ "(?i)([']['])":
      awk.match(url, "(?i)([']['][^$]*$)", WayLink[tag].fragment)
      sub("(?i)([']['][^$]*$)", "", url)
      sed("Step 6.7.4.0: Remove double-quote queryapiget", Debug.network)
      tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  # Try again with altered url
      if isarchiveorg(tup.url) and not dummydate(tup.url):
        return runStatus(tup, "A6.7.4.1", tag)                 # Log files: 6.7.4->6 or 6.7.4.1->6.7.4.3

   # http://buck.com/stuff.htlm"stuff
    elif WayLink[tag].origiaurl ~ "(?i)(\")":
      awk.match(url, "(?i)(\"[^$]*$)", WayLink[tag].fragment)
      sub("(?i)(\"[^$]*$)", "", url)
      sed("Step 6.7.7.0: Remove single-quote queryapiget", Debug.network)
      tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  # Try again with altered url
      if isarchiveorg(tup.url) and not dummydate(tup.url):
        return runStatus(tup, "A6.7.7.1", tag)                 # Log files: 6.7.7->9 or 6.7.7.1->6.7.7.3

   # http://buck.com/stuff.htlm%5B
    elif WayLink[tag].origiaurl ~ "(?i)([%][a-z0-9][a-z0-9]$)":
      if url ~ "[%]22$" and countsubstring(url, "%22") > 1:  # skip if trailing is "%22" (") and URL contains other %22
        return false
      if url ~ "[%]29$" and countsubstring(url, "%28") > 1:  # skip if trailing is "%29" ()) and URL contains %28 (()
        return false
      if url ~ "(?i)([%]5D)$" and countsubstring(tolowerAscii(url), "%5b") > 1:  # skip if trailing is "%5D" (]) and URL contains %5B ([)
        return false
      if url ~ "(?i)([%]7D)$" and countsubstring(tolowerAscii(url), "%7b") > 1:  # skip if trailing is "%7D" (}) and URL contains %7B ({)
        return false
      sub("(?i)([%][a-z0-9][a-z0-9]$)", "", url)
      sed("Step 6.7.10.0: Remove trailing percent char queryapiget", Debug.network)
      tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  # Try again with altered url
      if isarchiveorg(tup.url) and not dummydate(tup.url):
        return runStatus(tup, "A6.7.10.1", tag)                # Log files: 6.7.10->12 or 6.7.10.1->6.7.10.3

   # http://buck.com/stuff.pdfl
    elif WayLink[tag].origiaurl ~ "(?i)(pdfl|htmll)$":
      if url ~ "(?i)(pdfl)$":
        sub("(?i)(pdfl)$", "pdf", url)
      elif url ~ "(?i)(htmll)$":
        sub("(?i)(htmll)$", "html", url)
      sed("Step 6.7.13.0: Remove trailing letter", Debug.network)
      tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  # Try again with altered url
      if isarchiveorg(tup.url) and not dummydate(tup.url):
        return runStatus(tup, "A6.7.13.1", tag)                # Log files: 6.7.13->16 or 6.7.13.1->6.7.13.3

    return false

#
# Try 1970 timestamp
#
proc waytree_1970(tag: int): bool {.discardable} =

    var
      tup: tuple[url: string, status: int, response: int]

    sed("Step A1.3.2.0: Try again with earliest date 1970101 using original URL", Debug.network)
    tup = queryapiget(WayLink[tag].origencoded, "19700101000000")  # Try again with earliest date 1970101 using original URL
    if tup.url != "none" and tup.url ~ GX.shttp and not dummydate(tup.url):
      return runStatus(tup, "A1.3.2.1", tag)                   # Log files: 1.3.2->4 or 1.3.4.1->1.3.2.3

    return false

#
# Replace any HTML encoding with percent encoding
#
proc waytree_htmldecode(tag: int): bool {.discardable} =

    var
      ourl = ""
      tup: tuple[url: string, status: int, response: int]

    sed("Step A6.9.1.0: Remove HTML encoding in URL", Debug.network)
    ourl = uriparseEncodeurl(urldecode(html2percent(wayurlurl(WayLink[tag].origiaurl))))
    tup = queryapiget(ourl, "19700101")  # Try again with HTML-stripped URL using earliest date 1970101
    if tup.url != "none" and tup.url ~ GX.shttp:
      gsubs(wayurlurl(tup.url), ourl, tup.url)
      return runStatus(tup, "A6.9.1.1", tag)

    return false

#
# URL encoding variations of &amp; and &amp%3B
#
proc waytree_amp(tag: int): bool {.discardable} =

    var
      status, response = -1  
      url = WayLink[tag].origiaurl
      path, path2, query, query2 = ""
      tup: tuple[url: string, status: int, response: int]

    sed("Step 6.6: Trying any &amp; and &amp%3B variations", Debug.network)

  # path
    if not dummydate(url):
      path = uriparseElement(url, "path")
      path2 = path
      if path ~ "(?i)(&amp;|&amp%3B)":
        sed("Step 6.6.1.0: Try convert &amp;|&amp%3B to & in URL path", Debug.network)
        gsub("(?i)(&amp;|&amp%3B)", "&", path)
        gsubs(path2, path, url)
        if urltimestamp_wayback(url) ~ "000000": 
          tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  
        else:
          (status, response) = webpagestatus(url, "404")
          tup = (url: url, status: status, response: response)
        if runStatus(tup, "A6.6.1.1", tag):                    # Log files: 6.6.1->3 or 6.6.1.1->6.6.1.3
          return true

  # query
    url = WayLink[tag].origiaurl
    if not dummydate(url):
      query = uriparseElement(url, "query")
      query2 = query
      if query ~ "(?i)(&amp;|&amp%3B)":
        sed("Step 6.6.4.0: Try convert &amp;|&amp%3B to & in URL query", Debug.network)
        gsub("(?i)(&amp;|&amp%3B)", "&", query)
        gsubs(query2, query, url)
        if urltimestamp_wayback(url) ~ "000000": 
          tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  
        else:
          (status, response) = webpagestatus(url, "404")
          tup = (url: url, status: status, response: response)
        if runStatus(tup, "A6.6.4.1", tag):                    # Log files: 6.6.4->6 or 6.6.4.1->6.6.4.3
          return true

  # path+query
    url = WayLink[tag].origiaurl
    if not dummydate(url):
      path = uriparseElement(url, "path")
      path2 = path
      query = uriparseElement(url, "query")
      query2 = query
      if path ~ "(?i)(&amp;|&amp%3B)" and query ~ "(?i)(&amp;|&amp%3B)":
        sed("Step 6.6.7.0: Try convert &amp;|&amp%3B to & in URL path+query", Debug.network)
        gsub("(?i)(&amp;|&amp%3B)", "&", path)
        gsub("(?i)(&amp;|&amp%3B)", "&", query)
        gsubs(path2, path, url)
        gsubs(query2, query, url)
        if urltimestamp_wayback(url) ~ "000000": 
          tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  
        else:
          (status, response) = webpagestatus(url, "404")
          tup = (url: url, status: status, response: response)
        if runStatus(tup, "A6.6.7.1", tag):                    # Log files: 6.6.7->9 or 6.6.7.1->6.6.7.3
          return true

    return false

#
# Variations of %20 and + 
#
proc waytree_plus(tag: int): bool {.discardable} =

    var
      status, response = -1  
      url, path, path2, query, query2 = ""
      tup: tuple[url: string, status: int, response: int]

    sed("Step 6.5: Trying any %20 and + variations", Debug.network)

  # %20 to + in path
    url = WayLink[tag].origiaurl
    if not dummydate(url):
      path = uriparseElement(url, "path")
      path2 = path
      if path ~ "%20":
        sed("Step 6.5.1.0: Try convert %20 to + in URL path", Debug.network)
        gsub("%20", "%2B", path)
        gsubs(path2, path, url)
        if urltimestamp_wayback(url) ~ "000000": 
          tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  
        else:
          (status, response) = webpagestatus(url, "404")
          tup = (url: url, status: status, response: response)
        if runStatus(tup, "A6.5.1.1", tag):                    # Log files: 6.5.1->3 or 6.5.1.1->6.5.1.3
          return true

  # %20 to + in query
    url = WayLink[tag].origiaurl
    if not dummydate(url):
      query = uriparseElement(url, "query")
      query2 = query
      if query ~ "%20":
        sed("Step 6.5.4.0: Try convert %20 to + in URL query", Debug.network)
        gsub("%20", "%2B", query)
        gsubs(query2, query, url)
        if urltimestamp_wayback(url) ~ "000000": 
          tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  
        else:
          (status, response) = webpagestatus(url, "404")
          tup = (url: url, status: status, response: response)
        if runStatus(tup, "A6.5.4.1", tag):                    # Log files: 6.5.4->7 or 6.5.4.1->6.5.4.3
          return true

  # %20 to + in path and query
    url = WayLink[tag].origiaurl
    if not dummydate(url):
      path = uriparseElement(url, "path")
      path2 = path
      query = uriparseElement(url, "query")
      query2 = query
      if path ~ "%20" and query ~ "%20":
        sed("Step 6.5.7.0: Try convert %20 to + in URL path and query", Debug.network)
        gsub("%20", "%2B", query)
        gsub("%20", "%2B", path)
        gsubs(query2, query, url)
        gsubs(path2, path, url)
        if urltimestamp_wayback(url) ~ "000000": 
          tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  
        else:
          (status, response) = webpagestatus(url, "404")
          tup = (url: url, status: status, response: response)
        if runStatus(tup, "A6.5.7.1", tag):                   # Log files: 6.5.7->9 or 6.5.7.1->6.5.7.3
          return true

  # + to %20 in path
    url = WayLink[tag].origiaurl
    if not dummydate(url):
      path = uriparseElement(url, "path")
      path2 = path
      if path ~ "[+]|%2[Bb]":
        sed("Step 6.5.10.0: Try convert + to %20 in URL path", Debug.network)
        gsub("[+]|%2[Bb]", "%20", path)
        gsubs(path2, path, url)
        if urltimestamp_wayback(url) ~ "000000": 
          tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  
        else:
          (status, response) = webpagestatus(url, "404")
          tup = (url: url, status: status, response: response)
        if runStatus(tup, "A6.5.10.1", tag):                  # Log files: 6.5.10->12 or 6.5.10.1->6.5.10.3
          return true

  # + to %20 in query
    url = WayLink[tag].origiaurl
    if not dummydate(url):
      query = uriparseElement(url, "query")
      query2 = query
      if query ~ "[+]|%2[Bb]":
        sed("Step 6.5.13.0: Try convert + to %20 in URL query", Debug.network)
        gsub("[+]|%2[Bb]", "%20", query)
        gsubs(query2, query, url)
        if urltimestamp_wayback(url) ~ "000000": 
          tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  
        else:
          (status, response) = webpagestatus(url, "404")
          tup = (url: url, status: status, response: response)
        if runStatus(tup, "A6.5.13.1", tag):                  # Log files: 6.5.13->15 or 6.5.13.1->6.5.13.3
          return true

  # + to %20 in path and query
    url = WayLink[tag].origiaurl
    if not dummydate(url):
      path = uriparseElement(url, "path")
      path2 = path
      query = uriparseElement(url, "query")
      query2 = query
      if path ~ "[+]|%2[Bb]" and query ~ "[+]|%2[Bb]":
        sed("Step 6.5.16.0: Try convert + to %20 in URL path and query", Debug.network)
        gsub("[+]|%2[Bb]", "%20", path)
        gsub("[+]|%2[Bb]", "%20", query)
        gsubs(path2, path, url)
        gsubs(query2, query, url)
        if urltimestamp_wayback(url) ~ "000000": 
          tup = queryapiget(wayurlurl(url), urltimestamp_wayback(url))  
        else:
          (status, response) = webpagestatus(url, "404")
          tup = (url: url, status: status, response: response)
        if runStatus(tup, "A6.5.16.1", tag):                 # Log files: 6.5.16->18 or 6.5.16.1->6.5.16.3
          return true

    return false


#
# bogusapi - it failed API but webpagestatus is OK
#
#  if redir is true, allow for 301 pages of unknown status
#
proc bogusapi(tag, apicount: int, redir: bool): bool {.discardable} =

        var
          url = ""
          status, response, responseA, responseB = -1

       # 1899 dates sometimes fail the API, try again using 1970 after a pause to give the API time to load cache from first request
        if WayLink[tag].status ~ "^404$|^0$" and dummydate(WayLink[tag].origiaurl, "1899"):                
          sed("Pausing 30 seconds (1)..", Debug.network)
          if not Debug.network: 
            libutils.sleep(30)
          (url,status,response) = queryapiget(WayLink[tag].origencoded, "19700101000000") 
          if url != "none" and url ~ GX.shttp:
            sed("Step A8.0: 1899->1970 verified.", Debug.network)
            sed("Pausing 30 seconds (2)..", Debug.network)               # Tickle the page and wait.. often helps
            if not Debug.network: 
              libutils.sleep(30)
            (status, response) = webpagestatus(url)
            sed("Pausing 30 seconds (3)..", Debug.network)
            if not Debug.network: 
              libutils.sleep(30)            
            (status, response) = webpagestatus(url)
            if status == 1:                                     
              sed("Step A8.1: FOUND. 1899->1970 headers verify 200", Debug.network)
              fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, response, "Step A8.1: FOUND. 1899->1970 headers verify 200")
            elif status == 3 and redir:                               # (soft 404? working?)
              sed("Step A8.2: FOUND. 1899->1970.. 302 to a working page of unknown status", Debug.network)
              fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, response, "Step A8.2: FOUND. 1899->1970.. 302 to a working page of unknown status")
            elif status == 0 and Runme.robots and response == 4031 and not dummydate(WayLink[tag].origiaurl, "189908"):   # Keep link if blocked by robots and Runme.robots = true
              sed("Step A8.3: FOUND. 1899->1970.. robots.txt but keeping it.", Debug.network)
              fillway(tag, "200", "wayback", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl, response, "Step A8.3: FOUND. 1899->1970.. robots.txt but keeping it.")
              sendlog(Project.robotstxt, CL.name, validiaurl(url) & " ---- A8.3")  # send a second copy in case first isnt 1899 so that it gets processed by verifyiats()  
            elif status == 5:
              sed("Step A8.4: 503 SERVERS DOWN.", Debug.network)
              sendlog(Project.critical, CL.name, " 503_servers_down 8.4 ----" & WayLink[tag].origencoded)
              return false
            else:               
              sed("Step A8.5: NOT FOUND. Page headers verified *not* 200", Debug.network)
              fillway(tag, "0", "false", "none", "none", response, "Step A8.5: NOT FOUND. Page headers verified *not* 200")
          else:                                                                      # The API fails but 1970 page is a redirect which is a robots, bummer etc..
            sed("Step A8.6: 1899->1970 failed API check, but checking body for robots, bummer etc.. ", Debug.network)
            if dummydate(url, "189907"):
              url = replace(WayLink[tag].origiaurl, "18990101070101", "19700101000000")
            elif dummydate(url, "189908"):
              url = replace(WayLink[tag].origiaurl, "18990101080101", "19700101000000")
            (status, response) = webpagestatus(url)
            # If header contains a Location: to a robots, bummer or redirect page
            if (status == 0 and response == 3021) or (status == 1 and response == 200) or (status == 1 and response == 2001) or (status == 0 and Runme.robots and response == 4031) or status == 3:  
              sed("Step A8.7: 1899->1970 getting header again.. ", Debug.network)
              var head = gethead(url, "one")
              var dest = headerlocation(head)
              if validate_datestamp(dest):
                url = replace(url, "19700101000000", dest)
                if (status == 1 and response == 200):
                  sed("Step A8.8: FOUND. 1899->1970 redirect verify 200", Debug.network)
                  fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, response, "Step A8.8: FOUND. 1899->1970 redirect verify 200")
                  sendlog(Project.waydeep, CL.name, " Step A8.8 ---- " & url) 
                elif (status == 1 and response == 2001):
                  sed("Step A8.9: FOUND. 1899->1970 bummer header redirect verify 200", Debug.network)
                  fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, response, "Step A8.9: FOUND. 1899->1970 bummer header redirect verify 200")
                  sendlog(Project.waydeep, CL.name, " Step A8.9 ---- " & url) 
                elif (status == 0 and Runme.robots and response == 4031 and not dummydate(url, "189908")):
                  sed("Step A8.10: FOUND. 1899->1970.. robots.txt but keeping it.", Debug.network)
                  fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, response, "Step A8.10: FOUND. 1899->1970.. robots.txt but keeping it.")
                  sendlog(Project.robotstxt, CL.name, url & " ---- A8.10")  # send a second copy in case first isnt 1899 so that it gets processed by verifyiats()  
                  sendlog(Project.waydeep, CL.name, " Step A8.10 ---- " & url) 
                elif (status == 0 and response == 3021 and redir):
                  sed("Step A8.11: FOUND. 1899->1970.. double redirect.", Debug.network)
                  fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, response, "Step A8.11: FOUND. 1899->1970.. double redirect..")
                  sendlog(Project.waydeep, CL.name, " Step A8.11 ---- " & url) 
                elif status == 3 and redir:
                  sed("Step A8.12: FOUND. 1899->1970.. 302 to a working page of unknown status", Debug.network)
                  fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, response, "Step A8.12: FOUND. 1899->1970.. 302 to a working page of unknown status")
                  sendlog(Project.waydeep, CL.name, " Step A8.12 ---- " & url) 
              else:
                if head ~ "RobotAccessControlException[:][ ]{0,}Blocked By Robots" and Runme.robots and not dummydate(url, "189908"):
                  sed("Step A8.13: FOUND. 1899->1970.. robots.txt but keeping it.", Debug.network)
                  fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, response, "Step A8.13: FOUND. 1899->1970.. robots.txt but keeping it.")
                  sendlog(Project.robotstxt, CL.name, url & " ---- A8.13")  # send a second copy in case first isnt 1899 so that it gets processed by verifyiats()  
                  sendlog(Project.waydeep, CL.name, " Step A8.13 ---- " & url)                
                else: 
                  sed("Step A8.14: NOT FOUND. Page bummer header redirect not found.", Debug.network)
                  fillway(tag, "0", "false", "none", "none", response, "Step A8.14: NOT FOUND. Page bummer header redirect not found.")
                  sendlog(Project.waydeep, CL.name, " Step A8.14 ---- " & url)                
            elif status == 5:
              sed("Step A8.15: 503 SERVERS DOWN.", Debug.network)
              sendlog(Project.critical, CL.name, " 503_servers_down 8.15 ----" & WayLink[tag].origencoded)
              return false
            else:               
              sed("Step A8.16: NOT FOUND. Page headers verified *not* 200", Debug.network)
              fillway(tag, "0", "false", "none", "none", response, "Step A8.16: NOT FOUND. Page headers verified *not* 200")
          
       # API says not available, use webpagestatus() to verify
       # Don't run on imp "Add" since the URL is probably bogus anyway. "france" is same as add
       #  elif WayLink[tag].status ~ "^404$|^0$" and WayLink[tag].origiaurl != "none" and GX.imp != "Add" and (not empty(GX.imp) and CL.project !~ "france"):  
        elif WayLink[tag].status ~ "^404$|^0$" and WayLink[tag].origiaurl != "none" and GX.imp != "Add":  
          sed("Step 2: Verified origiaurl is not none.", Debug.network)
          (status, responseA) = webpagestatus(WayLink[tag].origiaurl, "404")   
          if status == 1:                                          # Page headers verify as 200
            sed("Step A3: FOUND. Page headers verify as 200", Debug.network)
            if tag <= apicount:
              sendlog(Project.bogusapi, CL.name, WayLink[tag].origiaurl & " A3")
            if dummydate(WayLink[tag].origiaurl, "1970"):
              sed("Step A3.2: FOUND. Page headers verify as 200 - checking 1970", Debug.network)
              var dest = headerlocation(gethead(WayLink[tag].origiaurl, "one"))
              if validate_datestamp(dest):
                var url = replace(WayLink[tag].origiaurl, "19700101000000", dest)
                (status, responseB) = webpagestatus(url)
                if status == 1 and not wayback_soft404(url):
                  fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, responseB, "Step A3.2: FOUND. Page headers verify as 200 - checking 1970")
                  sendlog(Project.bogusapi, CL.name, WayLink[tag].origiaurl & " A3.2")
            elif urltimestamp_wayback(WayLink[tag].origiaurl) ~ "000000$":
              sed("Step A3.3: FOUND. Page headers verify as 200 - checking 000000 timestamp", Debug.network)
              var url = headerlocation(gethead(WayLink[tag].origiaurl, "one"), "fullurl")
              if isarchiveorg(url):
                (status, responseB) = webpagestatus(url)
                if status == 1 and not wayback_soft404(url):
                  fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, responseB, "Step A3.3: FOUND. Page headers verify as 200 - checking 000000 timestamp")
                  sendlog(Project.bogusapi, CL.name, WayLink[tag].origiaurl & " A3.3")
            else:
              fillway(tag, "200", "wayback", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl, responseA, "Step A3: FOUND. Page headers verify as 200")
          elif status == 3 and redir:                              # Page redirect 302/301 to a working page of unknown status (soft 404? working?)
            sed("Step A4: FOUND. 302 to a working page of unknown status", Debug.network)
            if tag <= apicount:
              sendlog(Project.bogusapi, CL.name, WayLink[tag].origiaurl & " A4")
            if dummydate(WayLink[tag].origiaurl, "1970"):
              sed("Step A4.2: FOUND. 302 to a working page of unknown status - checking 1970", Debug.network)
              var dest = headerlocation(gethead(WayLink[tag].origiaurl, "one"))
              if validate_datestamp(dest):
                var url = replace(WayLink[tag].origiaurl, "19700101000000", dest)
                fillway(tag, "200", "wayback", validiaurl(url), WayLink[tag].origurl, responseA, "Step A4: FOUND. 302 to a working page of unknown status (1970)")
            else:
              fillway(tag, "200", "wayback", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl, responseA, "Step A4: FOUND. 302 to a working page of unknown status")

          elif status == 0 and Runme.robots and responseA == 4031 and not dummydate(WayLink[tag].origiaurl, "189908"):   # Keep link if blocked by robots and Runme.robots = true
            sed("Step A4.2: Found robots.txt but keeping it.", Debug.network)
            sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A4.2")
            fillway(tag, "200", "wayback", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl, responseA, "Step A4.2: Found robots.txt but keeping it.")
            if dummydate(WayLink[tag].origiaurl, "189907"):
              sendlog(Project.robotstxt, CL.name, validiaurl(WayLink[tag].origiaurl) & " ---- A4.2")  # send a second copy in case first isnt 1899 so that it gets processed by verifyiats()  
          elif status == 0 and not Runme.robots and responseA == 4031:                  # skip-down tree to the next if-then loop
            fillway(tag, "4031", "false", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl, 4031, "Step A4.3: Found robots.txt")
            sendlog(Project.robotstxt, CL.name, WayLink[tag].origiaurl & " ---- A4.3")                  

          elif status == 5:
            sed("Step A4.1: 503 SERVERS DOWN.", Debug.network)
            sendlog(Project.critical, CL.name, " 503_servers_down A4.1 ----" & WayLink[tag].origiaurl)
            return false

        return true

#
# Main logic loop for deciding how to discover an archive URL
#
#
proc waytree(apicount: int): bool =

    var
      url,turl,head,bodyfilename = ""
      status, response, responseA = -1

    for tag in 0..GX.id:

      if manual_soft404i(WayLink[tag].origurl):
        sed("Step ZZ: Skipping found in soft404i.bm", Debug.network)
        fillway(tag, "0", "false", "none", "none", -1, "Step ZZ: Skipping found in soft404i.bm")
        debugarray(tag, GX.datadir & "waylink.start")
        continue

      responseA = -1
      debugarray(tag, GX.datadir & "waylink.start")

      if WayLink[tag].status ~ "^2":                                      # API reports 2xx

          if WayLink[tag].newiaurl != "none":
            (status, response) = webpagestatus(WayLink[tag].newiaurl)
            if status == 1 and empty(GX.imp):               
              var ts = urltimestamp(WayLink[tag].origiaurl)     
                                                            # If newiaurl is different from origiaurl, but origiaurl is working use that.
              if ts !~ "000000$" and ts != urltimestamp(WayLink[tag].newiaurl) and validate_datestamp(ts) == true and not dummydate(ts, "1970") and WayLink[tag].dummy != "wikiwix":
                (status, response) = webpagestatus(WayLink[tag].origiaurl)
                if status == 1:
                  sed("Step A1.010: ORIG. Using original URL.", Debug.network)
                  WayLink[tag].newiaurl = WayLink[tag].origiaurl
                  WayLink[tag].response = response
                  WayLink[tag].breakpoint = "Step A1.010: ORIG. Using original URL."
                                                            # .. unless origurl has a timestamp ending in 000000 then go with newiaurl
              elif ts ~ "000000$" and ts != urltimestamp(WayLink[tag].newiaurl) and validate_datestamp(ts) == true and not dummydate(ts, "1970"):                            
                sed("Step A1.011: Using new URL. Old URL is 000000$", Debug.network)
                WayLink[tag].newiaurl = WayLink[tag].newiaurl
                WayLink[tag].response = response
                WayLink[tag].breakpoint = "Step A1.011: Using new URL. Old URL is 000000$"

              elif ts !~ "000000$" and ts != urltimestamp(WayLink[tag].newiaurl) and validate_datestamp(ts) == true and not dummydate(ts, "1970") and WayLink[tag].dummy == "wikiwix":
                sed("Step A1.012: Using new URL (redirected)", Debug.network)
                WayLink[tag].newiaurl = WayLink[tag].newiaurl
                WayLink[tag].response = response
                WayLink[tag].breakpoint = "Step A1.012: Using new URL (redirected)"

                                                            # Correct result most of the time
              else:                                                                             
                WayLink[tag].response = response
                WayLink[tag].breakpoint = "Step A0.012: API URL verified."
            elif status == 1 and not empty(GX.imp):                 # If imp stick with newiaurl.
                WayLink[tag].response = response
                WayLink[tag].breakpoint = "Step A1.013: API URL verified."
            elif status == 4:
              turl = replace(WayLink[tag].newiaurl, "archive.org/web/", "archive.org/")         # Sometimes need to remove "/web/" from URL for it to work
              (status, response) = webpagestatus(turl)
              if status == 1:
                sed("Step A1.02: ORIG. Using original URL after /web/ removal.", Debug.network)
                sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A1.02")
                WayLink[tag].newiaurl = turl
                WayLink[tag].formated = WayLink[tag].newiaurl
                WayLink[tag].response = response
                WayLink[tag].breakpoint = "Step A1.02: ORIG. Using original URL after /web/ removal."
              else:                                                                             # Sometimes need to remove "%0D" (CR) for it to work
                                                                                                # https://web.archive.org/19960512183908/http://www.mtv.com:80%0D/
                turl = replace(WayLink[tag].newiaurl, "%0D", "")
                (status, response) = webpagestatus(turl)
                if status == 1:
                  sed("Step A1.03: ORIG. Using original URL after %0D removal.", Debug.network)
                  sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A1.03")
                  WayLink[tag].newiaurl = turl
                  WayLink[tag].formated = WayLink[tag].newiaurl
                  WayLink[tag].response = response
                  WayLink[tag].breakpoint = "Step A1.03: ORIG. Using original URL after %0D removal."
                else:
                  turl = replace(WayLink[tag].newiaurl, "%0D%0A", "")
                  (status, response) = webpagestatus(turl)
                  if status == 1:
                    sed("Step A1.04: ORIG. Using original URL after %0D%0A removal.", Debug.network)
                    sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A1.04")
                    WayLink[tag].newiaurl = turl
                    WayLink[tag].formated = WayLink[tag].newiaurl
                    WayLink[tag].response = response
                    WayLink[tag].breakpoint = "Step A1.04: ORIG. Using original URL after %0D%0A removal."
                  else:
                    sed("Step A1.0: NOT FOUND. Page headers verified *not* 200", Debug.network)
                    sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A1.0")
                    fillway(tag, "0", "false", "none", "none", response, "Step A1.0: NOT FOUND. Page headers verified *not* 200")
            elif status == 5:
              sed("Step A1.1: 503 SERVERS DOWN.", Debug.network)
              sendlog(Project.critical, CL.name, " 503_servers_down A1.1 ----" & WayLink[tag].newiaurl)
              return false
            elif status == 0 and Runme.robots and response == 4031 and not dummydate(WayLink[tag].origiaurl, "189908"):   # Keep link if blocked by robots and Runme.robots = true
              sed("Step A1.2: Found robots.txt but keeping it.", Debug.network)
              sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A1.2")
              fillway(tag, "200", "wayback", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl, response, "Step A1.2: Found robots.txt but keeping it.")
              if dummydate(WayLink[tag].origiaurl, "189907"):
                sendlog(Project.robotstxt, CL.name, validiaurl(WayLink[tag].origiaurl) & " ---- A1.2")  # send a second copy in case first isnt 1899 so that it gets processed by verifyiats()  
            elif status == 0 and not Runme.robots and response == 4031:                  # skip-down tree to the next if-then loop
              fillway(tag, "4031", "false", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl, 4031, "Step A1.3: Found robots.txt")
              sendlog(Project.robotstxt, CL.name, WayLink[tag].origiaurl & " ---- A1.3")                  
            elif status != 1 and status != 3:                                            # Page headers *not* 200 .. sleep and try again 3 times (persistance needed)
              sed("Pausing 30 seconds (4)..", Debug.network)
              if not Debug.network: 
                libutils.sleep(30)                                                       # (Condition A1 occured in 400 of 10000 checks. Timeout etc)
              (status, response) = webpagestatus(WayLink[tag].newiaurl)
              if status == 1:
                sed("Step A1.2.0: ORIG. Using original URL.", Debug.network)
                WayLink[tag].response = response
                WayLink[tag].breakpoint = "Step A1.2.0: ORIG. Using original URL."
              if status == 5:
                sed("Step A1.2.1: 503 SERVERS DOWN.", Debug.network)
                sendlog(Project.critical, CL.name, " 503_servers_down A1.2.1 ----" & WayLink[tag].newiaurl)
                return false
              if status != 1 and status != 3:
                sed("Pausing 60 seconds (1)..", Debug.network)
                if not Debug.network: 
                  libutils.sleep(60)
                (status, response) = webpagestatus(WayLink[tag].newiaurl)               
                if status == 1: 
                  sed("Step A1.2.2: ORIG. Using original URL.", Debug.network)
                  sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A1.2.2")
                  WayLink[tag].response = response
                  WayLink[tag].breakpoint = "Step A1.2.2: ORIG. Using original URL."
                if status == 5:
                  sed("Step A1.2.2: 503 SERVERS DOWN.", Debug.network)
                  sendlog(Project.critical, CL.name, " 503_servers_down A1.2.2 ----" & WayLink[tag].newiaurl)
                  return false
                if status != 1 and status != 3:
                  sed("Pausing 60 seconds (2)..", Debug.network)
                  if not Debug.network: 
                    libutils.sleep(60)
                  (status, response) = webpagestatus(WayLink[tag].newiaurl)
                  if status == 1: 
                    sed("Step A1.2.3: ORIG. Using original URL.", Debug.network)
                    sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A1.2.3")
                    WayLink[tag].response = response
                    WayLink[tag].breakpoint = "Step A1.2.3: ORIG. Using original URL."
                  if status == 5:
                    sed("Step A1.2.3: 503 SERVERS DOWN.", Debug.network)
                    sendlog(Project.critical, CL.name, " 503_servers_down A1.2.3 ----" & WayLink[tag].newiaurl)
                    return false
                  if status != 1 and status != 3:                                                   # Try encoding newiaurl
                    var newurl = uriparseEncodeurl(WayLink[tag].newiaurl)
                    if newurl ~ "%3[Aa]": 
                      sed("Step A1.2.3.4: Attempting %3A encoding", Debug.network)
                      gsub("/http?%3[Aa]//", "/http://", newurl)    # don't encode the scheme 
                      gsub("/https?%3[Aa]//", "/https://", newurl)
                      (status, response) = webpagestatus(newurl)
                    else:
                      status = 0
                    if status == 1: 
                      sed("Step A1.2.3.4: ORIG. Using original URL encoded.", Debug.network)
                      sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " Step A1.2.3.4: FOUND: Using original URL encoded.")
                      WayLink[tag].response = response
                      WayLink[tag].breakpoint = "Step A1.2.3.4: FOUND: Using original URL encoded."
                      # WayLink[tag].newiaurl = WayLink[tag].origiaurl
                      WayLink[tag].newiaurl = newurl
                    else:                                                                          
                      sed("Step A1.2.3.7: NOT FOUND. Page headers verified *not* 200", Debug.network)
                      sendlog(Project.bogusapi, CL.name, WayLink[tag].newiaurl & " A1")
                      fillway(tag, "0", "false", "none", "none", response, "Step A1.2.3.7: NOT FOUND. Page headers verified *not* 200")
          else:
            sed("Step A2: NOT FOUND. Unknown.", Debug.network)
            fillway(tag, "0", "false", "none", "none", -1, "Step A2: NOT FOUND. Unknown.")

     # This should be "if" not "elif" so when above loop fails (status = 0) it falls into here       
     # API says not available, webpagestatus() to verify 
      if WayLink[tag].status ~ "^404$|^0$":                         

        sed("Step 1: API reports 404 or missing", Debug.network)

       # API says not available, use webpagestatus() to verify but don't follow redirects
       # don't do for IMP
        if not bogusapi(tag, apicount, false):
          return false

       # Replace + with %20 or %20 with +
        if WayLink[tag].status !~ "^2" and WayLink[tag].origiaurl ~ "%20|[+]|%2[Bb]":
          waytree_plus(tag)

       # Replace HTML encoding with percent encoding
        if WayLink[tag].status !~ "^2" and html2percent(WayLink[tag].origiaurl) != WayLink[tag].origiaurl:
          waytree_htmldecode(tag)

       # Encoding variations of &amp; and &amp%3B
        if WayLink[tag].status !~ "^2" and WayLink[tag].origiaurl ~ "(?i)(&amp;|&amp%3b)":
          waytree_amp(tag)

       # Trailing garbage characters
        if WayLink[tag].status !~ "^2":
          waytree_trailgarb(tag)

       # Double encoding 
        if WayLink[tag].status !~ "^2" and WayLink[tag].origiaurl ~ "[%]25":
          waytree_x2encoding(tag)

     # Try alt archives 
      var doalt = false
      # More aggresive alt-archive
      if GX.imp == "Add" or dummydate(WayLink[tag].origiaurl):
        if WayLink[tag].status ~ "^404$|^4031$|^0$" or WayLink[tag].breakpoint ~ "[ ]A[348]{1}":  # if A3, A4 or A8
          doalt = true
      # Less aggressive avoid changing pre-existing archives
      else:
        if WayLink[tag].status ~ "^404$|^4031$|^0$":
          doalt = true
      if doalt:
        sed("Step 5: Try alt archives via Memento API", Debug.network)
        if api_memento(WayLink[tag].origencoded, WayLink[tag].origdate, tag) == "OK":
          (status, response) = webpagestatus(WayLink[tag].altarchencoded, "404")
          if status == 1:
            sed("Step 5.1.0: FOUND. Alt archive", Debug.network)
            fillway(tag, "200", "altarch", "", "", response, "Step A7.1.0: FOUND. Alt archive")
          elif status == 3:
            sed("Step 5.1.2: FOUND. Alt archive redirect", Debug.network)
            fillway(tag, "200", "altarch", "", "", response, "Step A7.1.1: FOUND. Alt archive redirect")
            sendlog(Project.syslog, CL.name, WayLink[tag].altarchencoded & " ---- Step A7.1.1: FOUND. Alt archive redirect")
          else:
            (status, response) = webpagestatus(WayLink[tag].altarch, "404")
            if status == 1:
              sed("Step 5.2.0: FOUND. Alt archive unencoded", Debug.network)
              fillway(tag, "200", "altarchunencoded", "", "", response, "Step A7.2.0: FOUND. Alt archive unencoded")
            elif status == 3:
              sed("Step 5.2.1: FOUND. Alt archive unencoded redirect", Debug.network)
              fillway(tag, "200", "altarchunencoded", "", "", response, "Step A7.2.1: FOUND. Alt archive unencoded redirect")
              sendlog(Project.syslog, CL.name, WayLink[tag].altarch & " ---- Step A7.2.1: FOUND. Alt archive unencoded redirect")

      if WayLink[tag].status ~ "^404$|^0$":                         

       # API says not available, use webpagestatus() to verify and follow redirects
        if not bogusapi(tag, apicount, true):
          return false

       # Check 1970 snapshot
        if WayLink[tag].status !~ "^2":
          waytree_1970(tag)

      #  -- DONE CHECKING --

      # save local copy of webpage so it can later be checked for soft404 manually
      if WayLink[tag].status ~ "^2" and WayLink[tag].available ~ "^altarch":
        if WayLink[tag].available ~ "^altarchunencoded$":
          url = WayLink[tag].altarch
        elif WayLink[tag].available ~ "^altarch$":
          url = WayLink[tag].altarchencoded
        
       # create local cache of webpage, generate a uniq ID and log "newaltarchinx" with location
        if not empty(url) and Runme.newaltarchinx:
          (head, bodyfilename) = getheadbody(url, "one")
          if existsFile(bodyfilename):                             # create a uniq ID - tested-safe on 1 million tries no duplicates
            var htmlfile = parentDir(bodyfilename) & "/" & gsubs(".", "", $(epochTime() + (cpuTime() * 10000000))) & ".html"
            moveFile(bodyfilename, htmlfile)
            sed(CL.name & " ---- " & htmlfile & " ---- " & url & " ---- waytree1", Debug.network)
            sendlog(Project.newaltarchinx, CL.name, htmlfile & "----" & url & " ---- waytree1")
          
     # If all else fails, it's a robots.txt block and not dummy date, then treat as a 200 (ie don't delete the link)
      if WayLink[tag].status ~ "^4031$" and not dummydate(WayLink[tag].origiaurl):

        sed("Step A7.2: Found robots.txt but keeping it anyway.", Debug.network)

        #if dummydate(validiaurl(WayLink[tag].origiaurl)) and WayLink[tag].altarch ~ GX.shttp:
        #  fillway(tag, "200", "altarch", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl, responseA, "Step A7.2.1: Found robots.txt but using altarch instead due to 1970|1899.")
        #elif dummydate(validiaurl(WayLink[tag].origiaurl)):
        #  var newurl = WayLink[tag].origiaurl
        #  gsub("19700101000000|18990101070101", "20161230000000", newurl)
        #  fillway(tag, "200", "wayback", newurl, WayLink[tag].origurl, 4031, "Step A7.2.3: Found robots.txt and using 20161230 instead of 1970/1899.")            
        #else:
        fillway(tag, "200", "wayback", validiaurl(WayLink[tag].origiaurl), WayLink[tag].origurl, 4031, "Step A7.2.2: Found robots.txt but keeping it anyway.")
        #if dummydate(WayLink[tag].origiaurl, "189907"):
        #    sendlog(Project.robotstxt, CL.name, validiaurl(WayLink[tag].origiaurl) & " ---- A7.2.2")  # send a second copy in case first isnt 1899 so that it gets processed by verifyiats()  

      if Debug.api: debugarray(tag, "/dev/stderr")           # optionaly print to screen
      debugarray(tag, GX.datadir & "waylink.end")               # always to file

    return true


