#!/usr/local/bin/gawk -E   

#
# Debug routines
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


  type = "view"                    # Default
  difftype = "c"
  capturetype = "a"

  while ((C = getopt(ARGC, ARGV, "wzusvrp:n:d:c:t:")) != -1) { 
      opts++
      if(C == "p")                 #  -p <project>   Use project name. No default.
        pid = verifypid(Optarg)
      if(C == "n")                 #  -n <name>      Name to process
        name = verifyval(Optarg)

      if(C == "v")                 #  -v             View paths. Default. Name required.
        type = "view"

      if(C == "r")                 #  -r             Run medic. Name required.
        type = "run"

      if(C == "d") {               #  -d <type>      Diff. Type is "c" for color (default) or "p" for plain text
        difftype = verifyval(Optarg)
        type = "diff"
      }

      if(C == "c") {               #  -c <type>      Capture output to clipboard. "a" for article.txt and "w" for article.wayback.txt
        type = "capture"
        capturetype = verifyval(Optarg)
      }

      if(C == "s") {               # -s              Generate SQL query for CB from meta/wayrm (delete) and meta/newiadate (modify)
        type = "sql"
      }

      if(C == "w") {               # -s              Generate SQL query for CB from meta/wayrm (delete) and meta/newiadate (modify)
        type = "sql2"
      }

      if(C == "u") {               # -u              Search for articles that contain the "deadurl=no" bug where it added a {{dead link} when it shouldn't have
        type = "deadu"
      }

      if(C == "z") {               # -z              Search for articles that contain links that should have been deleted
        type = "zombie"
      }

      if(C == "t") {               #  -t <filename>  Create a master file across multiple project directories. eg. create a single "wayrm" from all projects listed in <filename>
        projfile = verifyval(Optarg)
        type = "master"
      }

      if(C == "h") {
        usage()
        exit
      }
  }

  if(opts == 0) {
    usage()
    exit
  }


 # No options or an empty -p given
  if( pid ~ /error/ ){
    usage()
    exit
  }

  setProject(pid)     # library.awk .. load Project[] paths via project.cfg
                      # if -p not given, use default noted in project.cfg
  

  delete Inx

  if(type ~ /view/) {
    view(name)
    exit
  }

  if(type ~ /run/) {
    run(name)
    exit
  }

  if(type ~ /master/) {
    masterfile(projfile, Config["default"]["meta"])
    exit
  }

  if(type ~ /diff/) {
    diff(name, difftype)
    exit
  }

  if(type ~ /capture/) {
    cap(name, capturetype)
    exit
  }

  if(type == "sql") {
    sqlquery()
    exit
  }

  if(type == "sql2") {
    sqlquery2()
    exit
  }

  if(type ~ /deadu/) {
    deadurlbug()
    exit
  }

  if(type ~ /zombie/) {
    zombielinkbug()
    exit
  }

}


#
# Send file to stdout for capture by clip
#
function cap(name, type,    command) {

  getindex(name)

  if(type ~ /^a$/) 
    command = Exe["cat"] " \"" Inx["path"] "\"article.txt"
  else if(type ~ /^w$/) 
    command = Exe["cat"] " \"" Inx["path"] "\"article.waybackmedic.txt"

  system(command)

}

function diff(name, type,   command) {

  getindex(name)

  if(type ~ /c/)
    command = Exe["coldiff"] " \"" Inx["path"] "\"article.txt \"" Inx["path"] "\"article.waybackmedic.txt"
  else
    command = Exe["diff"] " \"" Inx["path"] "\"article.txt \"" Inx["path"] "\"article.waybackmedic.txt"

  system(command)

}


function run(name,   command) {

  # escape for shell commands
#  esc_dir = name
#  gsub(/'/, "'\\''", esc_dir)
#  esc_dir = "'" esc_dir "'"
#print esc_dir
#exit

  getindex(name)
  command = Exe["medic"] " -p \"" Project["id"] "\" -n \"" name "\" -s \"" Inx["path"] "article.txt\" -d n"
  system(command)

}

