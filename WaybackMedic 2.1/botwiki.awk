#
# botwikiawk - library for Wikipedia bots 
#

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

#
# Define paths used by programs that share this file
#

BEGIN {

  # 1. Stop button page
  StopButton = "https://en.wikipedia.org/wiki/User:GreenC_bot/button"

  # 2. User page
  UserPage = "http://en.wikipedia.org/wiki/User:GreenC"

  # 3. Paths and agent
  #  . BotName defined in the BEGIN{} section of calling programs (bug, driver, project etc)
  switch(BotName) {
    case "wm2":
    case "medic":
    case "waybackmedic":
      Home = "/home/adminuser/wmnim/wm2/"
      BotName = "waybackmedic"
      Agent = UserPage "/WaybackMedic"
      IMPCfg = Home "static/imp.cfg"
      break
    case "iabget":
      Home = "/home/adminuser/wmnim/wm2/"
      Agent = UserPage 
      break
    default:
      Home = "/home/adminuser/wmnim/wm2/modules/" BotName "/"  
      Agent = UserPage " (ask me about " BotName ")"
      break
  }  

  # 4. Default wget options (include lead/trail spaces)
  Wget_opts = " --no-cookies --ignore-length --user-agent=\"" Agent "\" --no-check-certificate --tries=5 --timeout=120 --waitretry=60 --retry-connrefused "


  # 5. Dependencies 
  #    . this command will find instances in each file:
  #         grep -vE "^[ ]*Exe" runmedic.awk | grep -oE 'Exe\[\"[^\"]*\"\]' | sort | uniq

  # 5a. Dependencies for library.awk 

  Exe["date"] = "/bin/date"
  Exe["mkdir"] = "/bin/mkdir"
  Exe["rm"] = "/bin/rm"
  Exe["sed"] = "/bin/sed"
  Exe["tac"] = "/usr/bin/tac"             # GNU
  Exe["timeout"] = "/usr/bin/timeout"     # GNU 
  Exe["wget"] = "/usr/bin/wget"

  # 5b. driver.awk
  Exe["grep"] = "/bin/grep"
  Exe["gzip"] = "/bin/gzip"
  Exe["mv"] = "/bin/mv"

  # 5c. bug.awk
  Exe["cat"] = "/bin/cat"
  Exe["diff"] = "/usr/bin/diff"           # GNU 

  # 5d. project.awk
  Exe["cp"] = "/bin/cp"
  Exe["head"] = "/usr/bin/head"
  Exe["ls"] = "/bin/ls"
  Exe["tail"] = "/usr/bin/tail"
  
  # 5f. iab.awk
  Exe["sort"] = "/usr/bin/sort"
  Exe["uniq"] = "/usr/bin/uniq"
  Exe["zcat"] = "/bin/zcat"              

  # 5g. runbot.awk
  Exe["parallel"] = "/usr/bin/parallel"   # GNU

  # 5h. parallelwatch.awk
  Exe["touch"] = "/usr/bin/touch"
  Exe["wc"] = "/usr/bin/wc"

  # 5i. makebot.awk
  Exe["chmod"] = "/bin/chmod"
  Exe["ln"] = "/bin/ln"

  # 6. Color inline diffs. Requires wdiff
  #   sudo apt-get install wdiff
  Exe["coldiff"] = "coldiff"

  # 7, Bell command - play a bell sound. Requires 'play' such as SoX
  #   sudo apt-get install sox
  #    (copy a .wav file from Windows)
  #    Use full path/filenames for player and sound file
  Exe["bell"] = "/usr/bin/play -q /home/adminuser/scripts/chord.wav"
  # Exe["bell"] = ""

  # 8. bot executables local
  Exe[BotName]  = Home BotName
  Exe["iabget"] = Home "iabget.awk"

  # 9, bot executables global
  Exe["bug"] = "bug.awk"
  Exe["project"] = "project.awk"
  Exe["driver"] = "driver.awk"
  Exe["wikiget"] = "wikiget.awk"

  # 10. Bot-specific customizations

  if(BotName == "waybackmedic") {
    Exe["driver"] = Home "driverm"
    Exe["project"] = Home "projectm"
    Exe["medic"] = Home "medic"
  }

  # 11. PyWikiBot script - deprecated
  # Exe["pywikibotsavepage"] = "/home/adminuser/pywikibot/core_stable/savepage.py"
   # Also add the following to the .login or .bashrc 
   #  setenv PYWIKIBOT2_DIR /home/adminuser/pywikibot/core_stable/


  # 12. Bot setup routines
  
  if(BotName != "makebot") {
    if(! checkexists(Home)) {
      stdErr("No known bot '" BotName "'. Run botwikiawk commands while in the home directory of the bot.")
      exit
    } 
    delete Config
    delete ConfigImp
    readprojectcfg()
  }
 
}

