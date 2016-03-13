#!/usr/local/bin/gawk -E

# Create data files/directories and launch medic.awk

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

  while ((C = getopt(ARGC, ARGV, "hp:n:")) != -1) {
      opts++
      if(C == "p")                 #  -p <project>   Use project name. Default in project.cfg
        pid = verifypid(Optarg)
      if(C == "n")                 #  -n <name>      Name to process.
        namewiki = verifyval(Optarg)

      if(C == "h") {
        usage()
        exit
      }

  }
  if( pid ~ /error/ || ! opts || namewiki == "" ){
    usage()
    exit
  }

  setProject(pid)     # library.awk .. load Project[] paths via project.cfg

  wm_temp = Project["data"] "wm-" sys2var( Exe["date"] " +\"%m%d%H%M%S\"") "/" 
  if(!mkdir(wm_temp))
    exit

# Save wikisource
  print http2var("https://en.wikipedia.org/wiki/" gensub(/[ ]/, "_", "g", namewiki) "?action=raw") > wm_temp "article.txt"
  close(wm_temp "article.txt")

# Save namewiki
  print namewiki > wm_temp "namewiki.txt"

# Create index entry
  sendto(Project["index"], namewiki, wm_temp)

# Run medic

  print "\n"namewiki"\n"

  command = Exe["medic"] " -p \"" Project["id"] "\" -n \"" namewiki "\" -s \"" wm_temp "\"article.txt"  
  changes = sys2var(command)
  if(changes) {
    print "    Found " changes " change(s) for " namewiki > "/dev/stderr"
    sendto(Project["discovered"], namewiki, "")
  }
  else {
    if(checkexists(wm_temp "article.waybackmedic.txt")) {
      sys2var( Exe["rm"] " -- " wm_temp "article.waybackmedic.txt")
    }
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