#
# Search for zombie links bug - links that should have been deleted but still exist in the article.
#
function zombielinkbug(  c,a,i,b,d,name,link,fp) {

  print "\nWAYRM. Remove link and add {{dead}}{{cbignore}}"
  print "------"
  system("")
  c = split(readfile(Project["wayrm"]), a, "\n")
  while(i++ < c) {
    split(a[i], b, "----")
    name = b[1]
    link = b[2]
    getindex(name)
    if(checkexists(Inx["path"] "article.waybackmedic.txt")) {
      fp = readfile(Inx["path"] "article.waybackmedic.txt")
      if(countsubstring(fp, link) > 0) {
        print name " : " link
        system("")
      }
    }
    else  {
      if(length(strip(name)) > 0) {
        print name " : " link
        system("") 
      }
    }
  }

  i = c = 0

  print "\nLOGSKINDEEP. Modify URL to formatted condition."
  print "------"
  system("")
  c = split(readfile(Project["logskindeep"]), a, "\n")
  while(i++ < c) {
    split(a[i], b, "----")
    split(b[2], d, " ")
    name = b[1]
    link = d[2]
    getindex(name)
    if(checkexists(Inx["path"] "article.waybackmedic.txt")) {
      fp = readfile(Inx["path"] "article.waybackmedic.txt")
      if(countsubstring(fp, link) > 0) { 
        print name " : " link
        system("") 
      }
    }
    else  {
      if(length(strip(name)) > 0) { 
        print name " : " link
        system("") 
      }
    }
  }

  i = c = 0

  print "\nNEWIADATE. Modify date to new date.."
  print "------"
  system("") 
  c = split(readfile(Project["newiadate"]), a, "\n")
  while(i++ < c) {
    split(a[i], b, "----")
    split(b[2], d, " ")
    name = b[1]
    olddate = d[2]
    newdate = d[3]
    getindex(name)
    if(checkexists(Inx["path"] "article.waybackmedic.txt")) {
      fp = readfile(Inx["path"] "article.waybackmedic.txt")
      if(countsubstring(fp, olddate) > 0) { 
        print name " : " olddate " : " newdate
        system("") 
      }
    }
    else  {
      if(length(strip(name)) > 0) {
        print name " : " link
        system("") 
      }
    }
  }

  i = c = 0

  print "\nNEWALTARCHIVE. Modify to new alt archive.."
  print "------"
  system("") 
  c = split(readfile(Project["newaltarchive"]), a, "\n")
  while(i++ < c) {
    split(a[i], b, "----")
    split(b[2], d, " ")
    name = b[1]
    olddate = d[2]
    getindex(name)
    if(checkexists(Inx["path"] "article.waybackmedic.txt")) {
      fp = readfile(Inx["path"] "article.waybackmedic.txt")
      if(countsubstring(fp, olddate) > 0) {
        print name " : " olddate 
        system("") 
      }
    }
    else  {
      if(length(strip(name)) > 0) {
        print name " : " link
        system("") 
      }
    }
  }

}

#
# Search for articles containing the deadurl bug where {{dead link}} was added to cites on removal of a non-working IA URL, but still had a working url= parameter
#
function deadurlbug(  c,a,i,b,name,path,totala,totalw,fp) {

  c = split(readfile(Project["index"]), a, "\n")
  while(i++ < c) {
    if(split(a[i], b, "|")) {
      name = b[1]
      path = b[2]
      totala = 0
      totalw = 0
      fp = ""
      if(checkexists(path "article.waybackmedic.txt")) {
        fp = readfile(path "article.txt")
        totala += gsub(/dead[-]{0,1}url[ ]{0,}[=][ ]{0,}[Nn][Oo]/, "", fp)
        if(int(totala) > 0) {
          fp = readfile(path "article.waybackmedic.txt")
          totalw += gsub(/dead[-]{0,1}url[ ]{0,}[=][ ]{0,}[Nn][Oo]/, "", fp)
          if(int(totala) != int(totalw)) {
            print name
          }
        }
      }
    }
  }

}

function view(name) {

  getindex(name)
  print "Name: " Inx["name"]
  print "Meta: cd " Project["meta"]
  print "Data: cd " Inx["path"]
  print "./medic -p \"" Project["id"] "\" -n \"" name "\" -s \"" Inx["path"] "article.txt\" -d y"

}

function getindex(name,  a) {

  split(whatistempid(name, Project["index"]),a,"|")
  if(length(a[1])) 
    Inx["name"] = strip(a[1])
  if(length(a[2])) 
    Inx["path"] = strip(a[2])
  
  if(Inx["name"] == "" || Inx["path"] == "") {
    print "Unable to find " Inx["name"] " in " Project["index"]
    exit
  }
}


