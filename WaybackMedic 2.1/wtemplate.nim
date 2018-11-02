discard """

The MIT License (MIT)

Copyright (c) 2016-2018 by User:GreenC (at en.wikipedia.org)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE."""

import awk, libutils, strutils
from re import escapeRe

when compiles(GX.space):
  var GXspace = GX.space
else:
  var GXspace = "[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}"

#
# print string > stderr - useful for permanant debugging
#
proc sed(s: string, d: bool): bool {.discardable} =

  if d:
    s >* "/dev/stderr"

  when compiles(GX.datadir):
    if s !~ "^[>]":
      s >> GX.datadir & "apilog"

#
# Given a template, return the key name of the first arg
#  eg. {{cite |url=http |title=Page ..}} will return "url"
#
proc firstarg*(s: string): string =

  var
    field, sep = newSeq[string](0)
    c = 0

  c = patsplit(stripwikilinks(stripwikicomments(s)), field, "[|][^=]*[^=]?", sep)
  if c > 0:
    gsub("^[|]", "", field[0])
    return strip(field[0])

  return "url" # need to return something even though it won't work

#
# Given a template, return the key name of archive-url, archive-date or dead-url 
#  1. The returned key name is not the same as the given name (s)
#  2. The returned key name is not the last argument in the template
#
#  The purpose of the template is to avoid adding a new argument into a template as the last one
#   which can affect the model spacing due to it ending in }} with no new line unlike rest.
#
proc notlastarg*(tl, s: string): string =

  var
    field, sep = newSeq[string](0)
    c = 0

  c = patsplit(stripwikilinks(stripwikicomments(tl)), field, "[|][^=]*[^=]?", sep)
  if c > 0:
    if s ~ "[Aa][Rr][Cc][Ii][Vv][Ee][-]?[Uu][Rr][Ll]":          # Return second to last entry
      gsub("^[|]", "", field[c-2])
      return strip(field[c-2])
    if s ~ "[Aa][Rr][Cc][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]":
      if field[c-1] !~ "[Aa][Rr][Cc][Ii][Vv][Ee][-]?[Uu][Rr][Ll]":  # Return archive-url if it's not last
        if match(tl, "[Aa][Rr][Cc][Ii][Vv][Ee][-]?[Uu][Rr][Ll]", dest) > 0:
          return dest
      gsub("^[|]", "", field[c-2])
      return strip(field[c-2])
    if s ~ "[Dd][Ee][Aa][Dd][-]?[Uu][Rr][Ll]":
      if field[c-1] !~ "[Aa][Rr][Cc][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]":
        if match(tl, "[Aa][Rr][Cc][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]", dest) > 0:
          return dest
      if field[c-1] !~ "[Aa][Rr][Cc][Ii][Vv][Ee][-]?[Uu][Rr][Ll]":
        if match(tl, "[Aa][Rr][Cc][Ii][Vv][Ee][-]?[Dd][Aa][Tt][Ee]", dest) > 0:
          return dest
      gsub("^[|]", "", field[c-2])
      return strip(field[c-2])

  return "url"  # if it can't find anything better, and let's hope it's not the last argument! 

#
# Given a template argument key like "archive-url" 
#  return "[Aa][-]?[Rr][-]?[Cc][-]?[Hh][-]?[Ii][-]?[Vv][-]?[Ee][-]?[Uu][-]?[Rr][-]?[Ll][-]?"
#  It will match "archiveurl" or "archive-url"
#
proc buildkeyre*(s: string): string =

  var
    c = 0
    build = ""

  if len(s) < 1:
    return s

  c = awk.split(s, a, "")

  for i in 0..c - 1:
    if not empty(a[i]):
      if a[i] ~ "[ ]":                    
        build = build & "[ ]?"
      else:
        build = build & "[" & toupperAscii(a[i]) & tolowerAscii(a[i]) & "][-]{0,}"

  if contains(build, "[--]"):
    gsubs("[--]", "", build)

  if not empty(build):
    return build
  else:
    return s

