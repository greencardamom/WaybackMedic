#!/usr/local/bin/gawk -E

#
# IMP
#

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

# get bot name
BEGIN {
  delete _pwdA
  _pwdC = split(ENVIRON["PWD"],_pwdA,"/")
  BotName = _pwdA[_pwdC]
}

@include "botwiki.awk"
@include "library.awk"
@include "json.awk"

BEGIN {

  Optind = Opterr = 1 
  while ((C = getopt(ARGC, ARGV, "rc:")) != -1) {
    opts++
    if(C == "r")                                     # -r       Run 
      runit = 1
    if(C == "c")                                     # -c       Cfg filename (default: imp.cfg)
      cfgname = verifyval(Optarg)
  }

  if(opts == 0) {
    stdErr("No args.")
    exit
  }

  Meta = Home "metaimp/"
  Data = Home "dataimp/"

  if(empty(cfgname))
    CFGfile = Home "static/imp.cfg"
  else
    CFGfile = Home "static/" cfgname

  readCfg()

  if(Cfg["proj_name"] ~ "[Ff]rance") {
    MsgAdd = "Add archive"
    MsgDelete = "archive QC (1)"
    MsgReplace = "archive QC (2)"
  }
  else {
    MsgAdd = "Add archive"
    MsgDelete = "Delete dead archive"
    MsgReplace = "Replace or modify dead archive"
  }

 # Define stages in order processed
  Stage["create_project"] = 1
  Stage["download_dat"] = 2
  Stage["create_dat"] = 2
  Stage["run_medic"] = 3
  Stage["run_critical"] = 4
  Stage["run_medic_critical"] = 5
  Stage["shell_escape"] = 6
  Stage["process_articles"] = 7
  Stage["push2api"] = 8

# Set initial directories .. also changed in advanceBatch()
  Currbatch = Cfg["proj_name"] "." Cfg["curr_batch"]
  Metadir = Meta Currbatch "/"
  Datadir = Data Currbatch "/"
  Datdir  = Meta "dat/"
  Datfilename = Currbatch ".dat"
  Datfile = Datdir Datfilename
  Datfilemeta = Metadir Datfilename
  Authfile = Metadir "auth" 

  c = split(Metadir, a, "/")
  ProjID = a[c - 1]

# Set DatType based on "md" or "a" postfix in .dat filename
  split(Cfg["dat_file"], a, /[.]/)
  if(a[1] ~ /md$/)
    DatType = "ModDel"
  else if(a[1] ~ /a$/)
    DatType = "Add"
  else {
    stdErr("Unable to determine dat file type for " Cfg["dat_file"])
    exit
  }

  if(runit == 1) {
    mainLoop()
  }

}

function mainLoop() {

  while(1) {

    if(Cfg["last_stage"] == 0 || Cfg["last_stage"] == "")
      advanceBatch("curr_batch")

    stdErr("---")
    stdErr("mainLoop: Starting for batch " Cfg["proj_name"] "." Cfg["curr_batch"] " at " datefull())
    bell()

    create_project()
    # download_dat()
    create_dat()
    run_medic(Datfilename)
    stdErr("mainLoop: Ending for batch " Cfg["proj_name"] "." Cfg["curr_batch"] " at " datefull())
    run_critical()    
    run_medic("auth.critical")
    shell_escape()
    process_articles()
 
    if( getinput("Push to API? (Y/N): ") == "y")
      push2api()
    else {
      stdErr("Skipping push to API. Please manually run 'project -e iabget -p " Cfg["proj_name"] "." Cfg["curr_batch"] "'")
      advanceStage(Stage["push2api"])
    }

    advanceStage(0)

    if(zeropad2int(Cfg["curr_batch"]) == zeropad2int(Cfg["end_batch"])) {
      stdErr("mainLoop: Done imp.awk")
      exit
    }
  }

}

#
# Create Meta and Data directories
#
function create_project(  op,command) {

  if(Cfg["last_stage"] >= Stage["create_project"]) return

  # project -c -p <pid>
  command = Exe["project"] " -c -p " Cfg["proj_name"] "." Cfg["curr_batch"]
  stdErr("create_project: " command)
  op = sys2var(command)
  if(op ~ /Error[:]/) {
    stdErr("create_project: Error in imp: from project.awk: " op)
    exit
  }

  advanceStage(Stage["create_project"])

}


