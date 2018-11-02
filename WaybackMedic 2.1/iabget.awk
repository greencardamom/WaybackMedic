#!/usr/local/bin/awk -bE

# The MIT License (MIT)
#
# Copyright (c) 2017-2018 by User:GreenC (at en.wikipedia.org)
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

@load "filefuncs"

BEGIN {



 # SETUP BEGIN

  # External programs. Add full path if running from cron or within other programs

  Exe["timeout"] = "/usr/bin/timeout"
  Exe["wget"] = "/usr/bin/wget"
  Exe["jq"] = "/usr/bin/jq"
  Exe["rm"] = "/bin/rm"
  Exe["awk"] = "/usr/local/bin/awk"
  Exe["php"] = "/usr/bin/php"

  # If you want a bell sound ('play' can be installed as 'sudo apt-get install sox' - chord.wav is from Windows)

  Exe["bell"] = "/usr/bin/play -q /home/adminuser/scripts/chord.wav"

  # Default wiki language

  lang = "en"

  # Turn on/off debugging (1 = on)

  debug = 0

  # Setup OAuth Secrets and Keys 
  #
  #  Login to https://meta.wikimedia.org with the userid the script will be using
  #  If the userid is new and doesn't have Confirmed user permissions, apply for it in two places:
  #    enwiki: Wikipedia:Requests for permissions/Confirmed 
  #    meta  : https://meta.wikimedia.org/wiki/Steward_requests/Miscellaneous
  #  Apply for a OAuth consumer owner-only registration:
  #    https://meta.wikimedia.org/wiki/Special:OAuthConsumerRegistration/propose
  #     . Check the box "This consumer is for use only by.."
  #     . IP Ranges and Public RSA Key should be left empty 
  #  Add the provided Keys and Secrets below

  consumerKey = ""
  consumerSecret = ""
  accessKey = ""
  accessSecret = ""

  # String included with http requests shows in remote logs. Include name of program and your contact info.

  Agent = "http://en.wikipedia.org/wiki/User:GreenC via iabget.awk"

  # Location of cookies

  cookiejar = "/tmp/cookiejar"

 # SETUP END


  IGNORECASE = 1
  TIMEOUT = Exe["timeout"] " 40s " 

  if(!exists(cookiejar)) 
    cookieopt = " --save-cookies=\"" cookiejar "\""
  else {
    cookieopt = " --save-cookies=\"" cookiejar "\" --load-cookies=\"" cookiejar "\""
  }

  # Default wget options (include lead/trail spaces)    

  Wget_opts = cookieopt " --ignore-length --user-agent=\"" Agent "\" --no-check-certificate --tries=5 --timeout=120 --waitretry=60 --retry-connrefused "

  # getopt() initialization

  Optind = Opterr = 1

  main()

}

function main() {

  while ((C = getopt(ARGC, ARGV, "wehd:r:a:l:p:o:k:")) != -1) {
    opts++
    if(C == "l")                                     # -l <language>       Wiki language code. Default = en 
      lang = verifyval(Optarg)
    if(C == "r")                                     # -r <offset>         Page offset number of multi-page requests
      pagenumber = verifyval(Optarg)
    if(C == "a")                                     # -a <action code>    Action to make (see API doc for names)
      action = verifyval(Optarg)   
    if(C == "p")                                     # -p <parameter>      Parameter=value string (see API doc for names)
      parameter = verifyval(Optarg)   
    if(C == "d")                                      # -d                 Turn on debugging
      debug = verifyval(Optarg)
    if(C == "e")                                      # -e                 Send error msg to stdout (default: stderr)
      stdOut = 1
    if(C == "w")                                      # -w                 Show raw JSON instead of select CSV
      rawJSON = 1
    if(C == "o")                                      # -o                 Original URL -- dummy parameter used by imp
      origurl = Optarg
    if(C == "k")                                      # -k <string>        Optional field deliminator when printing 1-line API results. Default = <space>
      Delim = Optarg                                            
    if(c == "h") {
      help()
      exit
    }
  }

  if(opts < 1) {
    print "Error: no opts"
    help()
    exit
  }
  if(empty(action)) {
    print "Error: Must specify -a option\n"
    help()
    exit
  }

  if(debug == 2)
    db = " -d "

  if(debug == 1)  # temporary disable until imp.awk is updated to not use "-d 1" in iabget file
    debug = 0

  langarg = "wiki=" lang "wiki"

  identifyURL = "https://" lang ".wikipedia.org/w/index.php?title=Special:OAuth/identify"
  iabotURL = "https://tools.wmflabs.org/iabot/api.php"

  if(! loginMediaWiki()) {
    print "Error: Unable to login to MediaWiki"
    exit
  }

  if( ! empty(pagenumber) ) {
    if(pagenumber ~ /[+]$/) {
      gsub(/[+]$/,"",pagenumber)
      pageplus = 1
    }
  }

  if(empty(Delim))
    Delim = " "

  parameter = encodeParams(parameter)

  if(action == "searchurlfrompage") 
    searchurlfrompage()
  if(action == "searchpagefromurl") 
    searchpagefromurl()
  if(action == "searchurldata") 
    searchurldata()
  if(action == "modifyurl") 
    modifyurl()
  if(action == "submitbotjob") 
    botjob(postfile)
  if(action == "getbotjob")
    getbotjob(jobid)
  if(action == "getbotqueue")
    getbotqueue()
  if(action == "logout") 
    logout()

}

