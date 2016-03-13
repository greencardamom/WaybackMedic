@include "init.awk"
@include "library.awk"

#
#   Maintain index file. This will add a new entry and remove (re-pack) any prior name-duplicate entries 
#     keeping chronological order of addition.
#
# pass variables:
#               stamp = code or message on the right side of separateor eg. John Smith|wi-awb-12344545
#                        if stamp is blank (eg. -v stamp="") then there is no separator and a 1D flat file.
#                        Responsibility of calling program to ensure all calls to database are consistent about blank
#                        stamp value otherwise things will get garbaled. 
#               name = wikipedia article name complete no underscore. Name on left side of separator
#               indexf = name of index file *with full path* !!
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

BEGIN {

  debugfile = "/home/adminuser/wayback-medic/debug.index"

  if( stamp == "" ) 
    sep = ""
  else
    sep = "|"

  if( ! length(name) > 1 || ! length(stamp) > 1 || ! length(indexf) > 1 ) {
    print 0
    print name "|" filename "|4" >> debugfile
    exit
  }

  c = split(indexf,a,"/")
  filename = a[c]
  if( ! awklock(filename) ) {
    print 0
    myexit(filename,name,"1")
  }

  if(! checkexists(indexf, "index.awk", "check") ) {
    print name sep stamp > indexf
    close(indexf)
    print 1
    myexit(filename)
  }
  else {
    print name sep stamp >> indexf
    close(indexf)
    filep = readfile(indexf)
    c = split(filep, a, "\n")
    filep = ""
    while(i++< c) {
      split(a[i], b, "|")
      curname = strip(b[1])
      Hold[curname]["name"] = curname
      Hold[curname]["stamp"] = strip(b[2])
      Hold[curname]["index"] = i
    }
  }

 # re-index to prepare for sorting
  for(o in Hold) {
    Hold2[ Hold[o]["index"] ]["name"] = Hold[o]["name"]
    Hold2[ Hold[o]["index"] ]["stamp"] = Hold[o]["stamp"]
  }

  delete Hold
  removefile(indexf,filename)

  PROCINFO["sorted_in"] = "@ind_num_asc"
  for(o in Hold2) {
    if( length(Hold2[o]["name"]) > 0 ) {
      print Hold2[o]["name"] sep Hold2[o]["stamp"] >> indexf
    }
  }

  close(indexf)
  if(length(Hold2) > 0)
    print 1
  else {
    print 0
    print name "|" filename "|3" >> debugfile
  }

  myexit(filename)

}

#
# Delete a file
#
function removefile(str, filename) {

      if( checkexists(str, "index.awk", "check") ) {
        sys2var( Exe["rm"] " -- " str)
        system("")
      }
      if( checkexists(str, "index.awk", "check") ) {
        print("index.awk: Unable to delete " str ", aborting.") > "/dev/stderr"
        print 0
        myexit(filename,"","2")
      }
}

# Lock database with mkdir method and error status returned by OS
#
function awklock(filename,  status,count) {

  # mkdir lock 2>/dev/null ; echo $?

  while(1) {       
    status = sys2var( Exe["mkdir"] " /tmp/lock." filename " 2>/dev/null ; echo $?")
    if(count > 20) {
      print "Error in init.awk: awklock() - stuck lock file /tmp/lock." filename > "/dev/stderr"    
      return 0
    }
    if(status != 0) {
      sleep(2)
      count++       
    }
    else                 
      break      
  }
  return 1                       
}          

#
# Remove lockfile
#
function myexit(filename, name, point) {

  if(name)
    print name "|" filename "|" point >> debugfile

  if(exists("/tmp/lock." filename))
    sys2var( Exe["rm"] " -r -- /tmp/lock." filename)

  exit

}

#
# Run a system command and store result in a variable
#   eg. googlepage = sys2var("wget -q -O- http://google.com")
# Supports pipes inside command string. Stderr is sent to null.
# If command fails (errno) return null
#
function sys2var2(command        ,fish, scale, ship) {

         command = command " 2>/dev/null"
         while ( (command | getline fish) > 0 ) {
             if ( ++scale == 1 )
                 ship = fish
             else
                 ship = ship "\n" fish
         }        
         close(command)    
         return ship
}