#
# Create .dat file from a master .dat file (previously downloaded from API and defined in imp.cfg)
#
function create_dat(  start, startfull, end, command, fop,a,b,i,c,dt,f) {

  if(Cfg["last_stage"] >= Stage["create_dat"]) return

  masterdat = Meta "dat/" Cfg["dat_file"]
  if(!checkexists(masterdat)) {
    stdErr("Unable to find " masterdat)
    exit
  }

  if(DatType == "ModDel")
    dt = 8
  else if(DatType = "Add")
    dt = 5
    
  stdErr("create_dat: Creating " Datfile)

  start = zeropad2int(batchLeft(Cfg["curr_batch"]))
  end = start + (Cfg["batch_size"] - 1)
  if(start == 1) { 
    start = 0
    startfull = 0
    end = end - 1
  }
  else {
    startfull = ((start - 1) * 1000) + 1
  }

  command = Exe["tail"] " -n +" startfull " " masterdat " | " Exe["head"] " -n " ((end - (start - 1)) * 1000)
  stdErr("create_dat: " command)
  fop = sys2var(command)

 # Remove any garbage records with < dt > fields

  f = splitn(fop "\n", a, 1)
  fop = ""
  for(i = 1; i <= f; i++ ) { 
    d = split(a[i], b, " ")
    if(d == dt) {                         
      if(i == c )
        fop = fop a[i] 
      else
        fop = fop a[i] "\n"
    }
  }

  if( empty(strip(fop)) ) {
    stdErr("Error: empty or problem with " masterdat)
    exit
  }

  stdErr("create_dat: Saving dat file " Datfile)

  if(!checkexists(Meta "dat")) {
    if(!mkdir(Meta "dat")) {
      stdErr("Error: can't create directory " Meta "dat/")
      exit
    }
  }
  if(checkexists(Datfile)) {
    curdate = sys2var( Exe["date"] " +\"%m%d%H%M%S\"")
    sys2var(Exe["mv"] " " shquote(Datfile) " " shquote(Datfile "." curdate) )
    stdErr("Warning: datfile exists creating backup " Datfile "." curdate)
    print fop > Datfile
    close(Datfile)
  }
  else {
    print fop > Datfile
    close(Datfile)
  }

  system("")
  sleep(5)

  stdErr("create_dat: creating " shquote(Datfilemeta))
  sys2var("cp " shquote(Datfile) " " shquote(Datfilemeta))

  system("")
  sleep(5)

  stdErr("create_dat: creating " shquote(Authfile))
  if(checkexists(Authfile)) 
    stdErr("Error: can't create auth file already exists " Authfile)
  else {
    removefile(Authfile)
    for(i = 1; i <= splitn(Datfile, b, i); i++) 
      print splitx(b[i], " ", 1) >> Authfile
    close(Authfile)
  }

  advanceStage(Stage["create_dat"])

}