function help() {

   print ""
   print " iabget - InternetArchiveBot API command-line interface\n"
   print "           -a     <action>         Action (see API doc): "
   print "                                     searchpagefromurl"                
   print "                                     searchurlfrompage"                
   print "                                     searchurldata"
   print "                                     modifyurl"
   print "                                     submitbotjob (use with -f not -p)"
   print "                                     getbotjob"
   print "                                     getbotqueue"
   print "                                     logout"
   print "           -p     <parameter>      Parameter=value string (see API doc)."
   print "                                     Separating & between paramters should be {&} to disambig from & in URLs"
   print "                                     eg. -p \"urlid=55{&}archiveurl=http://..\""
   print "           -f     <filename>       Filename containing the postdata encoded"
   print "           -r     <pagenumber>     Show results for this page number only (optional)"
   print "                                     Use a plus sign eg. -r 2+ to continue downloading until end"
   print "           -l     <language>       Wiki language code (default: en)"
   print "           -d     <level>          Turn on debugging. 1 = level1 2 = level2"
   print "           -e                      Send error msgs to stdout (default: stderr)"
   print "           -w                      Show raw JSON"
   print "           -h                      help"
   print ""
   print "  Examples:" 
   print "     iabget -a getbotqueue -p displayqueued -w"
   print "     iabget -a getbotjob -p id=200 -w"
   print "     iabget -a searchurlfrompage -p pageids=4589"
   print ""
   print " API doc: https://meta.wikimedia.org/wiki/InternetArchiveBot/API"
   print " IABot  : https://tools.wmflabs.org/iabot/index.php"
   print " GreenC : https://tools.wmflabs.org/iabot/index.php?page=metausers&username=GreenC+bot"
   print ""

}

#
# Return list of link IDs in article ID
#
#   To get article ID: https://en.wikipedia.org/w/api.php?action=query&titles=Albert%20Einstein&prop=info
#
function searchurlfrompage(  command,pn) {

  if(parameter !~ /pageids[=]/) {
    print "Error: Parameter required: pageids"
    exit
  }
  if( ! empty(pagenumber)) 
    pn = "offset=" pagenumber "&"

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote(pn "action=searchurlfrompage&" parameter "&" langarg) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)  
  jqcommand = Exe["jq"] " -r '.arguments as $ids| .urls | map([$ids.pageids, .id, .url, .normalizedurl, .live_state, .archive, .snapshottime, .accesstime] | join(\"" Delim "\")) | join(\"\\n\")' " 
  coreReader(wgetcommand, jqcommand, oheader)

}

#
# Return list of article names containing a url or urlid
#
function searchpagefromurl(  command,pn) {

  if(parameter !~ /url[=]|urlid[=]/) {
    print "Error: Parameter required: url or urlid"
    exit
  }
  if( ! empty(pagenumber)) 
    pn = "offset=" pagenumber "&"

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote(pn "action=searchpagefromurl&" parameter "&" langarg) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)  
  jqcommand = Exe["jq"] " -r '.pages [] |.page_title' | " Exe["awk"] " '{gsub(/_/,\" \", $0); print $0}'"  
  coreReader(wgetcommand, jqcommand, oheader)

}

#
# Return URL data in <space> separated CSV format: id url livestate archiveurl snapshotYMD snapshotTime accesstime
#  1 line for each record.
#
function searchurldata(  command,pn,op) {

  if(parameter !~ /urls[=]|hasarchive[=]|urlids[=]|livestate[=]|isarchived[=]|reviewed[=]/) {
    print "Error: Parameter required: urls, hasarchive, urlids, livestate, isarchived, reviewed"
    exit
  }
  if( ! empty(pagenumber)) 
    pn = "offset=" pagenumber "&"

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote(pn "action=searchurldata&" parameter "&" langarg) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)   
  jqcommand = Exe["jq"] " -r '.urls | map([.id, .url, .live_state, .archive, .snapshottime, .accesstime] | join(\"" Delim "\")) | join(\"\\n\")' " 
  coreReader(wgetcommand, jqcommand, oheader)

}

function logout(  ) {

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote("action=logout") " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)   
  coreReader(wgetcommand, "", oheader)

}