#
# Return the name and path/tempid for a name (eg. "^George Wash|/home/adminuser/wi-awb/temp/wi-awb-0202173111/$" )
#
function whatistempid(name, filepath,      s, a, re) {  

  if(! checkexists(filepath) ) {
    print("bug.awk: Error unable to find " filepath ". " name )
    return 0    
  }
  re = "^" regesc2(strip(tolower(name))) "$"
  while ((getline s < filepath ) > 0) {
    split(s, a, "|")
    if(strip(tolower(a[1])) ~ re) {
      close(filepath)
      return strip(s)
    }               
  }
  close(filepath)
  return 0
}


#
# sqlquery - generate a SQL query for the CB database. See email discussion dated May 24 2016 with Max for details.
#
function sqlquery(  url, iaurl, c, a, b, d, i, s, newdate, part_when_null, part_when_zero, part_where, part_when_one, part_when_url, part_when_date, year, month, day, hour, minute, second, bogusdate) {

  if(! checkexists(Project["meta"] "wayrm.sql") ) {
    print("Error unable to find " Project["meta"] "wayrm.sql")
    return 0
  }
  if(! checkexists(Project["meta"] "newiadate.sql") ) {
    print("Error unable to find " Project["meta"] "newiadate.sql")
    return 0
  }

  # ---------- wayrm ---------- #

  delete bogusdate

  c = split(readfile(Project["meta"] "wayrm.sql"),a,"\n")  
  while(i++ < c) {
    if(split(a[i], b, "----") > 0) {
      url = strip(wayurlurl(b[2]))
      if(length(url) == 0) continue
      if(url ~ /^http%3A/)
        gsub(/^http%3A/, "http:", url)
      if(url ~ /^https%3A/)
        gsub(/^https%3A/, "https:", url)
      url = escsql(url)
      if(i == c - 1) {
        part_where = part_where sprintf("'%s'", url)
        part_when_zero = part_when_zero sprintf("\tWHEN '%s' THEN 0", url)
        part_when_one  = part_when_one  sprintf("\tWHEN '%s' THEN 1", url)
        part_when_null = part_when_null sprintf("\tWHEN '%s' THEN NULL", url)
      }
      else {
        part_where = part_where sprintf("'%s', ", url)
        part_when_zero = part_when_zero sprintf("\tWHEN '%s' THEN 0\n", url)
        part_when_one  = part_when_one  sprintf("\tWHEN '%s' THEN 1\n", url)
        part_when_null = part_when_null sprintf("\tWHEN '%s' THEN NULL\n", url)
      }
    }
  }
  print "UPDATE externallinks_global"
  print "SET `reviewed` = CASE `url`"
  print part_when_one
  print "END,"
  print "SET `has_archive` = CASE `url`"
  print part_when_zero
  print "END,"
  print "`archived` = CASE `url`"  
  print part_when_zero
  print "END,"
  print "`archive_url` = CASE `url`"
  print part_when_null
  print "END,"
  print "`archive_time` = CASE `url`"
  print part_when_null  
  print "END"
  print "WHERE `url` IN (" part_where ");"  

  # ---------- newiadate ---------- #

  part_where = ""
  part_when_one = ""
  i = 0
  c = split(readfile(Project["meta"] "newiadate.sql"),a,"\n")  
  while(i++ < c) {
    if(split(a[i], b, "----") > 0) {
      split(b[2], d, " ")
      if(validate_datestamp(d[3]) == "false") {
        bogusdate[i] = a[i]
        continue
      }
      url = strip(d[1])
      if(length(url) == 0) continue
      if(url ~ /^http%3A/)
        gsub(/^http%3A/, "http:", url)
      if(url ~ /^https%3A/)
        gsub(/^https%3A/, "https:", url)
      url = escsql(url)
      iaurl = "https://web.archive.org/web/" d[3] "/" url
      year = substr(d[3], 1, 4)
      if(year == 0 || length(year) < 4) {
        year = "1970"
      }
      month = substr(d[3], 5, 2)
      if(month == 0 || length(month) < 2) {
        month = "01"
      }
      day = substr(d[3], 7, 2)
      if(day == 0 || length(day) < 2) {
        day = "01"
      }
      hour = substr(d[3], 9, 2)
      if(hour == 0 || length(hour) < 2) {
        hour = "00"
      }
      minute = substr(d[3], 11, 2)
      if(minute == 0 || length(minute) < 2) {
        minute = "00"
      }
      second = substr(d[3], 13, 2)
      if(second == 0 || length(second) < 2) {
        second = "00"
      }

      newdate = year "-" month "-" day " " hour ":" minute ":" second

      if(i == c - 1) {
        part_where = part_where sprintf("'%s'", url)
        part_when_one = part_when_one sprintf("\tWHEN '%s' THEN 1", url)
        part_when_url = part_when_url sprintf("\tWHEN '%s' THEN '%s'", url, iaurl)
        part_when_date = part_when_date sprintf("\tWHEN '%s' THEN '%s'", url, newdate)
      }
      else {
        part_where = part_where sprintf("'%s', ", url)
        part_when_one = part_when_one sprintf("\tWHEN '%s' THEN 1\n", url)
        part_when_url = part_when_url sprintf("\tWHEN '%s' THEN '%s'\n", url, iaurl)
        part_when_date = part_when_date sprintf("\tWHEN '%s' THEN '%s'\n", url, newdate)
      }
    }
  }
  print "\nUPDATE externallinks_global"
  print "SET `reviewed` = CASE `url`"
  print part_when_one
  print "END,"
  print "SET `has_archive` = CASE `url`"
  print part_when_one
  print "END,"
  print "`archived` = CASE `url`"  
  print part_when_one
  print "END,"
  print "`archive_url` = CASE `url`"
  print part_when_url
  print "END,"
  print "`archive_time` = CASE `url`"
  print part_when_date  
  print "END"
  print "WHERE `url` IN (" part_where ");"  


  # ---------- logskindeep ---------- #

  part_where = ""
  part_when_one = ""
  part_when_url = ""
  i = 0
  c = split(readfile(Project["meta"] "logskindeep.sql"),a,"\n")  
  while(i++ < c) {
    if(split(a[i], b, "----") > 0) {

      split(b[2], d, " ")

      oldurl = strip(d[2])
      newurl = strip(d[3])
      if(length(oldurl) == 0) continue
      if(length(newurl) == 0) continue
      oldurl = escsql(oldurl)
      newurl = escsql(newurl)

      if(i == c - 1) {
        part_where = part_where sprintf("'%s'", oldurl)
        part_when_one = part_when_one sprintf("\tWHEN '%s' THEN 1", oldurl)
        part_when_url = part_when_url sprintf("\tWHEN '%s' THEN '%s'", oldurl, newurl)
      }
      else {
        part_where = part_where sprintf("'%s', ", oldurl)
        part_when_one = part_when_one sprintf("\tWHEN '%s' THEN 1\n", oldurl)
        part_when_url = part_when_url sprintf("\tWHEN '%s' THEN '%s'\n", oldurl, newurl)
      }
    }
  }
  print "\nUPDATE externallinks_global"
  print "SET `reviewed` = CASE `url`"
  print part_when_one
  print "END,"
  print "SET `has_archive` = CASE `url`"
  print part_when_one
  print "END,"
  print "`archived` = CASE `url`"  
  print part_when_one
  print "END,"
  print "`archive_url` = CASE `url`"
  print part_when_url
  print "END"
  print "WHERE `url` IN (" part_where ");"  


  if(length(bogusdate) > 0) {
    print "\nBogus Dates\n------------\n" > "/dev/stderr"
    for(s in bogusdate)
      print bogusdate[s] > "/dev/stderr"
  }

}


