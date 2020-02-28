#!/usr/bin/gawk -bE

# The MIT License (MIT)
#
# Copyright (c) 2020 by User:GreenC (at en.wikipedia.org)
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

#
# INSTALL: 
#  1. Download tre-agrep available via apt etc..
#  2. Set its location the line below Exe["agrep"]
#  3. Set location of awk in hash-bang line above
#  4. chmod 755 agrep.awk
#

#----------------------------------------------------
# Approximate (fuzzy) matching using tre-agrep
#
#  source  = source text
#  target  = text to search for in source
#  percent = maximum error rate percentage of search.
#            ie. if source is 12 characters and max error rate is 25%, set to ".25"
#                and it will return a match if up to 3 characters are wrong.
#  debug   = if "1", print debug statement.
#  stype   = target string is "regex" or "plain" text. Or "exact" for exact match (case-insensitive)
#  rlength = optional. Length of target string without regex characters. Use if using "regex".
#
#  Error rate is hard coded: max out at "6" on the upper and "1" on the lower.
#  Agrep set to case-insensitive
#
#  Return 0 if no match, otherwise number of matches
#
#----------------------------------------------------

BEGIN {

  Exe["agrep"] = "/usr/bin/tre-agrep"

  _debug = 0
  Optind = Opterr = 1  
  while ((C = getopt(ARGC, ARGV, "ds:t:p:r:l:")) != -1) {
      opts++
      if(C == "s")                 #  -s 'source_text'
        _source = Optarg
      if(C == "t")                 #  -t 'search_text'
        _target = Optarg
      if(C == "p")                 #  -p 'percent'
        _percent = Optarg
      if(C == "r")                 #  -r 'search type'
        _type = Optarg
      if(C == "l")                 #  -l 'search length'
        _length = Optarg
      if(C == "d")                 #  -d Enable debugging output
        _debug = 1
  }

  if(empty(opts)) {
    usage()
    exit
  }


  if(empty(_source) || empty(_target) || empty(_type) ) {
    print "0"
    exit
  }

  if(empty(_percent) && _type != "exact") {
    print "0"
    exit
  }
  
  if(empty(_length))
    print agrep(_source, _target, _percent, _debug, _type)
  else
    print agrep(_source, _target, _percent, _debug, _type, _length)

}

#
# Agrep.awk
#
function agrep(source, target, percent, debug, stype, rlength,      slength,errorlimit,results,s,command)
{

 if(stype == "")
   stype = "plain"
 slength = length(target)
 if(rlength == "" || rlength == 0)
  rlength = slength
 if(stype == "regex")
   slength = rlength

 # Limit # of errors to 25% of length of str, or no more than 6, whichever is less
  if(slength > 24)
    errorlimit = 6
  else
    errorlimit = int(slength * percent)
  if(errorlimit < 2) {
    if(slength < 6)
      errorlimit = 1
    else
      errorlimit = 2
  }

  if(stype == "regex")
    command = Exe["agrep"] " -i -c -" errorlimit " --word-regexp --regexp=" shquote(strip(target)) 
  else if(stype == "exact")
    command = Exe["agrep"] " -i -k -c -0 -- " shquote(strip(target))
  else if(stype == "plain")
    command = Exe["agrep"] " -i -k -c -" errorlimit  " -- " shquote(strip(target))
  else
    return 0

  if(debug)
    print "Agrep command = " command

  print agrepstrip(source) |& command
  close(command, "to")
  command |& getline results
  close(command)

  if(results > 0)
    return results
  else
    return 0

}

#
# Remove problem shell characters when running agrep
#
function agrepstrip(str) {
    return gensub(/[`]/, "", "g", str)
}

#
# Usage
#
function usage() {

  print ""
  print "agrep.awk - approximate match. Interface to tre-agrep"
  print ""
  print "Usage:"
  print "       -s <source>    Source text"
  print "       -t <target>    Text to search for in source"
  print "       -p <percent>   maximum error rate percentage of search"            
  print "                       ie. if source is 12 characters and max error rate is 25%, set to \".25\""
  print "                       and it will return a match if up to 3 characters are wrong."
  print "       -t <type>      Target string is plain, regex, exact"
  print "                       if exact, search will accept no errors other than case"
  print "       -l <length>    When using regex, pass length of search text w/out regex chars"
  print "       -d             Debug output"
  print ""
  print "Return 0 if no match, otherwise number of matches"
  print "" 
  print "Error rate is hard coded: max out at \"6\" on the upper and \"1\" on the lower."
  print "Agrep set to case-insensitive by default"
  print ""
  print "Examples: "
  print "   agrep.awk -s \"Hello\" -t \"Hellow\" -p \"0.25\" -r \"plain\""
  print "   agrep.awk -s \"Hello\" -t \"[Hh]ellow\" -p \"0.25\" -r \"regex\" -l \"6\""
  print "   agrep.awk -s \"Hello\" -t \"hello\" -r \"exact\""
  print ""
}

#
# _____________________________ Library ________________________________

#
# Awk has a limited standard library so these basic functions are included to make it portable
#

#                
# empty() - return 0 if string is 0-length
#                  
function empty(s) {
    if (length(s) == 0)
        return 1               
    return 0     
}        

#             
# shquote() - make string safe for shell     
#                     
function shquote(str,  safe) {
    safe = str                           
    gsub(/'/, "'\\''", safe)
    gsub(/’/, "'\\’'", safe)
    return "'" safe "'"
}

#
# strip() - strip leading/trailing whitespace
#   
function strip(str) {
    if (match(str, /[^ \t\n].*[^ \t\n]/))
        return substr(str, RSTART, RLENGTH)
    else if (match(str, /[^ \t\n]/))                
        return substr(str, RSTART, 1)
    else
        return ""
}

# 
# getopt() - command-line parser
# 
#   . define these globals before getopt() is called:
#        Optind = Opterr = 1
# 
#   Credit: GNU awk (/usr/local/share/awk/getopt.awk)
#
function getopt(argc, argv, options,    thisopt, i) {

    if (length(options) == 0)    # no options given
        return -1

    if (argv[Optind] == "--") {  # all done
        Optind++   
        _opti = 0  
        return -1
    } else if (argv[Optind] !~ /^-[^:[:space:]]/) {
        _opti = 0
        return -1     
    }
    if (_opti == 0)
        _opti = 2
    thisopt = substr(argv[Optind], _opti, 1)
    Optopt = thisopt
    i = index(options, thisopt)
    if (i == 0) {
        if (Opterr)
            printf("%c -- invalid option\n", thisopt) > "/dev/stderr"
        if (_opti >= length(argv[Optind])) {
            Optind++
            _opti = 0
        } else
            _opti++
        return "?"
    }
    if (substr(options, i + 1, 1) == ":") {
        # get option argument
        if (length(substr(argv[Optind], _opti + 1)) > 0)
            Optarg = substr(argv[Optind], _opti + 1)
        else
            Optarg = argv[++Optind]
        _opti = 0
    } else
        Optarg = ""
    if (_opti == 0 || _opti >= length(argv[Optind])) {
        Optind++    
        _opti = 0              
    } else       
        _opti++    
    return thisopt
}