#
# Download .dat file real-time from API as needed
#
function download_dat(  start, end, command, op, fop, i, c, d, curdate, a, b, e, dt) {

  if(Cfg["last_stage"] >= Stage["download_dat"]) return

  if(DatType == "ModDel")
    dt = 8
  else if(DatType = "Add")
    dt = 5

  start = zeropad2int(batchLeft(Cfg["curr_batch"]))
  end = start + (Cfg["batch_size"] - 1)

 # Download from IAB API

  printf("download_dat: Download from API start ") > "/dev/stderr"

  for(i=start; i <= end; i++) {
    command = Exe["iabget"] " -e -a searchurldata -p \"hasarchive=1\" -r " i
#    command = Exe["iabget"] " -e -a searchurldata -p \"hasarchive=1\" -r " i " | head -n 500"
    op = sys2var(command)
    printf(".") > "/dev/stderr"
    if(op ~ /^Error[:]/) {
      stdErr("download_dat: Error in imp: returned from iabget. See " Metadir "iabget-error")
      print command "\n" op > Metadir "iabget-error"
      exit
    }
    if(i == end)
      fop = fop op 
    else
      fop = fop op "\n"
  }

  stdErr(" end")

 # Remove any garbage records with < 6 > fields

  c = splitn(fop "\n", a, 1)
  fop = ""
  for(i = 1; i <= c; i++) {
    d = split(a[i], b, " ")
    if(d == dt) {                      
      if(i == c )
        fop = fop a[i] 
      else
        fop = fop a[i] "\n"
    }
  }

  if( empty(strip(fop)) ) {
    stdErr("Error: empty or problem from IABot API")
    exit
  }

  stdErr("download_dat: Saving dat file " Datfile)

  if(!checkexists(Meta "dat")) {
    if(!mkdir(Meta "dat")) {
      stdErr("Error: can't create directory " Meta "dat/")
      exit
    }
  }
  if(checkexists(Datfile)) {
    curdate = sys2var( Exe["date"] " +\"%m%d%H%M%S\"")
    sys2var(Exe["mv"] " " shquote(Datfile) " " shquote(Datfile "." curdate) )
    stdErr("Warning: datfile exists creating backup " Datfile "." curdate)
    print fop > Datfile
    close(Datfile)
  }
  else {
    print fop > Datfile
    close(Datfile)
  }
 
  stdErr("download_dat: creating " Authfile)
  if(checkexists(Authfile)) 
    stdErr("Error: can't create auth file already exists " Authfile)
  else {
    removefile(Authfile)
    for(i = 1; i <= splitn(Datfile, e, i); i++) 
      print splitx(e[i], " ", 1) >> Authfile
    close(Authfile)
  }

  advanceStage(Stage["download_dat"])

}


function run_medic(fid,  command, fish, scale, pid, pause, interval, procs) {

  if(fid == "auth" || fid ~ /[.]dat$/) {
    if(Cfg["last_stage"] >= Stage["run_medic"]) 
      return
    pause = Cfg["delay"]
    interval = Cfg["interval"]
    procs = Cfg["procs"]
  }
  else if(fid == "auth.critical") {
    if(Cfg["last_stage"] >= Stage["run_medic_critical"]) 
      return
    pause = 0.8    # slow down recheck
    interval = 30  # always verify 
    procs = 30     # slow down
  }
  else {
    stdErr("run_medic: Unable to determine target file: " fid)
    exit
  }

  pid = Cfg["proj_name"] "." Cfg["curr_batch"]

  # parallel -a meta/$1/$2 -r --delay 2 --trim lr -k -j 27 ./driver -p $1 -n {}
  command = Exe["parallel"] " -a " Metadir fid " -r --delay " pause " --trim lr -k -j " procs " " Exe["driver"] " -i " interval " -p " pid " -n {}"

  stdErr("run_medic: " command)

  while ( (command | getline fish) > 0 ) {
    if ( ++scale == 1 )     {
      stdErr(fish)
    }
    else {
      stdErr("\n" fish)
    }
  }
  close(command)

  # ./project -j -p $1
  command = Exe["project"] " -j -p " pid
  sys2var(command)

  # mv meta/$1/index.temp meta/$1/index.temp.$2
  if(checkexists(Metadir "index.temp" )) 
    sys2var(Exe["mv"] " " shquote(Metadir "index.temp") " " shquote(Metadir "index.temp." fid) )

  if(fid == "auth" || fid ~ /[.]dat$/) 
    advanceStage(Stage["run_medic"])
  else if(fid == "auth.critical") 
    advanceStage(Stage["run_medic_critical"])

}

function run_critical(  command,op) {

  if(Cfg["last_stage"] >= Stage["run_critical"]) return

  if(! chDir(Metadir)) {
    stdErr("run_critical: Error: unable to chdir to " Metadir)
    return
  }
  
  command = "tcsh ./criticalrunimp"
  stdErr("run_critical: " command)
  op = sys2var(command)
  command = "./deletenamewrapimp critical"
  stdErr("run_critical: " command)
  op = sys2var(command)

  if(! chDir(Home)) {
    stdErr("run_critical: Error: unable to chdir to " Home)
    return
  }

  advanceStage(Stage["run_critical"])

}

