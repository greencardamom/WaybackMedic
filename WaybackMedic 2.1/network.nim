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

# Procs that need to be defined ahead of others due to interdependency problems

#
# print string > stderr - useful for permanant debugging
#
proc sed*(s: string, d: bool): bool {.discardable} =

  if d:
    s >* "/dev/stderr"

  if s !~ "^[>]":
    s >> GX.datadir & "apilog"

#
# Returns a unique temporary name.
#  example: mktemp("/home/wgetbody.") -> /home/wgetbody.rzMKkkNz         
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
      name[i] = CHARSET[rand(CHARSET.len-1)]

  inc(GX.tempname)
  result = prefix & name & "." & $GX.tempname


#
# Header response code (200 is OK, 403 is permission denied etc..)         
#  Returns the last code listed eg. 301->301->404->200 will return 200
#  Return the code, otherwise -1
#
proc headerresponse(head: string): int =

  var cache = newSeq[int](0)
  var c, d, le: int

  c = awk.split(head, a, "\n")
  for i in 0..c - 1:                      
    if a[i] ~ "^[ ]{0,5}[Hh][Tt][Tt][Pp]/1[.][0-9]":
      a[i] = strip(a[i])
      if awk.split(a[i], b, " ") > 1:           
        d = parseInt(strip(b[1]))
        if d > 1:        
          cache.add(d)
 
  le = len(cache)
  if le > 0:
    if cache[le - 1] > 0:  # Get the last HTTP response
      return cache[le - 1]
  return -1

#
# By-pass anti-bot software Cloudflare used by archive.is on occasion
#
proc getCloudflare*(url: string): tuple[h:string, b:string] =

  var
    url = url
    body, head, command = ""
    errC = 0

  if url ~ GX.shttp:                              # cloudflare.py can't do ssl 
    gsub(GX.shttp, "http", url)

  command = "timeout 5m ./cloudflare.py content " & shquote(url)

  sed("Starting Cloudflare for " & url, Debug.network)
  sed(command, Debug.network)

  (body, errC) = execCmdEx(command)

  if errC == 124: 
    (body, errC) = execCmdEx(command)

  sed("Ending Cloudflare", Debug.network)

  if body ~ "(?i)(DDoS protection by Cloudflare)" or empty(body):
    body = ""
    head = "HTTP/1.1 503 Service Temporarily Unavailable"  
    sendlog(Project.syslog, CL.name, " Cloudflare DDOS protection. Unable to get by it.")
  else:
    head = "HTTP/1.1 200 OK"

  return (head, body)

#
# Get body using lynx
#  flag = "dump_inline" = lynx --dump --list_inline
#  flag = "dump"        = lynx --dump 
#
proc getbodylynx*(url, flag: string): string =

  var
    url = url
    body, command = ""
    errC = 0

  if url ~ GX.shttp:                              # lynx can't do ssl 
    gsub(GX.shttp, "http", url)

  if flag == "dump_inline":
    command = "timeout 5m lynx " & GX.agentlynx & " --dump --list_online " & shquote(url)   
  elif flag == "dump":
    command = "timeout 5m lynx " & GX.agentlynx & " --dump " & shquote(url)   
  else:
    return ""

  sed("Starting Lynx body (" & flag & ") for " & url, Debug.network)
  sed(command, Debug.network)

  (body, errC) = execCmdEx(command)

  if errC == 124: 
    (body, errC) = execCmdEx(command)

  sed("Ending Lynx body (" & $(len(body)) & ")", Debug.network)

  return body

#
# For sites with bot detection, Lynx sometimes works
#
proc getheadlynx*(url: string): string =

  var
    url = url
    head = ""
    errC = 0

  if GX.lynxloop > 5:
    return ""

#  if url ~ GX.shttp:                              # lynx can do ssl headers not body
#    gsub(GX.shttp, "http", url)

  let command = "timeout 5m lynx " & GX.agentlynx & " --head --source " & shquote(url)   

  sed("Starting Lynx header for " & url, Debug.network)

  (head, errC) = execCmdEx(command)

  if errC == 124 or headerresponse(head) == -1 or $headerresponse(head) ~ "^5": 
    (head, errC) = execCmdEx(command)

  sed("Ending Lynx header (" & $(len(head)) & " / " & $headerresponse(head) & ")", Debug.network)

  if headerresponse(head) == 302:                   # lynx can't follow redirects when using --head
    if match(head, "[ ]*[Ll]ocation[ ]*[:][^\n]*[^\n]", dest) > 0:
      gsub("^[ ]*[Ll]ocation[ ]*[:]","",dest)
      url = strip(dest)
      if url ~ GX.shttp:
        head = getheadlynx(url)                     # recursive call

  return head