#
# Write data to IAB
#
function modifyurl(  command) {

  if(parameter !~ /urlid[=]/) {
    print "Error: Parameter required: urlid"
    exit
  }

  if( empty(Checksum) || empty(CSRF) ) 
    getTokensFresh()
  
  parameter = parameter "&token=" CSRF "&checksum=" Checksum

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote("action=modifyurl&" parameter "&" langarg) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)   
  op = getAPIpage(wgetcommand)

  if(sys2varPipe(op, Exe["jq"] " -r '. .result'") == "success") {
    if(rawJSON) print op
    return
  }
  else {
    if(rawJSON) 
      print op
    else 
      stdErrO("Error: Unable to post data.")
    return
  }
}

#
# Submit bot job
#
function botjob(postfile,  p,oheader,wgetcommand,op) {

  if( empty(postfile) ) {
    print "Error: Unknown -f postfile" 
    exit
  }
  if( ! exists(postfile) ) {
    print "Error: Unable to find postfile: " postfile
    exit
  }

  if( empty(Checksum) || empty(CSRF) ) 
    getTokensFresh()

  p = readfile(postfile)
  if(empty(strip(p))) return
  p = "action=submitbotjob{&}" langarg "{&}token=" CSRF "{&}checksum=" Checksum "{&}pagelist=" p
  p = encodeParams(p)
  gsub(/(%0A){0,}$/,"",p)                            # Remove trailing \n ie. %0A an artifact of unix files always end with \n
  printf("%s", p) > postfile ".wget"
  close(postfile ".wget")

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-file=" shquote(postfile ".wget") " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)   

  op = getAPIpage(wgetcommand)

  if(sys2varPipe(op, Exe["jq"] " -r '. .result'") == "success") {
    if(rawJSON) 
      print op
    else {
      print "success " sys2varPipe(op, Exe["jq"] " -r '. .id'")  # Print 'sucess 56878' where the number is a job ID
    }
    return
  }
  else {
    if(rawJSON) 
      print op
    else 
      stdErrO("Error: Unable to submit job.")
    return
  }
  
}

#   
# Get bot job info.                    
#
#   Returns status only unless used with -w then full json                                               
#
function getbotjob(id,  oheader,wgetcommand,jqcommand) {

  if(parameter !~ /id[=]/) {
    print "Error: Parameter required: jobid"
    exit
  }       

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote("action=getbotjob&" parameter "&" langarg) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)
  jqcommand = Exe["jq"] " -r '. .status' "
  coreReader(wgetcommand, jqcommand, oheader)

} 

#   
# Get bot job info.                    
#
#   Returns status only unless used with -w then full json                                               
#
function getbotqueue(id,  oheader,wgetcommand,jqcommand) {

  if(parameter !~ /^displayqueued|^displayrunning|^displayfinished|^displaykilled|^displaysuspended/) {
    print "Error: Unknown parameter " parameter
    exit
  }       

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote("action=getbotqueue&" parameter "&" langarg) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)
  if(parameter ~ /^displayqueued/)
    jqcommand = Exe["jq"] " -r '. .queued' "
  else if(parameter ~ /^displayrunning/)
    jqcommand = Exe["jq"] " -r '. .running' " 
  else
    jqcommand = Exe["jq"] " -r '.' "
  coreReader(wgetcommand, jqcommand, oheader)

} 