function process_articles(  command,i,idir,parameter,c,a,op) {

  if(Cfg["last_stage"] >= Stage["process_articles"]) return

  if(! chDir(Metadir)) {
    stdErr("process_articles: Error: unable to chdir to " Metadir)
    return
  }

  if(checkexists("iabget")) {
    print "Warning: iabget exists and will be overwritten."
    print "If you don't continue the program will exit."
    print "You are free to rename it before continuing."
    if( getinput("Continue? [Y|N]: ") == "n")
      exit
  }

  if(checkexists("discovered")) {

   # reduce file size of index and discovered so it runs faster by removing entries also in wayrm which we don't care about
    if(DatType == "Add") {

      command = "awk -F\"----\" '{print $1}' wayrm > auth.process_articles"
      stdErr("process_articles: " command)
      print sys2var(command)

      command = "./deletename.awk -n discovered -l index -mk > index0"                         # in both discovered and index
      stdErr("process_articles: " command)
      print sys2var(command)

      command = "./deletename.awk -n auth.process_articles -l index0 > index.iabget"           # in index0 but not auth.process_articles
      stdErr("process_articles: " command)
      print sys2var(command)

      command = "./deletename.awk -n auth.process_articles -l discovered > discovered.iabget"  # in discovered but not auth.process_articles
      stdErr("process_articles: " command)
      print sys2var(command)

      ifile = "index.iabget"
      dfile = "discovered.iabget"

    }
    else {
      ifile = "index"
      dfile = "discovered"
    }

    stdErr("process_articles: create iabget")

   # clear previous project cycle
    delete INDEXA
    INDEXC = ""

    for(i = 1; i <= splitn(dfile, a, i); i++) {
      idir = whatistempid(a[i], ifile)  
      if(loadArticles(idir, a[i])) {
        parameter = ""

        if(DatType == "ModDel") {
          if(AWT["dead link"]) {
            parameter = "urlid=" a[i] "{&}archiveurl={&}reason=" AWT["reason"]
          }
          else if(tolower(AT["archiveurl"]) != tolower(AWT["archiveurl"]) ) {
            parameter = "urlid=" a[i] "{&}overridearchivevalidation=1{&}archiveurl=" AWT["archiveurl"] "{&}reason=" AWT["reason"] 
          }
          if(! empty(parameter) ) {
            command = Exe["iabget"] " -e -w -a modifyurl -p " shquote(parameter) " -o " shquote(AT["archiveurl"])
            op = op "\n" command 
            # print command >> "iabget"
            # close("iabget")
          }
        }
        else if(DatType == "Add") {
          if(AWT["dead link"] == 2) {  # special case
            parameter = "urlid=" a[i] "{&}archiveurl={&}reason=" AWT["reason"]
          }
          else if(! empty(AWT["archiveurl"]) && empty(AWT["dead link"]) ) {
            parameter = "urlid=" a[i] "{&}overridearchivevalidation=1{&}archiveurl=" AWT["archiveurl"] "{&}reason=" AWT["reason"]
            command = Exe["iabget"] " -e -w -a modifyurl -p " shquote(parameter) 
            op = op "\n" command
            # print command >> "iabget"
            # close("iabget")
          }          
        }
      }
      else {
        if(! empty(a[i]))
          stdErr(" .x. Unable to load " a[i] " (" idir ")")
      }
    }
  }
  else {
    stdErr("process_articles: none discovered")
  }

  if(! empty(op)) {
    print op > "iabget"
    close(op)
    # flush disk buffers, give it time to finish before cp to iabget.orig
    sleep(2)
    system("")
    sleep(10)
  }

 # Backup iabget
  if(checkexists("iabget")) {
    command = Exe["cp"] " iabget iabget.orig"
    sys2var(command)
  }

 # Append auth to metaimp/dat/auth.impdone
  stdErr("run_critical: Adding auth to " Datdir "auth.impdone")
  command = Exe["cat"] " " shquote(Datdir "auth.impdone") " auth | " Exe["sort"] " -u > " shquote(Datdir "auth.uniq") " ; " Exe["mv"] " " shquote(Datdir "auth.uniq") " " shquote(Datdir "auth.impdone") 
  stdErr("run_critical: " command)
  sys2var(command)

  if(! chDir(Home)) {
    stdErr("process_articles: Error: unable to chdir to " Home)
    return
  }

  advanceStage(Stage["process_articles"])

}

