#!/usr/local/bin/gawk -E

#
# Core functions for wayback medic
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
#  Pass these variables
#   -n name = Wikipedia article name
#   -s sourcefile = wikipedia source file
#   -p id = project ID
#
#  Returns 0 if no changes, or 1..X number of changes
#
#  Sample run: medic -p "cb20151231-20160304.0001-0002" -n "South Gare" -s "/home/adminuser/wm/data/cb20151231-20160304.0001-0002/wm-0308135732/article.txt" 
#
#  Normally called by driver.awk but can be called standalone when debugging data, or called with bug.awk -r 
#
#  Coding conventions: Capitalized variables are global eg. Project[] -- with the exception of name, sourcefile and id wich are global but not capitalized
#

@include "init.awk"
@include "library.awk"
@include "getopt.awk"
@include "api.awk"

BEGIN {

  Debug["network"] = 0    # Print debugging for networking
  Debug["api"] = 0        # Print debugging for API
  Debug["s"] = 0          # Print debugging for replacetext() functions in library.awk
  Debug["e"] = 0          # Print debugging for fixemptywayback()
  Debug["process"] = 0    # Print debugging for process_()
  Debug["wgetlog"] = 0    # Save wget.* header info created by webpagestatus()

  while ((C = getopt(ARGC, ARGV, "hp:n:s:")) != -1) {
      opts++
      if(C == "p")                 #  -p <project>   Use project name. Optional, default in project.cfg
        id = verifypid(Optarg)
      if(C == "n")                 #  -n <name>      Name to process. Required.
        name = verifyval(Optarg)
      if(C == "s")                 #  -s <file>      Wiki sourcefile to process. Required.
        sourcefile = verifyval(Optarg)
      if(C == "h") {
        usage()
        exit
      }

  }
  if( id ~ /error/ || ! opts || name == ""  || sourcefile == "" ){
    usage()
    exit
  }


  checkexists(sourcefile, "medic.awk", "exit")            # Exit if sourcefile missing
  setProject(id)                                          # Load paths and project file names (library.awk)
  Datadir = dirname(sourcefile)
  cx = split(Datadir, ax, "/")
  Wid = ax[cx - 1]
  printf "" > "/tmp/" Wid                                 # Directory ID of running process
  close("/tmp/" Wid)

  main()

}
function usage() {

  print ""
  print "Medic - process a wikisource file."
  print ""
  print "Usage:"
  print "       -p <project>   Project name. Optional, defaults to project.cfg"
  print "       -n <name>      Name to process. Required"
  print "       -s <file>      Wiki sourcefile to process. Required"
  print "       -h             Help"
  print ""
}


#
# fixthespuriousone (Rev: B)
#   B: changed from "1=" to "[1-9]=" 
#
# Remove spurious "|1=" from cite templates
#    https://en.wikipedia.org/w/index.php?title=List_of_Square_Enix_video_games&curid=1919116&diff=704745846&oldid=703682254
#
function fixthespuriousone(tl) {

  if(match(tl, /[|][ ]?[1-9][ ]?=[ ]{0,}[|}]/)) {
    Changes++
    sendlog(Project["logspurone"], name, "cite1")
    return gensub(/[|][ ]?[1-9][ ]?=[ ]{0,}/,"","g",tl)
  }
  return tl
}

#
# fixtrailingchar (Rev: A)
#
# Fix trailing char in url= created by user input error
#  See extra "," added to url https://en.wikipedia.org/w/index.php?title=Comanche_National_Grassland&type=revision&diff=707575983&oldid=655945746
#  Only needs to check wayback templates since those were imported by Cyberbot from bare URLs
#  Order: Must come before any web operations using the URL
#
function fixtrailingchar(tl,  url) {

  if(datatype(tl,"wayback")) {
    url = getargurl(tl)
    if( substr(url, length(url), 1) ~ /[,]|[.]|[:]/) {
      tl = replacetext(tl, url, gensub(/[,]$|[.]$|[:]$/, "", "g", url), "fixtrailingchar")
      Changes++
      sendlog(Project["logtrail"], name, "wayback1")
      return tl
    }
  }
  return tl
}

#
# fixencodedurl (Rev: A)
#
# Fix when a url= is encoded incorrectly in a cite template.
#  eg. http%3A%2F%2Fwww.advocate.com%2FArts_and_Entertainment%2FPeople%2F70_Is_the_New_40%2F
#  https://en.wikipedia.org/w/index.php?title=Jim_Morris_%28bodybuilder%29&type=revision&diff=709196054&oldid=703186121
#
function fixencodedurl(tl,  url,uxurl) {

  if(datatype(tl,"cite")) {
    url = getargurl(tl)
    if(url ~ /^http[s]{0,1}[%]3A[%]2F[%]2F/) {
      uxurl = uriparseEncodeurl(urldecodepython(url))  
      tl = replacetext(tl, url, uxurl, "fixencodedurl")
      Changes++
      sendlog(Project["logencode"], name, "cite1")
      return tl
    }
  }
  return tl
}

#
# fixemptywayback (Rev: A)
#
# Fix when a ref has an empty "{{wayback}}", with the intended url= portion misplaced at the start of the ref 
#   Boko Haram insurgency: https://en.wikipedia.org/w/index.php?title=Boko_Haram_insurgency&type=revision&diff=709268607&oldid=708528456
#   Comac C919: https://en.wikipedia.org/w/index.php?title=Comac_C919&type=revision&diff=709236286&oldid=708889462  
# 
function fixemptywayback(fullref,   date,url,df,dfout) {

  match(fullref, /^[|]url=[^|]*[^|]/, url)          # ^|url=http..[ ]$
  if(length(url[0])) {
    if(Debug["e"]) print "url = " url[0]
    fullref = strip(removesection(fullref, 1, length(url[0])))
    if(Debug["e"]) print "fullref(1) = " fullref
    match(fullref, /^[|]date=[^ ]*[ ]/, date)       # ^|date=Jan..[ ]$
    if(length(date[0])) {
      if(Debug["e"]) print "date = " date[0]
      fullref = strip(removesection(fullref, 1, length(date[0])))
      if(Debug["e"]) print "fullref(2) = " fullref
      if(match(fullref, /^[|]df=[yn][ ]/, df)) {     # ^|df=y[ ]$
        fullref = strip(removesection(fullref, 1, length(df[0])))
        if(Debug["e"]) print "fullref(3) = " fullref
        dfout = df[0]
      }
      else dfout = ""      
      if(Debug["e"]) print "fullref(4) = " fullref
      fullref = replacetext(fullref, "{{wayback}}", "{{wayback" url[0] date[0] dfout "}}", "fixemptywayback")
      if(Debug["e"]) print "fullref(5) = " fullref
      Changes++
      sendlog(Project["logemptyway"], name, "way1")      
      return fullref
    }
  }
  
  return fullref
}