#
# Core routine to download read results, handle paging
#
function coreReader(wgetcommand, jqcommand, oheader,    op, jsonfile, orig,dest) {

  if(empty(parameter) && !empty(jqcommand) ) {
    print "Error: parameter=value string required. See docs."
    exit 
  }

 # Get the first page of results starting at pagenumber (default: 1)

  op = getAPIpage(wgetcommand)

  if(debug == 1)
    print op

  if(op ~ /The requested query didn't yield any results/) {
    stdErrO("Error: No results found.")
    exit
  }

  if(rawJSON)
    print op
  else
    print sys2varPipe(op, jqcommand)

 # Exit if it was the only page or single pagenumber request. But keep going if there is a "+" 

  if(empty(Continue) || (! empty(pagenumber) && empty(pageplus) ) ) 
    return

 # Display to stderr page number working on

  if( ! empty(pagenumber) && ! empty(pageplus) ) 
    stdErr("Offset " Continue " ", "n")
  else
    stdErr("Offset " Continue, "n") 

  delayer() # be nice on large requests

 # Get rest of pages 

  while( ! empty(Continue) ) {

   # Build proper "offset=<string>" 
    if(match(wgetcommand, /[-][-]post[-]data[=]'offset[=][^&]*[^&]/, dest)) {
      orig = dest[0]
      gsub(/offset[=][^$]*$/, "offset=" Continue, dest[0])
      wgetcommand = subs(orig, dest[0], wgetcommand)
    }
    else if(match(wgetcommand, /[-][-]post[-]data[=]'action[=]/, dest)) {
      orig = dest[0]
      wgetcommand = subs(orig, "--post-data='offset=" Continue "&action=", wgetcommand)
    }

   # Freshen header
    if(index(wgetcommand, oheader) > 0) 
      wgetcommand = freshHeader(wgetcommand)
      
    op = getAPIpage(wgetcommand)

    if(rawJSON)
      print op
    else
      print sys2varPipe(op, jqcommand)

    if(! empty(Continue) ) {
      stdErr("Offset " Continue " ", "n") 
      delayer() # be nice on 1000-record requests
    }
    else {
      stdErrO("Error: Continue code not found. End of data? See JSON " jsonfile)
      bell()
      exit
    }
  }
}


#
# Main loop to get API result
#
function getAPIpage(command,   op, i,j,k) {

  # print sys2var("date") > "/dev/stderr"

  Continue = ""
  gsub(/\\n/,"\n",command)

  if(debug == 1) {
    print "\nCOMMAND = " command
    # exit
  }

  op = sys2var("timeout 40s " freshHeader(command))

 # Try up to j times 
  j = 5
  k = j + 1
  for(i = 1; i < k; i++) {
    if(op ~ /csrf["][ ]*[:][ ]*["][^}]*[}]$/) break
    if(i == j && op !~ /csrf["][ ]*[:][ ]*["][^}]*[}]$/) {
      stdErr(op) 
      stdErrO("Error: JSON or auth problem. Aborted. ")
      bell()
      exit
    }
    stdErr(" API retry " i)

    if(! loginMediaWiki()) {
      print "Error: Unable to login to MediaWiki"
      exit
    }

    if(op !~ /csrf["][ ]*[:][ ]*["][^}]*[}]$/) {
      newcommand = "timeout 40s " freshHeader(command)
      if(debug == 1)
        print "\nCOMMAND = " newcommand
      op = sys2var( newcommand )
      op = getAPIpageTimeout(command, op, "Timeout connecting to API (" i "). Aborted.", i)
    }
  }

  Continue = getContinue(op)  
  getTokensJSON(op)

  return op

}

#
# Loop to retry if API returns blank (timeout)
#
function getAPIpageTimeout(command, op, errmsg, loc,   i, timo) {

  for(i = 2; 1 < 6 ; i++) {
    if(! empty(op)) break
    if(i == 5 && empty(strip(op)) ) {
      if(loc >= 5) {
        stdErrO("Error: " errmsg)
        bell()
        exit
      }
      else
        return ""
    }

    if(i == 3) gsub("timeout 40s", "timeout 60s", command)
    if(i == 4 && loc < 4) gsub("timeout 60s", "timeout 90s", command)
    if(i == 4 && loc >= 4) gsub("timeout 60s", "timeout 900s", command)

    match(command, /[ ][0-9]{2,3}s[ ]/, timo)

    if(empty(strip(op))) {
      sleep(1)
      stdErr("  Timeout try " (i - 1) " (API retry=" loc ", timeout=" strip(timo[0]) ")")
      command = freshTokens(freshHeader(command))
      op = sys2var(command)

      if(debug == 1) 
        print "\nCOMMAND = " command
    }
  }
  return op
}


