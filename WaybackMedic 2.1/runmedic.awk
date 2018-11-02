#!/usr/local/bin/gawk -bE   

#
# Run medic eg. runmedic 20170601.001-002 auth
#
#  Pass project ID as first arg and name of file to process as second
#

# The MIT License (MIT)
#
# Copyright (c) 2016-2018 by User:GreenC (at en.wikipedia.org)
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

# get bot name
BEGIN {
  delete _pwdA
  _pwdC = split(ENVIRON["PWD"],_pwdA,"/")
  BotName = _pwdA[_pwdC]
}

@include "botwiki.awk"
@include "library.awk"

BEGIN {

  delay = "1"  # delay between each proc startup
  procs = "28"   # number of procs to run in parallel

  if(!checkexe(Exe["date"], "date") || !checkexe(Exe["parallel"], "parallel") || !checkexe(Exe["driver"], "driver") || !checkexe(Exe["wc"], "wc") || !checkexe(Exe["project"], "project"))
    exit

  dateb = sys2var(Exe["date"] " +'%s'")

  pid = ARGV[1]
  fid = ARGV[2]

  if(pid ~ /^imp/) 
    metadir = Home "metaimp/"
  else
    metadir = Home "meta/"

  if(checkexists(metadir pid "/index.temp")) {
    stdErr("runmedic.awk: Error: " metadir pid "/index.temp exists - delete or save it before running")
    exit
  }

  # parallel -a meta/$1/$2 -r --delay 2 --trim lr -k -j 27 ./driver -p $1 -n {}
  command = Exe["parallel"] " --joblog +joblog -a " metadir pid "/" fid " -r --delay " delay " --trim lr -k -j " procs " " Exe["driver"] " -i 30 -p " pid " -n {}"

  while ( (command | getline fish) > 0 ) {
    if ( ++scale == 1 )     {
      print fish
    }
    else     {   
      print "\n" fish      
    }
  }
  close(command)
  
  system("")
  sleep(1)

  # ./project -j -p $1
  command = Exe["project"] " -j -p " pid
  sys2var(command)

  system("")
  sleep(1)

  # mv meta/$1/index.temp meta/$1/index.temp.$2
  if(checkexists(metadir pid "/index.temp" )) 
    sys2var(Exe["mv"] " " shquote(metadir pid "/index.temp") " " shquote(metadir pid "/index.temp." fid) )

  system("")
  bell()

  datef = sys2var(Exe["date"] " +'%s'") - dateb
  acount = wc(metadir pid "/" fid)
  print "\nProcessed " acount " articles in " (datef / 60) " minutes. Avg " (datef / acount) " sec each"

  #datee = sys2var(Exe["date"] " +'%s'")
  #datef = (datee - dateb) 
  #acount = sys2var(Exe["wc"] " -l " shquote(metadir pid "/" fid) " | awk '{print $1}'")
  #avgsec = datef / acount 
  #print "\nProcessed " acount " articles in " (datef / 60) " minutes. Avg " (datef / acount) " sec each (delay = " delay "sec ; procs = " procs  ")"

}

