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
        Project["manual"] = Project["meta"] "manual"               # Manual processing needed
        Project["timeout"] = Project["meta"] "timeout"             # Remote server timed out
        Project["bogusapi"] = Project["meta"] "bogusapi"           # IA API returned a bogus recommendation
        Project["docfixes"] = Project["meta"] "Documentation"      # Documentation / fix revisions for this project
        Project["cbignore"] = Project["meta"] "cbignore"           # Articled were added {{cbignore|id=medic}}
        Project["discovered"] = Project["meta"] "discovered"       # Articles that have changes made (for import to AWB)

        Project["log404"] = Project["meta"] "log404"
        Project["logspurone"] = Project["meta"] "logspurone"
        Project["logmissprot"] = Project["meta"] "logmissprot"
        Project["logmissweb"] = Project["meta"] "logmissweb"
        Project["logemptyarch"] = Project["meta"] "logemptyarch"
        Project["logtrail"] = Project["meta"] "logtrail"
        Project["logemptyway"] = Project["meta"] "logemptyway"

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

     # return sys2var( Exe["wget"] " --no-check-certificate --user-agent=\"" Agent "\" -q -O- \"" url "\"")

     if(url ~ /'/) gsub(/'/,"%27",url)  # Escape shell literal string
     return sys2var( Exe["wget"] " --retry-connrefused --waitretry=1 --read-timeout=2 --timeout=5 --tries=1 --no-dns-cache --no-check-certificate --user-agent=\"" Agent "\" -q -O- '" url "'")

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
    return safe
}

