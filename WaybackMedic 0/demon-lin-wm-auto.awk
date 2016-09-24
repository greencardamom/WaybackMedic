#!/usr/local/bin/awk -E

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

# "Auto" if you plan to update via AWB, manually or automatic
#   The assumption is you have already run and processed the data via ./project

# Demon to pass data back and forth between Windows host and Linux guest OS under VirtualBox
# See also demon-win.awk for the version running on the Windows host.
# Purposes is to run AWB on windows, and unix scripts on Linux. 

@include "init.awk"
@include "library.awk"
@include "getopt.awk"

BEGIN {

  while ((C = getopt(ARGC, ARGV, "d:p:")) != -1) {
    if(C == "p")                                     # -p <project>        Project to run 
      pid = verifypid(Optarg)

    if(C == "d")                                     # -d <number>         Delay seconds to use (must be > 12, or 0)
      delay = Optarg                                 #                     If -d0 (zero), no delay 
                   
    if(C == "m")                                     # -m <r|s>            What to do if article on WP has been edited since medic ran
      method = Optarg                                #                     If "-m r" re-run medic real-time
                                                     #                     If "-m s" save name to <meta>/auth.demon 
  }
  setProject(pid)     # library.awk .. load Project[] paths via project.cfg
                      # if -p not given, use default noted in project.cfg

  if( delay == "" || (delay < 12 && delay > 0) || ! isanumber(delay) ) 
    delay = 15 
  else if(delay == 0) 
    delay = 0
  else 
    delay = 15

  if(method !~ /^r$|^s$/)
    method = "s"

  main()

}

function main(    name,tempid,article,command) {

  removefile(Ramdisk "abort.txt")                # Clear out old files. demon-lin should always be run as the first step, before AWB starts processing.
  removefile(Ramdisk "done.txt")              
  removefile(Ramdisk "article.txt")              
  removefile(Ramdisk "name.txt")              

  prnt("\ndemon-lin.awk: Waiting for " Ramdisk "name.txt ...")

  while(1) {

    sleep(2)
    Z++
    if(Z > 500) {   # time-out. 2500 = about 90 minutes w/ 2sec sleep
      print "demon-lin.awk: Time out"
      exit
    }

    if( checkexists(Ramdisk "name.txt") ) {

      Z = 0                              # reset time-out
      name=article=tempid=choose=""      # reset variables

      name = strip( readfile(Ramdisk "name.txt") )
      prnt("demon-lin.awk: New job request: " name )
      removefile(Ramdisk "name.txt")
      removefile(Ramdisk "done.txt")
     
      if(length(name) > 0) {           
          tempid = whatistempid(name, Project["index"] )
          if(tempid == "" || tempid == 0) {
            abort("demon-lin.awk: Error unknown tempid. " name)
          }         
          else {
            if(checkexists(tempid "article.waybackmedic.txt"))  {  # Skip if no changes were made.
              newarticle = strip(http2var("https://en.wikipedia.org/wiki/" gensub(/[ ]/, "_", "g", name) "?action=raw"))
              article = strip(readfile(tempid "article.txt"))
              if(length(newarticle) == 0 || length(article) == 0) {
                abort("demon-lin.awk: Error unable to retrieve wikisource or article.txt. " name)
              }
              else {                                                    
                if(length(article) != length(newarticle)) {
                  prnt("demon-lin.awk: Article lengths out of sync (old=" length(article) " new=" length(newarticle) ").")
                  prnt("               old ID: " tempid)
                  if(method == "r") {
                    prnt("demon-lin.awk: Re-running Medic ...")
                    print article > tempid "article.old.txt"
                    print newarticle > tempid "article.txt"
                    close(tempid "article.old.txt")
                    close(tempid "article.txt")
                    if( checkexists(tempid "article.waybackmedic.txt") )
                      removefile(tempid "article.waybackmedic.txt")                    
                    command = Exe["bug"] " -n \"" name "\" -p \"" Project["id"] "\" -r"
                    system(command)
                    tempid = whatistempid(name, Project["index"] )  # tempid shouldn't change 
                    prnt("               new ID: " tempid)
                    article = readfile(tempid "article.txt")
                    if(length(article) == 0) 
                      abort("demon-lin.awk: Error unable to run Wayback Medic. " name)
                  }
                  else if(method == "s") {
                    prnt("\ndemon-lin.awk: Saving " name " to auth.demon for later processing.")
                    if( checkexists(tempid "article.waybackmedic.txt") )
                      removefile(tempid "article.waybackmedic.txt")                    
                    print name >> Project["meta"] "auth.demon"
                    close(Project["meta"] "auth.demon")
                  }
                }
                if(checkexists(tempid "article.waybackmedic.txt")) {
                  article = readfile(tempid "article.waybackmedic.txt")
                  print article > Ramdisk "article.txt"
                  close(Ramdisk "article.txt")                  
                  prnt("demon-lin.awk: Status successful. Copying article.waybackmedic.txt to shared directory. " name)
                  sleep( delay )
                  print "done" > Ramdisk "done.txt"
                  close(Ramdisk "done.txt")
                }
                else {
                  prnt("\ndemon-lin.awk: No changes to article.")
                }
              }
            }
            else {
              prnt("\ndemon-lin.awk: No changes to article.")
            }
          }
      } 
      else {
        abort("demon-lin.awk: error retrieving name")
      }  
      prnt("\ndemon-lin.awk: Waiting for " Ramdisk "name.txt ...")
    }
  }
}

#
# Return the path/tempid of a name (eg. /home/adminuser/wi-awb/temp/wi-awb-0202173111/)
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
      return strip(a[2])
    }
  }
  close(filepath)
  return 0
}

#
# Return 1 if name is in file 
#
#
# Abort 
#
function abort(msg,  filen) {
  if( length(msg) > 0 ) 
    prnt(msg)
  printf "0" > Ramdisk "abort.txt"
  close(Ramdisk "abort.txt")
}

#
# Print and log messages
#
function prnt(msg) {
  if( length(msg) > 0 ) {
    print(msg)
    print(strftime("%Y%m%d %H:%M:%S") " " msg) >> Home "demon-lin.log"
    close(Home "demon-lin.log")
  }
}

function removefile(str) {
      if( checkexists(str) )
        sys2var( Exe["rm"] " -- " str)
      if( checkexists(str) ) {
        abort("demon-lin.awk: Error unable to delete " str ", aborting.")
        exit
      }
      system("") # Flush buffer
}