#
# Given a template and name of an argument, return how that argument is displayed ie. capitalizations and any dashes
#  If the argument is not in the template, return the argument as passed in arg: string
#  If bad data return ""
#
proc argkey*(tl, arg: string): string =

  var tl = tl

  if empty(arg) or empty(tl):
    return ""

  tl = stripwikicomments(tl)

  let re = "[|]" & GXspace & buildkeyre(arg) & GXspace 
  if match(tl, re, dest) > 0:
    dest[0] = ' '
    return strip(dest)

  return arg

#
# Given rightmodel = " data data WaybackMedicNewline data data  " and argval = "xx"
#   return " xx WaybackMedicNewline  "
#
# Preserve leading and trailing spaces and newline token       
# Replace first string with argval, delete all others
#
proc modelfieldhelper*(rightmodel, argval: string): string =

  var
    pos1, pos2, pos3, pos4, pos5 = 0
    newline, newnewline = ""
    rightmodel = rightmodel
  let
    debug = false

  sed("-----start modelhelper--------", debug)

  if rightmodel ~ "WaybackMedicNewline":
    newline = "WaybackMedicNewline"
  if rightmodel ~ "\n":
    newline = "\n"
    gsubs("WaybackMedicNewline", "\n", rightmodel)

  sed("newline = >" & newline & "<", debug)

  #
  # postition map:
  #   " data data WaybackMedicNewline data data  "    
  #     1         2                 3         4  5

  pos5 = len(rightmodel) - 1
  sed("len = " & $len(rightmodel), debug)

  pos1 = awk.match(rightmodel, "[^ ]") - 1
  if pos1 < 0:
    pos1 = 0
  sed("pos1 = " & $pos1 &  " = " & rightmodel[pos1], debug)

  pos4 = awk.match(uniReversedPreserving(rightmodel), "[^ ]") - 1
  if pos4 < 0:
    pos4 = 0
  sed("pos4 = " & $pos4  &  " = " & rightmodel[pos4], debug)

  pos2 = awk.match(rightmodel, newline) - 1  
  if pos2 < 0:
    pos3 = -1
    # newnewline = ""    # this screws up when arg val is empty followed by newline
    newnewline = newline
  else:
    pos3 = (len(newline) - 1) + pos2
    newnewline = newline
    sed("pos2 = " & $pos2 & ", pos3 = " & $pos3 & " value = >" & system.substr(rightmodel, pos2, pos3) & "<", debug)

  sed("rightmodel = >" & rightmodel & "<", debug)
  sed("returnval  = >" & spaces(pos1) & argval & newnewline & spaces(pos4) & "<", debug)
  
  return spaces(pos1) & argval & newnewline & spaces(pos4)