#
# Get continue code from API JSON result
#
function getContinue(s,  dest) {

  match(s, /"continue"[ ]*[:][ ]*"[^"]*"/, dest)
  if( ! empty(dest[0]) ) {
    gsub(/^"continue"[ ]*[:][ ]*"/,"",dest[0])
    gsub(/"$/,"",dest[0])
    return strip(dest[0])
  }
  return ""
}

#
# Add a fresh header to existing wget command string
#
function freshHeader(command,  dest) {

  # --header='Authorization .. '
  if(match(command, /[']Authorization[^']*[']/, dest) > 0) {
    newhead = "'" strip(oauthHeader()) "'"
    return subs(dest[0], newhead, command)
  }
  return command
}

#
# Add fresh Checksum and CSRF to existing wget command string
#
function freshTokens(command  ,s, dest) {

 # "&token=" CSRF "&checksum=" Checksum
  if(command ~ /[&]checksum[=]/ && command ~ /[&]token[=]/) {

    getTokensFresh()

    match(command, /[&]token[=][^&']*[^&']/, dest)
    s = dest[0]
    gsub(/^[&]token[=]/, "", s)
    s = "&token=" CSRF
    command = subs(dest[0], s, command)
    
    match(command, /[&]checksum[=][^&']*[^&']/, dest)
    s = dest[0]
    gsub(/^[&]checksum[=]/, "", s)
    s = "&checksum=" Checksum
    command = subs(dest[0], s, command)    
  }
  return command

}

#
# Get Checksum and CSRF tokens with a fresh request
#
function getTokensFresh() {

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data='action=noaction&" langarg "' --header='Content-Type: application/x-www-form-urlencoded' --header='" oheader "' -q -O- '" iabotURL "'"  
  jqcommand = Exe["jq"] " -r '.arguments | map([.checksum, .csrf] | join(\" \")) | join(\"\\n\")' " 

  op = getAPIpage(wgetcommand)

  if(debug == 1)
    print op

}

#
# Get Checksum and CSRF from existing JSON 
#
function getTokensJSON(op  ,jqcommand, jsonfile) {

  jqcommand = Exe["jq"] " -r '. .checksum' "
  Checksum = sys2varPipe(op, jqcommand)
  jqcommand = Exe["jq"] " -r '. .csrf' "
  CSRF = sys2varPipe(op, jqcommand)

}

#
# Login to MediaWiki
#
function loginMediaWiki(  command, sp, payload) {

  return 1  # Skip this 

  command = TIMEOUT Exe["wget"] Wget_opts db " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(strip(oauthHeader())) " -q -O- " shquote(identifyURL) 
  if(debug) {
    print "LOGIN = " command
  }
  sp = sys2var(command)
  payload = decryptIABot(sp)
  if(debug) {
    print "PAYLOAD: " payload
  }

  if( ! empty(payload) )
    return 1
  else
    return 0  
}

#
# URL encode paramters but not the separating '&' or '=' or '\n', and only params that use string values 
#
function encodeParams(s ,c,i,fields,sep) {

  c = patsplit(s, fields, /[{][&][}]/, sep)
  if(c == 0) 
    s = encodeParamsHelper(s)
  else {
    while(i++ < c) 
      sep[i] = encodeParamsHelper(sep[i])
    if(! empty(sep[0]) ) 
      sep[0] = encodeParamsHelper(sep[0])
    s = unpatsplit(fields, sep)
  }
  s = gsubs("{&}","&",s)
  return s
}
function encodeParamsHelper(s ,j,fieldnew,a,dest) {

  j = split(s, a, "=")
  if(a[1] ~ /reason|urls|url|archiveurl|fplist|pagesearch|pagelist/) {
    if(match(s, a[1] "=", dest) > 0) {
      fieldnew = s
      fieldnew = urlencodeawk(gsubs(dest[0], "", fieldnew))
      fieldnew = gsubs("%5Cn","\n", fieldnew)
      s = dest[0] fieldnew
    }
  }
  return s
}

#
# decryptIABot - decrypt payload
#
function decryptIABot(s,   command, sp) {
  if( ! empty(s) > 0) {
    sp = MWOAuthDecodePayload(consumerSecret, s)
    if(sp ~ /Invalid identify response/)  # error by MWOAuthDecodePayload.php
      return ""
    return sp
  }
  return ""
}
#
# MWOAuthDecodePayload.php script
#
# Source: https://meta.wikimedia.org/wiki/InternetArchiveBot/API#Helper_scripts_to_make_OAuth_easier
# Credit: User:Cyberpower678 May 2017 
# Conversion to awk-php function User:GreenC May 2018
#
# Notes by CP:
#  When the /identify request is successful, it will return a payload.
#  That payload has numerous elements to decode and validate.
#  And requires your Consumer secret to validate. The tool API passes back the payload as well since it can't do the validation without the consumer secret, 
#  and that would be plain reckless to ask for. 
#  If successful, it will return a JSON with your MW account details. If it fails, it will echo back an error message instead.
#  I copied it from my OAuth engine (InternetArchiveBot)
#
function MWOAuthDecodePayload(consumerSecret,payload,   s) {

     if(empty(consumerSecret) || empty(payload))
       return ""

     s = "$argv[1] = '" consumerSecret "'; \n\
     $argv[2] = '" payload "'; \n\
     define( 'CONSUMERSECRET', $argv[1] ); \n\
     \n\
     /* There are three fields in the response */ \n\
     $fields = explode( '.', $argv[2] ); \n\
     if( count( $fields ) !== 3 ) { \n\
       $error = 'Invalid identify response: '; \n\
       goto loginerror; \n\
     } \n\
     \n \
     /* Validate the header. MWOAuth always returns alg \"HS256\". */ \n\
     $header = base64_decode( strtr( $fields[0], '-_', '+/' ), true ); \n\
     if( $header !== false ) { \n\
       $header = json_decode( $header ); \n\
     } \n\
     if( !is_object( $header ) || $header->typ !== 'JWT' || $header->alg !== 'HS256' ) { \n\
       $error = 'Invalid header in identify response: '; \n\
       goto loginerror; \n\
     } \n\
     \n\
     /* Verify the signature */ \n\
     $sig = base64_decode( strtr( $fields[2], '-_', '+/' ), true ); \n\
     $check = hash_hmac( 'sha256', $fields[0] . '.' . $fields[1], CONSUMERSECRET, true ); \n\
     if( $sig !== $check ) { \n\
       $error = 'JWT signature validation failed: '; \n\
       goto loginerror; \n\
     } \n\
     \n\
     /* Decode the payload */ \n\
     $payload = base64_decode( strtr( $fields[1], '-_', '+/' ), true ); \n\
     if( $payload !== false ) { \n\
       $payload = json_decode( $payload ); \n\
     } \n\
     if( !is_object( $payload ) ) { \n\
       $error = 'Invalid payload in identify response: '; \n\
       goto loginerror; \n\
     } \n\
     \n\
     die( json_encode( $payload ) ); \n\
     \n\
     loginerror: \n\
     die( $error );"

     return sys2var(Exe["php"] " -r " shquote(s) )
     # to view script:
     # print s
}


#
# oauthHeader - generate OAuth header
#
function oauthHeader(   sp) {
  sp = MWOAuthGenerateHeader(consumerKey,consumerSecret,accessKey,accessSecret,identifyURL)
  if(empty(sp))
    stdErr("iabget.awk oauthHeader(): unable to determine header")
  return sp
}

#
# MWOAuthGenerateHeader.php - generate OAuth header 
#  
#  Source: https://meta.wikimedia.org/wiki/InternetArchiveBot/API#Helper_scripts_to_make_OAuth_easier
#  Credit: User:Cyberpower678 May 2017 
#  Conversion to awk-php function User:GreenC May 2018
#  
#  . return empty if params not set
#  . does not support RSA keys
#  
function MWOAuthGenerateHeader(consumerKey, consumerSecret, accessKey, accessSecret, indentifyURL,   s) {

     if(empty(consumerKey) || empty(consumerSecret) || empty(accessKey) || empty(accessSecret) || empty(indentifyURL))
       return ""

     s = "\n\
     define( 'CONSUMERKEY', '" consumerKey "' ); \n\
     define( 'CONSUMERSECRET', '" consumerSecret "' ); \n\
     define( 'ACCESSTOKEN', '" accessKey "' ); \n\
     define( 'ACCESSSECRET', '" accessSecret "' ); \n\
     \n\
     echo generateOAuthHeader( 'GET', '" indentifyURL "' ); \n\
     \n\
     function generateOAuthHeader( $method = 'GET', $url ) { \n\
       $headerArr = [ \n\
         /* OAuth information */ \n\
         'oauth_consumer_key'     => CONSUMERKEY, \n\
         'oauth_token'            => ACCESSTOKEN, \n\
         'oauth_version'          => '1.0', \n\
         'oauth_nonce'            => md5( microtime() . mt_rand() ), \n\
         'oauth_timestamp'        => time(), \n\
         \n\
                /* We're using secret key signatures here. */ \n\
                'oauth_signature_method' => 'HMAC-SHA1', \n\
        ]; \n\
        $signature = generateSignature( $method, $url, $headerArr ); \n\
        $headerArr['oauth_signature'] = $signature; \n\
        \n\
        $header = []; \n\
        foreach( $headerArr as $k => $v ) { \n\
          $header[] = rawurlencode( $k ) . '=\"' . rawurlencode( $v ) . '\"'; \n\
        } \n\
        $header = 'Authorization: OAuth ' . join( ', ', $header ); \n\
        unset( $headerArr ); \n\
        \n\
        return $header; \n\
      } \n\
      \n\
      function generateSignature( $method, $url, $params = [] ) { \n\
        $parts = parse_url( $url ); \n\
        \n\
        /* We need to normalize the endpoint URL */ \n\
        $scheme = isset( $parts['scheme'] ) ? $parts['scheme'] : 'http'; \n\
        $host = isset( $parts['host'] ) ? $parts['host'] : ''; \n\
        $port = isset( $parts['port'] ) ? $parts['port'] : ( $scheme == 'https' ? '443' : '80' ); \n\
        $path = isset( $parts['path'] ) ? $parts['path'] : ''; \n\
        if( ( $scheme == 'https' && $port != '443' ) || \n\
          ( $scheme == 'http' && $port != '80' ) \n\
        ) { \n\
                /* Only include the port if it's not the default */ \n\
                $host = \"$host:$port\"; \n\
        } \n\
        \n\
        /* Also the parameters */ \n\
        $pairs = []; \n\
        parse_str( isset( $parts['query'] ) ? $parts['query'] : '', $query ); \n\
        $query += $params; \n\
        unset( $query['oauth_signature'] ); \n\
        if( $query ) { \n\
          $query = array_combine( \n\
            /* rawurlencode follows RFC 3986 since PHP 5.3 */ \n\
            array_map( 'rawurlencode', array_keys( $query ) ), \n\
            array_map( 'rawurlencode', array_values( $query ) ) \n\
          ); \n\
          ksort( $query, SORT_STRING ); \n\
          foreach( $query as $k => $v ) { \n\
            $pairs[] = \"$k=$v\"; \n\
          } \n\
        } \n\
        \n\
        $toSign = rawurlencode( strtoupper( $method ) ) . '&' . \n\
                  rawurlencode( \"$scheme://$host$path\" ) . '&' . \n\
                  rawurlencode( join( '&', $pairs ) ); \n\
        \n\
        $key = rawurlencode( CONSUMERSECRET ) . '&' . rawurlencode( ACCESSSECRET ); \n\
        \n\
        return base64_encode( hash_hmac( 'sha1', $toSign, $key, true ) ); \n\
      }"

     return sys2var(Exe["php"] " -r " shquote(s) )
     # to view script:
     # print s

}


# ________________ Utilities _________________________________________________

#
# sys2var - run a system command and store result in a variable
#
#  . supports pipes inside command string
#  . stderr is sent to null
#  . if command fails (errno) return null
#
#  Example:
#     googlepage = sys2var("wget -q -O- http://google.com")
#
function sys2var(command        ,fish, scale, ship) {

         # command = command " 2>/dev/null"
         while ( (command | getline fish) > 0 ) {
             if ( ++scale == 1 )
                 ship = fish
             else
                 ship = ship "\n" fish
         }
         close(command)
         system("")
         return ship
}

#
# sys2varPipe - supports piping data into a program eg, echo <data> | <command>
#
#   Example: replicate 'cat /etc/passwd | wc'
#      print sys2varPipe(readfile("/etc/passwd"), Exe["wc"])
#
function sys2varPipe(data, command,   fish, scale, ship) {

         print data |& command
         close(command, "to")

         while ( (command |& getline fish) > 0 ) {
             if ( ++scale == 1 )
                 ship = fish
             else
                 ship = ship "\n" fish
         }
         close(command)
         return ship
}

#
# urlencodeawk
#
#  . this will work with any character type
#           
#  Requirement: gawk -b
#  Credit: Rosetta Code May 2015
#
function urlencodeawk(str,  c, len, res, i, ord) {

        for (i = 0; i <= 255; i++)
                ord[sprintf("%c", i)] = i
        len = length(str)        
        res = ""
        for (i = 1; i <= len; i++) {
                c = substr(str, i, 1);
                if (c ~ /[0-9A-Za-z]/)
                        res = res c
                else
                        res = res "%" sprintf("%02X", ord[c])
        }                 
        return res
}

#           
# strip - strip leading/trailing whitespace 
#   
#   . faster than gsub() or gensub() methods eg.
#        gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
#        gensub(/^[[:space:]]+|[[:space:]]+$/,"","g",s)
#   
#   Credit: https://github.com/dubiousjim/awkenough by Jim Pryor 2012
#
function strip(str) {
    if (match(str, /[^ \t\n].*[^ \t\n]/))
        return substr(str, RSTART, RLENGTH)
    else if (match(str, /[^ \t\n]/))            
        return substr(str, RSTART, 1)
    else
        return ""
}

#
# empty - return 0 if string is 0-length
#                         
function empty(s) {       
  if(length(s) == 0)      
    return 1              
  return 0                
}  

#           
# subs - like sub() but literal non-regex   
#   
#   Example:
#      s = "*field"
#      print subs("*", "-", s)  #=> -field             
#   
#   Credit: adapted from lsub() by Daniel Mills https://github.com/e36freak/awk-libs
#
function subs(pat, rep, str,    len, i) {

  if (!length(str))
    return

  # get the length of pat, in order to know how much of the string to remove
  if (!(len = length(pat)))
    return str

  # substitute str for rep
  if (i = index(str, pat))              
    str = substr(str, 1, i - 1) rep substr(str, i + len)

  # return the result     
  return str              
}                         

#           
# gsubs - like gsub() but literal non-regex 
#   
#   Example:
#      s = "****field****"
#      print gsubs("*", "-", s)  #=> ----field----     
#   
#   Credit: Adapted from glsub() by Daniel Mills https://github.com/e36freak/awk-libs
#
function gsubs(pat, rep, str,    out, len, i, a, l) {

  if (!length(str))
    return

  # get the length of pat to know how much of the string to remove          
  # if empty return original str
  if (!(len = length(pat)))
    return str            

  # loop while 'pat' is in 'str'
  while (i = index(str, pat)) {
    # append everything up to the search pattern, and the replacement, to out
    out = out substr(str, 1, i - 1) rep
    # remove everything up to and including the first instance of pat from str
    str = substr(str, i + len)
  }

  # append whatever is left in str to out and return
  return out str
}

#  
# unpatsplit - join arrays created by patsplit()
#
function unpatsplit(field,sep,   c,o, debug) {

  debug = 0
  if(length(field) > length(sep)) return

  o = sep[0]
  for(c = 1; c < length(field) + 1; c++) {  
    if(debug) {                 
      print "field[" c "] = " field[c]
      print "sep[" c "] = " sep[c]
    }
    o = o field[c] sep[c]          
  }     
  return o
}

#
# shquote - make string safe for shell
#           
#  . alternate is shell_quote.awk in /usr/local/share/awk which uses '"' instead of \'
#
#  Example:
#     print shquote("Hello' There")    produces 'Hello'\'' There'
#     echo 'Hello'\'' There'           produces Hello' There
#
function shquote(str,  safe) {
        safe = str       
        gsub(/'/, "'\\''", safe)
        gsub(/’/, "'\\’'", safe)
        return "'" safe "'"
}

#           
# removefile - delete a file
#
#   . rm options can be passed in 'opts'
#
#   Requirement: Exe["rm"]
#
function removefile(str,opts) {
      close(str)         
      if( checkexists(str) )    
        sys2var( Exe["rm"] " " opts " -- " shquote(str) )
      if( checkexists(str) ) {
        stdErr("Error: unable to delete " str ", aborting.")
        exit
      }     
      system("") # Flush buffer
}                               


# 
# bell - ring bell
# 
#   . Exe["bell"] defined using full path/filenames to play a sound                
#     eg. Exe["bell"] = "/usr/bin/play -q /home/adminuser/scripts/chord.wav"
#
function bell(  a,i,ok) {

  c = split(Exe["bell"], a, " ")

  if(!checkexists(a[1])) return

  for(i = 2; i <= c; i++) {
    if(tolower(a[i]) ~ /[.]wav|[.]mp3|[.]ogg/) {
      if(!checkexists(a[i]))
        continue
      else {    
        ok = 1
        break
      }               
    }
  }                
  if(ok) sys2var(Exe["bell"])
}

# 
# checkexists - check file or directory exists.
# 
#   . action = "exit" or "check" (default: check)
#   . return 1 if exists, or exit if action = exit
#   . requirement: @load "filefuncs"
#           
function checkexists(file, program, action) {
  if( ! exists(file) ) {
    if( action == "exit" ) {
      stdErr(program ": Unable to find/open " file)
      print program ": Unable to find/open " file
      system("")
      exit
    }
    else
      return 0
  }
  else
    return 1
}

#
# exists - check for file existence
#
#   . return 1 if exists, 0 otherwise.
#   . requirement: @load "filefuncs"
#
function exists(name    ,fd) {
    if ( stat(name, fd) == -1)
      return 0
    else
      return 1
}

#             
# stdErr - print s to /dev/stderr
# 
#  . if flag = "n" then no newline
# 
function stdErr(s, flag) {
  if(flag == "n")
    printf("%s",s) > "/dev/stderr"
  else
    printf("%s\n",s) > "/dev/stderr"
  close("/dev/stderr")
}
function stdErrO(s) {
  if(stdOut == 1)
    print s
  else
    stdErr(s)
}

#
# Print some dots
#
function delayer() {
  stdErr(".","n")
  stdErr(".","n") 
  stdErr(".") 
}

#              
# verifyval - verify any command-line argument has valid value. Usage in getopt()
#
function verifyval(val) {
  if(val == "" || substr(val,1,1) ~/^[-]/) {
    stdErr("Command line argument has an empty value when it should have something.")
    exit
  }
  return val           
}

# 
# getopt - command-line parser
# 
#   . define these globals before getopt() is called:
#        Optind = Opterr = 1
# 
#   Credit: GNU awk (/usr/local/share/awk/getopt.awk)
#
function getopt(argc, argv, options,    thisopt, i) {

    if (length(options) == 0)    # no options given
        return -1

    if (argv[Optind] == "--") {  # all done
        Optind++   
        _opti = 0  
        return -1
    } else if (argv[Optind] !~ /^-[^:[:space:]]/) {
        _opti = 0
        return -1     
    }
    if (_opti == 0)
        _opti = 2
    thisopt = substr(argv[Optind], _opti, 1)
    Optopt = thisopt
    i = index(options, thisopt)
    if (i == 0) {
        if (Opterr)
            printf("%c -- invalid option\n", thisopt) > "/dev/stderr"
        if (_opti >= length(argv[Optind])) {
            Optind++
            _opti = 0
        } else
            _opti++
        return "?"
    }
    if (substr(options, i + 1, 1) == ":") {
        # get option argument
        if (length(substr(argv[Optind], _opti + 1)) > 0)
            Optarg = substr(argv[Optind], _opti + 1)
        else
            Optarg = argv[++Optind]
        _opti = 0
    } else
        Optarg = ""
    if (_opti == 0 || _opti >= length(argv[Optind])) {
        Optind++    
        _opti = 0              
    } else       
        _opti++    
    return thisopt
}

#
# sleep() - sleep seconds
# 
#   Credit: Rosetta Code 2018
# 
function sleep(seconds,  t) {

    t = systime()
    while (systime() < t + seconds) {}

}              

