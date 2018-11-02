#!/usr/local/bin/gawk -E   

#
# Initialize a new project
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
  while ((C = getopt(ARGC, ARGV, "jfyabicxhp:d:m:s:t:v:e:u:")) != -1) { 
      opts++
      if(C == "p")                 #  -p <project>   Use project name. No default.
        pid = verifypid(Optarg)
      if(C == "d")                 #  -d <data dir>  Data directory. Defaults to default.data in project.cfg
        did = verifyval(Optarg)
      if(C == "m")                 #  -m <data dir>  Meta directory. Defaults to default.meta in project.cfg
        mid = verifyval(Optarg)
      if(C == "c")                 #  -c             Create project files. -p required
        type = "create"
      if(C == "i")                 #  -i             Build index from scratch from data directory. -p required
        type = "index"
      if(C == "y")                 #  -y             Check for corruption in data files. -p required
        type = "corrupt"
      if(C == "j")                 #  -j             Re-assemble index file after all driver's completed. -p required
        type = "assemble"
      if(C == "x")                 #  -x             Delete project files. -p required
        type = "delete"
      if(C == "a")                 #  -a             Verify fixemptyarchive. -p required
        type = "fixemptyarchive"
      if(C == "b")                 #  -b             Verify fixspurone. -p required
        type = "fixspurone"        
      if(C == "s") {               #  -s <filename>  Search for a string inside a file in the data directory
        type = "checkstring"        
        searchfile = verifyval(Optarg)
      }
      if(C == "u") {               #  -s <filename>  Search for a string inside a file in the meta directory
        type = "metacheck"        
        searchfile = verifyval(Optarg)
      }
      if(C == "t") {               #  -t <filename>  Generate project statistics. Filename contains a list of project IDs
        type = "stats"        
        statsfile = verifyval(Optarg)
      }
      if(C == "e") {               #  -e <filename>  IMP: reprocess iabget <file> (iabget, iabget.error or iabget.p2b) 
        type = "impredo"        
        iabgetfile = verifyval(Optarg)
      }
      if(C == "f")                 #  -f             Run -e in memory for reduced disk access - faster performance at cost
        Runinmem = 1               #                 of > memory usage and loss of data if a crash/abort. Use this when running medic in another window.

      if(C == "v")
        type = "verifywayrm"       #  -v             Verify links in wayrm
        verifyurl = Optarg

      if(C == "h") {
        usage()
        exit
      }
  }

 # No options or an empty -p given
  if( type == "" || (type ~ /delete|create|index|corrupt|assemble|verifywayrm/ && pid == "") || pid ~ /error/ ) {
    usage()
    exit
  }

 # IMP project
  if(pid ~ /^imp/) 
    imp = 1    

  if(imp) {
    Config["default"]["data"] = ConfigImp["default"]["data"]
    Config["default"]["meta"] = ConfigImp["default"]["meta"]
  }

 # Load default Data and Meta from project.cfg 
  if(did == "") 
    did = Config["default"]["data"]
  if(mid == "") 
    mid = Config["default"]["meta"]
  if(did == "" || mid == "") {
    print "Error: Unable to determine Data or Meta directories. Create project.cfg with default.data and default.meta"
    exit
  }

  if(type ~ /impredo/) {
    if(length(iabgetfile) > 0)
      redoiabget(iabgetfile, mid, pid)
    exit
  }
  if(type ~ /stats/) {
    if(length(statsfile) > 0)
      statistics(statsfile, mid)
    exit
  }
  if(type ~ /checkstring/) {
    if(length(searchfile) > 0)
      check_string(searchfile, pid, did, mid)
    exit
  }
  if(type ~ /metacheck/) {
    if(length(searchfile) > 0)
      check_stringmeta(searchfile, pid, did, mid)
    exit
  }
  if(type ~ /fixemptyarchive/) {
    check_fixemptyarchive(pid, did, mid)
    exit
  }
  if(type ~ /fixspurone/) {
    check_fixspurone(pid, did, mid)
    exit
  }

  if(type ~ /index/ ) {
    makeindex(pid,did,mid)
    exit
  }

  if(type ~ /corrupt/ ) {
    corruption(pid,did,mid)
    exit
  }

  if(type ~ /assemble/ ) {
    assemble(pid,did,mid)
    exit
  }

  if(type ~ /verifywayrm/ ) {
    verify_wayrm(pid,did,mid,verifyurl)
    exit
  }

  if(type ~ /delete/) {
    deleteproject(pid,mid,did)
    exit
  }
  
 # Everything following is type = create

 # Check everything looks ok
  if(substr(did,length(did),1) != "/" || substr(mid,length(mid),1) != "/") {
    print "Error: data and meta should end in a trailing slash. Maybe check project.cfg for default.data/meta"
    exit
  }

 # Make Data and Meta directories
  if(checkexists(did pid)) 
    print "Error: Data directory already exists: " did pid
  else {
    print "OK Creating " did pid
    sys2var(Exe["mkdir"] " " did pid)
    checkexists(did pid, "project.awk", "exit")
  }
  if(checkexists(mid pid)) 
    print "Error: Meta directory already exists: " mid pid
  else {
    print "OK Creating " mid pid
    sys2var(Exe["mkdir"] " " mid pid)
    checkexists(mid pid, "project.awk", "exit")
  }

  if(imp)
    newprojcfg("projimp.cfg")
  else
    newprojcfg("project.cfg")

 # Create .auth file (for IMP see imp.awk)
  if(! imp) {
    split(pid,a,".")
    if(checkexists(mid a[1] ".auth")) {
      if(a[2] ~ /[0-9]{1,5}[-][0-9]{1,5}/) {
        c = split(a[2],b,"-")
        if(c == 2 && strip(b[1]) ~ /^[0-9]+$/ && strip(b[2]) ~ /^[0-9]+$/) {
          start = strip(b[1])
          end = strip(b[2])
          if(! checkexists(mid pid "/auth")) {
            # head -n 750 meta/births1870.auth | tail -n 250 > /home/adminuser/wi-awb/meta/births1870.501-750/auth
            command = Exe["head"] " -n " end " " mid a[1] ".auth | " Exe["tail"] " -n " int( int(end) - int( int(start) - 1) ) " > " mid pid "/auth"
            print "OK creating " mid pid "/auth"
            sys2var(command)
          }
          else            
            print "Auth file " mid pid "/auth already exists. Not creating new one."
        }           
        else                       
          print "(1) Project ID doesn't take the form Name.####-#### - Unable to create " mid pid "/auth"
      }   
      else
        print "(2) Project ID doesn't take the form Name.####-#### - Unable to create " mid pid "/auth"
    }
    else {
      print "Unable to find " mid a[1] ".auth - Unable to create " mid pid "/auth"
    }
  }

 # Cp scripts into meta directory
  if(imp) {
    print "OK copying scripts/* to " mid pid
    command = Exe["cp"] " scripts/deletename.awk " mid pid
    sys2var(command)
    command = Exe["cp"] " scripts/deletenamewrapimp " mid pid
    sys2var(command)
    command = Exe["cp"] " scripts/criticalrunimp " mid pid
    sys2var(command)
    command = Exe["cp"] " scripts/createmosaic " mid pid
    sys2var(command)
    command = Exe["cp"] " scripts/monitor " mid pid
    sys2var(command)
  }

  else {
    print "OK copying scripts/* to " mid pid
    command = Exe["cp"] " scripts/deletename.awk " mid pid
    sys2var(command)
    command = Exe["cp"] " scripts/deletenamewrapper " mid pid
    sys2var(command)
    command = Exe["cp"] " scripts/criticalrun " mid pid
    sys2var(command)
    command = Exe["cp"] " scripts/sqlrun " mid pid
    sys2var(command)
    command = Exe["cp"] " scripts/push " mid pid
    sys2var(command)
    command = Exe["cp"] " scripts/monitor " mid pid
    sys2var(command)
  }

}