#
# sqlquery - generate a SQL query for the CB database. Modify a single field 'reviewed'
#
function sqlquery2(  url, iaurl, c, a, b, d, i, newdate, part_when_null, part_when_zero, part_where, part_when_one, part_when_url, part_when_date, year, month, day, hour, minute, second) {

  if(! checkexists(Project["meta"] "wayrm.sql") ) {
    print("Error unable to find " Project["meta"] "wayrm.sql")
    return 0
  }
  if(! checkexists(Project["meta"] "newiadate.sql") ) {
    print("Error unable to find " Project["meta"] "newiadate.sql")
    return 0
  }

  # ---------- wayrm ---------- #

  c = split(readfile(Project["meta"] "wayrm.sql"),a,"\n")  
  while(i++ < c) {
    if(split(a[i], b, "----") > 0) {
      url = strip(wayurlurl(b[2]))
      if(length(url) == 0) continue
      if(url ~ /^http%3A/)
        gsub(/^http%3A/, "http:", url)
      if(url ~ /^https%3A/)
        gsub(/^https%3A/, "https:", url)
      url = escsql(url)
      if(i == c - 1) {
        part_where = part_where sprintf("'%s'", url)
        part_when_one  = part_when_one  sprintf("\tWHEN '%s' THEN 1", url)
      }
      else {
        part_where = part_where sprintf("'%s', ", url)
        part_when_one  = part_when_one  sprintf("\tWHEN '%s' THEN 1\n", url)
      }
    }
  }
  print "UPDATE externallinks_global"
  print "SET `reviewed` = CASE `url`"
  print part_when_one
  print "END"
  print "WHERE `url` IN (" part_where ");"  

  # ---------- newiadate ---------- #

  part_where = ""
  part_when_one = ""
  i = 0
  c = split(readfile(Project["meta"] "newiadate.sql"),a,"\n")  
  while(i++ < c) {
    if(split(a[i], b, "----") > 0) {
      split(b[2], d, " ")
      url = strip(d[1])
      if(length(url) == 0) continue
      if(url ~ /^http%3A/)
        gsub(/^http%3A/, "http:", url)
      if(url ~ /^https%3A/)
        gsub(/^https%3A/, "https:", url)
      url = escsql(url)
      iaurl = "https://web.archive.org/web/" d[3] "/" url
      year = substr(d[3], 1, 4)
      if(year == 0 || length(year) < 4)
        year = "1970"
      month = substr(d[3], 5, 2)
      if(month == 0 || length(month) < 2)
        month = "01"
      day = substr(d[3], 7, 2)
      if(day == 0 || length(day) < 2)
        day = "01"
      hour = substr(d[3], 9, 2)
      if(hour == 0 || length(hour) < 2)
        hour = "00"
      minute = substr(d[3], 11, 2)
      if(minute == 0 || length(minute) < 2)
        minute = "00"
      second = substr(d[3], 13, 2)
      if(second == 0 || length(second) < 2)
        second = "00"

      newdate = year "-" month "-" day " " hour ":" minute ":" second

      if(i == c - 1) {
        part_where = part_where sprintf("'%s'", url)
        part_when_one = part_when_one sprintf("\tWHEN '%s' THEN 1", url)
      }
      else {
        part_where = part_where sprintf("'%s', ", url)
        part_when_one = part_when_one sprintf("\tWHEN '%s' THEN 1\n", url)
      }
    }
  }
  print "\nUPDATE externallinks_global"
  print "SET `reviewed` = CASE `url`"
  print part_when_one
  print "END"
  print "WHERE `url` IN (" part_where ");"  

}


