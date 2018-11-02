#!/usr/local/bin/gawk -bE

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

@include "library.awk"
@include "getopt.awk"

BEGIN {

  while ((C = getopt(ARGC, ARGV, "pu:t:c:")) != -1) {
      opts++
      if(C == "u")                 #  -u <url>         URL to check.
        url = verifyval(Optarg)
      if(C == "t")                 #  -t <timestamp>   (optional) Timestamp. Default: "20070101"
        timestamp = verifyval(Optarg)
      if(C == "c")                 #  -c <closest>     (optional) Closest: before|after|either - Default: before 
        closest = verifyval(Optarg)
      if(C == "p")                 #  -p               (optional) Print API command not results.
        showapi = 1

      if(C == "h") {
        usage()
        exit
      }
  }

  if(closest !~ /before|after|either/)
    closest = "before"
  if(!isanumber(timestamp) || timestamp == "")
    timestamp = "20070101"

  if( url ~ /error/ || ! opts || url == ""){
    usage()
    exit
  }

  url = urlencodeawk(url)

  command = "wget --header=" shquote("Wayback-Api-Version: 2") " --post-data=" shquote("url=" url "&closest=" closest "&statuscodes=200&statuscodes=203&statuscodes=206&statuscodes=403&tag=&timestamp=" timestamp) " -q -O- " shquote("http://archive.org/wayback/available")

  if(showapi)
    print command
  else
    print sys2var(command)

}


function usage() {

  print ""
  print "API - show Wayback API 2 results for a single URL"
  print ""
  print "     Usage  : api -u <url>"
  print ""
  print "     Options:"
  print "              -c <closest>   - before|after|either - default: before"
  print "              -t <timestamp> - default: 20070101"
  print "              -p             - print the API URL instead of results"
  print ""

}