#
# strip wiki markup <!-- comment -->
#  eg. "George Henry is a [[lawyer]]<!-- source? --> from [[Charlesville (Virginia)|Charlesville <!-- west? --> Virginia]]"
#      "George Henry is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]]"
#
function stripwikicomments(str, a,c,i,out,sep) {
  c =  patsplit(str, a, /<![^>]*>/, sep)
  out = sep[0]
  while(i++ < c) {
    out = out sep[i] 
  }
  return out
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
# Write to a database
#   eg. sendto(Project["manual"], name, "choosetxt")            
#
function sendto(database, name, msg,     command) {
  command = Exe["awk"] " -v indexf=\"" database "\" -v name=\"" name  "\" -v stamp=\"" msg "\" -f " Home "index.awk"
  if( sys2var(command) != 1) 
    print("Error unable to write to database using command: " command ". " name ) > "/dev/stderr"

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
function sleep(seconds)
{
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
# Replace old text with new text in source string. Non-regex match and replace. 
#  Only works if "old" is uniq in the text.
#
function replacetext(source, old, new,    safe, a) {

  # Prevent errors in case "old" has more than 1 match in "source"
  a = countsubstring(source, old)
  if(a > 1 || a < 1 ) {
    if(Debug["s"]) print "Abort. More than copy of string in source"
    return source
  }

  safe = source
  inx = index(safe, old) 
  safe = removesection(safe, inx, length(old) + inx )
  safe = insertsection(safe, inx, new)
  return safe
}

#
# Delete sub-string from "start" count to "end" count in "str"
#
function removesection(str, start, end,   i,out) {

  while(i++ < length(str)) {
    if(i < start || i >= end)
      out = out substr(str,i,1)   
  }
  return out
}

#
# Insert string "new" at location "start" in string "source"
#
function insertsection(source, start, new,   i,out,space) {

  if(length(source) == 0)    # If source is empty, return new string as the full replacement         
    return new

  if(start > length(source)) # Append to end of source if start is > length of source.
    start = length(source)

  if(Debug["s"]) {
    if(source ~ /^[{][{][ ]{0,2}wayback/) {
      print "new: |" new "|"
      print "start (" substr(source,start + 1,1) ") source (" start "): " source
    }
  }

  while(i++ < length(source)) {

    if(i == start) {

      if(Debug["s"]) print "start - 1 (" substr(source,i - 1,1) ")"
      if(Debug["s"]) print "start   1 (" substr(source,i ,1) ")"
      if(Debug["s"]) print "start + 1 (" substr(source,i + 1,1) ")"

                                                            # Preserve space if start is a space, no other spaces and followed by "|" or "}"
      if(substr(source,i,1) ~ /[ ]/ && substr(source,i+1,1) ~ /[|]|[}]/ && substr(source,i-1,1) !~ /[ ]/) {
        out = out new substr(source,i,1)        
        if(Debug["s"]) print "*5*"
      }
                                                            # Trim space except if the space is followed by .. (for external links)
      else if(substr(source,i,1) ~ /[ ]/ && substr(source,i+1,1) !~ /[0-9A-Za-z\]\<]/) { 
        out = out new 
        if(Debug["s"]) print "*1*"
      }
                                                            # Trim space if "start" is space and is preceeded by space, except if followed by ..
      else if(substr(source,i,1) ~ /[ ]/ && substr(source,i-1,1) ~ /[ ]/ && substr(source,i+1,1) !~ /[0-9A-Za-z\]\<]/) {   
        out = out new
        if(Debug["s"]) print "*4*"
      }
      else {
                                                            # Add space if "start" is | or }, and preceeding is not a space  
        if(substr(source,i,1) ~ /[|}]/ && substr(source,i-1,1) !~ /[ ]/) {          
          out = out new " " substr(source,i,1)
          if(Debug["s"]) print "*2*"
        }
        else {
          out = out new substr(source,i,1)                  # Default: Preserve space if start is a space
          if(Debug["s"]) print "*3*"
        }
      }
    }
    else {
      out = out substr(source,i,1)
    }
  }

  if(Debug["s"]) {
    if(source ~ /^[{][{][ ]{0,2}wayback/) {
      print "end source: " out
    }
  }

  return out
}

#
# countsubstring
#   Returns number of occurances of pattern in str.
#   Pattern treated as a literal string.
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


# usage: mktemp(template [, type])
#
## creates a temporary file or directory, safely, and returns its name.
## if template is not a pathname, the file will be created in ENVIRON["TMPDIR"]
## if set, otherwise /tmp. the last six characters of template must be "XXXXXX",
## and these are replaced with a string that makes the filename unique. type, if
## supplied, is either "f", "d", or "u": for file, directory, or dry run (just
## returns the name, doesn't create a file), respectively. If template is not
## provided, uses "tmp.XXXXXX". Files are created u+rw, and directories u+rwx,
## minus umask restrictions. returns -1 if an error occurs.
#
# Credit: https://github.com/e36freak/awk-libs
#

function mktemp(template, type,
                c, chars, len, dir, dir_esc, rstring, i, out, out_esc, umask,
                cmd) {

  # portable filename characters
  c = "012345689ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
  len = split(c, chars, "");

  # make sure template is valid
  if (length(template)) {
    if (template !~ /XXXXXX$/) {
      return -1;
    }

  # template was not supplied, use the default
  } else {
    template = "tmp.XXXXXX";
  }

  # make sure type is valid
  if (length(type)) {
    if (type !~ /^[fdu]$/) {
      return -1;
    }

  # type was not supplied, use the default
  } else {
    type = "f";
  }

  # if template is a path...
  if (template ~ /\//) {
    dir = template;
    sub(/\/[^/]*$/, "", dir);
    sub(/.*\//, "", template);

  # template is not a path, determine base dir
  } else {
    if (length(ENVIRON["TMPDIR"])) {
      dir = ENVIRON["TMPDIR"];
    } else {
      dir = "/tmp";
    }
  }

  # escape dir for shell commands
  esc_dir = dir;
  sub(/'/, "'\\''", esc_dir);
  esc_dir = "'" esc_dir "'";

  # if this is not a dry run, make sure the dir exists
  if (type != "u" && system("test -d " esc_dir)) {
    return -1;
  }

  # get the base of the template, sans Xs
  template = substr(template, 0, length(template) - 6);
  
  # generate the filename
  do {
    rstring = "";
    for (i=0; i<6; i++) {
      c = chars[int(rand() * len) + 1];
      rstring = rstring c;
    }
    
    out_esc = out = dir "/" template rstring;
    sub(/'/, "'\\''", out_esc);
    out_esc = "'" out_esc "'";
  } while (!system("test -e " out_esc));

  # if needed, create the filename
  if (type == "f") {
    system("touch " out_esc);
    cmd = "umask";
    cmd | getline umask;
    close(cmd);
    umask = substr(umask, 2, 1);
    system("chmod 0" 6 - umask "00 " out_esc);
  } else if (type == "d") {
    system("mkdir " out_esc);
    cmd = "umask";
    cmd | getline umask;
    close(cmd);
    umask = substr(umask, 2, 1);
    system("chmod 0" 7 - umask "00 " out_esc);
  }

  # return the filename
  return out;
}

#
# Make a directory ("mkdir -p dir")
#
function mkdir(dir      ,command, ret, var, cwd)
{

  command = Exe["mkdir"] " -p \"" dir "\" 2>/dev/null"
  while ((command | getline var) > 0) {
  }
  close(command)

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