#
# Print to screen contents of a file across multiple projects. 
#  First create a file with a list of project ID's and run with the -t <filename> switch
#  Useful for creating a master wayrm file for example.
#
#
function masterfile(projfile, mid,    c,a,i) {

  if(! checkexists(projfile) ) {
    print("Error unable to find " projfile )
    return 0
  }

  c = split(readfile(projfile), a, "\n")

  while(i++ < c) {
    if(length(a[i]) > 1) 
      print strip(readfile(mid a[i] "/wayrm"))
  }
}


#
# Escape a string for SQL (for URI type data)
#   https://dev.mysql.com/doc/refman/5.7/en/string-literals.html
#
function escsql(str,   safe) {

  safe = str
  gsub(/'/,"\\'",safe)
  gsub(/%/,"\\%",safe)
  gsub(/_/,"\\_",safe)

  return safe
}

function usage() {

  print ""
  print "Bug - routines to help debug."
  print ""              
  print "Usage:"
  print "       -n <name>      Name to process. Required"
  print "       -p <project>   Project name. Optional (default in project.cfg)"
  print ""           
  print "       -r             Run WaybackMedic for this name." 
  print "       -v             View name paths. Default."
  print "       -d <type>      Diff. Type = c (default: color) or p (plain text)" 
  print ""
  print "Examples: debug -n \"George Wash\" -d c"                 
  print ""

}