#
# fixemptyarchive (Rev: B)
#   B: overhauled. No longer tries to find a new URL. 
#
# Fix where archiveurl= is empty (or url= in wayback template)
#   If url= is not working, remove empty archiveurl/date and leave dead link sans cbignore
#
function fixemptyarchive(tl,   k,url,urlarch,newurl,newdate,urlencoded,status) {

  if( datatype(tl,"cite") && tl ~ /archive[-]{0,1}url[ ]{0,}=[ ]{0,}[}|]/) {      
    url = getargurl(tl)
    urlencoded = uriparseEncodeurl(urldecodepython(url))
    if(urlencoded ~ /^http/) {
      status = webpagestatus(urlencoded)
      if( status == 1 || status == 3)             # Leave empty arguments in place if url= is working 
        return tl
      Changes++                                   # Else remove them and leave a dead link tag
      sendlog(Project["logemptyarch"], name, "cite1")
      return removearchive(tl, "nocbignore")
    }
    else {
      Changes++
      sendlog(Project["logemptyarch"], name, "cite2")
      return removearchive(tl, "nocbignore")
    }
  }

 # Wayback templates

  if(datatype(tl,"wayback") && tl ~ /[|][ ]{0,}url[ ]{0,}=[ ]{0,}[|}]/ ) {
    Changes++
    sendlog(Project["logemptyarch"], name, "wayback1")
    return tl
  }

  return tl
}

