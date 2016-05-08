@load "filefuncs"
@load "readfile"

#
# Library routines
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


#
# Set Project[id/temp/locale] names and paths
#  Use Config["default"] unless Project is defined via pid (ie. command-line option)
#
function setProject(pid) {

        delete Project  # Global array

        if(pid ~ /error/) {
          print "Unknown project id. Using default in project.cfg" > "/dev/stderr"
          Project["id"] = Config["default"]["id"]
        }
        else if(pid == "" || pid ~ /unknown/ )  
          Project["id"] = Config["default"]["id"]
        else
          Project["id"] = pid

        for(o in Config) {
          if(o == Project["id"] ) {         
            for(oo in Config[o]) {
              if(oo == "data")
                Project["data"] = Config[o][oo]          
              else if(oo = "meta")
                Project["meta"] = Config[o][oo]          
            }
          } 
        } 

        if(Project["data"] == "" || Project["id"] == "" || Project["meta"] == "" ) {
          print "library.awk setProject(): Unable to determine Project"
          exit
        }

        Project["auth"]   = Project["meta"] "auth"
        Project["index"]  = Project["meta"] "index"
        Project["indextemp"]  = Project["meta"] "index.temp"
        Project["wayall"] = Project["meta"] "wayall"               # List of all IA links
        Project["newiadate"] = Project["meta"] "newiadate"         # Log of cases when the IA snapshot date changed
        Project["newaltarch"] = Project["meta"] "newaltarch"       # Log of cases when alternative archive's are added
        Project["manual"] = Project["meta"] "manual"               # Manual processing needed
        Project["timeout"] = Project["meta"] "timeout"             # Remote server timed out
        Project["apimismatch"] = Project["meta"] "apimismatch"     # API returned fewer records than sent. name|sent|received
        Project["jsonmismatch"] = Project["meta"] "jsonmismatch"   # API returned different size csv files. name|csv1|csv2
        Project["servicename"] = Project["meta"] "servicename"     # Archive service name found is unknown. Update servicename() in medic.awk
        Project["bogusapi"] = Project["meta"] "bogusapi"           # IA API returned a bogus recommendation. Page actually works.
        Project["bummer"] = Project["meta"] "bummer"               # Found a bummer page. 
        Project["docfixes"] = Project["meta"] "Documentation"      # Documentation / fix revisions for this project
        Project["cbignore"] = Project["meta"] "cbignore"           # {{cbignore|bot=medic}} was added to these articles
        Project["critical"] = Project["meta"] "critical"           # Critical system errors
        Project["discovered"] = Project["meta"] "discovered"       # Articles that have changes made (for import to AWB)

        Project["wayrm"]  = Project["meta"] "wayrm"                # IA links deleted from articles
        Project["wayrmfull"]  = Project["meta"] "wayrmfull"        # Formated to be run through medic.awk for testing

        Project["log404"] = Project["meta"] "log404"
        Project["logspurone"] = Project["meta"] "logspurone"
        Project["logmissprot"] = Project["meta"] "logmissprot"
        Project["logmissweb"] = Project["meta"] "logmissweb"
        Project["logemptyarch"] = Project["meta"] "logemptyarch"
        Project["logtrail"] = Project["meta"] "logtrail"
        Project["logemptyway"] = Project["meta"] "logemptyway"
        Project["logencode"] = Project["meta"] "logencode"

}

#
# Verify in case -p is given with no value. 
#
function verifypid(pid) {
  if(pid == "" || substr(pid,1,1) ~ /^[-]/)
    return "error"
  return pid
}

#
# Verify any argument has valid value
#
function verifyval(val) {
  if(val == "" || substr(val,1,1) ~/^[-]/) {
    print "Command line argument has an empty value when it should have something." > "/dev/stderr"
    exit
  }
  return val
}

#
# Print the directory portion of a /dir/filename string. End with trailing "/"
#   eg. /home/adminuser/wi-awb/tcount.awk -> /home/adminuser/wi-awb/
#
function dirname (pathname){
        if (sub(/\/[^\/]*$/, "", pathname))
                return pathname "/"
        else
                return "." "/"
}