function shell_escape() {

  if(Cfg["last_stage"] >= Stage["shell_escape"]) return

  if(! chDir(Metadir)) {
    stdErr("shell_escape: Error: unable to chdir to " Metadir)
    return
  }

  command = "tcsh ./createmosaic"
  stdErr("shell_escape: " command)
  op = sys2var(command)

  print ""
  if(checkexists("badway.mosaic")) {
    print "   Look for false postives of archive.org links\n"
    print "     firefox `awk '$0' mosaic/badway.mosaic.aa`\n"
  }
  if(checkexists("badarchiveis.mosaic")) {
    print "   Look for false postives of archive.is links\n"
    print "     firefox `awk '$0' mosaic/badarchiveis.mosaic.aa`"
    print "     (fine-tune proc archiveis_soft404() in medicapi.nim)\n"
  }
  if(checkexists("badwebcite.mosaic")) {
    print "   Look for false postives of webcitation.org links\n"
    print "     firefox `awk '$0' mosaic/badwebcite.mosaic.aa`\n"
  }
  if(checkexists("badother.mosaic")) {
    print "   Check the rest:\n"
    print "     firefox `awk '$0' mosaic/badother.mosaic.aa`\n"
  }
  if(checkexists("newaltarch.mosaic") && ! checkexists("newaltarchshort.mosaic")) {
    print "   Check Newaltarch for soft-404 and improve filters in medicapi:\n"
    print "     firefox `awk '$0' mosaic/newaltarch.mosaic.aa`\n"
    print "   Follow directions in 0README step 8b and 8c"
  }
  if(checkexists("newaltarchshort.mosaic")) {
    print "   Check Newaltarchshort for soft-404 and improve filters in medicapi:\n"
    print "     firefox `awk '$0' mosaic/newaltarchshort.mosaic.aa`\n"
    print "   Open file \"p soft404.bm\" in a new window"
    print "   Follow directions in 0SOFT step 8b and 8c for Method: newaltarch no-cache short"
  }
  print ""
  print "Exiting to shell. When done, 'exit' to begin creating iabget file."
  print "                  To abort process: ps aux | grep imp" 
  print ""

  bell()

  system("tcsh")

  if(! chDir(Home)) {
    stdErr("shell_escape: Error: unable to chdir to " Home)
    return
  }

  advanceStage(Stage["shell_escape"])


}

function push2api(  id,pid,jsona,command,i,action,op,c,a,b,dest, fish, scale) {

  if(Cfg["last_stage"] >= Stage["push2api"]) return

  if(! chDir(Home)) {
    stdErr("push2api: Error: unable to chdir to " Home)
    return
  }

  if(checkexists(Metadir "iabget")) {
    sys2var(Exe["cp"] " " shquote(Metadir "iabget") " " shquote(Metadir "iabget.orig") ) 
    stdErr("push2api: pushing changes to API\n")
    for(i = 1; i <= splitn(Metadir "iabget", a, i); i++) {
      if(a[i] ~ "iabget") {
        print "[___________ (" i "/" length(a) ") ___________]" 
        print a[i]

     # run iabget command, save result in jsona[]

        if( query_json(sys2var(a[i]), jsona) < 0) {
          print "  -->ERROR in JSON data"
          print a[i] >> meta "iabget.error"
          if(Runinmem != 1)
            close(meta "iabget.error")
          continue
        }

        if(jsona["result"] == "success") {
          print "  -->SUCCESS upload to API"
          print a[i] >> Metadir "iabget.done"
          close(Metadir "iabget.done")
         # add entry to iabget.log
          if(match(a[i], /IMPID[:][^)]*[^)]/, dest) > 0) {
            gsub(/^IMPID[:][ ]*/,"",dest[0])
            split(dest[0],b,".")
            id = strip(b[3])                     # urlid
            pid = strip(b[1]) "." strip(b[2])    # project id
            if(a[i] ~ MsgDelete)
              action = "delete"
            else if(a[i] ~ MsgReplace) 
              action = "modify"
            else if(a[i] ~ MsgAdd) 
              action = "add"
            print id " " pid " " dateeight() " " action >> Metadir "iabget.log"
            close(Metadir "iabget.log")
          }
        }
        else {
          print "  -->ERROR upload to API"
          print a[i] >> Metadir "iabget.error"
          close(Metadir "iabget.error")
        }
       # remove first line from iabget
        command = Exe["tail"] " -n +2 " shquote(Metadir "iabget") " > " shquote(Metadir "iabget.temp")
        sys2var(command)
        command = Exe["mv"] " " shquote(Metadir "iabget.temp") " " shquote(Metadir "iabget")
        sys2var(command)
      }
      else {
        if(! empty(strip(a[i]))) { 
          print "  -->UNKNOWN entry in iabget"
          print a[i] >> Metadir "iabget.unknown"
          close(Metadir "iabget.unknown")
        }
        command = Exe["tail"] " -n +2 " shquote(Metadir "iabget") " > " shquote(Metadir "iabget.temp")
        sys2var(command)
        command = Exe["mv"] " " shquote(Metadir "iabget.temp") " " shquote(Metadir "iabget")
        sys2var(command)
      }
    }
  }

 # Run iabget.error again
  if(checkexists(Metadir "iabget.error")) {
    command = Exe["project"] " -e " shquote("iabget.error") " -p " shquote(ProjID)
    print ""
    print "________________________________________________________________________________________"
    print ""
    stdErr("push2api: " command)

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

  advanceStage(Stage["push2api"])

}