#
# Given this:
#  model  : | url         = http://yahoo.com
#  argname: archive-url
#  argval : http://archive.org
#
# Return this:
#           | archive-url = http://archive.org
#
# Notice the spacing around "archiveurl" matches that around "url" to retain the "=" at the same column (when possible) 
# If argval is "" then don't replace the right side of the "=", rather retain it
# model should be obtained with the "bar" command of getarg()
#
# ON ERROR: return ""
#
proc modelfield*(model, argname, argval: string): string =

  var
    loc = 0
    model = model
    leftmodel, rightmodel = ""
    leftmodelname, finalarg = ""
    leftspaceS, rightspaceS, totalwidthS = 0
    build = ""    
  let
    debug = false

  # convert tabs to 8-spaces
  gsub("[\\t]", "        ", model)
 
  sed("-----start modelfield--------", debug)

  loc = awk.match(model, "[=]") - 1

  if loc > -1:

    leftmodel = system.substr(model, 0, loc - 1)
    rightmodel = system.substr(model, loc + 1, len(model) - 1)

    sed("leftmodel  = |" & leftmodel & "|", debug)
    sed("rightmodel = |" & rightmodel & "|", debug)   

    leftmodelname = leftmodel
    gsub("^[|]", "", leftmodelname)

    sed("leftmodelname  = |" & leftmodelname & "|", debug)

    if argname ~ ("^" & buildkeyre(strip(leftmodelname)) & "$"):
      finalarg = strip(leftmodelname)
    else:
      finalarg = strip(argname)    

    sed("leftmodelname = |" & leftmodelname & "|", debug)
    sed("buildkeyRe = " & argname & " ~ " & "^" & buildkeyre(strip(leftmodelname)) & "$", debug)
    sed("Final arg = |" & finalarg & "|", debug)
    sed("leftmodelname = |" & leftmodelname & "|", debug)

    if awk.split(leftmodelname, modelsplit, escapeRe(strip(leftmodelname))) == 2:
      leftspaceS = len(modelsplit[0]) 
      rightspaceS = len(modelsplit[1])
      totalwidthS = leftspaceS + rightspaceS + len(strip(leftmodelname))
      sed("leftspaces = " & $leftspaces, debug)
      sed("rightspaces = " & $rightspaces, debug)
      sed("totalwidths = " & $totalwidths, debug)
    else:
      sed("ERROR: awk split fail", debug)
      return ""

    build = "|" & spaces(leftspaceS) & finalarg
    for i in 1..rightspaceS:
      if len(build) > totalwidthS:
        if i == 1 and rightspaces > 0: # add a space before = if it existed in the model
          build = build & " "
        break
      build = build & " "

    if empty(argval):
      sed("Final output: " & build & "=" & rightmodel, debug)
      sed("No spaces, exiting", debug)
      return build & "=" & rightmodel
    elif empty(rightmodel):
      if empty(argval):
        sed("Final output: " & build & "=", debug)
        sed("No rightmodel or argval, exiting", debug)
        return build & "="
      else:
        sed("Final output: " & build & "=" & argval, debug)
        sed("No rightmodel, exiting", debug)
        return build & "=" & argval
    else:
      sed("Starting modelfieldhelper for:", debug)
      sed("  rightmodel = |" & rightmodel & "|", debug)
      sed("  argval = |" & argval & "|", debug)
      sed("  helper result = |" & modelfieldhelper(rightmodel, argval) & "|", debug)
      sed("Final output: " & build & "=" & gsubs(rightmodel, modelfieldhelper(rightmodel, argval), rightmodel), debug)
      return build & "=" & gsubs(rightmodel, modelfieldhelper(rightmodel, argval), rightmodel)

  sed("ERROR: proc fell through to bottom", debug)
  return ""


#
# Given a key=val pair, return the val, where key can be archiveurl|archivedate|deadurl
#   kv = "|archiveurl=http:.."
#   returns "http..."
#
proc getval*(kv: string): string =

  var
    kv = kv

  match(kv, "^[ ]*[|]?[ ]*(archive-?url|archive-?date|dead-?url)[ ]*[=][ ]*", dest)
  gsubs(dest,"",kv)
  return strip(kv)

#
# Given a template (citation, webarchive etc), return the key=value according to a menu of options
#  N.B. wiki comments (<!-- -->) are removed from the returned strings unless noted
#  tl = template contents string
#  arg = argument name to retrieve. If it contains dashes doesn't matter. eg. deadurl and dead-url both work.
#  magic = "bar" include the leading "|" including spaces/newlines up to but not including the ending | or }
#        = "clean" just the argument value with no leading/trailing spaces/newlines
#        = "complete" like the bar version with wikicomments included
#        = "empty" return the word "empty" if the argument value is empty (wikicomments ignored towards being empty)
#        = "missing" return the word "missing" if the argument doesn't exist.