#
# Write new project.cfg
#
function newprojcfg(cfgname,  i,a,c,re) {

  # Remove leading and trailing blank lines
  print stripfile(Home cfgname) > Home cfgname ".orig"
  close(Home cfgname ".orig")
  print "OK Saving " cfgname " to " cfgname ".orig"

  # Set new default
  re = "^default[.]id"   

  for(i = 1; i <= splitn(Home cfgname ".orig", a, i); i++) {
    if(a[i] ~ re) {
      a[i] = "default.id = " pid
      break
    }
  }
  c = length(a)
  if(i == c) 
    print "Unable to set default.id"
  else
    print "OK Setting default.id = " pid

  # Create new .data and .meta 
  a[c + 1] = pid ".data = " did pid "/"
  a[c + 2] = pid ".meta = " mid pid "/"

  print "OK Writing new " cfgname

  if(checkexists(Home cfgname)) 
    removefile(Home cfgname)

  i = 0
  while(i++ < c + 2) 
    print a[i] >> Home cfgname

  close(Home cfgname)

}

#
# Return 1 if name is in file
#
function nameisinfile(name, filen,    s, a, re) {

  checkexists(filen, "project.awk nameisinfile()", "exit")

  re = "^" regesc2(strip(name)) "$"
  while ((getline s < filen ) > 0) {
    split(s, a, "|")
    if(strip(a[1]) ~ re) {
      close(filen)
      return 1
    }
  }
  close(filen)
  return 0
}

#
# Make an index based on files in data directory
#
function makeindex(pid,did,mid,    data,meta,a) {

  data = did pid "/"
  meta = mid pid "/"

  if( ! checkexists(data) || ! checkexists(meta) ) {
    print "Unable to find " data " OR " meta
    exit
  }
  if(checkexists(meta "index")){
    print "File exists, aborting."
    print "To delete: rm " meta "index"
    exit
  }

  # list directories only
  # https://stackoverflow.com/questions/14352290/listing-only-directories-using-ls-in-bash-an-examination
  c = split( sys2var(Exe["ls"] " -d1 " data "wm*/"), a, "\n")
  while(i++ < c) {
    if( ! exists(a[i] "namewiki.txt") )
      print "Unable to find " a[i] "namewiki.txt" > "/dev/stderr"
    else 
      print strip(readfile(a[i] "namewiki.txt")) "|" a[i] >> meta "index"
  }
  close(meta "index")

}

