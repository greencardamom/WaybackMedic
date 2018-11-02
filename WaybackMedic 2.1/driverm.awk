#!/usr/local/bin/gawk -bE

# Create data files/directories and launch medic.awk

# The MIT License (MIT)
#
# Copyright (c) 2016-2018 by User:GreenC (at en.wikipedia.org)
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

BEGIN {

  IGNORECASE = 1
  _cliff_seed = "0.00" splitx(sprintf("%f", systime() * 0.000001), ".", 2)

  Optind = Opterr = 1 
  while ((C = getopt(ARGC, ARGV, "hp:n:i:")) != -1) {
      opts++
      if(C == "p")                 #  -p <project>   Use project name. Default in project.cfg
        pid = verifypid(Optarg)
      if(C == "n")                 #  -n <name>      Name to process.
        namewiki = verifyval(Optarg)
      if(C == "i")                 #  -i <interval>  Number of seconds medic waits between testing API/WM status 
        interval = verifyval(Optarg)

      if(C == "h") {
        usage()
        exit
      }

  }
  if( pid ~ /error/ || ! opts || namewiki == "" ){
    usage()
    exit
  }

 # IMP project                 
  if(pid ~ /^imp/) {
    imp = 1     
    split(pid, z, /[.]/)
    if(z[1] ~ /md$/)
      dt = 8
    else if(z[1] ~ /a$/)
      dt = 5
    else {
      stdErr("driver.awk: Unable to determine dat file type for " pid)
      exit
    }
  }

  if(namewiki ~ /[ ](https?|ftp)[:]\/\//) {  # Data drawn from .dat file
    datrec = namewiki
    namewiki = splitx(datrec, " ", 1)
    rectype = 2
  }
  else {                                     # Data drawn from auth file
    rectype = 1
  }

  if(interval == "") 
    interval = 0

  setProject(pid)     # library.awk .. load Project[] paths via project.cfg or projimp.cfg

  datdir  = Config["default"]["meta"] "dat/"
  datfile = datdir pid ".dat"
  datmetafile = Project["meta"] pid ".dat"

  # Skip previously verified links as tracked in dat/auth.impdone
#  if(imp && pid !~ "france") {
  if(skippy) {
    command = Exe["grep"] " -m 1 -w " namewiki " " shquote(datdir "auth.impdone")
    op = strip(sys2var(command))
    if(namewiki == op) {
      print namewiki >> Project["meta"] "auth.impskiped"
      close(Project["meta"] "auth.impskiped")
      exit
    }
    else {
      print namewiki >> Project["meta"] "auth.impverified"
      close(Project["meta"] "auth.impverified")
    }
  }

# Create temp directory
  nano = substr(sys2var( Exe["date"] " +\"%N\""), 1, 5)
  wm_temp = Project["data"] "wm-" sys2var( Exe["date"] " +\"%m%d%H%M%S\"") nano "/" 
  if(!mkdir(wm_temp)) {
    sendlog(Project["critical"], namewiki, "Error: driver.awk: unable to create temp file")      
    stdErr("driver.awk: unable to create temp file")
    exit
  }

# Save wikisource

  if(empty(imp)) {
    fp = getwikisource(namewiki, "dontfollow")
    if(fp == "REDIRECT") exit
    print fp > wm_temp "article.txt"
    close(wm_temp "article.txt")
    if(length(fp) < 8) {
      sleep(5, "unix")
      fp = getwikisource(namewiki, "dontfollow") 
      if(fp == "REDIRECT") exit
      print fp > wm_temp "article.txt"
      close(wm_temp "article.txt")
      if(length(fp) < 8) {
        sleep(30, "unix")
        fp = getwikisource(namewiki, "dontfollow") 
        if(fp == "REDIRECT") exit
        print fp > wm_temp "article.txt"
        close(wm_temp "article.txt")
        if(length(fp) < 8) {
          sendlog(Project["critical"], namewiki, "Error: driver.awk: unable to retrieve wikitext")      
          stdErr("driver.awk: unable to retrieve wikitext")
          createIndex(namewiki, wm_temp)
          exit
        }
      }
    }
    if(length(fp) > 8) {                                           # check for {{bots|deny=medic}} or {{nobots}}
      if(match(fp, /([{][{][ ]*[Bb][Oo][Tt][Ss][ ]*[|][^}]*[}][}])|([{][{][ ]*[Nn][Oo][Bb][Oo][Tt][Ss][ ]*[}][}])/, dest) > 0) {
        if(tolower(dest[0]) ~ /medic|nobots/) {
          sendlog(Project["critical"], namewiki, "Error: driver.awk: nobots found")
          stdErr("driver.awk: nobots found for " namewiki)
          createIndex(namewiki, wm_temp)
          exit
        }
      }
    }
  }
  else {

    if(checkexists(datfile)) {

      if(rectype == 1) {
        command = Exe["grep"] " -m1 -E \"^" namewiki " \" " shquote(datfile)
        fp = strip(sys2var(command))
      }
      else if(rectype == 2) 
        fp = datrec

      if(empty(fp)) {
        sendlog(Project["critical"], namewiki, "Error: driver.awk: unable to retrieve wikitext")
        stdErr("Error: driver.awk: unable to retrieve wikitext") 
        createIndex(namewiki, wm_temp)
        exit
      }

      if(dt == 8) {

        # 1 http://triplezero.gov.au/ alive https://web.archive.org/web/20071112051107/http://triplezero.gov.au/ 2007-11-12 05:11:07 2007-11-12 05:11:07
        # Create {{cite web}}
        split(fp, b, " ")
        if(b[3] == "alive")
          deadurl = "no"
        else
          deadurl = "yes"
        if(b[4] ~ /perma-archives[.]org/) { # wikiwix as dead/non-existent
          snapshot = gsubs("-", "", b[5]) "000000"   # "000000" has special meaning in waytree()
          archiveurl = "https://web.archive.org/web/" snapshot "/" b[2]
          citeweb = "<ref>{{cite web |url=" b[2] " |archiveurl=" archiveurl " |archivedate=" b[5] " |deadurl=yes |accessdate=" b[7] " }}</ref>"
        }
        else
          citeweb = "<ref>{{cite web |url=" b[2] " |archiveurl=" b[4] " |archivedate=" b[5] " |deadurl=" deadurl " |accessdate=" b[7] " }}</ref>"

        # Create article.txt
        print citeweb > wm_temp "article.txt"
        close(wm_temp "article.txt")
      }
      else if(dt == 5) {

        # 1 http://triplezero.gov.au/ dead 2007-11-12 05:11:07
        split(fp, b, " ")
        # citeweb = "<ref>{{cite web |url=" b[2] " |accessdate=" b[4] " }}{{dead link |date=July 2017}}</ref>"
        snapshot = gsubs("-", "", b[4]) "000000"
        archiveurl = "https://web.archive.org/web/" snapshot "/" b[2]
        citeweb = "<ref>{{cite web |url=" b[2] " |archiveurl=" archiveurl " |archivedate=" b[4] " |deadurl=yes |accessdate=" b[4] " }}</ref>"

        # Create article.txt
        print citeweb > wm_temp "article.txt"
        close(wm_temp "article.txt")
      }
    }
    else {
      print "Error: unknown error"
      exit
    }
  }