#
# fixbadstatus (Rev: A)
#
# Replace Wayback URLs reporting non-200 status. Update archivedate if changed.
#  tl is the contents of the template 
#  optional "fullref" string ie. everything between <ref></ref>
#
function fixbadstatus(tl, fullref,    urlarch,url,newurl,newdate,waybackdate,i,str,olddate) {

  if(datatype(tl,"cite")) {
    urlarch = getargarchive(tl, "url", "clean")
    if(isarchiveorg(urlarch)) {
      newurl = api(urlarch)
      if( newurl !~ /none/ && isarchiveorg(newurl) )    {   
        if( skindeep(newurl, urlarch) )                                       # Stays the same               
          return tl
        else {                                                                # Modify the snapshot date                         
          if(urltimestamp(urlarch) != urltimestamp(newurl)) {  
            newdate = urldate(newurl, getargarchive(tl, "date"))    
            tl = replacetext(tl, urlarch, newurl, "fixbadstatus1")
            tl = replacetext(tl, getargarchive(tl,"date"), newdate, "fixbadstatus2")
            Changes++
            sendlog(Project["log404"], name, "cite-modify")
            sendlog(Project["newiadate"], name, getargurl(tl) " " urltimestamp(urlarch) " " urltimestamp(newurl))
            return tl
          }
          else
            return tl
        }
      }
      else if( newurl !~ /none/ && ! isarchiveorg(newurl) )    {              # Change to alt archive
        newdate = altarchfield(newurl, "altarchdate")
        olddate = getargarchive(tl,"date","clean")
        tl = replacetext(tl, urlarch, newurl, "fixbadstatus3")
        tl = replacetext(tl, olddate, timestamp2date(newdate), "fixbadstatus4")
        Changes++
        sendlog(Project["log404"], name, "cite-modifyaltarch")
        sendlog(Project["newaltarch"], name, getargurl(tl) " " urltimestamp(urlarch) " " newurl " " newdate)
        return tl
      }
      else {                                                                  # Delete
        Changes++
        sendlog(Project["log404"], name, "cite-delete")
        sendlogwayrm(Project["wayrm"], name, urlarch, tl) 
        return removearchive(tl)
      }
    }
    else {
      sendlog(Project["log404"], name, "citeErrorB")
      return tl
    }
  }

  else if(datatype(tl,"wayback")) {

    url = getargurl(tl)
    waybackdate = getargwayback(tl,"date")
    urlarch = formatediaurl("https://web.archive.org/web/" waybackdate "/" url)

    if(length(url) > 10 && url ~ /^http/ && isarchiveorg(urlarch) && isanumber(waybackdate) ) {
      newurl = api(urlarch)
      if( newurl !~ /none/ && isarchiveorg(newurl) ) {
        if( skindeep(newurl, urlarch) )                                                   # Stays the same
          return tl
        else {                                                                            # Modify the snapshot date
          if(waybackdate != urltimestamp(newurl)) {
            tl = replacetext(tl, waybackdate, urltimestamp(newurl), "fixbadstatus5" )
            Changes++
            sendlog(Project["log404"], name, "wayback-modify")
            sendlog(Project["newiadate"], name, url " " waybackdate " " urltimestamp(newurl))
          }
          return tl
        }
      }
      if( newurl !~ /none/ && ! isarchiveorg(newurl) ) {                                  # Change to Alternative archive
        if(match(tl, /[{][ ]{0,}[Ww]ayback[ ]{0,}/, k)) {                  
          str = "[" altarchfield(newurl, "altarchencoded") " Archived copy] at " servicename(newurl) " (" timestamp2date(altarchfield(newurl, "altarchdate")) ")."
          tl = replacetext(tl, tl, str, "fixbadstatus6")
          Changes++
          sendlog(Project["log404"], name, "wayback-replaced-altarch")
          sendlog(Project["newaltarch"], name, url " " waybackdate " " newurl " " altarchfield(newurl, "altarchdate"))
        }
        return tl
      }
      else {
        i = countsubstring(fullref, url)    
        if( i == 2 ) {                                  # Delete wayback template / it follows an existing URL so replace with dead link only
          Changes++
          sendlog(Project["log404"], name, "wayback-delete1")
          sendlog(Project["cbignore"], name, "wayback-delete1")
          sendlogwayrm(Project["wayrm"], name, urlarch, tl) 
          return "{{dead link|date=" todaysdate() "|bot=medic}}{{cbignore|bot=medic}}"
        }
        else if( i == 1 ) {                             # Delete wayback template / replace with cite web (wayback template is standlone)
          Changes++
          sendlog(Project["log404"], name, "wayback-delete2")
          sendlog(Project["cbignore"], name, "wayback-delete2")
          sendlogwayrm(Project["wayrm"], name, urlarch, tl) 
          return buildciteweb(url, getargwayback(tl,"title")) "{{dead link|date=" todaysdate() "|bot=medic}}{{cbignore|bot=medic}}"
        }
        else {                                          # Bundled refs - leave alone and collect for future work
          Changes++
          sendlog(Project["log404"], name, "waybackErrorA")
          return tl
        }
      }
    }
    else {
      sendlog(Project["log404"], name, "waybackErrorB")
      return tl
    }
  }

  else if(datatype(tl,"barelink")) {
    newurl = api(tl)
    if( newurl !~ /none/ && isarchiveorg(newurl))  {
      if( skindeep(newurl,tl) )                                             # Stays the same
        return tl
      else {                                                                # Modify the snapshot date
        if(urltimestamp(tl) != urltimestamp(newurl)) {                      # Modify the snapshot date
          Changes++
          tl = replacetext(tl, tl, newurl, "fixbadstatus8")
          sendlog(Project["log404"], name, "barelink-modify")
          sendlog(Project["newiadate"], name, wayurlurl(tl) " " urltimestamp(tl) " " urltimestamp(newurl))
          return tl
        }
        else
          return tl
      }
    }
    if( newurl !~ /none/ && ! isarchiveorg(newurl) ) {                        # Change to Alternative archive
      str = tl
      tl = replacetext(tl, tl, newurl, "fixbadstatus9") 
      Changes++
      sendlog(Project["log404"], name, "barelink-replace-altarch")
      sendlog(Project["newaltarch"], name, wayurlurl(str) " " urltimestamp(str) " " newurl " " altarchfield(newurl, "altarchdate") )
      return tl
    }
    else {                                                 # Replace with original URL
      str = tl
      url = gensub(/^https[:]\/\/web[.]archive[.]org\/web\/[0-9]{1,14}\//, "", "g", formatediaurl(tl, "barelink")) 
      if(url ~ /^http/ && length(url) > 9 && url !~ /[ ]/) {
        Changes++
        tl = replacetext(tl, tl, url, "fixbadstatus5")      # No way to add {{cbignore}} - must be done manually. Check logs post run.
        sendlog(Project["log404"], name, "barelink-delete")
        sendlogwayrm(Project["wayrm"], name, str, tl) 
        return tl
      }
      else {
        sendlog(Project["log404"], name, "barelinkErrorA")
        return tl
      }
    }
  }
  else {
    # sendlog(Project["log404"], name, "unknownErrorA")
    return tl
  }
  return tl	
}

#
# Remove deadurl, archiveurl & archivedate from template and add {{cbignore}} and {{dead link}}
#
#  flag="nocbignore" means don't add it
#
function removearchive(tl, flag) {

  tl = replacetext(tl, strip(getargarchive(tl, "dead", "bar")), "", "removearchive1")
  tl = replacetext(tl, strip(getargarchive(tl, "url", "bar")), "", "removearchive2")
  tl = replacetext(tl, strip(getargarchive(tl, "date", "bar")), "", "removearchive3")
  if(flag ~ /nocbignore/) 
    tl = tl "{{dead link|date=" todaysdate() "|bot=medic}}"
  else
    tl = tl "{{dead link|date=" todaysdate() "|bot=medic}}{{cbignore|bot=medic}}"
  sendlog(Project["cbignore"], name, "removearchive1")
  return tl
}

#
# Return 1 if "tl" is of type "name" (wayback|cite|barelink)
#
function datatype(tl, name,    safe) {

  safe = stripwikicomments(tl)
  if(name ~ /wayback/) {
    if(safe ~ /[Ww]ayback[ ]{0,}[|]/ && safe ~ /[|][ ]{0,}[Uu][Rr][Ll][ ]{0,}=/ && safe ~ /[|][ ]{0,}[Dd]ate[ ]{0,}=/) 
      return 1
  }
  if(name ~ /cite/) {
    if(safe ~ /[Aa]rchive[-]{0,1}url[ ]{0,}=[ ]{0,}/ && safe ~ /[Aa]rchive[-]{0,1}date[ ]{0,}=/) 
      return 1
  }
  if(name ~ /barelink/) {
    if(safe ~ /^https?[:]\/\/w?[we]?[wb]?[.]?archive[.]org\/w?e?b?\/?[0-9]{1,14}\//)
      return 1
    if(safe ~ /^https?[:]\/\/wayback[.]archive[.]org\/web\/[0-9]{1,14}\//)
      return 1
  }

  return 0
}

#
# Given a citation or wayback template, return the url= argument 
#  if command = "full" also include the "url=" portion retaining original spacing
#
function getargurl(tl, command,     k,safe) {

  match(tl, /[|][ ]{0,}[Uu][Rr][Ll][ ]{0,}=[^|}]*[^|}]/, k)                         
  safe = stripwikicomments(k[0])
  if( length(safe) > 10 && substr(safe,1,1) ~ /[|]/) {
    if(command ~ /full/) 
      sub(/^[|][ ]{0,}/,"",safe)
    else
      sub(/^[|][ ]{0,}[Uu][Rr][Ll][ ]{0,}=[ ]{0,}/,"",safe)
    return safe
  }
  return
}

#
# Given a citation template, return the archivedate in timestamp format (YYYYMMDD) (not including archivedate=)
#
function getargarchivedatestamp(tl,  k,stamp) {

  if(tl ~ /archive[-]{0,1}url[ ]{0,}=/) {
    match(tl, /archive[-]{0,1}date[ ]{0,}=[^|}]*[^|}]/, k)
    if(length(k[0]) > 15) {
      sub(/archive[-]{0,1}date[ ]{0,}=/, "", k[0])
      k[0] = stripwikicomments(k[0])
      stamp = strip( sys2var(Exe["date"] " --date=\"" strip(k[0]) "\" +'%Y%m%d'") )
      if( length(stamp) && isanumber(stamp) ) 
        return stamp
    }
  }
}