#
# readprojectcfg - read project.cfg into Config[]
#
function readprojectcfg(  a,b,c,i,p) {

  if(checkexists(Home "project.cfg", "botwiki.awk")) {
    for(i = 1; i <= splitn(Home "project.cfg", a, i); i++) {
      if(a[i] ~ /^[#]/)                        # Ignore comment lines starting with #
        continue
      else if(a[i] ~ /^default.id/) {
        split(a[i],b,"=")
        Config["default"]["id"] = strip(b[2])
      }
      else if(a[i] ~ /[.]data/) {
        split(a[i], b, "=")
        p = gensub(/[.]data$/,"","g",strip(b[1]))
        Config[p]["data"] = strip(b[2])
      }
      else if(a[i] ~ /[.]meta/) {
        split(a[i], b, "=")
        p = gensub(/[.]meta$/,"","g",strip(b[1]))
        Config[p]["meta"] = strip(b[2])
      }
    }
  }

  if(checkexists(Home "projimp.cfg", "botwiki.awk")) {
    for(i = 1; i <= splitn(Home "projimp.cfg", a, i); i++) {
      if(a[i] ~ /^[#]/)                        # Ignore comment lines starting with #
        continue
      else if(a[i] ~ /^default.id/) {
        split(a[i],b,"=")
        ConfigImp["default"]["id"] = strip(b[2])
      }
      else if(a[i] ~ /[.]data/) {
        split(a[i], b, "=")
        p = gensub(/[.]data$/,"","g",strip(b[1]))
        ConfigImp[p]["data"] = strip(b[2])
      }
      else if(a[i] ~ /[.]meta/) {
        split(a[i], b, "=")
        p = gensub(/[.]meta$/,"","g",strip(b[1]))
        ConfigImp[p]["meta"] = strip(b[2])
      }
    }
  }

  if(length(Config) == 0 && length(ConfigImp) == 0) {
    stdErr("botwiki.awk readprojectcfg(): Unable to find project.cfg and/or projimp.cfg")
    exit
  }

}

#
# setProject - given a project ID, populate global array Project[]
#
#   Example:
#      setProject(id)
#      print Project["meta"] Project["data"] Project["id"]
#
function setProject(pid) {

        delete Project  # Global array

       # Config[] = projimp.cfg if pid == impxxx
       #  otherwise default to project.cfg
        if(pid ~ /^imp/) {
          for (i in ConfigImp) {
            if (isarray(ConfigImp[i])) {
              for (j in ConfigImp[i]) {
                Config[i][j] = ConfigImp[i][j]
              }
            }
            else
              Config[i] = ConfigImp[i]
          }
        }

        if(pid ~ /error/) {
          stdErr("Unknown project id. Using default in project.cfg")
          Project["id"] = Config["default"]["id"]
        }
        else if(pid == "" || pid ~ /unknown/ )  
          Project["id"] = Config["default"]["id"]
        else
          Project["id"] = pid

        for(o in Config) {
          if(o == Project["id"] ) {         
            for(oo in Config[o]) {
              if(oo == "data")
                Project["data"] = Config[o][oo]          
              else if(oo = "meta")
                Project["meta"] = Config[o][oo]          
            }
          } 
        } 

        if(Project["data"] == "" || Project["id"] == "" || Project["meta"] == "" ) {
          stdErr("botwiki.awk setProject(): Unable to determine Project")
          exit
        }

        Project["auth"]   = Project["meta"] "auth"
        Project["index"]  = Project["meta"] "index"
        Project["indextemp"]  = Project["meta"] "index.temp"
        Project["discovered"] = Project["meta"] "discovered"       # Articles that have changes made (for import to AWB)
        Project["discovereddone"] = Project["meta"] "discovered.done"         # Articles successfully processed by push2wiki.awk
        Project["discoverederror"] = Project["meta"] "discovered.error"       # Articles generated error during push2wiki.awk
        Project["discoverednochange"] = Project["meta"] "discovered.nochange" # Articles generated no change during push2wiki.awk
        Project["authdemon"] = Project["meta"] "auth.demon"        # Articles processed by push2wiki that need re-processing due to edit conflict

        if(BotName == "waybackmedic") {
          Project["wayall"] = Project["meta"] "wayall"               # List of all IA links
          Project["allwebcite"] = Project["meta"] "allwebcite"       # List of all WebCite links
          Project["allarchiveis"] = Project["meta"] "allarchiveis"   # List of all Archive.is links
          Project["alllocgov"] = Project["meta"] "alllocgov"         # List of all loc.gov links
          Project["allporto"] = Project["meta"] "allporto"           # List of all Portugal links
          Project["allstanford"] = Project["meta"] "allstanford"     # List of all Stanford links
          Project["allarchiveit"] = Project["meta"] "allarchiveit"   # List of all Archive-it.org links
          Project["allbibalex"] = Project["meta"] "allbibalex"       # List of all Bibalex.org links
          Project["allnatarchivesuk"] = Project["meta"] "allnatarchivesuk" # List of all National Archives (UK) links
          Project["alleuropa"] = Project["meta"] "alleuropa" 
          Project["allpermacc"] = Project["meta"] "allpermacc" 
          Project["allproni"] = Project["meta"] "allproni" 
          Project["allparliament"] = Project["meta"] "allparliament" 
          Project["allukweb"] = Project["meta"] "allukweb" 
          Project["allcanada"] = Project["meta"] "allcanada" 
          Project["allcatalon"] = Project["meta"] "allcatalon" 
          Project["allsingapore"] = Project["meta"] "allsingapore" 
          Project["allslovene"] = Project["meta"] "allslovene" 
          Project["allfreezepage"] = Project["meta"] "allfreezepage" 
          Project["allwebharvest"] = Project["meta"] "allwebharvest" 
          Project["allnlaau"] = Project["meta"] "allnlaau" 
          Project["allwikiwix"] = Project["meta"] "allwikiwix" 
          Project["allyork"] = Project["meta"] "allyork" 
          Project["allmemory"] = Project["meta"] "allmemory" 
          # newwebarchives

          Project["allitems"] = Project["meta"] "allitems"           # List of all archive.org /items/ links
          Project["newiadate"] = Project["meta"] "newiadate"         # Log of cases when the IA snapshot date changed
          Project["newaltarch"] = Project["meta"] "newaltarch"       # Log of cases when alternative archive's are added
          Project["newaltarchinx"] = Project["meta"] "newaltarchinx" # Index to cached copy of webpage that was found
          Project["newialink"] = Project["meta"] "newialink"         # Log of cases when new IA links are added
          Project["manual"] = Project["meta"] "manual"               # Manual processing needed
          Project["timeout"] = Project["meta"] "timeout"             # Remote server timed out
          Project["apimismatch"] = Project["meta"] "apimismatch"     # API returned fewer records than sent. name|sent|received
          Project["jsonmismatch"] = Project["meta"] "jsonmismatch"   # API returned different size csv files. name|csv1|csv2
          Project["servicename"] = Project["meta"] "servicename"     # Archive service name found is unknown. Update servicename() in medic.awk
          Project["bogusapi"] = Project["meta"] "bogusapi"           # IA API returned a bogus recommendation. Page actually works.
          Project["bummer"] = Project["meta"] "bummer"               # Found a bummer page. 
          Project["robotstxt"] = Project["meta"] "robotstxt"         # Found a robots.txt block. 
          Project["docfixes"] = Project["meta"] "Documentation"      # Documentation / fix revisions for this project
          Project["cbignore"] = Project["meta"] "cbignore"           # {{cbignore|bot=medic}} was added to these articles
          Project["critical"] = Project["meta"] "critical"           # Critical system errors
          Project["phantom"] = Project["meta"] "phantom"             # Has > 0 GX.changes but no changes to GX.articlework

          Project["wayrm"]  = Project["meta"] "wayrm"                # IA links deleted from articles
          Project["wayrmfull"]  = Project["meta"] "wayrmfull"        # Formated to be run through medic.awk for testing

          Project["log404"] = Project["meta"] "log404"
          Project["logspurone"] = Project["meta"] "logspurone"
          Project["logmissprot"] = Project["meta"] "logmissprot"
          Project["logmissweb"] = Project["meta"] "logmissweb"
          Project["logemptyarch"] = Project["meta"] "logemptyarch"
          Project["logtrail"] = Project["meta"] "logtrail"
          Project["logemptyway"] = Project["meta"] "logemptyway"
          Project["logencode"] = Project["meta"] "logencode"
          Project["logskindeep"] = Project["meta"] "logskindeep"
          Project["logdoubleurl"] = Project["meta"] "logdoubleurl"
          Project["logdatemismatch"] = Project["meta"] "logdatemismatch"
          Project["logwronghttps"] = Project["meta"] "logwronghttps"
          Project["logwam"] = Project["meta"] "logwam"
          Project["logstraydt"] = Project["meta"] "logstraydt"
          Project["logwebcitlong"] = Project["meta"] "logwebcitlong"
          Project["logbadstatusother"] = Project["meta"] "logbadstatusother"
          Project["logarchiveislong"] = Project["meta"] "logarchiveislong"
          Project["logciteaddl"] = Project["meta"] "logciteaddl"
          Project["logbrbug"] = Project["meta"] "logbrbug"
          Project["lognowikiway"] = Project["meta"] "lognowikiway"
          Project["logiats"] = Project["meta"] "logiats"
          Project["logembway"] = Project["meta"] "logembway"
          Project["logembwebarchive"] = Project["meta"] "logembwebarchive"
          Project["logfixswitch"] = Project["meta"] "logfixswitch"
          Project["logfixitems"] = Project["meta"] "logfixitems"
          Project["logdoublewebarchive"] = Project["meta"] "logdoublewebarchive"
          Project["logpctmagic"] = Project["meta"] "logpctmagic"
          Project["log3slash"] = Project["meta"] "log3slash"
        }
}

#
# verifypid - check if -p has no value. Usage in getopt()
#
function verifypid(pid) {
  if(pid == "" || substr(pid,1,1) ~ /^[-]/)
    return "error"
  return pid
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
# sendlog - log (append) a line in a text file
#
#   . if you need more than 2 columns (ie. name|msg) format msg with separators in the string itself. 
#   . if flag="noclose" don't close the file (flush buffer) after write. Useful when making many
#     concurrent writes, particularly running under GNU parallel.
#   . if flag="space" use space as separator 
#
function sendlog(database, name, msg, flag,    safed,safen,safem,sep) {

  safed = database
  safen = name
  safem = msg
  gsub(/"/,"\42",safed)
  gsub(/"/,"\42",safen)
  gsub(/"/,"\42",safem)

  if(flag ~ /space/)
    sep = " " 
  else
    sep = " ---- "

  if(length(safem))
    print safen sep safem >> database
  else
    print safen >> database

  if(flag !~ /noclose/)
    close(database)
}

#
# getwikisource - download plain wikisource. 
#
# . default: follows "#redirect [[new name]]"
# . optional: redir = "follow/dontfollow"
#
function getwikisource(namewiki, redir,    f,ex,k,a,b,command,urlencoded,r,redirurl) {

  if(redir !~ /follow|dontfollow/)
    redir = dontfollow

  urlencoded = urlencodeawk(strip(namewiki))

  # See notes on action=raw at: https://phabricator.wikimedia.org/T126183#2775022

  command = "https://en.wikipedia.org/w/index.php?title=" urlencoded "&action=raw"
  f = http2var(command)
  if(length(f) < 5) {                                             # Bug in ?action=raw - sometimes it returns a blank page
    command = "https://en.wikipedia.org/wiki/Special:Export/" urlencoded
    f = http2var(command)
    if(tolower(f) !~ /[#][ ]{0,}redirect[ ]{0,}[[]/) {
      split(f, b, /<text xml[^>]*>|<\/text/)
      f = convertxml(b[2])
    }
  }

  if(tolower(f) ~ /[#][ ]{0,}redirect[ ]{0,}[[]/) {
    print "Found a redirect:"
    match(f, /[#][ ]{0,}[Rr][Ee][^]]*[]]/, r)
    print r[0]
    if(redir ~ /dontfollow/) {
      print namewiki " : " r[0] >> "redirects"
      return "REDIRECT"
    }
    gsub(/[#][ ]{0,}[Rr][Ee][Dd][Ii][^[]*[[]/,"",r[0])
    redirurl = strip(substr(r[0], 2, length(r[0]) - 2))

    command = "https://en.wikipedia.org/w/index.php?title=" urlencodeawk(redirurl) "&action=raw"
    f = http2var(command)
  }
  return strip(f)

}

#
# validate_datestamp - return "true" if 14-char datestamp is a valid date
#
function validate_datestamp(stamp,   vyear, vmonth, vday, vhour, vmin, vsec) {

  if(length(stamp) == 14) {

    vyear = substr(stamp, 1, 4)
    vmonth = substr(stamp, 5, 2)
    vday = substr(stamp, 7, 2)
    vhour = substr(stamp, 9, 2)
    vmin = substr(stamp, 11, 2)    
    vsec = substr(stamp, 13, 2)

    if (vyear !~ /^(19[0-9]{2}|20[0-9]{2})$/) return "false"
    if (vmonth !~ /^(0[1-9]|1[012])$/) return "false"
    if (vday !~ /^(0[1-9]|1[0-9]|2[0-9]|3[01])$/) return "false"
    if (vhour !~ /^(0[0-9]|1[0-9]|2[0123])$/) return "false"
    if (vmin !~ /^(0[0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9])$/) return "false"
    if (vsec !~ /^(0[0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9])$/) return "false"

  }
  else
    return "false"

  return "true"

}

#
# stopbutton - check status of stop button page
#
#  . return RUN or STOP
#  . stop button page URL defined globally as 'StopButton' in botwiki.awk BEGIN{} section
#
function stopbutton(button,bb,  command,butt,i) {

 # convert https://en.wikipedia.org/wiki/User:GreenC_bot/button
 #         https://en.wikipedia.org/w/index.php?title=User:GreenC_bot/button
  if(urlElement(StopButton, "path") ~ /^\/wiki\// && urlElement(StopButton, "netloc") ~ /wikipedia[.]org/) 
    StopButton = subs("/wiki/", "/w/index.php?title=", StopButton)

  command = "timeout 20s wget -q -O- " shquote(StopButton "&action=raw")
  button = sys2var(command)

  if(button ~ /[Aa]ction[ ]{0,}[=][ ]{0,}[Rr][Uu][Nn]/)
    return "RUN"      

  butt[2] = 2; butt[3] = 20; butt[4] = 60; butt[5] = 240
  for(i = 2; i <= 5; i++) {
    if(length(button) < 2) {           
      stdErr("Button try " i " - ", "n")
      sleep(butt[i], "unix")
      button = sys2var(command)          
    }  
    else break       
  }

  if(length(button) < 2) {              
    stdErr("Aborted Button (page blank? wikipedia down?) - ", "n")        
    return "RUN"               
  }

  if(button ~ /[Aa]ction[ ]{0,}[=][ ]{0,}[Rr][Uu][Nn]/)
    return "RUN"

  stdErr("ABORTED by stop button page. " name)
  while(bb++ < 5)  {                                          
    bell()
    sleep(2)
    bell()
    sleep(4)
  }
  sleep(864000, "unix")      # sleep up to 24 days .. no other way to stop GNU parallel from running
  return "STOP"
}


#
# whatistempid - return the path/tempid of a name
#
#   . given first field of an index file, return second field
#   . 'indexfile' is optional, if not given use Project["index"]
#   . this function uses global vars INDEXA and INDEXC for performance caching
#       caution observed if accessing multiple index files in the same program 
#
#   Example:
#      > grep "George Wash" $meta/index
#        ==> George Wash|/home/adminuser/wi-awb/temp/wi-awb-0202173111/
#      print whatistempidcache("George Wash")
#        ==> /home/adminuser/wi-awb/temp/wi-awb-0202173111/
#
function whatistempid(name,indexfile,   i,a,b) {

  if(empty(INDEXC)) {
    if(empty(indexfile))
      indexfile = Project["index"]
    if(! checkexists(indexfile) ) {
      stdErr("botwiki.awk (whatistempid): Error unable to find " shquote(indexfile) " for " name )
      return
    }
    for(i = 1; i <= splitn(indexfile, a, i); i++) {
      split(a[i], b, /[|]/)
      INDEXA[strip(b[1])] = strip(b[2])
    }
    INDEXC = length(INDEXA)
  }
  return INDEXA[name]
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
# deflate() - Collapse article - selected common-things so it doesn't mess with parsing cites
#
#  . If opt = "magic" then convert wikipedia magic templates to percent-encoded within URLs
#      eg. {{!}} = "|" = %7D
#    Use this option if your program will be operating on URLs such as checking they work or modifying them
#
function deflate(article,opt,   c,i,field,sep,inner,re,loopy,j,codename,ReSpace,ReTemplate) {

  ReSpace = "[\n\r\t]*[ ]*[\n\r\t]*[ ]*[\n\r\t]*"
  ReTemplate = "[{]" ReSpace "[{][^}]+[}]" ReSpace "[}]"

  # Collapse newlines 
  gsub("\n"," zzCRLFzz",article)  

  # Replace "{{date|data}}" with "dateZzPp1z" and populate global array InnerDd["dateZzPp1z"] = "{{date|data}}"
  re = "[{]" ReSpace "[{]" ReSpace "date[^}]*[}]" ReSpace "[}]"
  c = patsplit(article, field, re, sep)
  for(i = 1; i <= c; i++) {
    re = "[{]" ReSpace "[{][^{]*[{]" ReSpace "[{]"
    if(field[i] ~ re)
      continue
    codename = "dateZzPp" i "z"
    InnerDd[codename] = field[i]
    field[i] = codename
  }
  if(c > 0) article = unpatsplit(field, sep)

  # Replace "|id={{template|data}}" with "|id=idQqYy1z" and populate global array InnerId["idQqYy1z"] = "|id={{template|data}}"
  # Repeat for other commonly templated arguments
  split("id|ref|url|author|title|work|publisher|contribution|quote|website|editor|series", loopy, /[|]/)
  for(j in loopy) {
    re = "[|]" ReSpace loopy[j] ReSpace "[=]" ReSpace ReTemplate
    c = patsplit(article, field, re, sep)
    for(i = 1; i <= c; i++) {
      if(match(field[i], ReTemplate, inner) ) {
        re = "[{]" ReSpace "[{][^{]*[{]" ReSpace "[{]"
        if(field[i] ~ re)
          continue
        codename = loopy[j] "QqYy" i "z"
        field[i] = gsubs(inner[0], codename, field[i])
        InnerId[codename] = inner[0]
      }
    }
    if(c > 0) article = unpatsplit(field, sep)
  }

  # Replace "{{template}}" with "aAxXQq1z" and populate global array InnerSd["aAxXQq1z"] = "{{template}}"
  # Repeat for other common templates
  i = 0
  split("{{=}}|{{!}}|{{'}}|{{snd}}|{{spnd}}|{{sndash}}|{{spndash}}|{{Spaced en dash}}|{{spaced en dash}}|{{·}}|{{•}}|{{\\}}|{{en dash}}|{{em dash}}|{{-'}}", loopy, /[|]/)
  for(j in loopy) {
    i++
    codename = "aAxXQq" i "z"
    InnerSd[codename] = loopy[j]
    article = gsubs(InnerSd[codename], codename, article)
  }

  # Within URLs, convert Wikipedia magic characters to percent-encoded 

  if(opt == "magic") {
    c = patsplit(article, field, "[Hh][Tt][Tt][Pp][^ <|\\]}\n\t]*[^ <|\\]}\n\t]", sep)
    for(i = 1; i <= c; i++) {
      if(field[i] ~ /aAxXQq1z/)              # aAxXQq1z is {{=}} is "=" is %3D
        field[i] = gsubs("aAxXQq1z", "%3D", field[i])
      if(field[i] ~ /aAxXQq2z/)              # aAxXQq2z is {{!}} is "|" is %7C
        field[i] = gsubs("aAxXQq2z", "%7C", field[i])
    }
    if(c > 0) article = unpatsplit(field, sep)
  }
  
  return article

}
#
# Re-inflate article in reverse order
#
function inflate(articlenew, i) {

    for(i in InnerSd)
      articlenew = gsubs(i, InnerSd[i], articlenew)
    for(i in InnerId)
      articlenew = gsubs(i, InnerId[i], articlenew)
    for(i in InnerDd)
      articlenew = gsubs(i, InnerDd[i], articlenew)
    gsub(/[ ]zzCRLFzz/,"\n",articlenew)

    return articlenew
}


#
# Return true if s is an encoded template
#  Optional second argument: date, template, static (ie. ZzPp, QqYy, aAxXQq - respective)
#            
function istemplate(s, code) {

  if(code == "date") {
    if(s ~ /ZzPp/) return 1
  }
  else if(code == "template") {
    if(s ~ /QqYy/) return 1
  }
  else if(code == "static") {
    if(s ~ /aAxXQq/) return 1       
  }    
  else {
    if(s ~ /ZzPp|QqYy|aAxXQq/) return 1       
  }
  return 0
}

#
# isembedded - given a template, return true if it contains an embedded template
#    Example:
#        print isembedded( "{{cite web|date{{august 1|mdy}}" }} ==> 1
#
function isembedded(tl) {
  if (tl ~ /[{][{][^{]*[{][{]/)
    return 1
  return 0
}