#
# Get the header of a URL (non-API)
#  On error, head will be 0-length
#  optional second parameter can be "one" and it will only try one time instead of 3
#
proc gethead*(url: string, fl: varargs[string]): string =

  var
    url = strip(url)
    errC = 0
    j = 1
    tries = 6              
    triesSleep = 8
    responsecode: int
    head, curlhead = ""

  if url !~ "^http":  
    return ""

  if len(fl) > 0:
    if fl[0] == "one":
      tries = 1       

  if url ~ "'":
    gsub("'","%27",url)    # shell escape literal string

  # Try curl and then wget if needed
  # Use internal timeout routines, but backup with GNU timeout as they sometimes get stuck

  # -s silent
  # -L follow redirects
  # -I header only
  let curlcommand = "timeout 40s curl -4 -s -I -L '" & url & "'"
  let wgetcommand = "timeout 80s wget -SO- -q --retry-connrefused --waitretry=5 --read-timeout=2 --timeout=5 --tries=3 --no-dns-cache --no-check-certificate '" & url & "' 2>&1 >/dev/null"

  while j <= tries:

    head = ""

    sed("Starting headers (" & $(j) & ") for " & url, Debug.network)
    if Debug.wgetlog:
      curlhead = mktempname(GX.datadir & "wgethead.")

    (head, errC) = execCmdEx(curlcommand)
    responsecode = headerresponse(head)

    if errC == 124 or responsecode == -1 or responsecode == 400 or $responsecode ~ "^5": 
      (head, errC) = execCmdEx(wgetcommand)
      responsecode = headerresponse(head)

    sed("Ending headers (" & $(len(head)) & " / " & $responsecode & ")", Debug.network)
    if Debug.wgetlog:
      head >* curlhead
    if empty(head) or responsecode == -1 or errC == 124 or $responsecode ~ "^5":
      j.inc
      libutils.sleep(triesSleep)
    else:
      break

  if responsecode == 401:  # Bot detection block eg. books.google.com
    GX.lynxloop = 0
    head = getheadlynx(url)
    return head

  if responsecode == 403 and url ~ "^https[:]//web[.]archive[.]org":
    if head ~ "Blocked Site Error":
      sed("Blocked Site Error", Debug.network)
      sendlog(Project.syslog, CL.name, url & " ---- Blocked Site Error")

  if j == tries and (empty(head) or responsecode == -1 or errC == 124):
    sed("Headers time out", Debug.network)
    sendlog(Project.timeout, CL.name, getClockStr() & " ---- headers: " & url)
    head = ""

  return head


