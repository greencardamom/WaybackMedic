#!/usr/local/bin/gawk -bE

# The MIT License (MIT)
#
# Copyright (c) 2018 by User:GreenC (at en.wikipedia.org)
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

# get bot name
BEGIN {
  delete _pwdA
  _pwdC = split(ENVIRON["PWD"],_pwdA,"/")
  BotName = _pwdA[_pwdC]
}

@include "botwiki.awk"
@include "library.awk"
@include "atools.awk"
@include "json.awk"

#
# Manage changes made by WaybackMedic upload to the IAB Database
#
# Three steps:
#
#   1. (-c) Download IAB DB information for all links from all articles processed by WM for a project -p
#   2. (-g) Compare this with the logs created by WM. Generate appropriate API requests for upload to API
#   3. (-a) Send API requests to IAB API 
#
# See 0IAB for more instructions
#

BEGIN {

  IGNORECASE = 1
  PROCINFO["sorted_in"] = "@ind_num_asc"
  Optind = Opterr = 1 

  while ((C = getopt(ARGC, ARGV, "dagcp:f:")) != -1) {
    opts++
    if(C == "p")                 #   -p <project>   Use project name. No default.
      pid = verifypid(Optarg)
    if(C ~ /^[cga]{1}$/)         #   -c             Create iabwikdb.gz database
      opmode["arg"] = C          #   -g             Generate iabget file
                                 #   -a             Push changes to IAB API
                                 #
    if(C == "d")                 #   -d             Debug mode (dry-run, show results to screen)
      debug = 1
    if(C == "f")                 #   -f <file>      File to process (wayrm|logbadstatusother|newialink|newaltarch|newiadate|logskindeep)
      target = verifyval(Optarg) #                   default: all
  }

  if(empty(opmode) || opts == 0) {
    stdErr("iab.awk: No options given")
    exit
  }
 # No options or an empty -p given
  if( pid ~ /error/ || empty(pid) ){
    stdErr("iab.awk: -p <id> required")
    exit                
  }

  setProject(pid)     # library.awk .. load Project[] paths via project.cfg
                      # if -p not given, use default noted in project.cfg

  Lognamelist = "wayrm logbadstatusother newialink newaltarch newiadate logskindeep"

  if(empty(target)) 
    split(Lognamelist, Logname, " ")
  else
    Logname[1] = target

  if(opmode["arg"] == "c")  # -c is run via -g so this is not normally needed
    createdb()
  if(opmode["arg"] == "g")
    genapi()
  if(opmode["arg"] == "a")
    push2api()

}