#
# Run a system command and store result in a variable
#   eg. googlepage = sys2var("wget -q -O- http://google.com")
# Supports pipes inside command string. Stderr is sent to null.
# If command fails (errno) return null
#
function sys2var(command        ,fish, scale, ship) {

         # command = command " 2>/dev/null"
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
# http2var - replicate "wget -q -O- http://..." in pure gawk
#   Return the HTML page as a string.
#
function http2var(url) {

     if(url ~ /'/) gsub(/'/,"%27",url)  # Escape shell literal string
     return sys2var( Exe["wget"] Wget_opts "-q -O- '" url "'")
}


#
# Merge an array of strings into a single string. Array indice are numbers.
#  Credit: GNU awk manual
#
function join(arr, start, end, sep,    result, i) {
        if(length(arr) == 0)
          return ""

        result = arr[start]

        for (i = start + 1; i <= end; i++)
            result = result sep arr[i]

        return result
}

#
# Merge an array of strings into a single string. Array indice are strings.
#
function join2(arr, sep         ,i,lobster) {

        for ( lobster in arr ) {
            if(++i == 1) {
                result = lobster
                continue
            }
            result = result sep lobster
        }
        return result
}


#
# Strip leading/trailing whitespace
#
function strip(str, opt) {
       return gensub(/^[[:space:]]+|[[:space:]]+$/,"","g",str)
#        gsub(/^[[:space:]]+|[[:space:]]+$/,"",str)
#        return str
}


#
# Clean text of HTML codes
#            
function clean(str) {           

  gsub(/\342\200\231/, "'", str)
  gsub(/\342\200\230/, "`", str)
  gsub(/\342\200\246/, "…", str)
  gsub(/\342\200\223/, "-", str)
  gsub(/\342\200\224/, "—", str)
  gsub(/\342\200\234/, "“", str)
  gsub(/\342\200\235/, "\"", str)

  return str                  
}

#
# Escape regex symbols
#  Caution: causes trouble with regex and [g]sub() with "&"
#  Consider instead using the non-regex literal string replacetext() in library.awk
#
function regesc2(str,   safe) {
  safe = str
  gsub(/[][^$".*?+{}\\()|]/, "\\\\&", safe)
  gsub(/&/,"\\\\\\&",safe)
  return safe
}
#
# Escape regex symbols
#  See caution above. Regesc2 is the prefered of these two, unless passing to a CL utility that can't handle \ escapes
#
function regesc(str,   safe) {
  safe = str
  gsub(/[][^$".*?+{}\\()|]/, "[&]", safe)
  gsub("[\\^]","\\^",safe)
  #gsub(/&/,"\\\\\\\\&",safe) # Eight! Test this ..
  return safe
}

#
# strip wiki markup 
#   eg. "George Henry is a [[lawyer<!--no-->]]<ref name=wp>{{fact|Is {{lang|en|[[true]]}}}}<!--yes-->. See [http://wikipedia.org]</ref> from [[Charlesville (Virginia)|Charlesville Virginia]]<ref>See note.</ref> and holds two [[degree]]s in philosophy."
#       "George Henry is a lawyer from Charlesville Virginia and holds two degrees in philosophy."
#
# NOTE: A possibly better soltions here:
#       http://stackoverflow.com/questions/1625162/get-text-content-from-mediawiki-page-via-api/21844127#21844127
#
#
function stripwikimarkup(str) {
    safe = stripwikicomments(str)
    safe = stripwikitemplates(safe)
    safe = stripwikirefs(safe)
    safe = stripwikilinks(safe)
    return strip(safe)
}

#
# strip wiki markup <!-- comment -->
#  eg. "George Henry is a [[lawyer]]<!-- source? --> from [[Charlesville (Virginia)|Charlesville <!-- west? --> Virginia]]"
#      "George Henry is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]]"
#
function stripwikicomments(str, a,c,i,out,sep) {
  c =  patsplit(strip(str), a, /<[ ]{0,}[!][^>]*>/, sep)
  out = sep[0]
  while(i++ < c) {
    out = out sep[i] 
  }
  return strip(out)
}

#
# strip wiki markup <ref></ref>
#  eg. "George Henry is a [[lawyer]]<ref name=wp>Is [[true]]. See [http://wikipedia.org]</ref> from [[Charlesville (Virginia)|Charlesville Virginia]]<ref>See note.</ref> and holds two [[degree]]s in philosophy."
#      "George Henry is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]] and holds two [[degree]]s in philosophy."
#
function stripwikirefs(str, a,c,i,out,sep) {
  c =  patsplit(str, a, /<ref[^>]*>[^>]*>/, sep)
  out = sep[0]
  while(i++ < c) {
    out = out sep[i] 
  }
  return out
}

#
# strip wiki markup {{templates}}
#  eg. "George Henry is a [[lawyer]]{{fact|{{name}}}} {from} [[Charlesville (Virginia)|Charlesville Virginia]]"
#      "George Henry is a lawyer {from} Charlesville Virginia"
#
function stripwikitemplates(str,  a,c,i,out,sep) {

  c =  patsplit(str, a, /[{][{][^}]*[}][}]/, sep)
  out = sep[0]
  while(i++ < c) 
    out = out sep[i] 
  gsub(/{{|}}/,"",out)
  return out
}

#
# strip wiki markup [[wikilinks]]
#  eg. "George Henry is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]] and holds two [[degree]]s in philosophy."
#      "George Henry is a lawyer from Charlesville Virginia and holds two degrees in philosophy."
#
function stripwikilinks(str,  a,b,c,i,ai,out,sep) {

  c =  patsplit(str, a, /[[][[][^\]]*[]][]]/, sep)
  out = sep[0]
  while(i++ < c) {
    ai = gensub(/[[]|[]]/,"","g",a[i])
    if(split(ai, b, "|") > 1)
      ai = b[2]
    out = out ai sep[i] 
  }
  return out
}


#
# Check file or directory exists. 
#  action = "exit" or "check" (return 1 if exists) (default is check)
#
function checkexists(file, program, action) {                       
  if( ! exists(file) ) {              
    if( action == "exit" ) {
      print program ": Unable to find/open " file  > "/dev/stderr"           
      print program ": Unable to find/open " file  
      system("")
      exit
    }
    else
      return 0
  }
  else
    return 1
}

#
# Check for file existence. Return 1 if exists, 0 otherwise.
#  Requires GNU Awk: @load "filefuncs"
#
function exists(name    ,fd) {
    if ( stat(name, fd) == -1)
      return 0
    else
      return 1
}

#
# File size
#
function filesize(name         ,fd) {
    if ( stat(name, fd) == -1) 
      return -1  # doesn't exist
    else
      return fd["size"]
}

#
# Log (append) a line in a database
#
#  If you need more than 2 columns (ie. name|msg) then format msg with separators in the string itself. 
#    If flag="noclose" don't close the file (flush buffer) after write. Useful when making many
#      concurrent writes, particularly running under GNU parallel.
#    If flag="space" use space as separator 
#
function sendlog(database, name, msg, flag,    safed,safen,safem,sep) {

  safed = database
  safen = name
  safem = msg
  gsub(/"/,"\42",safed)
  gsub(/"/,"\42",safen)
  gsub(/"/,"\42",safem)

  if(flag ~ /space/)
    sep = " " 
  else
    sep = "----"

  if(length(safem))
    print safen sep safem >> database
  else
    print safen >> database

  if(flag !~ /noclose/)
    close(database)
}

#
# strip blank lines from start/end of a file
#  Require: @load "readfile"
#
#  Optional type = "inplace" will overwrite file, otherwise return as variable
#    These do the same:
#      out = stripfile("test.txt"); print out > "test.txt"; close("test.txt")
#      stripfile("test.txt", "inplace")
#
#  One-liner shell method:
#    https://stackoverflow.com/questions/7359527/removing-trailing-starting-newlines-with-sed-awk-tr-and-friends   
#      awk '{ LINES=LINES $0 "\n"; } /./ { printf "%s", LINES; LINES=""; }' input.txt | sed '/./,$\!d' > output.txt   
#
function stripfile(filen, type,    i,c,a,o,start,end,out) {
  
  if( ! exists(filen) ) {
    print "stripfile(): Unable to find " filen > "/dev/stderr"
    return 
  }

  c = split(readfile(filen),a,"\n")

 # First non-blank line
  while(i++ < c) {
    if(a[i] != "") {
      start = i
      break
    }
  }

  i = 0

 # Last non-blank line
  while(i++ < c) {
    if(a[i] != "")
      end = i
  }

  i = 0

  while(i++ < c) {
    if(i >= start && i <= end) {
      if(i == start) 
        out = a[i] 
      else
        out = out "\n" a[i]
    }
  }

  if(type == "inplace") {  
    system("")   # flush buffers
    print out > filen
    close(filen)
  }
  else
    return out

}

#
# Sleep
#
function sleep(seconds) {
  if(seconds > 0)
    sys2var( Exe["sleep"] " " seconds)
}


#
# Return a random number between 1 to max
#
#  Seed is clock-based (systime) so ensure there is plenty of time between each call or it will return the same number.
#  Otherwise find a different method to seed srand.
#
function randomnumber(max) {
  srand(systime())
  return int( rand() * max)
}

#
# Return 1 if str is a pure digit
#  eg. "1234" == 1. "0fr123" == 0
#
function isanumber(str,    safe,i) {

  safe = str
  while( i++ < length(safe) ) {
    if( substr(safe,i,1) !~ /[0-9]/ )          
      return 0
  }
  return 1   

}          

#
# Return 1 if URL is for archive.org .. datatype() will check if for Wayback
#                  
function isarchiveorg(url,  safe) {
  safe = url
  sub(/^https?[:]\/\//,"",safe)
  sub(/^web[.]|^www[.]|^wayback[.]/,"",safe)
  if(safe ~ /^archive[.]org/) { 
    if(urltimestamp(safe) !~ /[*|?]/)          # Ignore if timestamp contains * or ?
      return 1      
  } 
  return 0
}


#
# Given an archive.org URL, return the original url portion
#  http://archive.org/web/20061009134445/http://timelines.ws/countries/AFGHAN_B_2005.HTML ->
#   http://timelines.ws/countries/AFGHAN_B_2005.HTML
#
function wayurlurl(url,  date,inx) {

   date = urltimestamp(url)
   if(length(date) > 0) {
     inx = index(url, date) + length(date) + 1
     return removesection(url, 1, inx)
   }
}

#                     
# Given an archive.org URL, return the date stamp portion
#  https://archive.org/web/20061009134445/http://timelines.ws/countries/AFGHAN_B_2005.HTML ->
#   20061009134445                  
#
function urltimestamp(url,  a,c,i,re) {                

  re = "^web$"

  c = split(url, a, "/")
  while(i++ < c) {             
    if(length(a[i])) {
      if(a[i] ~ re) {
        i++
        return a[i]
      }
      if(a[i] ~ /^[0-9?*]*$/) {
        return a[i]
      }
    }
  }
}

#
# Replace old text with new text in source string. Non-regex match and replace. 
#  Only works if "old" is uniq in the text.
#  caller = debug tag calling function
#
function replacetext(source, old, new, caller,    safe, a) {

  # Prevent errors in case "old" has more than 1 (or 0) match in "source"
  a = countsubstring(source, old)
  if(a > 1 || a < 1 ) {
    if(Debug["s"]) print "Abort. More than " a " copy(s) of string (" old ") in source: " new
    return source
  }

  if(length(source) == 0 || length(old) == 0) return source

  if(Debug["s"]) print "\n\n____ENTERING REPLACE from " caller
  if(Debug["s"]) print "old: " old
  
  safe = source
  inx = index(safe, old) 
  safe = removesection(safe, inx, length(old) + inx, caller)
  safe = insertsection(safe, inx, new, caller)
  return safe
}

#
# Delete sub-string from "start" count to "end" count in "str"
#
function removesection(str, start, end, caller,   i,out) {

  if(Debug["s"]) print "\n\n  --ENTERING REMOVE from " caller
#  if(Debug["s"]) print "start: " str

  while(i++ < length(str)) {
    if(i < start || i >= end)
      out = out substr(str,i,1)   
  }
  if(Debug["s"]) print "end: " out
  return out
}

#
# Insert string "new" at location "start" in string "source" 
#
function insertsection(source, start, new, caller,  i,out,space) {

  if(Debug["s"]) print "\n\n  --ENTERING INSERTION from " caller

  if(length(source) == 0) {                                  # If source is empty, return new string as the full replacement         
    if(Debug["s"]) print "Source == 0 (" new ")"
    return new
  }

  if(start > length(source)) {                              # Append to end of source if start is > length of source.
    if(substr(source,length(source),1) ~ /[ ]/) {
      if(Debug["s"]) print "Start is > source (1)"
      return source new
    }
    else {
      if(Debug["s"]) print "Start is > source (2)"
      return source " " new
    }
  }

  if(Debug["s"]) {
#    if(source ~ /nileslibrary.org/) {                                   # inside 
    if(1) {                                                              # outside
      Debug["s1"] = 1
      print "\nnew: |" new "|"
      print "\nstart (" substr(source,start + 1,1) ") source (" start "): " source   # inside
#      print "start (" substr(source,start + 1,1) ") source (" start "): "         # outside
    }
  }

  while(i++ < length(source)) {

    if(i == start) {

      if(Debug["s1"]) print "start - 1 (" substr(source,i - 1,1) ")"
      if(Debug["s1"]) print "start   1 (" substr(source,i ,1) ")"
      if(Debug["s1"]) print "start + 1 (" substr(source,i + 1,1) ")"

                                                            # Preserve space if start is a space, no other spaces and followed by "|" or "}"
      if(substr(source,i,1) ~ /[ ]/ && substr(source,i+1,1) ~ /[|]|[}]/ && substr(source,i-1,1) !~ /[ ]/) {
        out = out new substr(source,i,1)        
        if(Debug["s1"]) print "*5*"
      }
                                                            # Trim space except if the space is followed by .. (for external links)
      else if(substr(source,i,1) ~ /[ ]/ && substr(source,i+1,1) !~ /[0-9A-Za-z\]\<\"'(\[]/) { 
#      else if(substr(source,i,1) ~ /[ ]/ && substr(source,i+1,1) !~ /[[:graph:]]/) { 
        out = out new 
        if(Debug["s1"]) print "*1*"
      }
                                                            # Trim space if "start" is space and is preceeded by space, except if followed by ..
      else if(substr(source,i,1) ~ /[ ]/ && substr(source,i-1,1) ~ /[ ]/ && substr(source,i+1,1) !~ /[0-9A-Za-z\]\<\"'(\[]/) {   
#      else if(substr(source,i,1) ~ /[ ]/ && substr(source,i-1,1) ~ /[ ]/ && substr(source,i+1,1) !~ /[[:graph:]]/) {   
        out = out new
        if(Debug["s1"]) print "*4*"
      }
      else {
                                                            # Add space if "start" is | or }, and preceeding is not a space  
        if(substr(source,i,1) ~ /[|}]/ && substr(source,i-1,1) !~ /[ ]/) {          
          out = out new " " substr(source,i,1)
          if(Debug["s1"]) print "*2*"
        }
        else {
          out = out new substr(source,i,1)                  # Default: Preserve space if start is a space
          if(Debug["s1"]) print "*3*"
        }
      }
    }
    else {
      out = out substr(source,i,1)
    }
  }

  if(Debug["s1"]) {
    print "\nend source: " out      # inside
#    print "end source: "         # outside
    Debug["s1"] = 0
  }

  return out
}

#
# countsubstring
#   Returns number of occurances of pattern in str.
#   Pattern treated as a literal string, regex char safe
#
#   Example: print countsubstring("[do&d?run*d!run>run*", "run*")
#            2
#
function countsubstring(str, pat,    len, i, c) {
  c = 0
  if( ! (len = length(pat) ) ) {
    return 0
  }
  while(i = index(str, pat)) {
    str = substr(str, i + len)
    c++
  }
  return c
}

#
#  usage: qsplit(string, array [, sep [, qualifier] ])
#
## a version of split() designed for CSV-like data. splits "string" on "sep"
## (,) if not provided, into array[1], array[2], ... array[n]. returns "n", or
## "-1 * n" if the line is incomplete (it has an uneven number of quotes). both
## "sep" and "qualifier" will use the first character in the provided string.
## uses "qualifier" (" if not provided) and ignores "sep" within quoted fields.
## doubled qualifiers are considered escaped, and a single qualifier character
## is used in its place. for example, foo,"bar,baz""blah",quux will be split as
## such: array[1] = "foo"; array[2] = "bar,baz\"blah"; array[3] = "quux";
#
# Credit: https://github.com/e36freak/awk-libs
#
function qsplit(str, arr, sep, q,    a, len, cur, isin, c) {
  delete arr;

  gsub(/\\"/,"\"\"",str) # Modification for Wayback API which returns " as \"

  # set "sep" if the argument was provided, using the first char
  if (length(sep)) {
    sep = substr(sep, 1, 1);
  # otherwise, use ","
  } else {
    sep = ",";
  }

  # set "q" if the argument was provided, using the first char
  if (length(q)) {
    q = substr(q, 1, 1);
  # otherwise, use '"'
  } else {
    q = "\"";
  }

  # split the string into the temporary array "a", one element per char
  len = split(str, a, "");

  # "cur" contains the current element of 'arr' the function is assigning to
  cur = 1;
  # boolean, whether or not the iterator is in a quoted string
  isin = 0;
  # iterate over each character
  for (c=1; c<=len; c++) {
    # if the current char is a quote...
    if (a[c] == q) {
      # if the next char is a quote, and the previous character is not a
      # delimiter, it's an escaped literal quote (allows empty fields 
      # that are quoted, such as "foo","","bar")
      if (a[c+1] == q && a[c-1] != sep) {
        arr[cur] = arr[cur] a[c];
        c++;

      # otherwise, it's a qualifier. switch boolean
      } else {
        isin = ! isin;
      }

    # if the current char is the separator, and we're not within quotes
    } else if (a[c] == sep && !isin) {
      # increment array element
      cur++;

    # otherwise, just append to the current element
    } else {
      arr[cur] = arr[cur] a[c];
    }
  }
  # return length
  return cur * (isin ? -1 : 1);
}

# usage: mktemp(template [, type])
#
## creates a temporary file or directory and returns its name.
## if template is not a pathname, the file will be created in ENVIRON["TMPDIR"]
## if set, otherwise /tmp. the last six characters of template must be "XXXXXX",
## and these are replaced with a string that makes the filename unique. type, if
## supplied, is either "f", "d", or "u": for file, directory, or dry run (just
## returns the name, doesn't create a file), respectively. If template is not
## provided, uses "tmp.XXXXXX". Recommend don't use spaces or " or ' in pathname.
#
#  Credit: https://github.com/e36freak/awk-libs
#  Modified by GreenC
#
function mktemp(template, type,                 
                c, chars, len, dir, dir_esc, rstring, i, out, out_esc, umask,
                cmd) {           

  # portable filename characters
  c = "012345689ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  len = split(c, chars, "")

  # make sure template is valid
  if (length(template)) {
    if (template !~ /XXXXXX$/) {
      return -1
    } 

  # template was not supplied, use the default
  } else {
    template = "tmp.XXXXXX"
  }         
  # make sure type is valid
  if (length(type)) {
    if (type !~ /^[fdu]$/) {
      return -1
    }
  # type was not supplied, use the default
  } else {
    type = "f"
  }

  # if template is a path...
  if (template ~ /\//) {
    dir = template
    sub(/\/[^/]*$/, "", dir)
    sub(/.*\//, "", template)
  # template is not a path, determine base dir
  } else {
    if (length(ENVIRON["TMPDIR"])) {
      dir = ENVIRON["TMPDIR"]
    } else {
      dir = "/tmp"
    }
  }

  # if this is not a dry run, make sure the dir exists
  if (type != "u" && ! exists(dir)) {
    return -1
  }

  # get the base of the template, sans Xs
  template = substr(template, 0, length(template) - 6)

  # generate the filename
  do {
    rstring = ""
    for (i=0; i<6; i++) {
      c = chars[int(rand() * len) + 1]
      rstring = rstring c
    }
    out = dir "/" template rstring
  } while( exists(out) )

  if (type == "f") {
    printf "" > out
    close(out)
  } else if (type == "d") {
    mkdir(out)
  }
  return out
}

#
# Make a directory ("mkdir -p dir")
#
function mkdir(dir,    ret, var, cwd) {
  sys2var(Exe["mkdir"] " -p \"" dir "\" 2>/dev/null")
  cwd = ENVIRON["PWD"]
  ret = chdir(dir)
  if (ret < 0) {
    printf("Could not create %s (%s)\n", dir, ERRNO) > "/dev/stderr"
    return 0
  }
  ret  = chdir(cwd)
  if (ret < 0) {
    printf("Could not chdir to %s (%s)\n", cwd, ERRNO) > "/dev/stderr"
    return 0
  }
  return 1
}


#
# Given a URI, return percent-encoded in the hostname (limited), path and query portion only. Retain +
#
#  Doesn't do international hostname encoding "http://你好.com/" different from percent encoding
#
#  Example:
#  https://www.cwi.nl:80/guido&path/Python/http://www.test.com/Władysław T. Benda.com ->
#    https://www.cwi.nl:80/guido%26path/Python/http%3A//www.test.com/W%C5%82adys%C5%82aw%20T.%20Benda.com
#
#  Documentation: https://docs.python.org/3/library/urllib.parse.html
#                 http://www.programcreek.com/python/example/53325/urllib.parse.urlsplit
#                 https://pymotw.com/2/urlparse/
#
function uriparseEncodeurl(str,   safe,command) {

  safe = str
  gsub(/'/, "'\"'\"'", safe)     # make safe for shell
  gsub(/’/, "'\"’\"'", safe)

  command = Exe["python3"] " -c \"from urllib.parse import urlunsplit, urlsplit, quote; import sys; o = urlsplit(sys.argv[1]); print(urlunsplit((o.scheme, o.netloc, quote(o.path), quote(o.query), o.fragment)))\" '" safe "'"
  return sys2var(command)
}


#          
# url-encode via Python (slow)
#  Credit: https://askubuntu.com/questions/53770/how-can-i-encode-and-decode-percent-encoded-strings-on-the-command-line
#     See for other options          
#   
function urlencodepython(str,   command) {

   # python -c "import urllib, sys; print urllib.quote(sys.argv[1])" "Emil Młynarski"
   command = Exe["python"] " -c \"import urllib, sys; print urllib.quote(sys.argv[1])\" \"" str "\""
   return strip(sys2var(command))
}                      

#
# url-decode via Python 
#
function urldecodepython(str,   command,safe) {

   safe = str
   gsub(/'/, "'\"'\"'", safe)    
   gsub(/’/, "'\"’\"'", safe)

   command = Exe["python3"] " -c \"from urllib.parse import unquote; import sys; print(unquote(sys.argv[1]))\" '" safe "'"
   return strip(sys2var(command))
}

#
# Given a URI, return a sub-portion (scheme, netloc, path, query, fragment)
#
#  In the URL "https://www.cwi.nl:80/nl?dooda/guido&path.htm#section"
#   scheme = https
#   netloc = www.cwi.nl:80
#   path = /nl
#   query = dooda/guido&path.htm
#   fragment = section
#
#  Example: uriElement("https://www.cwi.nl:80/nl?", "path") returns "/nl"
#
function uriparseElement(str, element,   safe,command,scheme) {
  safe = str               
  gsub(/'/, "'\"'\"'", safe)
  gsub(/’/, "'\"’\"'", safe)              
  command = Exe["python3"] " -c \"from urllib.parse import urlsplit; import sys; o = urlsplit(sys.argv[1]); print(o." element ")\" '" safe "'"
  return sys2var(command)
}



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

function sendtoindex(indexf, name, stamp,    debugfile,sep,c,a,filep,i,b,curname,o,hold2,hold) {

  debugfile = Home "debug.index"

  sep = "|"

  if( ! length(name) > 1 || ! length(stamp) > 1 || ! length(indexf) > 1 ) {
    print name "|" filename "|4" >> debugfile
    close(debugfile)
    return 0
  }

  c = split(indexf, a, "/")
  filename = a[c]
  if( ! awklock(filename) ) {
    awkunlock(filename,name,"1")
    return 0
  }

  if(! checkexists(indexf, "sendtoindex", "check") ) {
    print name sep stamp > indexf
    close(indexf)
    awkunlock(filename)
    return 1
  }
  else {
    print name sep stamp >> indexf
    close(indexf)
    filep = readfile(indexf)
    c = split(filep, a, "\n")
    filep = ""
    while(i++ < c) {
      split(a[i], b, sep)
      curname = strip(b[1])
      hold[curname]["name"] = curname
      hold[curname]["stamp"] = strip(b[2])
      hold[curname]["index"] = i
    }
  }

 # re-index to prepare for sorting
  for(o in hold) {
    hold2[ hold[o]["index"] ]["name"] = hold[o]["name"]
    hold2[ hold[o]["index"] ]["stamp"] = hold[o]["stamp"]
  }

  delete hold

  if(!removeindexfile(indexf,filename)) 
    return 0

  PROCINFO["sorted_in"] = "@ind_num_asc"
  for(o in hold2) {
    if( length(hold2[o]["name"]) > 0 ) {
      print hold2[o]["name"] sep hold2[o]["stamp"] >> indexf
    }
  }

  close(indexf)
  if(length(hold2) > 0) {
    awkunlock(filename)
    return 1
  }
  else {
    awkunlock(filename)
    print name "|" filename "|3" >> debugfile
    close(debugfile)
    return 0
  }

  awkunlock(filename)
  return 0
}

#
# Delete index file
#
function removeindexfile(str, filename) {

      if( checkexists(str, "index.awk", "check") ) {
        sys2var( Exe["rm"] " -- " str)
        system("")
      }
      if( checkexists(str, "index.awk", "check") ) {
        print("index.awk: Unable to delete " str ", aborting.") > "/dev/stderr"
        awkunlock(filename)
        return 0
      }
      return 1
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
function awkunlock(filename, name, point) {

  if(name) {
    print name "|" filename "|" point >> debugfile
    close(debugfile)
  }

  if(exists("/tmp/lock." filename)) {
    sys2var( Exe["rm"] " -r -- /tmp/lock." filename)
  }
  else {
  }

}

#
# Convert XML to plain
#
function convertxml(str,   safe) {

      safe = str
      gsub(/&lt;/,"<",safe)
      gsub(/&gt;/,">",safe)
      gsub(/&quot;/,"\"",safe)
      gsub(/&amp;/,"\\&",safe)
      gsub(/&#039;/,"'",safe)
      return safe
}



#
# Get plain wikisource. Follow "#redirect [[new name]]"
#       
# redir = "follow/dontfollow" 
#
function getwikisource(namewiki, redir,    f,ex,k,a,command,urlencoded,r) {

  if(redir !~ /follow|dontfollow/)
    redir = dontfollow       

  urlencoded = urlencodepython(strip(namewiki))
  command = "https://en.wikipedia.org/wiki/" urlencoded "?action=raw"
  f = http2var(command)

  if(length(f) < 1000) {
    if(tolower(f) ~ "[#][ ]{0,}redirect[ ]{0,}[[]") {
      print "Found a redirect:"
      match(f, "[#][ ]{0,}[Rr][Ee][^]]*[]]", r)
      print r[0]
      if(redir ~ /dontfollow/) 
        return ""
      ex = http2var("https://en.wikipedia.org/wiki/Special:Export/" urlencoded)
      match(ex,/<redirect title=\"[^\"]*\"/,k)
      if( length(k[0]) > 0) {
        split(k[0],a,"\"")
        if( length(a[2]) > 0) {
          f = http2var("https://en.wikipedia.org/wiki/" urlencoded "?action=raw")
          return strip(f)
        }
        else
          return ""
      }
      else
        return ""
    }
  }
  return strip(f)
}