#
# Given a wayback template, return the title, date or url arg content (not including arg=)
#  tl = contents of template
#  arg = "url" or "date" or "title"
#
function getargwayback(tl, arg,    k,safe,re) {

  re = "[|][ ]{0,}" arg "[ ]{0,}=[^|}]*[^|}]"   # If field exists and has content
  match(tl, re, k)
  safe = stripwikicomments(k[0])
  if(length(safe) && substr(safe,1,1) ~ /[|]/) {
    re = "^[|][ ]{0,}" arg "[ ]{0,}=[ ]{0,}"
    sub(re,"",safe)
    return strip(safe)
  }
}

#
# Given a citation template, return the archiveurl or archivedate (including the "archiveurl=" or "archivedate=" )
#  tl = template contents string
#  arg = argument to return (deadurl|url|date)
#  magic = "bar" (include the leading "|" in return string)
#        = "clean" don't include the "archiveurl=" portion just the field value
#  N.B. wiki comments (<!-- -->) are removed from the returned string
#
function getargarchive(tl, arg, magic,    k,s,b,re,subre,safe) {

  if(arg ~ /url/)
    subre = "archive[-]{0,1}url"
  else if(arg ~ /date/)
    subre = "archive[-]{0,1}date"
  else if(arg ~ /dead/)
    subre = "dead[-]{0,1}url"
  else
    return tl

  gsub(/\n/, " ", tl)  # collapse multi-line templates

  if(magic ~ /bar/) 
    re = "[|][ ]{0,}" subre "[ ]{0,}=[^|}]*[^|}]"            # Field has content
  else
    re = subre "[ ]{0,}=[^|}]*[^|}]"

  match(tl, re, k)
  split(strip(k[0]), b, "=")
  if(length(strip(b[2]))) { 
    if(magic ~ /clean/) {
      re = subre "[ ]{0,}=[ ]{0,}" 
      sub(re, "", k[0])
      return stripwikicomments(k[0])
    }
    else
      return stripwikicomments(k[0])
  }

  if(magic ~ /bar/) 
    re = "[|][ ]{0,}" subre "[ ]{0,}=[ ]{0,}[|}]"            # Field is empty
  else
    re = subre "[ ]{0,}=[ ]{0,}[|}]"

  if(match(tl, re, k)) {  # if right side of = is blank
    if(magic ~ /clean/) {
      return
    }
    s = substr(strip(k[0]), 1, length(strip(k[0])) - 1)
    return stripwikicomments(s)
  }
}

#
# Build a cite web template given url (required), date (optional), title (optional)
#
function buildciteweb(url, title,   ndate,ntitle) {

  if(length(title)) 
   ntitle = "|title=" title
  else
   ntitle = "|title=Unknown"

  return "{{cite web |url=" url " " ntitle " |dead-url=yes |accessdate=" todaysdate() "}}"
}


#
# Given an alt archive website url (eg. archive.is, webcite.org etc) 
#  return the field value designated by "field" argument
#
function altarchfield(url, field) {

  for(tag in WayLink) {
    if(countsubstring(WayLink[tag]["altarch"], url) )
      return WayLink[tag][field]
  }
}

