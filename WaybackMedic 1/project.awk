#!/usr/local/bin/gawk -E   

#
# Initialize a new project
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


@include "init.awk"
@include "library.awk"
@include "getopt.awk"

BEGIN {

  while ((C = getopt(ARGC, ARGV, "jyabicxhp:d:m:s:t:")) != -1) { 
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
      if(C == "t") {               #  -t <filename>  Generate project statistics. Filename contains a list of project IDs
        type = "stats"        
        statsfile = verifyval(Optarg)
      }

      if(C == "h") {
        usage()
        exit
      }
  }

 # No options or an empty -p given
  if( type == "" || (type ~ /delete|create|index|corrupt|assemble/ && pid == "") || pid ~ /error/ ){
    usage()
    exit
  }

 # Load default Data and Meta from project.cfg 
  if(did == "") 
    did = Config["default"]["data"]
  if(mid == "") 
    mid = Config["default"]["meta"]
  if(did == "" || mid == "") {
    print "Unable to determine Data or Meta directories. Create project.cfg with default.data and default.meta"
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

  if(type ~ /delete/) {
    deleteproject(pid,mid,did)
    exit
  }
  
 # Everything following is type = create

 # Check everything looks ok
  if(substr(did,length(did),1) != "/" || substr(mid,length(mid),1) != "/") {
    print "data = " data
    print "meta = " meta
    print "data and meta should end in a trailing slash. Maybe check project.cfg for default.data/meta"
    exit
  }

 # Make Data and Meta directories
  if(checkexists(did pid)) 
    print "Data directory already exists: " did pid
  else {
    print "OK Creating " did pid
    sys2var(Exe["mkdir"] " " did pid)
    checkexists(did pid, "project.awk", "exit")
  }
  if(checkexists(mid pid)) 
    print "Meta directory already exists: " mid pid
  else {
    print "OK Creating " mid pid
    sys2var(Exe["mkdir"] " " mid pid)
    checkexists(mid pid, "project.awk", "exit")
  }

 # Write new project.cfg

  # Remove leading and trailing blank lines
  print stripfile(Home "project.cfg") > Home "project.cfg.orig"
  close(Home "project.cfg.orig")
  print "OK Saving project.cfg to project.cfg.orig"

  c = split(readfile(Home "project.cfg.orig"),a,"\n")

  # Set new default
  i = 0
  re = "^default[.]id"   
  while(i++ < c) {
    if(a[i] ~ re) {
      a[i] = "default.id = " pid
      break
    }
  }
  if(i == c) 
    print "Unable to set default.id"
  else
    print "OK Setting default.id = " pid

  # Create new .data and .meta 
  a[c + 1] = pid ".data = " did pid "/"
  a[c + 2] = pid ".meta = " mid pid "/"

  print "OK Writing new project.cfg"

  if(checkexists(Home "project.cfg")) 
    sys2var( Exe["rm"] " " Home "project.cfg")

  i = 0
  while(i++ < c + 2) 
    print a[i] >> Home "project.cfg"

  close(Home "project.cfg")

 # Create .auth file
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
#
function assemble(pid,did,mid,   data,meta) {

  data = did pid "/"
  meta = mid pid "/"

  if(!checkexists(meta "index.temp")) {
    print "Unable to find " meta "index.temp" 
    exit
  }

  if(!checkexists(meta "index")) {                          # If no index, just rename file
    sys2var(Exe["mv"] " " meta "index.temp " meta "index")
    exit
  }

  sys2var(Exe["cp"] " " meta "index " meta "index.orig")

  c = split(readfile(meta "index.temp"), a, "\n")           # index.temp was created by driver.awk
  while(i++ < c) {
    split(a[i], b, "|")
    if(!sendtoindex(meta "index", b[1], b[2])) {
      print "driver.awk: ERROR with " b[1] ". Unable to update " meta "index" > "/dev/stderr"
      exit
    }
  }
}

#
# Delete project
#
function deleteproject(pid,mid,did,    i,c,re,a) {

 # Delete Data and Meta directories
  if( ! checkexists(did pid)) 
    print "Data directory doesn't exist: " did pid
  else {
    print "OK Deleting " did pid
    sys2var(Exe["rm"] " -r " did pid)
  }
  if( ! checkexists(mid pid)) 
    print "Meta directory doesn't exist: " mid pid
  else {
    print "OK Deleting " mid pid
    sys2var(Exe["rm"] " -r " mid pid)
  }

 # Remove .meta and .data lines from project.cfg but leave default.* lines untouched 
  if(checkexists(Home "project.cfg.out"))
    sys2var( Exe["rm"] " project.cfg.out")
  if(checkexists(Home "project.cfg.orig"))
    sys2var( Exe["rm"] " project.cfg.orig")
  if(checkexists(Home "project.cfg"))
    command = Exe["mv"] " " Home "project.cfg" " " Home "project.cfg.orig"
  else {
    print "Unable to find " Home "project.cfg"
    return
  }
  print "OK Making backup project.cfg -> project.cfg.orig"
  sys2var(command)
  system("")
  c = split(readfile(Home "project.cfg.orig"),a,"\n")
  re = "^" regesc2(pid) "[.](data|meta)"     
  while(i++ < c) {
    if(a[i] ~ re) { # delete if re matches 
    }
    else {
      print a[i] >> Home "project.cfg.out"
    }
  }
  close(Home "project.cfg.out")
  if(checkexists(Home "project.cfg.out")) {
    print stripfile(Home "project.cfg.out") > Home "project.cfg"
    close(Home "project.cfg")
    print "OK Removed data & meta lines from project.cfg (default.id untouched)"
  }
  else {
    print "Unable to modify project.cfg - restoring backup"
    sys2var(Exe["mv"] " " Home "project.cfg.orig" " " Home "project.cfg")
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
# Search for string "re" in <filename> across entire project 
#
function check_string(filename, pid, did, mid,    re,c,files,stampdir,i,command,count) {

 # Be careful with escaping as unsure how grep responds 
  re = "web[.]http"

  files = sys2var(Exe["ls"] " " did pid "/")

  if(pid == "") {
    print "\nRequires -p <projectid> .. available project IDs:\n"
    print files
    print ""
    exit
  }

  c = split(files, stampdir, "\n")
  while(i++ < c) {
    if(checkexists(did pid "/" stampdir[i] "/" filename)) {
      command = Exe["grep"] " -ciE \"" re "\" " did pid "/" stampdir[i] "/" filename
      count = sys2var(command)
      if(count > 0) {
        newid = whatisindexname(did pid "/" stampdir[i], mid pid "/index")
        if(newid !~ /^0$/)
          print newid
#        print newid " ( cd " did pid "/" stampdir[i] " )"
      }
    }
  }
}

#
# Return the name portion given a path/tempid in an index (eg. /home/adminuser/wi-awb/temp/wi-awb-0202173111/)
#
function whatisindexname(name, filepath,      s, a, re) {

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
# Generate project stats. Create a file with a list of project ID's and run with the -t <filename> switch
#
#
function statistics(statsfile, mid,    c,a,i,b) {

  if(! checkexists(statsfile) ) {
    print("Error unable to find " statsfile )
    return 0
  }
  c = split(readfile(statsfile), a, "\n")

  while(i++ < c) {
    if(length(a[i]) > 1) {
      stats[a[i]]["bummer"] = split(readfile(mid a[i] "/bummer"), b, "\n")
      stats[a[i]]["bogusapi"] = split(readfile(mid a[i] "/bogusapi"), b, "\n")
      stats[a[i]]["apimismatch"] = split(readfile(mid a[i] "/apimismatch"), b, "\n")
      stats[a[i]]["discovered"] = split(readfile(mid a[i] "/discovered"), b, "\n")
      stats[a[i]]["jsonmismatch"] = split(readfile(mid a[i] "/jsonmismatch"), b, "\n")
      stats[a[i]]["log404"] = split(readfile(mid a[i] "/log404"), b, "\n")
      stats[a[i]]["logemptyarch"] = split(readfile(mid a[i] "/logemptyarch"), b, "\n")
      stats[a[i]]["logemptyway"] = split(readfile(mid a[i] "/logemptyway"), b, "\n")
      stats[a[i]]["logencode"] = split(readfile(mid a[i] "/logencode"), b, "\n")
      stats[a[i]]["logspurone"] = split(readfile(mid a[i] "/logspurone"), b, "\n")
      stats[a[i]]["logtrail"] = split(readfile(mid a[i] "/logtrail"), b, "\n")
      stats[a[i]]["logdeadurl"] = split(readfile(mid a[i] "/logdeadurl"), b, "\n")
      stats[a[i]]["newaltarch"] = split(readfile(mid a[i] "/newaltarch"), b, "\n")
      stats[a[i]]["newiadate"] = split(readfile(mid a[i] "/newiadate"), b, "\n")
      stats[a[i]]["redirects"] = split(readfile(mid a[i] "/redirects"), b, "\n")
      stats[a[i]]["wayrm"] = split(readfile(mid a[i] "/wayrm"), b, "\n")
      stats[a[i]]["wayall"] = split(readfile(mid a[i] "/wayall"), b, "\n")
      stats[a[i]]["zombielinks"] = split(readfile(mid a[i] "/zombielinks"), b, "\n")

      print "\n____________________ " a[i] " ______________________________"

      print "Bummer         : " stats[a[i]]["bummer"] "\t (Wayback links that return \"Bummer page not found\")"
      print "Bogusapi       : " stats[a[i]]["bogusapi"] "\t (Wayback API-returned links that don't match real status code)"
      print "API mismatch   : " stats[a[i]]["apimismatch"] "\t (Wayback API returned fewer records than sent.)"
      print "JSON mismatch  : " stats[a[i]]["jsonmismatch"] "\t (Wayback API returned different size JSON)" 
      print "Discovered     : " stats[a[i]]["discovered"] "\t (Number of articles edited by WaybackMedic)"
      print "Log 404        : " stats[a[i]]["log404"] "\t (Dead wayback links)"
      print "Log emptyarch  : " stats[a[i]]["logemptyarch"] "\t (Empty archiveurl arguments)"
      print "Log emptyway   : " stats[a[i]]["logemptyway"] "\t (Ref has an empty {{wayback}})"
      print "Log encode     : " stats[a[i]]["logencode"] "\t (URL misencoded)"
      print "Log spurious 1 : " stats[a[i]]["logspurone"] "\t (Spurious \"|1=\" parameter)"
      print "Log trail      : " stats[a[i]]["logtrail"] "\t (URL has a trailing bad character)"
      print "Log dead URL   : " stats[a[i]]["logdeadurl"] "\t (|url= is dead even though dead-url=no, archiveurl is dead and no {{dead}})"
      print "New alt archive: " stats[a[i]]["newaltarch"] "\t (Replaced with archive URL found at Mementoweb.org)"
      print "New IA date    : " stats[a[i]]["newiadate"] "\t (Changed snapshot date)"
      print "Redirects      : " stats[a[i]]["redirects"] "\t (Page was a redirect)"
      print "Zombie links   : " stats[a[i]]["zombielinks"] "\t (Links needing removal by hand)"
      print "Wayback RM     : " stats[a[i]]["wayrm"] "\t (Wayback link deleted)"
      print "Wayback All    : " stats[a[i]]["wayall"] "\t (Wayback links total found)"
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

  print "Bummer         : " stats["total"]["bummer"] "\t (Wayback links that return \"Bummer page not found\")"
  print "Bogusapi       : " stats["total"]["bogusapi"] "\t (Wayback API-returned links that don't match real status code)"
  print "API mismatch   : " stats["total"]["apimismatch"] "\t (Wayback API returned fewer records than sent.)"
  print "JSON mismatch  : " stats["total"]["jsonmismatch"] "\t (Wayback API returned different size JSON)" 
  print "Discovered     : " stats["total"]["discovered"] "\t (Number of articles edited by WaybackMedic)"
  print "Log 404        : " stats["total"]["log404"] "\t (Dead wayback links)"
  print "Log emptyarch  : " stats["total"]["logemptyarch"] "\t (Empty archiveurl arguments)"
  print "Log emptyway   : " stats["total"]["logemptyway"] "\t (Ref has an empty {{wayback}})"
  print "Log encode     : " stats["total"]["logencode"] "\t (URL misencoded)"
  print "Log spurious 1 : " stats["total"]["logspurone"] "\t (Spurious \"|1=\" parameter)"
  print "Log trail      : " stats["total"]["logtrail"] "\t (URL has a trailing bad character)"
  print "Log dead URL   : " stats["total"]["logdeadurl"] "\t (|url= is dead even though dead-url=no, archiveurl is dead and no {{dead}})"
  print "New alt archive: " stats["total"]["newaltarch"] "\t (Replaced with archive URL found at Mementoweb.org)"
  print "New IA date    : " stats["total"]["newiadate"] "\t (Changed snapshot date)"
  print "Redirects      : " stats["total"]["redirects"] "\t (Page was a redirect)"
  print "Zombie links   : " stats["total"]["zombielinks"] "\t (Links needing removal by hand)"
  print "Wayback RM     : " stats["total"]["wayrm"] "\t (Wayback link deleted)"
  print "Wayback All    : " stats["total"]["wayall"] "\t (Wayback links total found)"


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
  print "       -a             Find all fixemptyarchive"
  print "       -h             Help"
  print ""
  print "Path names for -d and -m end with trailing slash."
  print ""

}
