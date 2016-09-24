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


@include "init.awk"
@include "library.awk"
@include "getopt.awk"

BEGIN {

  while ((C = getopt(ARGC, ARGV, "b:d:p:")) != -1) {
    if(C == "p")                                     # -p <project>        Project to run 
      pid = verifypid(Optarg)
    if(C == "d")                                     # -d <number>         Delay seconds to use (must be > 12, or 0)
      delay = Optarg                                 #                      If -d0 (zero), no delay                    
    if(C == "b")                                     # -b <number>         Number of times to play bell on timeout (default: 1)
      bell = Optarg                                  #                      If -b0 (zero), no bell                    
  }
  setProject(pid)     # library.awk .. load Project[] paths via project.cfg
                      # if -p not given, use default noted in project.cfg

  if( delay == "" || (delay < 12 && delay > 0) || ! isanumber(delay) ) 
    delay = 15 
  else if(delay == 0) 
    delay = 0
  else 
    delay = 15

  if(bell == "") 
    bell = 1
  if(!checkexists("/home/adminuser/scripts/bell"))
    bell = 0

  Talkpagestart = http2var("https://en.wikipedia.org/wiki/User_talk:GreenC_bot")

  main()
}

function main(    name,tempid,article,command,b,bb,summary,result,i,c,talkpage) {

  c = split(readfile(Project["discovered"]), Discovered, "\n")  

  while(i++ < c) {
    
    name = strip(Discovered[i])

# print "name = " name
       
    talkpage = http2var("https://en.wikipedia.org/wiki/User_talk:GreenC_bot")
    if(talkpage != Talkpagestart) {   #  Abort
      prnt("push2wiki.awk: ABORTED by talk page posting. " name)
      bb = 0
      while(bb++ < 4)                                              # Ring my bell...
        system("/home/adminuser/scripts/bell")
        sleep(2)
      exit
    }

    if(length(name) > 0) {           
      tempid = whatistempid(name, Project["index"] )

# print "tempid = " tempid

      if(tempid == "" || tempid == 0) {
        prnt("push2wiki.awk: Error unknown tempid. " name)
        print name >> Project["discoverederror"]
        close(Project["discoverederror"])
      }         
      else {
        if(checkexists(tempid "article.waybackmedic.txt"))  {  # Skip if no changes were made.
          newarticle = strip(getwikisource(name, "dontfollow"))
          article = stripfile(tempid "article.txt")

# print "length = " length(newarticle) " " length(article)

          if(length(newarticle) == 0 || length(article) == 0) {
            prnt("push2wiki.awk: Error unable to retrieve wikisource or article.txt. " name)
            print name >> Project["discoverederror"]
            close(Project["discoverederror"])
          }
          else {                                                    
            if(article != newarticle) {
              prnt("push2wiki.awk: Articles out of sync (old=" length(article) " new=" length(newarticle) "). Saving to auth.demon ... " name)
              if( checkexists(tempid "article.waybackmedic.txt") )
                removefile(tempid "article.waybackmedic.txt")                   
              print name >> Project["meta"] "auth.demon" 
              close(Project["meta"] "auth.demon")
            }
            if(checkexists(tempid "article.waybackmedic.txt")) {
              article = tempid "article.waybackmedic.txt"
              summary = readfile(tempid "editsummary")
              if(length(summary) < 5)
                summary = "[[User:Green Cardamom/WaybackMedic 2|WaybackMedic 2]]"

              safe = name
              gsub(/["]/,"\\\"",safe)  # Special character shell escape                
              gsub(/[$]/,"\\$",safe)                  
              command = Exe["pywikibotsavepage"] " \"" safe "\" \"" summary "\" \"" article "\""

# print "command = " command
# exit
              result = sys2var(command)

              if(result ~ /OKMEDIC/) { # Success
                prnt("push2wiki.awk: Status successful (savepage.py). Page uploaded to Wikipedia. " name)
                print name >> Project["discovereddone"]
                close(Project["discovereddone"])
              }
              else {
               prnt("push2wiki.awk: Error uploading to Wikipedia (savepag.py). " name)
                print name >> Project["discoverederror"]
                close(Project["discoverederror"])
              }              
            }
            else {
              prnt("push2wiki.awk: No changes to article (2). " name)
            }
          }
        }
        else {
          prnt("push2wiki.awk: No changes to article (1). " name)
        }
      }
    }
    Discovered[i] = ""
    writediscovered()
    sleep( delay )
  } 

  bb = 0
  while(b++ < 3) {                                             # Ring my bell...
    system("/home/adminuser/scripts/bell")
    sleep(2)
  }

}


#
# Write Discovered[] to Project["discovered"], repacking the file
#
function writediscovered() {

  if(checkexists(Project["discovered"])) {
    close(Project["discovered"])
    command = Exe["rm"] " " Project["discovered"]
    sys2var(command)
    system("")
  }
  if(checkexists(Project["discovered"])) {
    print "writediscovered(): Unable to delete " Project["discovered"]
    exit
  }

  for(o in Discovered) {
    if(length(Discovered[o]) > 0) 
      print Discovered[o] >> Project["discovered"]
  }
  close(Project["discovered"])

  # Backup
  if(checkexists(Project["discovered"])) {
    command = Exe["cp"] " " Project["discovered"] " " Project["discovered"] ".bak"
    sys2var(command)
    system("")
  }

}

#
# Return the path/tempid of a name (eg. /home/adminuser/wi-awb/temp/wi-awb-0202173111/)
#
function whatistempid(name, filepath,      s, a, re) {

  if(! checkexists(filepath) ) {
    prnt("push2wiki.awk: Error unable to find " filepath ". " name )
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
# Print and log messages
#
function prnt(msg) {
  if( length(msg) > 0 ) {
    print msg 
    print(strftime("%Y%m%d %H:%M:%S") " " msg) >> Home "push2wiki.log"
    close(Home "push2wiki.log")
  }
}

function removefile(str) {
      if( checkexists(str) )
        sys2var( Exe["rm"] " -- " str)
      if( checkexists(str) ) {
        prnt("push2wiki.awk: Error unable to delete " str ", aborting.")
        exit
      }
      system("") # Flush buffer
}

