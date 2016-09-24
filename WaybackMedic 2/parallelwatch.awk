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


# Demon to pass data back and forth between Windows host and Linux guest OS under VirtualBox
# See also demon-win.awk for the version running on the Windows host.
# Purposes is to run AWB on windows, and unix scripts on Linux. 

# This is the "Auto" version if you plan to update via AWB, manually or automatic
#   The assumption is you have already run and processed the data via ./project

@include "init.awk"
@include "library.awk"
@include "getopt.awk"

BEGIN {

  while ((C = getopt(ARGC, ARGV, "t:p:")) != -1) {
    if(C == "p")                                     # -p <project>        Project to run 
      pid = verifypid(Optarg)
    if(C == "t")                                     # -t <seconds>        Number of seconds between refresh
      timer = verifypid(Optarg)
  }
  setProject(pid)     # library.awk .. load Project[] paths via project.cfg
                      # if -p not given, use default noted in project.cfg

  if(!checkexists("/home/adminuser/scripts/bell")) {
    print "Can't find /home/adminuser/scripts/bell"
    exit
  }

  if(timer == "" || timer < 60) {
    print "Setting refresh to 900 seconds (15 minutes)"
    timer = 900
  }

  bellcount = 10

  main()

}

function main(    name,tempid,curcountindex,outindex,commandindex,commandcritical,curcountcritical,outcritical,b,i) {

  commandindex = Exe["wc"] " " Project["meta"] "index.temp"
  commandcritical = Exe["wc"] " " Project["meta"] "critical"

  if(!checkexists(Project["meta"] "critical")) 
    sys2var(Exe["touch"] " " Project["meta"] "critical")
  if(!checkexists(Project["meta"] "index.temp"))  {
    print "Unable to find " Project["meta"] "index.temp"
    exit
  }


  while(1) {

    split(sys2var(commandindex), outindex, " ")
    curcountindex = outindex[1]
    split(sys2var(commandcritical), outcritical, " ")
    curcountcritical = outcritical[1]

    sleep(timer)  

    split(sys2var(commandindex), outindex, " ")
    newcountindex = outindex[1]
    split(sys2var(commandcritical), outcritical, " ")
    newcountcritical = outcritical[1]

    if(curcountindex == newcountindex) {                                
      if( sys2var("ps aux | grep \"perl /usr/bin/parallel\" | grep -v grep") ~ "perl /usr/bin/parallel") {
        i = 0
        while(i++ < bellcount) {                                # Abnormal exit
          system("/home/adminuser/scripts/bell")
          sleep(3)
        }
        exit
      }
      else {                                                    # Normal exit
        print strftime("%Y%m%d %H:%M:%S") ": " newcount
        system("/home/adminuser/scripts/bell")
        exit
      }
    }
    else {
      if(int(newcountcritical) > int(int(curcountcritical + 10)) ) {
        i = 0
        print strftime("%Y%m%d %H:%M:%S") ": Too many critical failures during the time period."
        while(i++ < bellcount) {                                # Abnormal condition
          system("/home/adminuser/scripts/bell")
          sleep(3)
        }
      }
                                                                # Keep on running 
      changes = newcountindex - curcountindex
      print strftime("%Y%m%d %H:%M:%S") ": " newcountindex " (" changes ")"

    }
  }
}


