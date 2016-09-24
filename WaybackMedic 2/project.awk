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

  while ((C = getopt(ARGC, ARGV, "jyabicxhp:d:m:s:t:v:")) != -1) { 
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

      if(C == "v")
        type = "verifywayrm"       #  -v             Verify links in wayrm
        verifyurl = Optarg

      if(C == "h") {
        usage()
        exit
      }
  }

 # No options or an empty -p given
  if( type == "" || (type ~ /delete|create|index|corrupt|assemble|verifywayrm/ && pid == "") || pid ~ /error/ ){
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

 # Cp scripts into meta directory
   command = Exe["cp"] " deletename* " mid pid
   sys2var(command)
   command = Exe["cp"] " criticalrun " mid pid
   sys2var(command)
   command = Exe["cp"] " sqlrun " mid pid
   sys2var(command)

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
    sys2var(Exe["rm"] " " meta "index")
    sys2var(Exe["mv"] " " outfile " " meta "index")
#  } 
#  else 
#    print "Index and index.orig don't match. Check " outfile " and compare with index"


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
  re = "http[:]//jobs[.]suntimes[.]com/news/metro/kelly/940633[,]kellytimeline[.]stng"

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
         print did pid "/" stampdir[i] "/" filename
#        newid = whatisindexname(did pid "/" stampdir[i], mid pid "/index")
#        if(newid !~ /^0$/)
#          print newid
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
      stats[a[i]]["bummer"] = split(strip(readfile(mid a[i] "/bummer")), b, "\n")
      stats[a[i]]["bogusapi"] = split(strip(readfile(mid a[i] "/bogusapi")), b, "\n")
      stats[a[i]]["apimismatch"] = split(strip(readfile(mid a[i] "/apimismatch")), b, "\n")
      stats[a[i]]["discovered"] = split(strip(readfile(mid a[i] "/discovered")), b, "\n")
      stats[a[i]]["discovereddone"] = split(strip(readfile(mid a[i] "/discovered.done")), b, "\n")
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
      stats[a[i]]["newaltarch"] = split(strip(readfile(mid a[i] "/newaltarch")), b, "\n")
      stats[a[i]]["newiadate"] = split(strip(readfile(mid a[i] "/newiadate")), b, "\n")
      stats[a[i]]["redirects"] = split(strip(readfile(mid a[i] "/redirects")), b, "\n")
      stats[a[i]]["wayrm"] = split(strip(readfile(mid a[i] "/wayrm")), b, "\n")
      if(! checkexists(mid a[i] "/run1/wayall"))
        stats[a[i]]["wayall"] = split(strip(readfile(mid a[i] "/wayall")), b, "\n")
      else
        stats[a[i]]["wayall"] = split(strip(readfile(mid a[i] "/run1/wayall")), b, "\n")
      stats[a[i]]["zombielinks"] = split(strip(readfile(mid a[i] "/zombielinks")), b, "\n")

      print "\n____________________ " a[i] " ______________________________"

      printf("Bummer          : %-7s (Wayback links that return \"Bummer page not found\")\n", stats[a[i]]["bummer"])
      printf("Bogusapi        : %-7s (Wayback API-returned links that don't match real status code)\n", stats[a[i]]["bogusapi"])
      printf("API mismatch    : %-7s (Wayback API returned fewer records than sent.)\n", stats[a[i]]["apimismatch"])
      printf("JSON mismatch   : %-7s (Wayback API returned different size JSON)\n", stats[a[i]]["jsonmismatch"]) 
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
      printf("New alt archive : %-7s (Replaced with archive URL found at Mementoweb.org)\n", stats[a[i]]["newaltarch"])
      printf("New IA date     : %-7s (Changed snapshot date)\n", stats[a[i]]["newiadate"])
      printf("Redirects       : %-7s (Page was a redirect)\n", stats[a[i]]["redirects"])
      printf("Zombie links    : %-7s (Links needing removal by hand)\n", stats[a[i]]["zombielinks"])
      printf("Wayback RM      : %-7s (Wayback link deleted)\n", stats[a[i]]["wayrm"])
      printf("Wayback All     : %-7s (Wayback links total found)\n", stats[a[i]]["wayall"])
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
  printf("Bogusapi        : %-7s (Wayback API-returned links that don't match real status code)\n", stats["total"]["bogusapi"])
  printf("API mismatch    : %-7s (Wayback API returned fewer records than sent.)\n", stats["total"]["apimismatch"])
  printf("JSON mismatch   : %-7s (Wayback API returned different size JSON)\n", stats["total"]["jsonmismatch"])
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
  printf("New alt archive : %-7s (Replaced with archive URL found at Mementoweb.org)\n", stats["total"]["newaltarch"])
  printf("New IA date     : %-7s (Changed snapshot date)\n", stats["total"]["newiadate"])
  printf("Redirects       : %-7s (Page was a redirect)\n", stats["total"]["redirects"])          
  printf("Zombie links    : %-7s (Links needing removal by hand)\n", stats["total"]["zombielinks"])
  printf("Wayback RM      : %-7s (Wayback link deleted)\n", stats["total"]["wayrm"])
  printf("Wayback All     : %-7s (Wayback links total found)\n", stats["total"]["wayall"])  


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
  print "       -a             Find all fixemptyarchive"
  print "       -h             Help"
  print ""
  print "Path names for -d and -m end with trailing slash."
  print ""

}