#
# Read contents of article.txt and article.waybackmedic.txt into global arrays AT and AWT
#
function loadArticles(idir, id,   fpat,fpawt,tail,a,dest) {

      delete AT
      delete AWT
      tail = "(IMPID: " Cfg["proj_name"] "." Cfg["curr_batch"] "." id ")"

      if(checkexists(idir "article.txt") && checkexists(idir "article." BotName ".txt") ) {
        fpat = readfile(idir "article.txt")
        fpawt = readfile(idir "article." BotName ".txt")
        if(! empty(fpat) && ! empty(fpawt) ) {
         # url=
          if(match(fpat, /url[=][^ ]*[^ ]/, dest)) {
            gsub(/^url[=]/, "", dest[0])
            if(! empty(strip(dest[0]))) {
              AT["url"] = strip(dest[0])
             # Delete |url=http://http:/| caused by malformed URLs like 19583370 in imp20170708a.000139-000198
              if(strip(AT["url"]) ~ /http[:]\/\/http[:]\/$/)  {
                AWT["dead link"] = 2
                return 1
              } 
            }
            else return 0
          }
         # url=
          if(match(fpawt, /url[=][^ ]*[^ ]/, dest)) {
            gsub(/^url[=]/, "", dest[0])
            if(! empty(strip(dest[0])))
              AWT["url"] = strip(dest[0])
            else return 0
          }
         # archiveurl=
          if(match(fpat, /archive[-]?url[=][^ ]*[^ ]/, dest)) {
            gsub(/^archive[-]?url[=]/, "", dest[0])
            if(! empty(strip(dest[0])))
              AT["archiveurl"] = strip(dest[0])
            else {
              if(DatType == "ModDel") return 0
            }
          }
         # archiveurl=
          if(match(fpawt, /archive[-]?url[=][^ ]*[^ ]/, dest)) {
            gsub(/^archive[-]?url[=]/, "", dest[0])
            if(! empty(strip(dest[0]))) {
              AWT["archiveurl"] = strip(dest[0])
              if(split(AWT["archiveurl"], a, "?") > 0) {      # Mark if query string contains %2B
                if(a[2] ~ /%2B/)
                  AWT["P2B"] = 1 
              }
            }
          }
          else {                                              # If no archiveurl but url and no deadlink then mark it as a dead link
            if(! empty(AWT["url"]) ) {
              AWT["dead link"] = 1
            }
          }
         # deadurl=
          if(match(fpawt, /dead[-]?url[=][^ ]*[^ ]/, dest)) {
            gsub(/^dead[-]?url[=]/, "", dest[0])
            if(! empty(strip(dest[0])))
              AWT["deadurl"] = strip(dest[0])
          }
         # {{dead link}}
          if(match(fpawt, /[{][{][ ]*dead link/)) {
            AWT["dead link"] = 1
          }        
          if(empty(AWT["archiveurl"]) && empty(AWT["dead link"]) ) {
            return 0
          }
         # reason
          if(checkexists(idir "reasonimp"))
            AWT["reason"] = readfile(idir "reasonimp")
          else {
            if(DatType == "ModDel") {
              if(AWT["dead link"]) {
                AWT["reason"] = MsgDelete " " tail
              }
              else {
                AWT["reason"] = MsgReplace " " tail
              }
            }
            else if(DatType == "Add") {
              if(! empty(AWT["archiveurl"])) {
                AWT["reason"] = MsgAdd " " tail
              }
            }
          }
        }
        return 1
      }
      return 0
}

#
# Advance a batch counter in imp.cfg
#
function advanceBatch(batchname,  i, op, mark, batchnamere, c, a, b) {

  batchnamere = "^" batchname
  for(i = 1; i <= splitn(CFGfile, a, i); i++ ) { 
    if(a[i] ~ /^#/) {
      op = op a[i] "\n"
      continue
    }
    if(split(a[i],b,"=") > 0) {
      if(b[1] ~ batchnamere) {
        op = op batchname "=" incBatch(strip(b[2]), Cfg["batch_size"]) "\n"
        Cfg[batchname] = incBatch(strip(b[2]), Cfg["batch_size"])
      }
      else 
        op = op a[i] "\n"
    }
  }
  print op > CFGfile
  close(CFGfile)

  if(batchname == "curr_batch") {
    Currbatch = Cfg["proj_name"] "." Cfg["curr_batch"]
    Metadir = Meta Currbatch "/"
    Datadir = Data Currbatch "/"
    Datdir = Meta "dat/"
    Datfilename = Currbatch ".dat"
    Datfile = Datdir Datfilename
    Datfilemeta = Metadir Datfilename 
    Authfile = Metadir "auth" 
    c = split(Metadir, a, "/")
    ProjID = a[c - 1]
  }

}

#
# Advance the stage counter in imp.cfg
#
function advanceStage(stage,  i, op, mark, c, a, b) {

  for(i = 1; i <= splitn(CFGfile, a, i); i++ ) { 
    if(a[i] ~ /^#/) {
      op = op a[i] "\n"
      continue
    }
    if(split(a[i],b,"=") > 0) {
      if(b[1] ~ /^last_stage/) {
        op = op "last_stage=" stage "\n"
        Cfg["last_stage"] = stage
        mark = 1
      }
      else 
        op = op a[i] "\n"
    }  
  }
  if(!mark) 
    op = op "last_stage=" stage "\n"

  print op > CFGfile
  close(CFGfile)

  if(stage > 0) {
    if(stage == Stage[Cfg["end_stage"]]) {
      stdErr("advanceStage: End stage " Cfg["end_stage"])
      exit
    }
  }

}

#
# Read imp.cfg into Cfg[] data structure
#
function readCfg(  i, c, a, b) {

  if(!checkexists(CFGfile)) {
    print "Unable to open cfg file: " CFGfile
    exit
  }
  for(i = 1; i <= splitn(CFGfile, a, i); i++ ) { 
    if(a[i] ~ /^#/) continue
    if(split(a[i],b,"=") > 0) {
      Cfg[strip(b[1])] = strip(b[2])
    }
  }

  if(Cfg["batch_size"] == 1) Cfg["batch_size"] = 2

}

#
# Increase batch string by batch_size
#
function incBatch(batch, batch_size,  newleft, op, a) {

  if(empty(batch)) 
    return "000001-" incNumber("000001", batch_size)

  if(split(batch, a, "-") == 2) {
    newleft = incNumber(a[2], 1)
    op = newleft "-" incNumber(newleft, batch_size)
    return op
  }

}

#
# Increase 0-padded number by size .. with 0-padding to 6-digit
#  eg 000001 4 -> 000005
#
function incNumber(strnum, size) {

    if(size != 1) size = size - 1  
    return sprintf("%06d", zeropad2int(strnum) + size)
}

#
# Given a 0-padded string return its int 
#  00001 -> 1
#
function zeropad2int(strnum,  i, c, a) {

  c = split(strnum,a,"")
  while(i++ < c) {
    if(a[i] == "0")
      continue
    else
      break
  }
  return int(substr(strnum, i, length(strnum)))
}


function batchLeft(s, a) {
  split(s, a, "-")
  return a[1]
}
function batchRight(s, a) {
  split(s, a, "-")
  return a[2]
}


#
# Return current date: 06/10/17 09:10:43
#
function datefull () {
  return sys2var( Exe["date"] " +\"%D %H:%M:%S\"")
}


#
# Return first character of prompted input
#
function getinput(prompt,  resp) {
    bell()
    printf(prompt)
    getline resp < "-"
    return tolower(substr(strip(resp), 1,1))
}


