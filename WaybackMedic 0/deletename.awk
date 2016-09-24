#!/usr/local/bin/gawk -E

@include "getopt.awk"
@load "readfile"

#
# Delete entries from a log file based on a list of names
#

BEGIN {

  while ((C = getopt(ARGC, ARGV, "n:l:")) != -1) {
    if(C == "n")
      namefile = Optarg
    if(C == "l")
      logfile = Optarg
  }

  if(!length(namefile)) {
    print "Unable to open namefile: " namefile
    exit
  }
  if(!length(logfile)) {
    print "Unable to open logfile: " logfile
    exit
  }

  c = split(readfile(namefile), a, "\n")
  d = split(readfile(logfile), b, "\n")

  while(i++ < d) {
    if(b[i] == "") continue
    split(b[i],g,"----")
    mark = j = 0
    while(j++ < c) {
      if(a[j] == "") continue
      if( index(g[1], a[j]) ) {
#print g[1] " = " a[j]
#if(a[j] == "McGraw Hill Financial") print "1. McGraw Hill Financial" > "/dev/stderr"
        mark = 1
        break
      }
    }
    if(!mark) {
#if(b[i] ~ "McGraw Hill Financial") print "2. McGraw Hill Financial" > "/dev/stderr"
      print b[i]
    } 
  }

}