#
# Create iabwikidb - download URL data for all articles from the IAB API
#
# Line example:
#
# 14th Dalai Lama ---- 20238168 ---- 51572232 ---- http://articles.chicagotribune.com/1996-05-01/news/9605010131_1 ---- http://articles.chicagotribune.com/1996-05-01/news/9605010131_1 ---- alive ---- https://web.archive.org/web/20160322024650/http://articles.chicagotribune.com/1996-05-01/news/9605010131_1 ---- 2016-03-22 02:46:50 ---- 2017-07-28 00:00:00
#
# article title ---- article ID (WP) ---- URL ID (IAB) ---- URL (IAB) ---- Normalized URL (IAB) ---- live_state (IAB) ---- archive (IAB) ---- snapshottime (IA) ---- accesstime (IAB)
#
function createdb(s,a,i,j,k,c,artids,command,jsona,op,logs,maxreq,blocks,offset,re,numred,rfrom,rto,titles,articles,pageid,title,ca,aa,ia,da,ba,hold) {

  if(checkexists(Project["meta"] "iabwikdb.gz")) 
    return -1

 # Generate list of log files to open and read
  split(Lognamelist, logs, " ")
  for(j = 1; j <= length(logs); j++) 
    s = s shquote(Project["meta"] logs[j]) " "

 # Creat sorted unique list of article names
  # this: Exe["awk"] " -F\"----\" 'BEGINFILE{if (ERRNO) nextfile} {print $1}' " s " | " Exe["sort"] " | " Exe["uniq"]
  ca = split(s, aa, /'/)
  for(ia = 1; ia <= ca; ia++) {
    aa[ia] = strip(aa[ia])
    if(!checkexists(aa[ia])) 
      continue
    for(da = 1; da <= splitn(aa[ia], ba, da); da++)  {
      hold[splitx(ba[da], "----", 1)] = 1
    }
  }

  c = splitn(join2(hold, "\n", "@ind_num_asc"), articles)

 # Maximum articles to request from the MW API per call
  maxreq = 50  
 # How many blocks of maxreq size
  blocks = c / maxreq
  if(blocks ~ /[.]/) {
    blocks++
    blocks = splitx(blocks, "[.]", 1)
  }
  
 # create a maxreq long titles string with "|" separator between each article name
  delete titles
  for(i = 1; i <= blocks; i++) {
    if(blocks != 1)
      offset = ( (i - 1) * maxreq) + 1
    else      
      offset = 1
    for(j = offset; j < offset + maxreq; j++) {
      if(!empty(articles[j])) {
        titles[i] = titles[i] urlencodeawk(articles[j]) "|"
      }
    }
    sub(/[|]$/,"",titles[i])
  }

 # Download batch of requests and extract from json -> artids["article name"] = articleID
  stdErr("Retrieving Wikipedia article IDs..")
  delete artids
  for(i in titles) {
    command = Exe["wget"] " -q -O- " shquote("https://en.wikipedia.org/w/api.php?action=query&titles=" titles[i] "&prop=info&format=json&utf8=&redirects")

    if( query_json(sys2var(command), jsona) < 0) {
      stdErr("  -->ERROR in JSON data for " titles[i])
      continue
    }

    splitja(jsona, pageid, 3, "pageid")
    splitja(jsona, title, 3, "title")
    for(j in pageid) 
      artids[title[j]] = pageid[j]

    # Re-set #redirect names back to the original name so it matches with log files (eg. wayrm field #1)
    # Note: the articleID is now out of sync with the articleName and could become bug if ever needed in future.

    numred = jsona["query","redirects","0"]
    if(numred > 0) {
      for(i = 1; i <= numred; i++) {
        rfrom = jsona["query","redirects",i,"from"]
        rto   = jsona["query","redirects",i,"to"]
        for(j in artids) {
          if(j == rto) {
            artids[rfrom] = artids[j]
            delete artids[j]
          }
        }
      }
    }
  }


  if(checkexists(Project["meta"] "iabwikdb"))
    removefile(Project["meta"] "iabwikdb")

 # Get article URL data from IABot API and print result
  stdErr("Retrieving URLs from IABot API..")
  for(i in artids) {
    if(!empty(i)) {
      command = Exe["iabget"] " -a searchurlfrompage -p pageids=\"" artids[i] "\" -k \" ---- \" "
      op =  sys2var(command)
      if(!empty(strip(op))) {
        for(j = 1; j <= splitn(op "\n", a, j); j++) {
          print i " ---- " a[j] >> Project["meta"] "iabwikdb"
        }
      }
      else
        stdErr("iab.awk: Unable to access IABot API for " i " : " command)
    }
  }
  
  close(Project["meta"] "iabwikdb")
  sys2var(Exe["gzip"] " " shquote(Project["meta"] "iabwikdb"))

}

#
# Generate API commands - match URLs in logfiles with API database, create command to update IAB database via API
#
function genapi(j,c,a,i,b,d,e,f,g,h,k,reason,found,pass,surl,isurl,filler,subb) {

  loadDB()

  if(!debug) {
    if(checkexists(Project["meta"] "iabget")) 
      removefile(Project["meta"] "iabget")
  }

  for(j in Logname) {

    if(Logname[j] ~ /wayrm|logbadstatusother/) {
      for(i = 1; i <= splitn(Project["meta"] Logname[j], a, i); i++) {
        split(a[i], b, "----")
        subb = subs(b[1] "----", "", a[i])
        split(subb, h, " ----")
        b[2] = strip(h[1])
        if(b[2] !~ /\/1970/ && b[2] !~ /\/1899/) {
          found = 0
          for(k = 1; k <= splitn(getDB(strip(b[1])) "\n", d, k); k++) {
            split(d[k], e, " ---- ")

            # URL = the archive URL from the logfile, not the IA database
#            if(e[1] == "San Jose, California") 
#              scope(e, "47498980", "https://perma-archives.org/warc/20160331221305/////https://www.census.gov/popest/data/counties/totals/2015/CO-EST2015-01.html", Logname[j])

            pass = 0
            if(Logname[j] == "wayrm") {
              if(urlequal(e[7], b[2]))
                pass = 1
            }
            else if(Logname[j] == "logbadstatusother") {   # Don't delete if IAB archive is a different service from one being deleted. These can be
                                                           # viewed by searching on MISS in debug mode.
              if( urlequal(e[7], b[2]) )
                pass = 1
              else if(!empty(e[7])) {
                if( archivename(e[7]) == archivename(b[2]) ) {
                  if(urlequal(e[4], urlurl(b[2])) || urlequal(e[5], urlurl(b[2]))) 
                    pass = 1
                  else if(iswebcite(e[7])) {
                    id1 = webciteid(e[7]); id2 = webciteid(b[2])
                    if(id1 !~ /error|nobase62/ && id2 !~ /error|nobase62/) {
                      if(tolower(id1) == tolower(id2))
                        pass = 1
                    }
                  }
                }
              }
            }

            #if(!pass)  {                        # When source URL in archive is different from source URL in IAB DB
            #  ourl = origurl(strip(b[1]), b[2])
            #  if(!empty(ourl)) {
            #    if(e[4] == ourl || e[5] == ourl)
            #      pass = 1
            #    else if(urlequal(e[4], ourl) || urlequal(e[5], ourl)) 
            #      pass = 1
            #  }
            #}


            if( pass ) {
              reason = "delete inoperable archive | iab.awk | " pid "/" Logname[j] " | " b[1] " | url " e[3]
              parameter = "urlid=" e[3] "{&}archiveurl={&}reason=" reason
              command = Exe["iabget"] " -e -w -a modifyurl -p " shquote(parameter) " -o " shquote(strip(e[7]))
              if(debug)
                print toupper(Logname[j]) " FOUND: " command 
              else 
                print command >> Project["meta"] "iabget"
              found = 1
              break
            }
          }
          if(!found) {
            found2 = 0
            f = length(d)
            for(k = 1; k <= f; k++) {
              split(d[k], e, " ---- ")
  
              if( urlequal(e[4], urlurl(b[2])) || urlequal(e[5], urlurl(b[2])) ) {
                if(!empty(e[7])) {
                  if(debug)
                    print toupper(Logname[j]) " MISSED: " d[k] " ---- " b[2]
                  found2 = 1
                  break
                }
                else if(empty(e[7])) {
                  if(debug)
                    print toupper(Logname[j]) " SKIP: " d[k] " ---- " b[2]
                  found2 = 1
                  break
                }
              }                  
            }
            if(!found2) {
              if(debug)
                print toupper(Logname[j]) " UNKNOWN: " a[i]                              
            }
          }
        }
      }
      close(Project["meta"] Logname[j])
    }

    if(Logname[j] ~ /newialink|newiadate|logskindeep/ ) {
      for(i = 1; i <= splitn(Project["meta"] Logname[j], a, i); i++) {

        split(a[i], b, "----")         # b[1] == namewiki
        subb = subs(b[1] "----", "", a[i])
        if(Logname[j] == "logskindeep")
          split(subb, h, " ")
        else
          split(subb, h, " ----")

        if(Logname[j] == "newiadate")  # b[2] == archive URL
          b[2] = strip(h[2])
        else if(Logname[j] == "newialink")
          b[2] = strip(h[1])
        else if(Logname[j] == "logskindeep")
          b[2] = strip(h[3])

        if(b[2] !~ /\/1970/ && b[2] !~ /\/1899/) {
          found = 0
          for(k = 1; k <= splitn(getDB(strip(b[1])) "\n", d, k); k++) {

            split(d[k], e, " ---- ")

            # if(e[1] == "Patika, Harju County") {
            #   scopeDB(d,k)
            # }
            # URL = the archive URL from the logfile, not the IA database
#            if(e[1] == "The Miz")
#              scope(e, "4122408", "https://web.archive.org/web/20160601083429/http://slam.canoe.com/Slam/Wrestling/2010/05/11/13914666.html", Logname[j])
#            if(e[1] == "Pat Meehan")
#              scope(e, "20494374", "https://web.archive.org/web/20120106013744/http://www.politico.com/2012-election/map/#/House/2010/PA", Logname[j])


            # limit calls to urlequal() performance reasons
            surl = urlurl(b[2])
            isurl = urlurl(e[7])
            pass = 0
            if(e[4] != e[5]) {  
              if( e[4] == surl || e[5] == surl )
                pass = 1
              else if( urlequal(e[4], surl) || urlequal(e[5], surl) )
                pass = 1
              else if(!empty(isurl)) {
                if( urlequal(isurl, surl))
                  pass = 1
              }
            }
            else {
              if(e[4] == surl)
                pass = 1
              else if( urlequal(e[4], surl))
                pass = 1
              else if(!empty(isurl)) {
                if( urlequal(isurl, surl))
                  pass = 1
              }
            }
            if(!pass && Logname[j] == "newialink")  { # When source URL in new archive is different from source URL in IAB DB
              ourl = origurl(strip(b[1]), b[2])
              if(!empty(ourl)) {
                if(e[4] == ourl || e[5] == ourl)
                  pass = 1
                else if(urlequal(e[4], ourl) || urlequal(e[5], ourl)) 
                  pass = 1
              }
            }

            if( pass ) {

  # Policy overwrite existing unless it is a duplicate (SKIP) or can't be found in API database (UNKNOWN)
              if( ! urlequal(urlurl(e[7]), surl) || ! isarchiveorg(b[2]) ||\
                  archivename(b[2]) == archivename(e[7]) || (isarchiveorg(b[2]) && ! isarchiveorg(e[7])) ) {
                if(! urlequal(e[7], b[2])) {
                  if(Logname[j] == "newiadate") 
                    filler = " date"
                  else if(Logname[j] == "logskindeep") 
                    filler = " path"
                  else if(Logname[j] == "newialink") 
                    filler = " replace"
                  reason = "modify archive" filler " | iab.awk | " pid "/" Logname[j] " | " b[1] " | url " e[3]
                  parameter = "urlid=" e[3] "{&}overridearchivevalidation=1{&}archiveurl=" strip(b[2]) "{&}reason=" reason
                  command = Exe["iabget"] " -e -w -a modifyurl -p " shquote(parameter) " -o " shquote(strip(e[7]))
                  if(debug)
                    print toupper(Logname[j]) " FOUND: " command 
                  else
                    print command >> Project["meta"] "iabget"
                  found = 1
                  break
                }
              }
            }
          } 
          if(!found) {
            found2 = 0
            f = length(d)
            for(k = 0; k <= f; k++) {
              split(d[k], e, " ---- ")
              if( urlequal(e[4], surl) || urlequal(e[5], surl) ) {
                if(! urlequal(b[2], e[7])) {                                                  
                  if(debug)
                    print toupper(Logname[j]) " MISSED: " d[k] " ---- " b[2]           # should be 0 hits
                  found2 = 1
                  break
                }
                else if(urlequal(b[2], e[7])) {                                        # skip when same archive URL
                  if(debug)
                    print toupper(Logname[j]) " SKIP: " d[k] " ---- " b[2]
                  found2 = 1
                  break
                }
              }                  
              else if(urlequal(e[7], b[2])) {                                          # skip when same archive URL
                if(debug)
                  print toupper(Logname[j]) " SKIP: " d[k] " ---- " b[2]
                found2 = 1
                break
              }                  
            }
            if(!found2) {
              if(debug)
                print toupper(Logname[j]) " UNKNOWN: " a[i]                              
            }
                                                                                         # url doesn't exist in IAB database
                                                                                         # do nothing because IABot will pick up the new URL 
                                                                                         # when scanning pages. API has no option to add new
                                                                                         # urls. Can happen when editor adds new content to
                                                                                         # wiki in between IABot and GreenC bot edits.
          }
        }
      }
      close(Project["meta"] Logname[j])
    }

    if(Logname[j] ~ /newaltarch/ ) {
      for(i = 1; i <= splitn(Project["meta"] Logname[j], a, i); i++) {
        split(a[i], g, "----")
        g[2] = subs(g[1] "----", "", a[i])
        split(g[2], b, " ")
        b[4] = strip(b[2])   # b[4] = original url
        b[2] = strip(b[3])   # b[2] = archive url
        b[1] = strip(g[1])   # b[1] = wikipedia name
          
        b[2] = https(b[2])   

        if(b[2] !~ /\/1970/ && b[2] !~ /\/1899/) {
          found = 0
          for(k = 1; k <= splitn(getDB(strip(b[1])) "\n", d, k); k++) {
            split(d[k], e, " ---- ")

#            if(e[1] == "Drexel University") {
#              scopeDB(d,k)
#            }
#            if(e[1] == "Rafael Grugman")
#              scope(e, "11136303", "https://archive.is/20150404120937/http://www.kolhauma.org.il/index.php/publications/israel/1312-q------q.html", Logname[j])


            # limit calls to urlequal() performance reasons
            surl = urlurl(b[2])
            pass = 0
            if(e[4] != e[5]) { 
              if(      e[4] == surl || e[5] == surl)                  { pass = 1 }
              else if( e[4] == b[4] || e[5] == b[4])                  { pass = 1 }                   
              else if( urlequal(e[4], surl) || urlequal(e[5], surl) ) { pass = 1 }
            }
            else {
              if(      e[4] == surl       )  { pass = 1 }
              else if( e[4] == b[4]       )  { pass = 1 }
              else if( urlequal(e[4], surl)) { pass = 1 }
              else if( e[4] != b[4]       )  {
                if(urlequal(e[4], b[4]))     { pass = 1 }
              }
            }
            if(!pass && Logname[j] == "newaltarch")  { # When source URL in new archive is different from source URL in IAB DB
              ourl = origurl(strip(b[1]), b[2])
              if(!empty(ourl)) {
                if(e[4] == ourl || e[5] == ourl)
                  pass = 1
                else if(urlequal(e[4], ourl) || urlequal(e[5], ourl)) 
                  pass = 1
              }
            }

            if( pass ) {

  # Policy overwrite existing unless it is a duplicate (SKIP) or can't be found in API database (UNKNOWN)

              if( ! urlequal(e[7], b[2]) ) {
                reason = "new archive | iab.awk | " pid "/" Logname[j] " | " b[1] " | url " e[3]
                parameter = "urlid=" e[3] "{&}overridearchivevalidation=1{&}archiveurl=" strip(b[2]) "{&}reason=" reason
                command = Exe["iabget"] " -e -w -a modifyurl -p " shquote(parameter) " -o " shquote(strip(e[7]))
                if(debug)
                  print toupper(Logname[j]) " FOUND: " command 
                else
                  print command >> Project["meta"] "iabget"
                found = 1
                break
              }

            }
          } 
          if(!found) {
            found2 = 0
            f = length(d)
            for(k = 0; k <= f; k++) {
              split(d[k], e, " ---- ")
              if( urlequal(e[4], surl) || urlequal(e[5], surl) ) {
                if( ! urlequal(b[2], e[7]) ) {                                                  
                  if(debug)
                    print toupper(Logname[j]) " MISSED: " d[k] " ---- " b[2]           # should be 0 hits
                  found2 = 1
                  break
                }
                else if( urlequal(e[7], b[2])) {                                       # skip when same archive URL
                  if(debug)
                    print toupper(Logname[j]) " SKIP: " d[k] " ---- " b[2]
                  found2 = 1
                  break
                }
              }
              else if(urlequal(e[7], b[2])) {
                if(debug)
                  print toupper(Logname[j]) " SKIP: " d[k] " ---- " b[2]               # skip when same archive URL
                found2 = 1
                break
              }                  
            }
            if(!found2) {
              if(debug)
                print toupper(Logname[j]) " UNKNOWN: " a[i]                              
            }
                                                                                         # url doesn't exist in IAB database
                                                                                         # do nothing because IABot will pick up the new URL 
                                                                                         # when scanning pages. API has no option to add new
                                                                                         # urls. Can happen when editor adds new content to
                                                                                         # wiki in between IABot and GreenC bot edits.
          }
        }
      }
      close(Project["meta"] Logname[j])
    }
  }
}

#
# Cycle the iabget file - largely mirrors same function in imp.awk and project.awk
#
function push2api(  ppid,jsona,command,i,action,a,b,dest, fish, scale, runagain) {

  if(!checkexists(Project["meta"] "iabget")) {
    print("Error unable to find " Project["meta"] "iabget" )
    return 0
  }
  if(filesize(Project["meta"] "iabget") == 0) {
    print("Error file is size-0: " Project["meta"] "iabget")
    return 0
  }

  if(checkexists(Project["meta"] "iabget")) {
    sys2var(Exe["cp"] " " shquote(Project["meta"] "iabget") " " shquote(Project["meta"] "iabget.orig") )
    stdErr("iab.awk: pushing changes to API\n")

    for(i = 1; i <= splitn(Project["meta"] "iabget", a, i); i++) {
      if(a[i] ~ "iabget") {
        print "[___________ (" i "/" length(a) ") ___________]"
        print a[i]

       # run iabget command, save result in jsona[]

        if( query_json(sys2var(a[i]), jsona) < 0) {
          print "  -->ERROR in JSON data"
          print a[i] >> meta "iabget.error"
          continue
        }
        if(jsona["result"] == "success") {
          print "  -->SUCCESS upload to API"
          print a[i] >> Project["meta"] "iabget.done"
          close(Project["meta"] "iabget.done")

         # add entry to iabget.log

          if(match(a[i], /[{][&][}]reason[=][^$]*[^$]?/, dest)) {
            split(dest[0], b, /[ ][|][ ]/)    
            action = strip(subs("{&}reason=", "", b[1]))
            ppid = strip(b[3])
            sub(/['][^$]*[^$]?/, "", b[5])       
            sub(/^[ ]*url[ ]*/,"", b[5])            
            print b[5] " " ppid " " dateeight() " " action >> Project["meta"] "iabget.log"
            close(Project["meta"] "iabget.log")
          }
        }
        else {
          print "  -->ERROR upload to API"
          print a[i] >> Project["meta"] "iabget.error"
          close(Project["meta"] "iabget.error")
        }
       # remove first line from iabget
        command = Exe["tail"] " -n +2 " shquote(Project["meta"] "iabget") " > " shquote(Project["meta"] "iabget.temp")
        sys2var(command)
        command = Exe["mv"] " " shquote(Project["meta"] "iabget.temp") " " shquote(Project["meta"] "iabget")
        sys2var(command)
      }
      else {
        if(! empty(strip(a[i]))) {
          print "  -->UNKNOWN entry in iabget"
          print a[i] >> Project["meta"] "iabget.unknown"
          close(Project["meta"] "iabget.unknown")
        }
        command = Exe["tail"] " -n +2 " shquote(Project["meta"] "iabget") " > " shquote(Project["meta"] "iabget.temp")
        sys2var(command)
        command = Exe["mv"] " " shquote(Project["meta"] "iabget.temp") " " shquote(Project["meta"] "iabget")
        sys2var(command)
      }
    }
  }

 # Run iabget.error again

  runagain = 0

  if(runagain) {
    if(checkexists(Project["meta"] "iabget.error") && filesize(Project["meta"] "iabget.error") > 0) {
      command = Exe["project"] " -e " shquote("iabget.error") " -p " shquote(pid)
      print ""
      print "________________________________________________________________________________________"
      print ""
      stdErr("iab.awk: " command)

      while ( (command | getline fish) > 0 ) {
        if ( ++scale == 1 )     {
          stdErr(fish)
        }
        else {
          stdErr("\n" fish)
        }
      }
      close(command)
    }
  }
}

#
# Given a Wikipedia name, return all lines matching field #1 (name) in iabwikdb.gz
#
function getDB(name,   c,i,a,op) {

  if(length(IndexName) == 0) {
    stdErr("iab.awk: Unable to find IndexName[]")
    exit
  }

  c = split(strip(IndexName[name]), a, " ")
  for(i = 1; i <= c; i++) 
    op = op sprintf("%s\n",IabWikDB[a[i]])

  return strip(op)

}

#
# Load iabwikdb.gz -> IabWikDB[] and create an index on names in IndexName[]
#
function loadDB(c,i,a) {

  if(!checkexists(Project["meta"] "iabwikdb.gz")) {
    stdErr("iab.awk: Creating " shquote(Project["meta"] "iabwikdb.gz"))
    createdb()
  }

  if(!checkexists(Project["meta"] "iabwikdb.gz")) {
    stdErr("iab.awk: Unable to find " shquote(Project["meta"] "iabwikdb.gz"))
    exit
  }

 # Unpack and load iabwikdb.gz into global array     
 # Create index on names
  c = splitn(sys2var(Exe["zcat"] " " shquote(Project["meta"] "iabwikdb.gz")), IabWikDB)
  for(i = 1; i <= c; i++) {
    split(IabWikDB[i],a," ---- ")
    IndexName[a[1]] = IndexName[a[1]] " " i
  }
}

#
# Convert certain services to https
#  This is due to medic not properly converting to https
#  and logs containing outdated info
#
function https(url) {

  if(isarchiveis(url) && url ~ /^[Hh][Tt][Tt][Pp][:]/)
    sub(/^[Hh][Tt][Tt][Pp][:]/, "https:", url)
  else if(isarchiveit(url) && url ~ /^[Hh][Tt][Tt][Pp][:]/)
    sub(/^[Hh][Tt][Tt][Pp][:]/, "https:", url)

  return url
}

#
# Given a wiki name and newiaurl, return the origurl found in waylink.end
#  Otherwise return ""
#
function origurl(name, newarchiveurl,   datapath,c,i,a,dest,re,key,debug) {

  if(name == "Tarek Fatah") 
    debug = 0

  if(!empty(ORIGURL[name SUPSEP newarchiveurl]))  # return cached copy
    return ORIGURL[name SUPSEP newarchiveurl]

  datapath = whatistempid(name)

  if(debug)
    print "SCOPE datapath = " datapath

  if(empty(datapath) || !checkexists(datapath "waylink.end")) 
    return ""

  c = split(readfile(datapath "waylink.end"), a, /\n[-][-]/)

  if(isarchiveorg(newarchiveurl))
    key = "newiaurl"
  else
    key = "altarch"

  if(debug)
    print "SCOPE key = " key

  for(i = 1; i<= c; i++) {
    re = "[.]" key "[ ][=][ ][^\n]*[^\n]?"
    if(match(a[i], re, dest)) {
      re = "^[.]" key "[ ]*[=][ ]*"
      sub(re, "", dest[0])

      if(debug) {
        print "SCOPE newarchive = " newarchiveurl
        print "SCOPE waylink.end archive = " dest[0]
      }

      if(newarchiveurl == dest[0]) {
        if(match(a[i], /[.]origurl[ ][=][ ][^\n]*[^\n]?/, dest)) {
          sub(/^[.]origurl[ ]*[=][ ]*/,"",dest[0])
          if(debug)
            print "SCOPE origurl = " dest[0]
          if(!empty(dest[0])) {
            ORIGURL[name SUPSEP newarchiveurl] = dest[0]
            return dest[0]
          }
        }
      }
    }
  }

  if(key == "altarch") {
    key = "altarchencoded"

    if(debug)
      print "SCOPE key = " key

    for(i = 1; i<= c; i++) {
      re = "[.]" key "[ ][=][ ][^\n]*[^\n]?"
      if(match(a[i], re, dest)) {
        re = "^[.]" key "[ ]*[=][ ]*"
        sub(re, "", dest[0])

        if(debug) {
          print "SCOPE newarchive          = " newarchiveurl
          print "SCOPE waylink.end archive = " dest[0]
        }

        if(urlequal(newarchiveurl, dest[0])) {
          if(match(a[i], /[.]origencoded[ ][=][ ][^\n]*[^\n]?/, dest)) {
            sub(/^[.]origencoded[ ]*[=][ ]*/,"",dest[0])
            if(debug)
              print "SCOPE origencoded = " dest[0]
            if(!empty(dest[0])) {
              ORIGURL[name SUPSEP newarchiveurl] = dest[0]
              return dest[0]
            }
          }
        }
      }
    }

  }


  return ""
}


#
# Debugging function to find and view results
# 
# URL = the archive URL from the logfile, not the IA database
#
function scope(e,id,url,logname,   b,logtype,pass) {

  delete b
  b[2] = url

#  print "SCOPE NAME: " e[3]

  if(e[3] == id && logname ~ /logbadstatusother|wayrm/ ) {

            if(logname == "wayrm")
              logtype = "wayrm"
            else
              logtype = "logbadstatusother"

            if(logtype == "wayrm") {
              if(urlequal(e[7], b[2]))
                pass = 1
            }
            else if(logtype == "logbadstatusother") {
              if( urlequal(e[7], b[2]) )
                pass = 1
              else if(!empty(e[7])) {
                if( archivename(e[7]) == archivename(b[2]) ) {
                  if(urlequal(e[4], urlurl(b[2])) || urlequal(e[5], urlurl(b[2]))) 
                    pass = 1
                  else if(iswebcite(e[7])) {
                    id1 = webciteid(e[7]); id2 = webciteid(b[2])
                    if(id1 !~ /error|nobase62/ && id2 !~ /error|nobase62/) {
                      if(tolower(id1) == tolower(id2))
                        pass = 1
                    }
                  }
                }
              }
            }

            if(!pass)  { # When source URL in new archive is different from source URL in IAB DB
              ourl = origurl(strip(e[1]), b[2])
              print "SCOPE: ourl = " ourl
              if(!empty(ourl)) {
                if(e[4] == ourl || e[5] == ourl)
                  pass = 1
                else if(urlequal(e[4], ourl) || urlequal(e[5], ourl)) 
                  pass = 1
              }
            }


    print "SCOPE: ***************************************************"
    print "SCOPE: id = " id
    print "SCOPE: wmurl = |" b[2] "|"
    print "SCOPE: dburl = |" e[7] "|"
    print "SCOPE: pass = " pass
    print "SCOPE: ***************************************************"

  }

  if(e[3] == id && logname ~ /newialink|newiadate|logskindeep/) {

            # limit calls to urlequal() performance reasons
            surl = urlurl(b[2])
            isurl = urlurl(e[7])
            pass = 0
            if(e[4] != e[5]) {  
              if( e[4] == surl || e[5] == surl )
                pass = 1
              else if( urlequal(e[4], surl) || urlequal(e[5], surl) )
                pass = 1
              else if(!empty(isurl)) {
                if( urlequal(isurl, surl))
                  pass = 1
              }
            }
            else {
              if(e[4] == surl)
                pass = 1
              else if( urlequal(e[4], surl))
                pass = 1
              else if(!empty(isurl)) {
                if( urlequal(isurl, surl))
                  pass = 1
              }
            }
            if(!pass && logname == "newialink")  { # When source URL in new archive is different from source URL in IAB DB
              ourl = origurl(strip(e[1]), b[2])
              print "SCOPE: ourl = " ourl
              print "SCOPE e4 = " e[4]
              if(!empty(ourl)) {
                if(e[4] == ourl || e[5] == ourl)
                  pass = 1
                else if(urlequal(e[4], ourl) || urlequal(e[5], ourl)) 
                  pass = 1
              }
            }


    print "SCOPE: ***************************************************"
    print "SCOPE: id = " id
    print "SCOPE: wmurl = |" b[2] "|"
    print "SCOPE: dburl = |" e[7] "|"
    print "SCOPE: pass = " pass
    print "SCOPE: ***************************************************"


  }


  if(e[3] == id && logname ~ /newaltarch/) {


            # limit calls to urlequal() performance reasons
            surl = urlurl(b[2])
            pass = 0
            if(e[4] != e[5]) { 
              if(      e[4] == surl || e[5] == surl)                  { pass = 1 }
              else if( e[4] == b[4] || e[5] == b[4])                  { pass = 1 }                   
              else if( urlequal(e[4], surl) || urlequal(e[5], surl) ) { pass = 1 }
            }
            else {
              if(      e[4] == surl       )  { pass = 1 }
              else if( e[4] == b[4]       )  { pass = 1 }
              else if( urlequal(e[4], surl)) { pass = 1 }
              else if( e[4] != b[4]       )  {
                if(urlequal(e[4], b[4]))     { pass = 1 }
              }
            }

            if(!pass && logname == "newaltarch")  { # When source URL in new archive is different from source URL in IAB DB
              ourl = origurl(strip(e[1]), b[2])
              print "SCOPE: ourl = " ourl
              if(!empty(ourl)) {
                if(e[4] == ourl || e[5] == ourl)
                  pass = 1
                else if(urlequal(e[4], ourl) || urlequal(e[5], ourl)) 
                  pass = 1
              }
            }


    print "SCOPE: ***************************************************"
    print "SCOPE: id = " id
    print "SCOPE: wmurl = |" b[2] "|"
    print "SCOPE: dburl = |" e[7] "|"
    print "SCOPE: pass = " pass
    print "SCOPE: ***************************************************"


  }

}

function scopeDB(d,name,k,   i) {

  if(k == 1) {
    for(i in d)
      print "SCOPEDB: " d[i]
  }

}