#
# Check for data corruption. 
#  If namewiki string is not contained in article.txt 
#
function corruption(pid,did,mid,    data,meta,a,namewiki,command) {

  data = did pid "/"
  meta = mid pid "/"

  if( ! checkexists(data) || ! checkexists(meta) ) {
    print "Unable to find " data " OR " meta
    exit
  }

  # list directories only
  # https://stackoverflow.com/questions/14352290/listing-only-directories-using-ls-in-bash-an-examination
  c = split( sys2var(Exe["ls"] " -d1 " data "wm*/"), a, "\n")
  while(i++ < c) {
    if( ! exists(a[i] "namewiki.txt") )
      print "Unable to find " a[i] "namewiki.txt" > "/dev/stderr"
    else {
      namewiki = readfile(a[i] "namewiki.txt") 
      gsub(/["]/,"\\\"",namewiki)
      command = Exe["grep"] " -c \"" namewiki "\" " a[i] "article.txt"
      if(sys2var(command) == "0") {
        print a[i]
      }
    }
  }
  close(meta "index")

}


#
# Assemble index from index.temp post-GNU parallel 
#  Given an index and index.temp, this will merge into index leaving only uniq entries 
#
function assemble(pid,did,mid,   data,meta,indextemp,indexmain,d,dd,a,c,i,b,j,k,m,outfile,gold) {

  data = did pid "/"
  meta = mid pid "/"

  outfile = mktemp(meta "index.XXXXXX", "u")

  if(!checkexists(meta "index.temp")) {
    print "Unable to find " meta "index.temp" 
    exit
  }

  if(!checkexists(meta "index")) {                          # If no index, just rename file
    sys2var(Exe["mv"] " " meta "index.temp " meta "index")
    exit
  }

  sys2var(Exe["cp"] " " meta "index " meta "index.orig")

  c = split(readfile(meta "index.temp"), a, "\n")           
  while(i++ < c) {
    if(length(a[i]) > 5) {
      split(a[i], b, "|")
      indextemp[i]["name"] = b[1]
      k = split(b[2], m, "/")
      indextemp[i]["id"] = substr(m[k-1],4,length(m[k-1]))
      indextemp[i]["full"] = a[i]
    }
  }
  i = 0
  d = split(readfile(meta "index"), a, "\n")          
  while(i++ < d) {
    if(length(a[i]) > 5) {
      split(a[i], b, "|")
      indexmain[i]["name"] = b[1]
      k = split(b[2], m, "/")
      indextemp[i]["id"] = substr(m[k-1],4,length(m[k-1]))
      indexmain[i]["full"] = a[i]
    }
  }

  print "index.temp   = " c
  print "index.orig   = " d

  # If a record exists in both index and index.temp, replace the record in index with the one from index.temp
  i = j = 0
  gold = "no"
  while(i++ < d) {
    while(j++ < c) {
      if( indexmain[i]["name"] == indextemp[j]["name"] ) {
        if(length(indextemp[j]["full"]) > 5) {
          print indextemp[j]["full"] >> outfile
          close(outfile)
          gold = "yes"
          break
        }
      }
    }
    if(gold == "no") {
      if(length(indexmain[i]["full"]) > 5) {
        print indexmain[i]["full"] >> outfile
        close(outfile)
      }
    }
    else gold = "no"
    j = 0
  }

  # If a record exists in index.temp but not index, add it to index
  i = j = 0
  gold = "no"
  while(j++ < c) {
    while(i++ < d) {
      if( indexmain[i]["name"] == indextemp[j]["name"] ) {
        gold = "yes"
        break
      }
    }
    if(gold == "no") {
      if(length(indextemp[j]["full"]) > 5) {
        print indextemp[j]["full"] >> outfile
        close(outfile)
      }
    }
    else gold = "no"
    i = 0
  }

  system("")
  dd = split(readfile(outfile), a, "\n")          
  print "index        = " dd 
#  if(dd == d) {
    removefile(meta "index")
    sys2var(Exe["mv"] " " shquote(outfile) " " shquote(meta "index") )  
#  } 
#  else 
#    print "Index and index.orig don't match. Check " outfile " and compare with index"


}

#
# Delete project
#
function deleteproject(pid,mid,did,    i,c,re,a,cfgname) {

  if(imp) 
    cfgname = "projimp.cfg"
  else
    cfgname = "project.cfg"

 # Delete Data and Meta directories
  if( ! checkexists(did pid)) 
    print "Data directory doesn't exist: " did pid
  else {
    print "OK Deleting " did pid
    removefile(did pid, "-r")
  }
  if( ! checkexists(mid pid)) 
    print "Meta directory doesn't exist: " mid pid
  else {
    print "OK Deleting " mid pid
    removefile(mid pid, "-r")
  }

 # Remove .meta and .data lines from project.cfg but leave default.* lines untouched 
  if(checkexists(Home cfgname ".out"))
    removefile(cfgname ".out")
  if(checkexists(Home cfgname ".orig"))
    removefile(cfgname ".orig")
  if(checkexists(Home cfgname))
    command = Exe["mv"] " " Home cfgname " " Home cfgname ".orig"
  else {
    print "Unable to find " Home cfgname
    return
  }
  print "OK Making backup " cfgname " -> " cfgname ".orig"
  sys2var(command)
  system("")
  c = split(readfile(Home cfgname ".orig"),a,"\n")
  re = "^" regesc2(pid) "[.](data|meta)"     
  while(i++ < c) {
    if(a[i] ~ re) { # delete if re matches 
    }
    else {
      print a[i] >> Home cfgname ".out"
    }
  }
  close(Home cfgname ".out")
  if(checkexists(Home cfgname ".out")) {
    print stripfile(Home cfgname ".out") > Home cfgname
    close(Home cfgname)
    print "OK Removed data & meta lines from " cfgname " (default.id untouched)"
  }
  else {
    print "Unable to modify " cfgname " - restoring backup"
    sys2var(Exe["mv"] " " Home cfgname ".orig " Home cfgname)
  }
}


#
# Check each article.txt in the project data directory to verify which have the fixemptyarchive bug
#
function check_fixemptyarchive(pid, did, mid,    command,files,stampdir,c,i,re) {

  re = "archive[-]?url[ ]{0,}=[ ]{0,}[|}]"
  files = sys2var(Exe["ls"] " " did pid "/")
  c = split(files, stampdir, "\n")
  while(i++ < c) {
    command = Exe["grep"] " -cE \"" re "\" " did pid "/" stampdir[i] "/article.txt"
    count = sys2var(command)
    if(count > 0) {
      print whatisindexname(did pid "/" stampdir[i], mid pid "/index") " ( cd " did pid "/" stampdir[i] " )"
    }
  }

}
#
# Check each article.txt in the project data directory to verify which have the fixspurone bug
#
function check_fixspurone(pid, did, mid,    command,files,stampdir,c,i,re) {

  re = "[|][ ]?1[ ]?=[ ]{0,2}[|}]"
  files = sys2var(Exe["ls"] " " did pid "/")
  c = split(files, stampdir, "\n")
  while(i++ < c) {
    command = Exe["grep"] " -cE \"" re "\" " did pid "/" stampdir[i] "/article.txt"
    count = sys2var(command)
    if(count > 0) {
      print whatisindexname(did pid "/" stampdir[i], mid pid "/index") " ( cd " did pid "/" stampdir[i] " )"
    }
  }
}

#
# Search for string "re" in <filename> in meta directory
#  
function check_stringmeta(filename, pid, did, mid,    re,c,files,stampdir,i,command,count) {

  print "Processing " pid > "/dev/stderr"

 # Be careful with escaping as unsure how grep responds 
  #re = "[|][ ]url[ ][=][ ]http[^{}]*[{][{][ ]?dead[ ]link"
  re = "Check 6[.]2"

  count = 0

  if(pid == "") {
    print "\nRequires -p <projectid> .. available project IDs:\n"
    print files
    print ""
    exit
  }

  if(checkexists(mid pid "/" stampdir[i] "/" filename)) {

    #
    # Grep version for generic searches
    #

    command = Exe["grep"] " -ciE \"" re "\" " mid pid "/" stampdir[i] "/" filename

    count = sys2var(command)

    if(count > 0) {

      command = Exe["grep"] " -iE \"" re "\" " mid pid "/" stampdir[i] "/" filename
      print sys2var(command)
    }
  }

}

#
# Search for string "re" in <filename> in data directory
#
function check_string(filename, pid, did, mid,    re,c,files,stampdir,i,command,count) {

  print "Processing " pid > "/dev/stderr"

 # Be careful with escaping as unsure how grep responds 
  re = "[}][}]0"

  files = sys2var(Exe["ls"] " " did pid "/")

  count = 0

  if(pid == "") {
    print "\nRequires -p <projectid> .. available project IDs:\n"
    print files
    print ""
    exit
  }

  c = split(files, stampdir, "\n")
  while(i++ < c) {
    if(checkexists(did pid "/" stampdir[i] "/" filename)) {

#
# Grep version for generic searches
      command = Exe["grep"] " -ciE \"" re "\" " did pid "/" stampdir[i] "/" filename

#
# Awk module versions 
#
      # command = "/home/adminuser/wmnim/wm2/modules/webcitlong/webcitlong -s " did pid "/" stampdir[i] "/" filename    
      # command = "/home/adminuser/wmnim/wm2/modules/straydt/straydt -s " did pid "/" stampdir[i] "/" filename    
#      print did pid "/" stampdir[i] "/" filename 

      count = sys2var(command)

      if(count > 0) {
#         print did pid "/" stampdir[i] "/" filename
        newid = whatisindexname(did pid "/" stampdir[i], mid pid "/index")
        if(!empty(newid))
          print newid
#        print newid " ( cd " did pid "/" stampdir[i] " )"
      }
    }
  }
}

#
# Return the name portion given a path/tempid in an index (eg. /home/adminuser/wi-awb/temp/wi-awb-0202173111/)
#
#  . see also whatistempid()
#
function whatisindexname(name,indexfile,   i,a,b) {     

  sub(/\/$/,"",name)
  if(empty(_INDEXC)) {
    if(empty(indexfile))
      indexfile = Project["index"]
    if(! checkexists(indexfile) ) {
      stdErr("project.awk (whatistempid): Error unable to find " shquote(indexfile) " for " name )
      return
    }           
    for(i = 1; i <= splitn(indexfile, a, i); i++) {
      split(a[i], b, /[|]/)
      sub(/\/$/,"",b[2])
      _INDEXA[strip(b[2])] = strip(b[1])  
    }           
    _INDEXC = length(_INDEXA)
  }
  return _INDEXA[name]
}         


#
# Return the name portion given a path/tempid in an index (eg. /home/adminuser/wi-awb/temp/wi-awb-0202173111/)
#
function whatisindexname2(name, filepath,      s, a, re) {

  if(! checkexists(filepath) ) {
    print("Error unable to find " filepath ". " name )
    return 0
  }
  re = name
  while ((getline s < filepath ) > 0) {
    split(s, a, "|")
    if(strip(a[2]) ~ re) {
      close(filepath)
      return strip(a[1])       
    }
  }
  close(filepath)
  return 0
}


#
# Re-process an iabget file: -e <filename>
#
# This is a copy of push2api() from imp.awk
#
function redoiabget(iabgetfile,mid,pid,   meta,target,command,c,i,a,jsona,b,id,ppid,action,DatType) {

  MsgAdd = "Add archive"
  MsgDelete = "Delete dead archive"
  MsgReplace = "Replace or modify dead archive"

  meta = mid pid "/"
  
  if(!checkexists(meta iabgetfile)) {
    print("Error unable to find " meta iabgetfile )
    return 0
  }
  if(filesize(meta iabgetfile) == 0) {
    print("Error file is size-0: " meta iabgetfile)
    return 0
  }
  
  if(iabgetfile != "iabget") {
    target = meta "iabget.redo"
    command = Exe["mv"] " " shquote(meta iabgetfile) " " shquote(target)
    print command
    system(command) 
  }
  else
    target = meta iabgetfile

  for(i = 1; i <= splitn(target, a, i); i++) {
    if(a[i] ~ "iabget") {

      print "[___________ (" i "/" length(a) ") ___________]"
      print a[i]

     # remove first line from target
      if(Runinmem != 1) {
        command = Exe["tail"] " -n +2 " shquote(target) " > " shquote(meta "iabget.temp")
        sys2var(command)         
        command = Exe["mv"] " " shquote(meta "iabget.temp") " " shquote(target)
        sys2var(command)   
      }

     # run iabget command, save result in jsona[]

      if( query_json(sys2var(a[i]), jsona) < 0) {
        print "  -->ERROR with JSON data"
        print a[i] >> meta "iabget.error"
        if(Runinmem != 1)
          close(meta "iabget.error")
        continue
      }

      if(jsona["result"] == "success") {
        print "  -->SUCCESS upload to API"
        print a[i] >> meta "iabget.done"
        if(Runinmem != 1) 
          close(meta "iabget.done")

       # add entry to iabget.log

       # imp.awk
        if(match(a[i], /IMPID[:][^)]*[^)]/, dest) > 0) {     
          gsub(/^IMPID[:][ ]*/,"",dest[0])
          split(dest[0],b,".")
          id = strip(b[3])                      # urlid
          ppid = strip(b[1]) "." strip(b[2])    # project id
          if(a[i] ~ MsgDelete)
            action = "delete"
          else if(a[i] ~ MsgReplace)
            action = "modify"
          else if(a[i] ~ MsgAdd)
            action = "add"
          print id " " ppid " " dateeight() " " action >> meta "iabget.log"
          if(Runinmem != 1)
            close(meta "iabget.log")
        }
       # iab.awk
        else if(match(a[i], /[{][&][}]reason[=][^$]*[^$]?/, dest) > 0) {
          split(dest[0], b, /[ ][|][ ]/)    
          action = strip(subs("{&}reason=", "", b[1]))
          ppid = strip(b[3])
          sub(/['][^$]*[^$]?/, "", b[5])       
          sub(/^[ ]*url[ ]*/,"", b[5])            
          print b[5] " " ppid " " dateeight() " " action >> meta "iabget.log"
          if(Runinmem != 1)
            close(meta "iabget.log")
        }
      }
      else {                         
        print "  -->ERROR upload to API"
        print a[i] >> meta "iabget.error"
        if(Runinmem != 1)
          close(meta "iabget.error")
      }                  

    }                                       
    else {
      if(! empty(strip(a[i]))) {
        print "  -->UNKNOWN entry in " iabgetfile
        print a[i] >> meta "iabget.unknown"
        if(Runinmem != 1)
          close(meta "iabget.unknown")
      }
      if(Runinmem != 1) {
        command = Exe["tail"] " -n +2 " shquote(target) " > " shquote(meta "iabget.temp")
        sys2var(command)         
        command = Exe["mv"] " " shquote(meta "iabget.temp") " " shquote(target)
        sys2var(command)   
      }
    }
  }

  if(Runinmem == 1) {
    printf "" > target
    close(target)
  }


}


#
# Generate project stats. Create a file with a list of project ID's and run with the -t <filename> switch
#
function statistics(statsfile, mid,    c,a,i,b) {

  if(! checkexists(statsfile) ) {
    print("Error unable to find " statsfile )
    return 0
  }
  c = split(readfile(statsfile), a, "\n")

  while(i++ < c) {
    if(length(a[i]) > 1) {
      stats[a[i]]["bummer"] = split(strip(readfile(mid a[i] "/bummer")), b, "\n")
      stats[a[i]]["robotstext"] = split(strip(readfile(mid a[i] "/robotstext")), b, "\n")
      stats[a[i]]["bogusapi"] = split(strip(readfile(mid a[i] "/bogusapi")), b, "\n")
      stats[a[i]]["apimismatch"] = split(strip(readfile(mid a[i] "/apimismatch")), b, "\n")
      stats[a[i]]["discovered"] = split(strip(readfile(mid a[i] "/discovered")), b, "\n")
      stats[a[i]]["discovereddone"] = split(strip(readfile(mid a[i] "/discovered.done")), b, "\n")
      stats[a[i]]["processed"] = split(strip(readfile(mid a[i] "/auth")), b, "\n")
      stats[a[i]]["jsonmismatch"] = split(strip(readfile(mid a[i] "/jsonmismatch")), b, "\n")
      stats[a[i]]["log404"] = split(strip(readfile(mid a[i] "/log404")), b, "\n")
      stats[a[i]]["logemptyarch"] = split(strip(readfile(mid a[i] "/logemptyarch")), b, "\n")
      stats[a[i]]["logemptyway"] = split(strip(readfile(mid a[i] "/logemptyway")), b, "\n")
      stats[a[i]]["logencode"] = split(strip(readfile(mid a[i] "/logencode")), b, "\n")
      stats[a[i]]["logspurone"] = split(strip(readfile(mid a[i] "/logspurone")), b, "\n")
      stats[a[i]]["logtrail"] = split(strip(readfile(mid a[i] "/logtrail")), b, "\n")
      stats[a[i]]["logdeadurl"] = split(strip(readfile(mid a[i] "/logdeadurl")), b, "\n")
      stats[a[i]]["logskindeep"] = split(strip(readfile(mid a[i] "/logskindeep")), b, "\n")
      stats[a[i]]["logdoubleurl"] = split(strip(readfile(mid a[i] "/logdoubleurl")), b, "\n")
      stats[a[i]]["logdatemismatch"] = split(strip(readfile(mid a[i] "/logdatemismatch")), b, "\n")
      stats[a[i]]["logwronghttps"] = split(strip(readfile(mid a[i] "/logwronghttps")), b, "\n")
      stats[a[i]]["logwam"] = split(strip(readfile(mid a[i] "/logwam")), b, "\n")
      stats[a[i]]["logstraydt"] = split(strip(readfile(mid a[i] "/logstraydt")), b, "\n")
      stats[a[i]]["logwebcitlong"] = split(strip(readfile(mid a[i] "/logwebcitlong")), b, "\n")
      stats[a[i]]["logbadstatusother"] = split(strip(readfile(mid a[i] "/logbadstatusother")), b, "\n")
      stats[a[i]]["logarchiveislong"] = split(strip(readfile(mid a[i] "/logarchiveislong")), b, "\n")
      stats[a[i]]["logciteaddl"] = split(strip(readfile(mid a[i] "/logciteaddl")), b, "\n")
      stats[a[i]]["lognowikiway"] = split(strip(readfile(mid a[i] "/lognowikiway")), b, "\n")
      stats[a[i]]["logbrbug"] = split(strip(readfile(mid a[i] "/logbrbug")), b, "\n")
      stats[a[i]]["logiats"] = split(strip(readfile(mid a[i] "/logiats")), b, "\n")
      stats[a[i]]["logembway"] = split(strip(readfile(mid a[i] "/logembway")), b, "\n")
      stats[a[i]]["logembwebarchive"] = split(strip(readfile(mid a[i] "/logembwebarchive")), b, "\n")
      stats[a[i]]["logfixswitch"] = split(strip(readfile(mid a[i] "/logfixswitch")), b, "\n")
      stats[a[i]]["logfixitems"] = split(strip(readfile(mid a[i] "/logfixitems")), b, "\n")
      stats[a[i]]["logdoublewebarchive"] = split(strip(readfile(mid a[i] "/logdoublewebarchive")), b, "\n")
      stats[a[i]]["logpctmagic"] = split(strip(readfile(mid a[i] "/logpctmagic")), b, "\n")
      stats[a[i]]["log3slash"] = split(strip(readfile(mid a[i] "/log3slash")), b, "\n")
      stats[a[i]]["newaltarch"] = split(strip(readfile(mid a[i] "/newaltarch")), b, "\n")
      stats[a[i]]["newialink"] = split(strip(readfile(mid a[i] "/newialink")), b, "\n")
      stats[a[i]]["newiadate"] = split(strip(readfile(mid a[i] "/newiadate")), b, "\n")
      stats[a[i]]["redirects"] = split(strip(readfile(mid a[i] "/redirects")), b, "\n")
      stats[a[i]]["wayrm"] = split(strip(readfile(mid a[i] "/wayrm")), b, "\n")
      stats[a[i]]["zombielinks"] = split(strip(readfile(mid a[i] "/zombielinks")), b, "\n")
     # wayall
      if(! checkexists(mid a[i] "/run1/wayall"))
        stats[a[i]]["wayall"] = split(strip(readfile(mid a[i] "/wayall")), b, "\n")
      else
        stats[a[i]]["wayall"] = split(strip(readfile(mid a[i] "/run1/wayall")), b, "\n")
     # WebCite
      if(! checkexists(mid a[i] "/run1/allwebcite"))
        stats[a[i]]["allwebcite"] = split(strip(readfile(mid a[i] "/allwebcite")), b, "\n")
      else
        stats[a[i]]["allwebcite"] = split(strip(readfile(mid a[i] "/run1/allwebcite")), b, "\n")
     # Archive.is
      if(! checkexists(mid a[i] "/run1/allarchiveis"))
        stats[a[i]]["allarchiveis"] = split(strip(readfile(mid a[i] "/allarchiveis")), b, "\n")
      else
        stats[a[i]]["allarchiveis"] = split(strip(readfile(mid a[i] "/run1/allarchiveis")), b, "\n")
     # Loc.gov
      if(! checkexists(mid a[i] "/run1/alllocgov"))
        stats[a[i]]["alllocgov"] = split(strip(readfile(mid a[i] "/alllocgov")), b, "\n")
      else
        stats[a[i]]["alllocgov"] = split(strip(readfile(mid a[i] "/run1/alllocgov")), b, "\n")
     # Portugual
      if(! checkexists(mid a[i] "/run1/allporto"))
        stats[a[i]]["allporto"] = split(strip(readfile(mid a[i] "/allporto")), b, "\n")
      else
        stats[a[i]]["allporto"] = split(strip(readfile(mid a[i] "/run1/allporto")), b, "\n")
     # Stanford
      if(! checkexists(mid a[i] "/run1/allstanford"))
        stats[a[i]]["allstanford"] = split(strip(readfile(mid a[i] "/allstanford")), b, "\n")
      else
        stats[a[i]]["allstanford"] = split(strip(readfile(mid a[i] "/run1/allstanford")), b, "\n")
     # Archive-it.org
      if(! checkexists(mid a[i] "/run1/allarchiveit"))
        stats[a[i]]["allarchiveit"] = split(strip(readfile(mid a[i] "/allarchiveit")), b, "\n")
      else
        stats[a[i]]["allarchiveit"] = split(strip(readfile(mid a[i] "/run1/allarchiveit")), b, "\n")
     # Bibalex.org
      if(! checkexists(mid a[i] "/run1/allbibalex"))
        stats[a[i]]["allbibalex"] = split(strip(readfile(mid a[i] "/allbibalex")), b, "\n")
      else
        stats[a[i]]["allbibalex"] = split(strip(readfile(mid a[i] "/run1/allbibalex")), b, "\n")
     # National Archives (UK)
      if(! checkexists(mid a[i] "/run1/allnatarchivesuk"))
        stats[a[i]]["allnatarchivesuk"] = split(strip(readfile(mid a[i] "/allnatarchivesuk")), b, "\n")
      else
        stats[a[i]]["allnatarchivesuk"] = split(strip(readfile(mid a[i] "/run1/allnatarchivesuk")), b, "\n")

      if(! checkexists(mid a[i] "/run1/alleuropa"))
        stats[a[i]]["alleuropa"] = split(strip(readfile(mid a[i] "/alleuropa")), b, "\n")
      else
        stats[a[i]]["alleuropa"] = split(strip(readfile(mid a[i] "/run1/alleuropa")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allpermacc"))
        stats[a[i]]["allpermacc"] = split(strip(readfile(mid a[i] "/allpermacc")), b, "\n")
      else
        stats[a[i]]["allpermacc"] = split(strip(readfile(mid a[i] "/run1/allpermacc")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allproni"))
        stats[a[i]]["allproni"] = split(strip(readfile(mid a[i] "/allproni")), b, "\n")
      else
        stats[a[i]]["allproni"] = split(strip(readfile(mid a[i] "/run1/allproni")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allparliament"))
        stats[a[i]]["allparliament"] = split(strip(readfile(mid a[i] "/allparliament")), b, "\n")
      else
        stats[a[i]]["allparliament"] = split(strip(readfile(mid a[i] "/run1/allparliament")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allukweb"))
        stats[a[i]]["allukweb"] = split(strip(readfile(mid a[i] "/allukweb")), b, "\n")
      else
        stats[a[i]]["allukweb"] = split(strip(readfile(mid a[i] "/run1/allukweb")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allcanada"))
        stats[a[i]]["allcanada"] = split(strip(readfile(mid a[i] "/allcanada")), b, "\n")
      else
        stats[a[i]]["allcanada"] = split(strip(readfile(mid a[i] "/run1/allcanada")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allcatalon"))
        stats[a[i]]["allcatalon"] = split(strip(readfile(mid a[i] "/allcatalon")), b, "\n")
      else
        stats[a[i]]["allcatalon"] = split(strip(readfile(mid a[i] "/run1/allcatalon")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allsingapore"))
        stats[a[i]]["allsingapore"] = split(strip(readfile(mid a[i] "/allsingapore")), b, "\n")
      else
        stats[a[i]]["allsingapore"] = split(strip(readfile(mid a[i] "/run1/allsingapore")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allslovene"))
        stats[a[i]]["allslovene"] = split(strip(readfile(mid a[i] "/allslovene")), b, "\n")
      else
        stats[a[i]]["allslovene"] = split(strip(readfile(mid a[i] "/run1/allslovene")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allfreezepage"))
        stats[a[i]]["allfreezepage"] = split(strip(readfile(mid a[i] "/allfreezepage")), b, "\n")
      else
        stats[a[i]]["allfreezepage"] = split(strip(readfile(mid a[i] "/run1/allfreezepage")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allwebharvest"))
        stats[a[i]]["allwebharvest"] = split(strip(readfile(mid a[i] "/allwebharvest")), b, "\n")
      else
        stats[a[i]]["allwebharvest"] = split(strip(readfile(mid a[i] "/run1/allwebharvest")), b, "\n")

      if(! checkexists(mid a[i] "/run1/allnlaau"))
        stats[a[i]]["allnlaau"] = split(strip(readfile(mid a[i] "/allnlaau")), b, "\n")
      else
        stats[a[i]]["allnlaau"] = split(strip(readfile(mid a[i] "/run1/allnlaau")), b, "\n")

     # archive.org /items/
      if(! checkexists(mid a[i] "/run1/allitems"))
        stats[a[i]]["allitems"] = split(strip(readfile(mid a[i] "/allitems")), b, "\n")
      else
        stats[a[i]]["allitems"] = split(strip(readfile(mid a[i] "/run1/allitems")), b, "\n")


      print "\n____________________ " a[i] " ______________________________"

      printf("Bummer          : %-7s (Wayback links that return \"Bummer page not found\")\n", stats[a[i]]["bummer"])
      printf("Robots.txt      : %-7s (Wayback links blocked by robots.txt)\n", stats[a[i]]["robotstext"])
      printf("Bogusapi        : %-7s (Wayback API-returned links that don't match real status code)\n", stats[a[i]]["bogusapi"])
      printf("API mismatch    : %-7s (Wayback API returned fewer records than sent.)\n", stats[a[i]]["apimismatch"])
      printf("JSON mismatch   : %-7s (Wayback API returned different size JSON)\n", stats[a[i]]["jsonmismatch"]) 
      printf("Checked         : %-7s (Number of articles checked by WaybackMedic)\n", stats[a[i]]["processed"])
      printf("Discovered      : %-7s (Number of articles edited by WaybackMedic)\n", (int(stats[a[i]]["discovered"]) + int(stats[a[i]]["discovereddone"])))
      printf("Log 404         : %-7s (Dead wayback links)\n", stats[a[i]]["log404"])
      printf("Log emptyarch   : %-7s (Empty archiveurl arguments)\n", stats[a[i]]["logemptyarch"])
      printf("Log emptyway    : %-7s (Ref has an empty {{wayback}})\n", stats[a[i]]["logemptyway"])
      printf("Log encode      : %-7s (URL misencoded)\n", stats[a[i]]["logencode"])
      printf("Log spurious 1  : %-7s (Spurious \"|1=\" parameter)\n", stats[a[i]]["logspurone"])
      printf("Log trail       : %-7s (URL has a trailing bad character)\n", stats[a[i]]["logtrail"])
      printf("Log dead URL    : %-7s (|url= is dead even though dead-url=no, archiveurl is dead and no {{dead}})\n", stats[a[i]]["logdeadurl"])
      printf("Log skindeep    : %-7s (changes to URL are skindeep)\n", stats[a[i]]["logskindeep"])
      printf("Log doubleurl   : %-7s (Double archive.org URL error)\n", stats[a[i]]["logdoubleurl"])
      printf("Log datemismatch: %-7s (Date in archive URL doesn't match archivedate argument in cite template)\n", stats[a[i]]["logdatemismatch"])
      printf("Log wrong https : %-7s (https and :80 conflict)\n", stats[a[i]]["logwronghttps"])
      printf("Log WAM         : %-7s (webarchive merge - wam.awk)\n", stats[a[i]]["logwam"])
      printf("Log stray dead  : %-7s (stray {{dead link}} - straydt.awk)\n", stats[a[i]]["logstraydt"])
      printf("Log WC|IS->IA   : %-7s (Convert WebCite|Archive.is to Wayback et al.)\n", stats[a[i]]["logbadstatusother"])
      printf("Log short url   : %-7s (WebCite URL elongated - webcitlong.awk)\n", stats[a[i]]["logwebcitlong"])
      printf("Log short url   : %-7s (Archive.is URL elongated - archiveis.awk)\n", stats[a[i]]["logarchiveislong"])
      printf("Log citeaddl    : %-7s (webarchive merge - citeaddl.awk)\n", stats[a[i]]["logciteaddl"])
      printf("Log nowikiway   : %-7s (Wayback mangled a certain way)\n", stats[a[i]]["lognowikiway"])
      printf("Log br bug      : %-7s (br bug)\n", stats[a[i]]["logbrbug"])
      printf("Log miss timest : %-7s (Timestamp missing from IA URL)\n", stats[a[i]]["logiats"])
      printf("Log embeded way : %-7s (embedded wayback template in cite template)\n", stats[a[i]]["logembway"])
      printf("Log embeded wa  : %-7s (embedded cite template in webarchive template)\n", stats[a[i]]["logembwebarchive"])
      printf("Log switch URL  : %-7s (archive in url= field)\n", stats[a[i]]["logfixswitch"])
      printf("Log dead /items/: %-7s (/items/ URL dead replacement)\n", stats[a[i]]["logfixitems"])
      printf("Log x2 webarch  : %-7s (double webarchive template)\n", stats[a[i]]["logdoublewebarchive"])
      printf("Log pct encode  : %-7s (pct encode magic characters)\n", stats[a[i]]["logpctmagic"])
      printf("Log x3 slash    : %-7s (https:/// error fix)\n", stats[a[i]]["log3slash"])
      printf("New alt archive : %-7s (Replaced with archive URL found at Mementoweb.org)\n", stats[a[i]]["newaltarch"])
      printf("New IA link     : %-7s (Added new IA link)\n", stats[a[i]]["newialink"])
      printf("New IA date     : %-7s (Changed snapshot date)\n", stats[a[i]]["newiadate"])
      printf("Redirects       : %-7s (Page was a redirect)\n", stats[a[i]]["redirects"])
      printf("Zombie links    : %-7s (Links needing removal by hand)\n", stats[a[i]]["zombielinks"])
      printf("Wayback RM      : %-7s (Wayback link deleted)\n", stats[a[i]]["wayrm"])
      printf("Wayback All     : %-7s (Wayback links total found)\n", stats[a[i]]["wayall"])
      printf("WebCite All     : %-7s (WebCite links total found)\n", stats[a[i]]["allwebcite"])
      printf("Archive.is All  : %-7s (Archive.is links total found)\n", stats[a[i]]["allarchiveis"])
      printf("Loc.gov All     : %-7s (Loc.gov links total found)\n", stats[a[i]]["alllocgov"])
      printf("Portugal All    : %-7s (Portugal links total found)\n", stats[a[i]]["allporto"])
      printf("Stanford All    : %-7s (Stanford links total found)\n", stats[a[i]]["allstanford"])
      printf("Archive-it All  : %-7s (Archive-it.org links total found)\n", stats[a[i]]["allarchiveit"])
      printf("Bibalex All     : %-7s (Bibalex.org links total found)\n", stats[a[i]]["allbibalex"])
      printf("NatArchiveUK All: %-7s (National Archives (UK) links total found)\n", stats[a[i]]["allnatarchivesuk"])
      printf("Europa Archives : %-7s (Europa Archives (Ireland) links total found)\n", stats[a[i]]["alleuropa"])
      printf("Perma.cc All    : %-7s (Perma.CC links total found)\n", stats[a[i]]["allpermacc"])
      printf("PRONI All       : %-7s (PRONI links total found)\n", stats[a[i]]["allproni"])
      printf("UK Parliament   : %-7s (UK Parliament links total found)\n", stats[a[i]]["allparliament"])
      printf("UK Web Archive  : %-7s (UK Web Archive (British Library) links total found)\n", stats[a[i]]["allukweb"])
      printf("Canada All      : %-7s (Canada links total found)\n", stats[a[i]]["allcanada"])
      printf("Catalonian All  : %-7s (Catalonian links total found)\n", stats[a[i]]["allcatalon"])
      printf("Singapore Archiv: %-7s (Singapore Archives links total found)\n", stats[a[i]]["allsingapore"])
      printf("Slovenian Archiv: %-7s (Slovenian Archives links total found)\n", stats[a[i]]["allslovene"])
      printf("Freezepage.com  : %-7s (Freezepage.com links total found)\n", stats[a[i]]["allfreezepage"])
      printf("Webharvest.gov  : %-7s (US Nat. Archives links total found)\n", stats[a[i]]["allwebharvest"])
      printf("NLA AU ALL      : %-7s (AU Nat. Archives links total found)\n", stats[a[i]]["allnlaau"])
      printf("archiveorg items: %-7s (Archive.org /items/ total found)\n", stats[a[i]]["allitems"])
    }
  }

  # Sum totals
  for(proj in stats) {
    for(field in stats[proj]) 
      stats["total"][field] = stats["total"][field] + stats[proj][field]
  }  


  print "\n_________________________________________________________"
  print "                     Total"
  print "_________________________________________________________\n"

  printf("Bummer          : %-7s (Wayback links that return \"Bummer page not found\")\n", stats["total"]["bummer"])
  printf("Robots.txt      : %-7s (Wayback links blocked by robots.txt)\n", stats["total"]["robotstext"])
  printf("Bogusapi        : %-7s (Wayback API-returned links that don't match real status code)\n", stats["total"]["bogusapi"])
  printf("API mismatch    : %-7s (Wayback API returned fewer records than sent.)\n", stats["total"]["apimismatch"])
  printf("JSON mismatch   : %-7s (Wayback API returned different size JSON)\n", stats["total"]["jsonmismatch"])
  printf("Checked         : %-7s (Number of articles checked by WaybackMedic)\n", stats["total"]["processed"])
  printf("Discovered      : %-7s (Number of articles edited by WaybackMedic)\n", (int(stats["total"]["discovered"]) + int(stats["total"]["discovereddone"])))
  printf("Log 404         : %-7s (Dead wayback links)\n", stats["total"]["log404"])
  printf("Log emptyarch   : %-7s (Empty archiveurl arguments)\n", stats["total"]["logemptyarch"])
  printf("Log emptyway    : %-7s (Ref has an empty {{wayback}})\n", stats["total"]["logemptyway"])
  printf("Log encode      : %-7s (URL misencoded)\n", stats["total"]["logencode"])
  printf("Log spurious 1  : %-7s (Spurious \"|1=\" parameter)\n", stats["total"]["logspurone"])
  printf("Log trail       : %-7s (URL has a trailing bad character)\n", stats["total"]["logtrail"])
  printf("Log dead URL    : %-7s (|url= is dead even though dead-url=no, archiveurl is dead and no {{dead}})\n", stats["total"]["logdeadurl"])
  printf("Log skindeep    : %-7s (changes to URL are skindeep)\n", stats["total"]["logskindeep"])
  printf("Log doubleurl   : %-7s (Double archive.org URL error)\n", stats["total"]["logdoubleurl"])
  printf("Log datemismatch: %-7s (Date in archive URL doesn't match archivedate argument in cite template)\n", stats["total"]["logdatemismatch"])
  printf("Log wrong https : %-7s (https and :80 conflict)\n", stats["total"]["logwronghttps"])
  printf("Log WAM         : %-7s (webarchive merge - wam.awk)\n", stats["total"]["logwam"])
  printf("Log stray dead  : %-7s (stray {{dead link}} - straydt.awk)\n", stats["total"]["logstraydt"])
  printf("Log WC|IS->IA   : %-7s (Convert WebCite|Archive.is to Wayback et al.)\n", stats["total"]["logbadstatusother"])
  printf("Log short url   : %-7s (WebCite URL elongated - webcitlong.awk)\n", stats["total"]["logwebcitlong"])
  printf("Log short url   : %-7s (Archive.is URL elongated - archiveis.awk)\n", stats["total"]["logarchiveislong"])
  printf("Log citeaddl    : %-7s (webarchive merge - citeaddl.awk)\n", stats["total"]["logciteaddl"])
  printf("Log nowikiway   : %-7s (Wayback mangled a certain way)\n", stats["total"]["lognowikiway"])
  printf("Log br bug      : %-7s (br bug)\n", stats["total"]["logbrbug"])
  printf("Log miss timest : %-7s (Timestamp missing from IA URL)\n", stats["total"]["logiats"])
  printf("Log embeded way : %-7s (embedded wayback template in cite template)\n", stats["total"]["logembway"])
  printf("Log embeded wa  : %-7s (embedded cite template in webarchive template)\n", stats["total"]["logembwebarchive"])
  printf("Log switch URL  : %-7s (archive in url= field)\n", stats["total"]["logfixswitch"])
  printf("Log dead /items/: %-7s (/items/ URL dead replacement)\n", stats["total"]["logfixitems"])
  printf("Log x2 webarch  : %-7s (double webarchive template)\n", stats["total"]["logdoublewebarchive"])
  printf("Log pct encode  : %-7s (pct encode magic characters in URLs)\n", stats["total"]["logpctmagic"])
  printf("Log x3 slash    : %-7s (https:/// error fix)\n", stats["total"]["log3slash"])
  printf("New alt archive : %-7s (Replaced with archive URL found at Mementoweb.org)\n", stats["total"]["newaltarch"])
  printf("New IA link     : %-7s (Added new IA link)\n", stats["total"]["newialink"])
  printf("New IA date     : %-7s (Changed snapshot date)\n", stats["total"]["newiadate"])
  printf("Redirects       : %-7s (Page was a redirect)\n", stats["total"]["redirects"])          
  printf("Zombie links    : %-7s (Links needing removal by hand)\n", stats["total"]["zombielinks"])
  printf("Wayback RM      : %-7s (Wayback link deleted)\n", stats["total"]["wayrm"])
  printf("Wayback All     : %-7s (Wayback links total found)\n", stats["total"]["wayall"])  
  printf("WebCite All     : %-7s (WebCite links total found)\n", stats["total"]["allwebcite"])
  printf("Archive.is All  : %-7s (Archive.is links total found)\n", stats["total"]["allarchiveis"])
  printf("Loc.gov All     : %-7s (Loc.gov links total found)\n", stats["total"]["alllocgov"])
  printf("Portugal All    : %-7s (Portugal links total found)\n", stats["total"]["allporto"])
  printf("Stanford All    : %-7s (Stanford links total found)\n", stats["total"]["allstanford"])
  printf("Archive-it All  : %-7s (Archive-it.org links total found)\n", stats["total"]["allarchiveit"])
  printf("Bibalex All     : %-7s (Bibalex.org links total found)\n", stats["total"]["allbibalex"])
  printf("NatArchiveUK All: %-7s (National Archives (UK) links total found)\n", stats["total"]["allnatarchivesuk"])
  printf("Europa Archives : %-7s (Europa Archives (Ireland) links total found)\n", stats["total"]["alleuropa"])
  printf("Perma.cc All    : %-7s (Perma.CC links total found)\n", stats["total"]["allpermacc"])
  printf("PRONI All       : %-7s (PRONI links total found)\n", stats["total"]["allproni"])
  printf("UK Parliament   : %-7s (UK Parliament links total found)\n", stats["total"]["allparliament"])
  printf("UK Web Archive  : %-7s (UK Web Archive (British Library) links total found)\n", stats["total"]["allukweb"])
  printf("Canada All      : %-7s (Canada links total found)\n", stats["total"]["allcanada"])
  printf("Catalonian All  : %-7s (Catalonian links total found)\n", stats["total"]["allcatalon"])
  printf("Singapore Archiv: %-7s (Singapore Archives links total found)\n", stats["total"]["allsingapore"])
  printf("Slovenian Archiv: %-7s (Slovenian Archives links total found)\n", stats["total"]["allslovene"])
  printf("Freezepage.com  : %-7s (Freezepage.com links total found)\n", stats["total"]["allfreezepage"])
  printf("Webharvest.gov  : %-7s (US Nat. Archives links total found)\n", stats["total"]["allwebharvest"])
  printf("NLA AU ALL      : %-7s (AU Nat. Archives links total found)\n", stats["total"]["allnlaau"])

  printf("archiveorg items: %-7s (Archive.org /items/ total found)\n", stats["total"]["allitems"])

}

function verify_wayrm(pid, did, mid, verifyurl, a,c,i,g,page,url) {

  # This function for testing purposes
  if(length(verifyurl) > 0) {
    page = http2var(url)
    if(page ~ /Got an HTTP 302 response at crawl time|\
               Redirecting to[.][.][.]|\
               Wayback Machine doesn't have that page archived|\
               Page cannot be crawled or displayed due to robots.txt|\
               404[ ]{0,}[-][ ]{0,}Page cannot be found|\
               404[ ]{0,}[-][ ]{0,}File or directory not found|\
               show[_]404|\
               This URL has been excluded from the Wayback Machine/) {
       print "Page unavailable"
     } else {
       print "Page available"
     }
     return
  }

  meta = mid pid "/"
  wayrm = meta "wayrm"

  if(!length(wayrm)) {
    print "Unable to open file: " wayrm
    exit
  }

  c = split(readfile(wayrm), a, "\n")

  while(i++ < c) {
    print i
    if(a[i] == "") continue
    split(a[i],g,"----")
    url = g[2]
    page = http2var(url)
    if(length(page) < 5) continue
    if(page ~ /Got an HTTP 302 response at crawl time|\
               Redirecting to[.][.][.]|\
               Wayback Machine doesn't have that page archived|\
               Page cannot be crawled or displayed due to robots.txt|\
               404[ ]{0,}[-][ ]{0,}Page cannot be found|\
               404[ ]{0,}[-][ ]{0,}File or directory not found|\
               show[_]404|\
               This URL has been excluded from the Wayback Machine/) {
       continue
     } else {
       print a[i]
     }
  }
}


function usage() {

  print ""
  print "Project - manage projects."
  print ""
  print "Usage:"
  print "       -i             Build index from ~/data files. CAUTION: only use if data dir is fresh (one run of medic). -p required"
  print "       -y             Check for data corruption. See project.awk source for description. -p required"
  print "       -j             Re-assemble index file after all drivers (via parallel) is completed. -p required." 
  print "       -c             Create project files. -p required"
  print "       -x             Delete project files. -p required"
  print "       -p <project>   Project name."
  print "       -d <data dir>  Data directory. Defaults to default.data in project.cfg"
  print "       -m <meta dir>  Meta directory. Defaults to default.meta in project.cfg"
  print ""
  print "       -s <filename>  Find a string (defined in source) in <filename> in the data directory"
  print "       -e <filename>  IMP: reprocess an iabget file (iabget, iabget.error, iabget.p2b)"
  print "       -f             Run -e in-memory for reduced disk access. See code notes for warnings."
  print "       -a             Find all fixemptyarchive"
  print "       -h             Help"
  print ""
  print "Path names for -d and -m end with trailing slash."
  print ""

}

