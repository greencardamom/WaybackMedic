@load "filefuncs"

#
# demon-win.awk - script called by AWB Tools->External processes
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

 # Begin configuration

  rm = "/usr/bin/rm"
  sleepbin = "/usr/bin/sleep"
  dir = "/mnt/ramdisk/"             # Shared directory with WaybackMedic (ie. the "Ramdisk" setting in init.awk)

 # End configuration

  fname = dir "name.txt"            # File containing name passed *from* AWB
  farticle = dir "article.txt"      # File containing article passed *to* AWB
  fabort = dir "abort.txt"          # File flag remote script aborted


  name = ARGV[1]
                                    # Clear out old files
  removefile(farticle)
  removefile(fname)
  removefile(fabort)
  system("")                        # Flush buffers

  if(length(name) == 0)             # Abort if bad name data
    exit

  printf("%s",name) > fname
  close(fname)
  system("")

  print("demon-win.awk: Waiting for " farticle " ...")

  while(1) {
    sleep(2)
    if( exists(fabort) ) {
      print("demon-win.awk: Received abort.txt")
      removefile(fabort)
      exit
    }
    if( exists(farticle) ) {
      print("demon-win.awk: Received article.txt")
      exit
    }
  }

}


function removefile(str) {

      if( exists(str) )
        sys2var(rm " -- " str)
      if( exists(str) ) {
        print("demon-lin.awk: Unable to delete " str ", aborting.")
        exit
      }
}

#
# Check for file existence. Return 1 if exists, 0 otherwise.
#  Requires GNU Awk:
#     @load "filefuncs"
#
function exists(name    ,fd) {
    if ( stat(name, fd) == -1)
      return 0
    else
      return 1
}

#
# Run a system command and store result in a variable
#   eg. googlepage = sys2var("wget -q -O- http://google.com")
# Supports pipes inside command string. Stderr is sent to null.
# If command fails (errno) return null
#
function sys2var(command        ,fish, scale, ship) {

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

#
# Sleep
#
function sleep(seconds){
  if(seconds == 0) return
  sys2var(sleepbin " " seconds)
}