#
# Get the header and body of a URL 
#  return a tuple, with h being the header content and b the path/filename to the body content
#  On error, head and body will be 0-length
#  optional second parameter can be "one" and it will only try one time instead of tries
#
proc getheadbody*(url: string, fl: varargs[string]): tuple[h:string, b:string] =

  var
    url = strip(url)
    errC = 0
    fs: BiggestInt
    triesWG = 3                          # even-number of tries, 4 or more .. see code for splits                
    triesSleep = 2                       # seconds to sleep between each try
    head, flag, errS = ""
    command = ""

  if url !~ "^[Hh][Tt][Tt][Pp]":  
    return ("", "")

  if len(fl) > 0:
    if fl[0] == "one":
      flag = "one"
  if flag == "one":
    triesWG = 1
    
  if url ~ "'":
    gsub("'","%27",url)    # shell escape literal string

  head = gethead(url, flag)
  let bodyfile = mktempname(GX.datadir & "wgetbody.")
  if empty(head):
    "" >* bodyfile
    return (head, bodyfile)

  let
    commandWget    = "timeout 3m wget" & GX.wgetopts & "-O- -q '" & url & "' | head -c 500k > " & bodyfile
    commandWgetS   = "timeout 3m wget" & GX.wgetopts & "--content-on-error -SO- -q '" & url & "' 2>&1 > " & bodyfile

  if headerresponse(head) == 503 and head ~ "(?i)(cloudflare)":
    # bypass anti-bot dector used by archive.is
    return getCloudflare(url)  
  elif headerresponse(head) == 200:
    command = commandWget
  else:
    # content-on-error needed to see output of body during a 403/4
    command = commandWgetS

 # Skip notorious blocked sites
  if url ~ "slam[.]canoe[.]ca" and url ~ "https?[:]//web[.]archive[.]org":
    "" >* bodyfile
    head = ""
    sed("Error: wget protocol error SIGNAL 8 received (notorious)", Debug.network)
    sendlog(Project.timeout, CL.name, " wget protocol SIGNAL 8 received (notorious) ---- " & url)
    return (head, bodyfile)

  sed("Starting body for " & url, Debug.network)
  (errS, errC) = execCmdEx(command)
  sed("Ending body (" & $(getFileSize(bodyfile)) & ")", Debug.network)

  if errC != 0:
    for j in 1..triesWG:
      "" >* bodyfile
      sed("timeout.. sleeping " & $triesSleep & " and try again (" & $j & " of " & $triesWG & " ) " & url, Debug.network)
      libutils.sleep(triesSleep)
      sed("Starting body for " & url, Debug.network)
      (errS, errC) = execCmdEx(command)
      fs = getFileSize(bodyfile)
      sed("Ending body (" & $fs & ")", Debug.network)
      if (errC == 0 and fs > 256):
        break
        
    if errC != 0:
      
      #
      # wget error codes
      # https://www.gnu.org/software/wget/manual/html_node/Exit-Status.html
      #
      if errC == 124: # GNU timeout
        "" >* bodyfile
        head = ""
        sed("Error: wget + GNU timeout SIGNAL 124 received", Debug.network)
        sendlog(Project.timeout, CL.name, " wget + GNU timeout SIGNAL 124 received ---- " & url)
      elif errC == 4:
        "" >* bodyfile
        head = ""
        sed("Error: wget network failure SIGNAL 4 received", Debug.network)
        sendlog(Project.timeout, CL.name, " wget network failure SIGNAL 4 received ---- " & url)
      elif errC == 3:
        "" >* bodyfile
        head = ""
        sed("Error: wget file I/O SIGNAL 3 received", Debug.network)
        sendlog(Project.timeout, CL.name, " wget File I/O SIGNAL 3 received ---- " & url)
      elif errC == 1:
        "" >* bodyfile
        head = ""
        sed("Error: wget generic error SIGNAL 1 received", Debug.network)
        sendlog(Project.timeout, CL.name, " wget generic SIGNAL 1 received ---- " & url)
      elif errC == 2:
        "" >* bodyfile
        head = ""
        sed("Error: wget parse error SIGNAL 2 received", Debug.network)
        sendlog(Project.timeout, CL.name, " wget parse SIGNAL 2 received ---- " & url)
      elif errC == 5:
        "" >* bodyfile
        head = ""
        sed("Error: wget SSL verify error SIGNAL 5 received", Debug.network)
        sendlog(Project.timeout, CL.name, " wget SSL verify SIGNAL 5 received ---- " & url)
      elif errC == 6:
        "" >* bodyfile
        head = ""
        sed("Error: wget username/pass error SIGNAL 6 received", Debug.network)
        sendlog(Project.timeout, CL.name, " wget username/pass SIGNAL 6 received ---- " & url)
      elif errC == 7:
        "" >* bodyfile
        head = ""
        sed("Error: wget protocol error SIGNAL 7 received", Debug.network)
        sendlog(Project.timeout, CL.name, " wget protocol SIGNAL 7 received ---- " & url)
      elif errC == 8:
        "" >* bodyfile
        head = ""
        sed("Error: wget protocol error SIGNAL 8 received", Debug.network)
        sendlog(Project.timeout, CL.name, " wget protocol SIGNAL 8 received ---- " & url)
      else:
        "" >* bodyfile
        head = ""
        sed("Error: wget protocol error UNKNOWN (" & $errC & ") received", Debug.network)
        sendlog(Project.timeout, CL.name, " wget protocol error UNKNOWN (" & $errC & ") received ---- " & url)

  return (head, bodyfile)