proc getarg*(arg, magic, tl: string): string =

  var 
    tl = tl
    subre, re, k, s = ""
    debug = false

  if tl == nil or tl == "":
    #sed("getarg() exit 1", debug)
    return ""
  if arg == nil or arg == "":
    #sed("getarg() exit 2", debug)
    return ""
  if magic == nil or magic == "":
    #sed("getarg() exit 3", debug)
    return ""

  subre = buildkeyre(arg)

  re = "[|]" & GXspace & subre & GXspace & "[=][^|}]*[^|}]"           # Field has contents
  if match(tl, re, k) > 0:
    if magic == "complete":
      #sed(">" & k & "<", debug)
      return k 
    elif magic == "bar":
      #sed(">" & stripwikicomments(k) & "<", debug)
      if ifwikicomments(k):
        return strip(stripwikicomments(k))
      return k
    elif magic == "clean":
      gsub("\n","",k)
      k = strip(stripwikicomments(k))
      gsub("[|]" & GXspace & subre & GXspace & "[=]" & GXspace, "", k)
      if countstrings(k) > 1 and arg ~ "url":                    # Return first-word only for url arguments
        k = firststring(k)
      #sed(">" & strip(k) & "<", debug)
      return strip(k)
    elif magic == "empty":
      if empty(getarg(arg, "clean", tl)):                     # clear wikicomments and blank spaces
        #sed(">empty<", debug)
        return "empty"
    else:
      gsub("^[|]","",k)
      #sed(">" & strip(stripwikicomments(k)) & "<", debug)
      return strip(stripwikicomments(k))

  re = "[|]" & GXspace & subre & GXspace & "[=]" & GXspace & "[|}]"    # Field is empty
  if match(tl, re, k) > 0:                                       # right side of = is blank
    s = awk.substr(strip(k), 0, len(strip(k)) - 1)
    if magic == "empty":
      #sed(">empty<", debug)
      return "empty"
    elif magic == "complete":
      #sed(">" & s & "<", debug)
      return s 
    elif magic == "bar":
      #sed(">" & stripwikicomments(s) & "<", debug)
      return stripwikicomments(s) 
    elif magic == "clean":
      #sed(">" & "" & "<", debug)
      return "" 
    else:
      gsub("^[|]","",s)
      #sed(">" & strip(stripwikicomments(s)) & "<", debug)
      return strip(stripwikicomments(s)) 

  if magic == "missing":
    #sed(">missing<", debug)
    return "missing"

  #sed("getarg() exit 4", debug)
  return ""

#
# Given a template (citation, webarchive etc) return true/false if key=value pair in tl meets a condition
#  arg = name of argument eg. "archive-url" or "title". For aliases with dashes either will work
#  condition = "empty" return true if argument key exists, but value is empty
#                      (NOTE: returns true if argument is missing) 
#                      (See isargempty() which returns false if argument is missing) 
#                      (consider using "value" since it returns false if missing or empty)
#              "value" a convenience for not empty
#                      (return false if argument is missing)
#              "missing" return true if argument key doesn't exist in template 
#              "exists" a convenience for not missing
#  tl = template
#
#  eg. isarg("url", "value", tl)
#
proc isarg*(arg, cond, tl: string): bool =

  var
    tl = tl

  if tl == nil or tl == "":
    return false
  if arg == nil or arg == "":
    return false

  tl = stripwikicomments(tl)
 
  if cond == "empty":
    if not isarg(arg, "missing", tl):
      if getarg(arg, "empty", tl) == "empty":
        return true
    else:
      return true
  elif cond == "value":
    if isarg(arg, "exists", tl):
      if getarg(arg, "empty", tl) != "empty":
        return true
    else:
      return false

  elif cond == "missing":
    if getarg(arg, "missing", tl) == "missing":
      return true
  elif cond == "exists":
    if getarg(arg, "missing", tl) != "missing":
      return true

  return false


#
# Shortcut for a common usage.. need to check for existence of arg before checking empty status
#  return true if it exists and is empty
#  return false if it exists but contains something
#  return false if argument doesn't exist
#
#  CAUTION: Don't use in the negative eg. "not isargempty()" it will return "false" if the argument is missing
#            giving the wrong impression that it is not empty (has a value)
#            Instead use isarg(arg, "value", tl) which returns false if the argument is missing, false if empty and true if a value
#
proc isargempty*(arg, tl: string): bool =

  if isarg(arg, "exists", tl):
    if isarg(arg, "empty", tl):
      return true
  return false

#
# Given a template and argument name, replace with new argument value preserving original spacing around the "=" inclduing newlines/tabs
#
proc replacearg*(tl, argname, argval, caller: string): string =

  var debug = false

  if isarg(argname, "exists", tl):
    var bar = getarg(argname, "bar", tl)
    sed("-----------------------------", debug)
    sed("---- start replacearg -------", debug)
    sed("-----------------------------", debug)
    sed("caller = " & caller, debug)
    sed("bar = " & bar, debug)
    sed("argkey = " & argkey(tl, argname), debug)
    sed("argval = " & argval, debug)
    sed("modelfield = " & modelfield(bar, argkey(tl, argname), argval), debug)
    if not empty(modelfield(bar, argkey(tl, argname), argval)):
      sed("return = " & gsubs(bar, modelfield(bar, argkey(tl, argname), argval), tl), debug)
      return gsubs(bar, modelfield(bar, argkey(tl, argname), argval), tl) 

  return tl

