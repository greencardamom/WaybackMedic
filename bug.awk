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

  while ((C = getopt(ARGC, ARGV, "vrp:n:d:")) != -1) { 
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

  if(type ~ /diff/) {
    diff(name, difftype)
    exit
  }

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
  command = Exe["medic"] " -p \"" Project["id"] "\" -n \"" name "\" -s \"" Inx["path"] "article.txt\""
  system(command)

}

function view(name) {

  getindex(name)
  print "Name: " Inx["name"]
  print "Meta: cd " Project["meta"]
  print "Data: cd " Inx["path"]
  print "./medic -p \"" Project["id"] "\" -n \"" name "\" -s \"" Inx["path"] "article.txt\""

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
    abort("demon-lin.awk: Error unable to find " filepath ". " name )
    return 0    
  }
  re = "^" regesc2(strip(name)) "$"
  while ((getline s < filepath ) > 0) {
    split(s, a, "|")
    if(strip(a[1]) ~ re) {
      close(filepath)
      return strip(s)
    }               
  }
  close(filepath)
  return 0
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