# Strip leading/trailing newlines
  fp = stripfile(wm_temp "article.txt")
  if(length(fp) < 8) {
    sendlog(Project["critical"], namewiki, "Error: driver.awk: stripfile error")      
    stdErr("driver.awk: stripfile error")
    createIndex(namewiki, wm_temp)
    exit
  }
  print fp > wm_temp "article.txt" 
  close(wm_temp "article.txt")

# Make backup copy 
  print fp > wm_temp "article.txt.2" 
  close(wm_temp "article.txt.2")
  
# Save namewiki
  print namewiki > wm_temp "namewiki.txt"
  close(wm_temp "namewiki.txt")

# Create index.temp entry (re-assemble when GNU Parallel is done with "project -j") 
  createIndex(namewiki, wm_temp)

# Run medic

  if(! imp) 
    stdErr("\n"namewiki"\n")

  # See medicinit.nim for info about "xx42" bug workaround

  command = Exe["timeout"] " 360m " Exe["medic"] " -p=" shquote(Project["id"]) " -n=" shquote(gsubs("\"","xx42",namewiki)) " -s=" shquote(wm_temp "article.txt") " -d=n -i=" shquote(interval)  

  result = sys2varStderr(command)

  #command = Exe["gzip"] " " shquote(wm_temp "apilog")
  #sys2var(command)

  if(result != "0 0") {
    if(imp) 
      print "    Found |" result "| " Project["id"] "." namewiki 
    else
      stdErr("    Result |" result "| for " namewiki)
  }

  if(split(result, changes, " ") == 2) {
  
    if(changes[1] > 0 ) {
      if(!imp) 
        stdErr("    Found " changes[1] " change(s) for " namewiki)
      sendlog(Project["discovered"], namewiki, "")
    }
    else {
      if(checkexists(wm_temp "article." BotName ".txt") ) {
        sys2var( Exe["mv"] " " shquote(wm_temp "article." BotName ".txt") " " shquote(wm_temp "article." BotName ".txt.driver") )
        sendlog(Project["phantom"], namewiki, "driver.awk: " result)
      }
    }
    if(changes[2] == "124") { 
      sendlog(Project["critical"], namewiki, "Error: driver.awk: GNU timeout SIGNAL 124 running medic")
      stdErr("driver.awk: GNU timeout SIGNAL 124 running medic")
      if(checkexists(wm_temp "article." BotName ".txt")) 
        sys2var( Exe["mv"] " " shquote(wm_temp "article." BotName ".txt") " " shquote(wm_temp "article." BotName ".txt.driver2") )
    }
    else if(changes[2] != "0") {
      sendlog(Project["critical"], namewiki, "Error: driver.awk: Uknown error running medic")
      stdErr("driver.awk: Unknown error running medic")
      if(checkexists(wm_temp "article." BotName ".txt")) 
        sys2var( Exe["mv"] " " shquote(wm_temp "article." BotName ".txt") " " shquote(wm_temp "article." BotName ".txt.driver3") )
    }
  }
  else {
    sendlog(Project["critical"], namewiki, "Error: driver didn't get changes + stderr. Aborted.")
    if(checkexists(wm_temp "article." BotName ".txt")) 
      sys2var( Exe["mv"] " " shquote(wm_temp "article." BotName ".txt") " " shquote(wm_temp "article." BotName ".txt.driver4") )
  }
}

function usage() {

  print ""
  print "Driver - create data files and launch medic.awk"
  print ""
  print "Usage:"        
  print "       -p <project>   Project name. Optional, defaults to project.cfg"
  print "       -n <name>      Name to process. Required"
  print "       -h             Help"
  print ""
  print "Example: "
  print "          driver -n \"Charles Dickens\" -p cb14feb16"
  print ""
}

#
# Create entry in Index file
#
function createIndex(namewiki, wm_temp) {

  print namewiki "|" wm_temp >> Project["indextemp"]
  close(Project["indextemp"])

}