#
# Given a url, return its archival service name in wikisource markup.
#
function servicename(url) {

  out = "(Unknown)<!--bot generated title-->"
  safe = url
  sub(/^https?[:]\/\//,"",safe)

  if(match(safe,/archive[.]today/))
    out = "[[Archive.is]]"

  else if(match(safe,/archive[.]is/))
    out = "[[Archive.is]]"

  else if(match(safe,/archive[.]org/))
    out = "[[Internet Archive]]"

  else if(match(safe,/archive[-]it/))
    out = "[[Archive-It]]"

  else if(match(safe,/bibalex[.]org/))
    out = "[[Bibliotheca_Alexandrina#Internet_Archive_partnership|Bibliotheca Alexandrina]]"

  else if(match(safe,/collectionscanada/))
    out = "Canadian Government Web Archive"

  else if(match(safe,/haw[.]nsk/))
    out = "the Croatian Web Archive (HAW)"

  else if(match(safe,/nlib[.]ee/))
    out = "the Estonian Web Archive"

  else if(match(safe,/vefsafn[.]is/))
    out = "the Icelandic Web Archive"

  else if(match(safe,/loc[.]gov/))
    out = "the [[Library of Congress]]"

  else if(match(safe,/webharvest[.]gov/))
    out = "the [[National Archives and Records Administration]]"

  else if(match(safe,/arquivo[.]pt/))
    out = "the [[Portugese Web Archive]]"

  else if(match(safe,/proni[.]gov/))
    out = "the [[Public Record Office of Northern Ireland]]"

  else if(match(safe,/uni[-]lj[.]si/))
    out = "the Slovenian Web Archive" 

  else if(match(safe,/stanford[.]edu/))
    out = "the [[Stanford University Libraries|Stanford Web Archive]]"

  else if(match(safe,/nationalarchives[.]gov[.]uk/))
    out = "the [[UK Government Web Archive]]"

  else if(match(safe,/parliament[.]uk/))
    out = "the UK Parliament's Web Archive"

  else if(match(safe,/webarchive[.]org[.]uk/))
    out = "the UK Web Archive"

  else if(match(safe,/nlb[.]gov[.]sg/))
    out = "Web Archive Singapore"

  else if(match(safe,/webcitation[.]org/))
    out = "[[WebCite]]"
  
  if(out ~ /Unknown/) 
    sendlog(Project["servicename"], name, url)
  
  return out

}

#
# Given a archive.org url, return its datestamp in Datetype format (dmy or mdy). Return includes "archivedate="
#  Otherwise, return curdate
#  eg. 20080101 -> January 1, 2008 (if global Datetype=mdy)
#
function urldate(url, curdate,   a,c,i,dateinput,re,newdate) {

  re = "^web$"

  c = split(url, a, "/")
  while(i++ < c) {
    if(a[i] ~ re) {
      i++
      dateinput = substr(a[i], 1, 4) "-" substr(a[i], 5, 2) "-" substr(a[i], 7, 2)
      if(Datetype ~ /dmy/) {
        newdate = sys2var(Exe["date"] " --date=\"" strip(dateinput) "\" +'%-d %B %Y'")
        if(length(newdate))
          return "archivedate=" newdate
      }
      else { 
        newdate = sys2var(Exe["date"] " --date=\"" strip(dateinput) "\" +'%B %-d, %Y'")
        if(length(newdate))
          return "archivedate=" newdate
      }
    }
  }
  return curdate
}

#
# Given a timestamp, return in Datetype format (dmy or mdy). 
#
function timestamp2date(timestamp,  dateinput) {

      dateinput = substr(timestamp, 1, 4) "-" substr(timestamp, 5, 2) "-" substr(timestamp, 7, 2)
      if(Datetype ~ /dmy/) 
        return sys2var(Exe["date"] " --date=\"" strip(dateinput) "\" +'%-d %B %Y'")
      else 
        return sys2var(Exe["date"] " --date=\"" strip(dateinput) "\" +'%B %-d, %Y'")
}

#
# Today's date ie. "March 2016"
#
function todaysdate() {
  return sys2var(Exe["date"] " +'%B %Y'")
}

#
# Determine date type - set global Datetype = dmy or mdy
#   Search for {{use dmy dates..} or {{use mdy dates..}
#   default mdy
#
function setdatetype(  i) {
  Datetype = "mdy"
  while(i++ < ArticleC) {
    if(ArticleS[i] ~ /[{]{0,}[{][ ]{0,}[Uu]se [Dd][Mm][Yy] [Dd]ates/)
      Datetype = "dmy"
    if(ArticleS[i] ~ /[{]{0,}[{][ ]{0,}[Uu]se [Mm][Dd][Yy] [Dd]ates/)
      Datetype = "mdy"
  }
}

#
# Return 0 if ref is not WP:BUNDELED (ie. more than one cite inside a <ref></ref>)
#  Only works if ref contains "archiveurl=" and/or "wayback|" otherwise return 4
#
function bundled(ref, caller,    a,c,d) {

  if(length(caller) && Debug["process"])
    print "BUNDLED REF (" caller ") = " ref

  c = split(ref, a, /archive[-]{0,1}url[ ]{0,}=/)  
  if(c > 2) return 2
  d = split(ref, a, /[Ww]ayback[ ]{0,}[|]/)
  if(d > 2) return 3

  if(c < 2 && d < 2) 
    return 4

  return 0
}

#
# Return 1 if ref (or string) contains {{cbignore}} template.
#  Does not look outside <ref></ref> pair
#  caller is for debugging
#
function cbignore(ref, caller) {

  if(length(caller) && Debug["process"])
    print "CBIGNORE REF (" caller ") = " ref

  if(tolower(ref) !~ /cbignore/)
    return 0
  return 1
}

#
# Return 1 if same \n separarted line as "lk" contains {{cbignore}} template.
#  Does not look beyond the line break
#  Pass copy of the article you want to check (such as ArticleWork)
#
function cbignorebareline(article, lk, caller,      i, articles, articlec) {

  if(length(caller) && Debug["process"])
    print "CBIGNOREBARELINE REF (" caller ") = " lk

  articlec = split(article, articles, "\n")

  while(i++ < articlec) {
    if( countsubstring(articles[i], lk) > 0 ) {
      if(tolower(articles[i]) ~ /cbignore/)
        return 1
    }
  }
  return 0
}


#
# Document the fixes and revisions made for this project and run
#
function documentation( a,c,i) {

  if(!checkexists(Project["docfixes"])) {
    print "Documentation for Wayback Medic project " Project["id"] "\n" >> Project["docfixes"]
    print "File descriptions:" >> Project["docfixes"]
    print "        index     =    Database index file" >> Project["docfixes"]
    print "        auth      =    List of articles processed" >> Project["docfixes"]
    print "        discovered =   List of articles edited by WaybackMedic." >> Project["docfixes"]
    print "        timeout   =    Server timeout log. The IA API or Wayback Machine" >> Project["docfixes"]
    print "        bogusapi  =    IA API returned a bogus recommendation (eg. 404/403), page really works." >> Project["docfixes"]
    print "        manual    =    Articles that need manual processing. Search medic.awk for Project[\"manual\"] for reasons." >> Project["docfixes"]
    print "        cbignore  =    {{cbignore|bot=medic}} was added to these articles." >> Project["docfixes"]
    print "        critical  =    Critical system errors.." >> Project["docfixes"]
    print "        jsonmismatch = First and second API request are different lengths. Files are csv.orig and csv2.orig in data directory." >> Project["docfixes"]
    print "        apimismatch =  API returned +/- number json records originally requested. C.f. data/postfile and data/csv." >> Project["docfixes"]
    print "        servicename =  Archive service name found is unknown. Update list in servicename() in medic.awk" >> Project["docfixes"]
    print "        log*      =    Log files for fixes made" >> Project["docfixes"]
    print "        newiadate =    Log of cases when the IA snapshot date changed." >> Project["docfixes"]
    print "        newaltarch =   Log of cases where alternative archive URL added." >> Project["docfixes"]
    print "        wayall    =    All IA links found." >> Project["docfixes"]
    print "        wayrm     =    IA links deleted from wikipedia." >> Project["docfixes"]
    print "        wayrmfull =    Formated file for processing by medic.awk to see why links were removed."  >> Project["docfixes"]
    print "" >> Project["docfixes"]
    print " # Function names (Revision) for this project:" >> Project["docfixes"]
    print "" >> Project["docfixes"]

    c = split(readfile(Exe["medic"]), a, "\n")
    while(i++ < c) {
      if(a[i] ~ /[(]Rev[:][ ][A-Z]/) 
        print " " a[i]  >> Project["docfixes"]
    }
    close(Project["docfixes"])
  }
}

#
# Log (append) a line to Project["wayrmfull"] and Project["wayrm"]
#
function sendlogwayrm(database, name, msg, tl) {    

  print name "----" msg >> database

  print "" >> Project["wayrmfull"]
  print name ":" >> Project["wayrmfull"]

  if(datatype(tl, "cite")) {  
    print "<ref>" tl "</ref>" >> Project["wayrmfull"]
  }
  else if(datatype(tl, "wayback")) {
    iaurl = "https://web.archive.org/web/" getargwayback(tl,"date") "/" uriparseEncodeurl(urldecodepython(getargwayback(tl,"url")))
    print "<ref>" tl "</ref> (" iaurl ")" >> Project["wayrmfull"]
  }
  else if(datatype(tl, "barelink")) {
    print "<ref>[" tl " Link]</ref>" >> Project["wayrmfull"]
  }

  close(Project["wayrmfull"])
  close(database)
}

#
# skindeep(url1, url2)
#  
#  Return 1 if the difference between url1 and 2 is "skin deep" 
#  ie. the only diff is https and/or :80 and/or archive.org/web/ and/or web.archive.org .. return 1                  
#
function skindeep(url1, url2) {

  safe1 = url1
  safe2 = url2
  sub(/^https/,"http", safe1); sub(/^https/,"http", safe2)
  sub(/[:]80\//,"/",safe1); sub(/[:]80\//,"/",safe2)
  sub(/archive[.]org\/web\//,"archive.org/", safe1); sub(/archive[.]org\/web\//,"archive.org/", safe2)      
  sub(/http[:]\/\/web[.]archive[.]org/, "http://archive.org", safe1); sub(/http[:]\/\/web[.]archive[.]org/, "http://archive.org", safe2)

  if(countsubstring(safe1, safe2) > 0)
    return 1

  return 0
}

#
# formatediaurl(string, type)
#  type = cite|wayback|bareurl 
#
# Re-format IA URL into a regular format 
#  Function previously called fixmissingprotocol()
#
# https RFC https://en.wikipedia.org/wiki/Wikipedia:VPR/Archive_127#RfC:_Should_we_convert_existing_Google_and_Internet_Archive_links_to_HTTPS.3F 
#
function formatediaurl(tl, type) {

  if(type ~ /cite/) {

    if(tl ~ /archive[-]{0,1}url[ ]{0,}=[ ]{0,}web/) {
      sub(/archive[-]{0,1}url[ ]{0,}=[ ]{0,}web/,"archiveurl=https://web",tl)
    }
    if(tl ~ /archive[-]{0,1}url[ ]{0,}=[ ]{0,}wayback/) {
      sub(/archive[-]{0,1}url[ ]{0,}=[ ]{0,}wayback/,"archiveurl=https://web",tl)
    }
    if(tl ~ /archive[-]{0,1}url[ ]{0,}=[ ]{0,}archive/) {
      sub(/archive[-]{0,1}url[ ]{0,}=[ ]{0,}archive/,"archiveurl=https://web.archive",tl)
    }
    url = getargarchive(tl, "url", "clean")
    newurl = formatediaurl(url, "barelink")   # recurse
    if( countsubstring(url, newurl) < 1) {
      tl = replacetext(tl, url, newurl, "formatediaurl1")
      return tl
    }
    return tl
  }

  if(type ~ /wayback/) {

    if(tl !~ /[|][ ]{0,}url[ ]{0,}=[ ]{0,}[Hh][Tt][Tt][Pp]/ && tl !~ /[|][ ]{0,}url[ ]{0,}=[ ]{0,}[}|]/ && tl ~ /[|][ ]{0,}url[ ]{0,}=/) {
      sub(/[|][ ]{0,}url[ ]{0,}=[ ]{0,}/,"|url=http://",tl)
      return tl
    }
  }

  if(type ~ /barelink/) {
    if(tl ~ /^https?[:]\/\/archive/) {
      sub(/^https?[:]\/\/archive/, "https://web.archive", tl)
    }
    else if(tl ~ /^https?[:]\/\/w[we][wb].archive/) {
      sub(/^http[:]\/\/w[we][wb].archive/, "https://web.archive", tl)
    }
    else if(tl ~ /^http[:]\/\/wayback.archive/) {
      sub(/^http[:]\/\/wayback.archive/, "https://web.archive", tl)
    }
    tl = gensub(/[:]80\//,"/",1,tl)   
    return tl
  }

  return tl
}

#
# Format a non-IA URL into a regular format
#
function formatedorigurl(url,  safe) {

  if(url ~ /^none/) 
    return "none"

  safe = url
  if(safe ~ /^http[s]?[:]\/\//)
    return safe
  else if(safe ~ /^\/\//) {
    sub(/^\/\//,"http://",safe)
    return safe
  }
  else
    return "http://" safe  # Assume the best..
}

#
# Populate WayLink array with new data parsed from article
#   fillarray(url, type [, date]) 
#    type = "normal" or "build"
#     If type build, also pass date
#
function fillarray(url, type, date,    uuid) {

  uuid = sys2var(Exe["uuidgen"])  # Create a uniq ID for this link for the API call

  if(type ~ /normal/) {
    WayLink[uuid]["origiaurl"] = url                            # http://archive.org/web/20061009134445/http://timelines.ws:80/countries/AFGHAN_B_2005.HTML
    WayLink[uuid]["formated"] = formatediaurl(url, "barelink")  # https://web.archive.org/web/20061009134445/http://timelines.ws/countries...
    WayLink[uuid]["origurl"] = wayurlurl(url)                   # http://timelines.ws:80/countries/AFGHAN_B_2005.HTML
    WayLink[uuid]["origdate"] = urltimestamp(url)               # 20061009134445
    WayLink[uuid]["tag"] = uuid
  }
  if(type ~ /build/) {
    WayLink[uuid]["origiaurl"] = "https://web.archive.org/web/" date "/" url   
    WayLink[uuid]["formated"] = formatediaurl(WayLink[uuid]["origiaurl"], "barelink")
    WayLink[uuid]["origurl"] = url                                             
    WayLink[uuid]["origdate"] = date                                           
    WayLink[uuid]["tag"] = uuid

  }
  WayLink[uuid]["origiaurl"] == "" ? WayLink[uuid]["origiaurl"] = "none" : ""
  WayLink[uuid]["formated"] == "" ? WayLink[uuid]["formated"] = "none" : ""
  WayLink[uuid]["origurl"] == "" ? WayLink[uuid]["origurl"] = "none" : ""
  WayLink[uuid]["origdate"] == "" ? WayLink[uuid]["origdate"] = "197001010001" : ""

 # Create ["origencoded"]
  if(WayLink[uuid]["origurl"] !~ /^http/ )  
    eurl = formatedorigurl(WayLink[uuid]["origurl"])
  else 
    eurl = WayLink[uuid]["origurl"]

  if(WayLink[uuid]["origurl"] !~ /none/) 
    WayLink[uuid]["origencoded"] = uriparseEncodeurl(urldecodepython(eurl))    
  else
    WayLink[uuid]["origencoded"] = "none"      

  WayLink[uuid]["altarch"] = "none"
  WayLink[uuid]["altarchencoded"] = "none"
  WayLink[uuid]["altarchdate"] = "none"

}

#
# Given a full ref string, replace old string with new string. Also remove duplicate dead link or cbignore templates.
#   caller is a debugging string.
#
function replacefullref(fullref, old, new, caller,   re1,re2,c,origfullref) {

  origfullref = fullref

 # Remove {{dead link}} .. but only if one in ref, and one in new text
  re1 = "[{][ ]{0,}[{][ ]{0,}[Dd]ead[ ]{0,}[Ll]ink"
  re2 = re1 "[^}]*[}][ ]{0,}[}]"
  c = split(new, a, re1)
  if(c == 2) {
    c = split(fullref, a, re1)
    if(c == 2) {
      sub(re2,"",fullref)
    }
  }
 # Remove {{cbignore}} .. but only if one in ref, and one in new text
  re1 = "[{][ ]{0,}[{][ ]{0,}[Cc][Bb][Ii][Gg][Nn][Oo][Rr][Ee]"
  re2 = re1 "[^}]*[}][ ]{0,}[}]"
  c = split(new, a, re1)
  if(c == 2) {
    c = split(fullref, a, re1)
    if(c == 2) {
      sub(re2,"",fullref)
    }
  }

  fullref = replacetext(fullref, old, new, caller "/replacefullref1")
  return replacetext(ArticleWork, origfullref, fullref, caller "/replacefullref2")
 
}

#
# Parse and process article. Action to perform is defined by "action". Type of links to process is defined by "target".
#
#   action = "format"   .. run the fix routines that are purely page formating (run first)
#   action = "getlinks" .. add Wayback Machine links found in the article to the WayLink[] array (run second)
#   action = "process"  .. run the fix routines that access the Wayback API (run last)
#
#   target = "citeinside"     .. Citation templates inside ref pairs
#   target = "citeoutside"    .. Citation templates outside ref pairs
#   target = "waybackinside"  .. Wayback template inside ref pairs
#   target = "waybackoutside" .. Wayback templates outside ref pairs
#   target = "bareoutside"    .. Bare links outside ref pairs
#
function process_article(action, target,    c,b,i,tl,k,d,url,date,uuid,articlenoref,orig) {

   if(action !~ /getlinks|format|process/) {
     print "Error in parsearticle: no right action defined" > "/dev/stderr"
     return
   }
   if(target !~ /citeinside|citeoutside|waybackinside|waybackoutside|bareoutside/) {
     print "Error in parsearticle: no right target defined" > "/dev/stderr"
     return
   }


 # Cite or Wayback templates inside ref pairs
   if(target ~ /citeinside|waybackinside/) {
     c = split(ArticleWork, b, "<ref[^>]*>")
     i = 1
     while(i++ < c) {
       tl = k = ""
       delete d
       k = substr(b[i], 1, match(b[i], "</ref>") - 1)
    # Cite templates
       if(k ~ /archive[-]{0,1}url[ ]{0,}=/ && ! cbignore(k, "cite") && ! bundled(k, "cite") && target ~ /citeinside/ ) {   
         # Note: the following match string is slightly different from the similar one below
         match(k, /[{][ ]{0,1}[{][ ]{0,}[Cc]ite[^}]+}|{[ ]{0,}[Cc]ita[^}]+}|{[ ]{0,}[Vv]cite[^}]+}|{[ ]{0,}[Vv]ancite[^}]+}|{[ ]{0,}[Hh]arvrefcol[^}]+}|{[ ]{0,}[Cc]itation[^}]+}/, d) 
         orig = tl = d[0] "}" 
         url = getargarchive(tl, "url", "clean")
         if( isarchiveorg(url) ) {
           if( action ~ /format/ ) {
             tl = fixthespuriousone(tl)
             tl = fixencodedurl(tl)
             if(orig != tl) {
               ArticleWork = replacefullref(k, orig, tl, "process_article1")
             }
           }
           else if(action ~ /getlinks/) {
             fillarray(url, "normal")
           }
           else if(action ~ /process/) {
             tl = fixbadstatus(tl)
             if(orig != tl) {
               ArticleWork = replacefullref(k, orig, tl, "process_article2")           
             }
           }
         }
         else if(url == "" && action ~ /format/) {
           tl = fixemptyarchive(tl)
           if(orig != tl) {
             ArticleWork = replacefullref(k, orig, tl, "process_article1")
           }         
         }
       }
    # Wayback templates 
       else if(k ~ /[Ww]ayback[ ]{0,}[|]/ && ! cbignore(k, "wayback") && ! bundled(k, "wayback") && target ~ /waybackinside/ ) {
         match(k, /{[ ]{0,}[Ww]ayback[^}]+}/, d)
         orig = tl = "{" d[0] "}"
         url = getargwayback(tl, "url")
         if( url ~ /^http/ ) {
           if(action ~ /format/) {
             tl = fixtrailingchar(tl)
             tl = fixencodedurl(tl)
             tl = fixemptyarchive(tl)
             if(orig != tl) { 
               ArticleWork = replacefullref(k, orig, tl, "process_article3")
             }
           }
           else if(action ~ /getlinks/) {
             date = getargwayback(tl, "date")
             if(isanumber(date) && date != 0) {
               fillarray(url, "build", date)
             }
           }
           else if(action ~ /process/) {
             tl = fixbadstatus(tl, k)
             if(orig != tl) 
               ArticleWork = replacefullref(k, orig, tl, "process_article2")           
           }
         }
       }
     }
   }

 # Cite/Wayback templates or Barelink outside ref pairs

   if(target ~ /citeoutside|waybackoutside|bareoutside/) {

     # Create version of article with ref's deleted (retaining the actual <ref></ref> pairs)
     articlenoref = ArticleWork
     gsub(/<ref[^>]*\/[ ]{0,}>/,"",articlenoref)  # remove <ref name=string />
     c = split(articlenoref, b, "<ref[^>]*>")      # remove <ref></ref>      
     i = 1
     while(i++ < c){
       articlenoref = replacetext(articlenoref, substr(b[i], 1, match(b[i], "</ref>") - 1), "","process_article5")
    }

    # Cite templates outside ref pairs
     if(target ~ /citeoutside/ ) {
       c = split(articlenoref, b, /[{][ ]{0,}[{]/)
       i = 0
       while(i++ < c) {
         tl = k = ""
         delete d
         k = substr(b[i], 1, match(b[i], /[}][ ]{0,}[}]/) - 1)
         if(k ~ /archive[-]{0,1}url[ ]{0,}=/ && ! cbignorebareline(ArticleWork, k, "citeoutside") ) {
           k = "{" k "}"          
           # Note: the following match string is slightly different from the similar one above
           match(k, /[{][ ]{0,}[Cc]ite[^}]+}|{[ ]{0,}[Cc]ita[^}]+}|{[ ]{0,}[Vv]cite[^}]+}|{[ ]{0,}[Vv]ancite[^}]+}|{[ ]{0,}[Hh]arvrefcol[^}]+}|{[ ]{0,}[Cc]itation[^}]+}/, d) 
           orig = tl = d[0] "}"
           url = getargarchive(tl, "url", "clean")
           if(url ~ /^http/ && isarchiveorg(url)) {
             if(action ~ /format/) {
               tl = fixthespuriousone(tl)
               tl = fixencodedurl(tl)
               tl = fixemptyarchive(tl)
               if(orig != tl) 
                 ArticleWork = replacetext(ArticleWork,orig,tl,"process_article6")
             }
             else if(action ~ /getlinks/) {
	       fillarray(url, "normal")
             }
             else if(action ~ /process/) {
               tl = fixbadstatus(tl)
               if(orig != tl) 
                 ArticleWork = replacetext(ArticleWork,orig,tl,"process_article7")           
             }
           }
         }
       }    
     }

    # Wayback templates outside ref pairs -- DISABLED. Possible source of errors needs more debugging. Cyberbot does not add wayback outside refs.
    # if(target ~ /waybackoutside/ ) {
    if(0 == 1) {
       c = split(articlenoref, b, /[{][ ]{0,}[{]/)
       i = 0
       while(i++ < c) {
         k = substr(b[i], 1, match(b[i], /[}][ ]{0,}[}]/) - 1)
         if(k ~ /^[ ]{0,}[Ww]ayback[ ]{0,}[|]/ && ! cbignorebareline(ArticleWork, k, "waybackoutside") ) { 
           orig = tl = k
           url = getargwayback(tl, "url")
           if(url ~ /^http/) {
             if(action ~ /format/) {
               tl = fixtrailingchar(tl)
               tl = fixencodedurl(tl)
               tl = fixemptyarchive(tl)
               if(orig != tl) 
                 ArticleWork = replacetext(ArticleWork, orig, tl, "process_article8")
             }
             else if(action ~ /getlinks/) {
               date = getargwayback(tl, "date")
               if(isanumber(date) && date != 0) {
                 fillarray(url, "build", date)
               }
             }
             else if(action ~ /process/) {
               tl = fixbadstatus(tl)
               if(orig != tl) 
                 ArticleWork = replacetext(ArticleWork, orig, tl, "process_article9")           
             }
           }
         }
       }
     }

    # Bare links outside ref pairs
     if(target ~ /bareoutside/ ) {
       c = patsplit(articlenoref, b, /[\[][ ]{0,}https?[:]\/\/w?[we]?[wb]?[.]?archive[.]org\/?w?e?b?\/[0-9]{1,14}\/[^ \]]*[^ \]]/)
       i = 0
       while(i++ < c) {
         tl = strip(substr(b[i], 2, length(b[i])))  # Remove leading "["
         orig = tl 
         if(tl ~ /^http/ && tl !~ /[ ]/ && length(tl) > 24 && ! cbignorebareline(ArticleWork, tl, "bareoutside") && isarchiveorg(tl) ) {
           if(action ~ /format/) {
             # nothing
             if(orig != tl) {
               ArticleWork = replacetext(ArticleWork, orig, tl, "process_article11")
             }
           }
           else if(action ~ /getlinks/) {
             fillarray(tl, "normal")
           }
           else if(action ~ /process/) {
             tl = fixbadstatus(tl)
             if(orig != tl) {
               ArticleWork = replacetext(ArticleWork, orig, tl, "process_article12")           
             }
           }
         }
       }
     }
   }

   if(action ~ /getlinks/) {
     c = 0
     for(i in WayLink) 
       c++
     return c
   }
}

function main(  c,i,num) {

   Article = readfile(sourcefile)
   ArticleC = split(Article, ArticleS, "\n")
   ArticleWork = Article

   documentation()
   setdatetype()

   Changes = c = num = 0

  # Fix pure formating problems 
   process_article("format", "bareoutside")
   process_article("format", "citeoutside")
   process_article("format", "waybackinside")
   process_article("format", "citeinside")

  # Parse IA links 
   process_article("getlinks", "bareoutside")
   process_article("getlinks", "citeoutside")
   process_article("getlinks", "waybackinside")
   num = process_article("getlinks", "citeinside")

   if(Debug["api"] && num > 0) print "\nFound [" num "] links:\n"
   for(i in WayLink) {
     c++
     if(Debug["api"]) {
       print "  WayLink[" i "][\"origiaurl\"] = " WayLink[i]["origiaurl"]
       print "  WayLink[" i "][\"origurl\"] = " WayLink[i]["origurl"]
       print "  WayLink[" i "][\"origencoded\"] = " WayLink[i]["origencoded"]
       print "  WayLink[" i "][\"origdate\"] = " WayLink[i]["origdate"]
       print "  WayLink[" i "][\"altarch\"] = " WayLink[i]["altarch"]
       print "  WayLink[" i "][\"altarchencoded\"] = " WayLink[i]["altarchencoded"]
       print "--"
     }
     sendlog(Project["wayall"], name, WayLink[i]["origiaurl"], "noclose")     # Print all Wayback URLs to file. Comment out during debugging. 
   }
   close(Project["wayall"])

   if( queryapipost(c) ) {                         # -> api.awk
     process_article("process", "bareoutside")
     process_article("process", "citeoutside")
     process_article("process", "waybackinside")
     process_article("process", "citeinside")      # N.B.: this must be last
   }
   else {
     print "Error in queryAPI() for " name " : bad data. Skipped process_article(\"process\", ____)" > "/dev/stderr"
     sendlog(Project["critical"], name, "queryapipost")
   }

   if(Article != ArticleWork) { # Only save if there was a change to the article
     print ArticleWork > Datadir "article.waybackmedic.txt"
     close(Datadir "article.waybackmedic.txt")
   }
   
   print Changes
   sys2var(Exe["rm"] " -r /tmp/" Wid)

   exit

}

