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


#
# Today's date ie. "March 2016"
#
proc todaysdate(): string =
  return format(parse(getDateStr(), "yyyy-MM-dd"), "MMMM yyyy")

#
# Today's date full ie. "12 March 2016" .. "day" is not zero-padded
#
proc todaysdatefull(): string =
  
  if GX.datetype == "dmy":
    return format(parse(getDateStr(), "yyyy-MM-dd"), "d MMMM yyyy")

  if GX.datetype == "mdy":
    return format(parse(getDateStr(), "yyyy-MM-dd"), "MMMM d, yyyy")

#
# Today's date in ymd ie. 20180901
#
proc todaysdateymd(): string =
  return format(parse(getDateStr(), "yyyy-MM-dd"), "yyyyMMdd")

#
# Determine date type - set global Datetype = dmy or mdy
#   Search for {{use dmy dates..} or {{use mdy dates..}
#   default mdy
#
proc setdatetype() =

  var articlec = awk.split(GX.article, articles, "\n")

  for i in 0..articlec - 1:
    if articles[i] ~ ("[{]{0,}[{]" & GX.space & "[Uu][Ss][Ee]" & GX.space & "[Dd][Mm][Yy]" & GX.space & "[Dd]?[Aa]?[Tt]?[Ee]?[Ss]?|[{]{0,}[{]" & GX.space & "[Dd][Mm][Yy]" & GX.space & "[|]|[{]{0,}[{]" & GX.space & "[Dd][Mm][Yy]" & GX.space & "[}]|[{]{0,}[{]" & GX.space & "[Uu][Ss][Ee][Dd][Mm][Yy]"):
      GX.datetype = "dmy"
      GX.datetypeexists = true      
      break
    if articles[i] ~ ("[{]{0,}[{]" & GX.space & "[Uu][Ss][Ee]" & GX.space & "[Mm][Dd][Yy]" & GX.space & "[Dd]?[Aa]?[Tt]?[Ee]?[Ss]?|[{]{0,}[{]" & GX.space & "[Mm][Dd][Yy]" & GX.space & "[|]|[{]{0,}[{]" & GX.space & "[Mm][Dd][Yy]" & GX.space & "[}]|[{]{0,}[{]" & GX.space & "[Uu][Ss][Ee][Mm][Dd][Yy]"):
      GX.datetype = "mdy"
      GX.datetypeexists = true      
      break

#
# Given a full IA URL (including http://) return wayback timestamp (see main function below, urltimestamp())
#
proc urltimestamp_wayback*(url: string): string =
  var
    c = 0

  c = awk.split(url, a, "/")
  for i in 0..c - 1:
    if not empty(a[i]):
      if a[i] ~ "^post$":    # skip: https://archive.org/post/119669/lawsuit-settled
        return ""
      if a[i] ~ "^web$":
        return a[i + 1]
      if a[i] ~ "^[0-9*?]+$" and i == 3:   
        return a[i] 

  return ""


# Return true if s contain the dummy snapshot date: 189908, 189907, 1899, 1970
# If no flag set then any of the dummy dates
#
proc dummydate*(s: string, fl: varargs[string]): bool =

  var
    flag = ""

  if len(fl) > 0:
    if fl[0] == nil or fl[0] == "":
      flag = ""
    else:
      flag = fl[0]

  if flag == "189908":
    if s ~ "18990101080101":
      return true
  elif flag == "189907":
    if s ~ "18990101070101":
      return true
  elif flag == "1899":
    if s ~ "18990101080101|18990101070101":
      return true
  elif flag == "1970":
    if s ~ "19700101000000|197001010001":
      return true
  else:  
    if s ~ "18990101080101|18990101070101|19700101000000|197001010001":
      return true

  return false

#
# Return true if URL is archive.org 
#
proc isarchiveorg*(url: string): bool =
  var safe = url  
  gsub("^[Hh][Tt][Tt][Pp][Ss]?[:]//" & GX.iahre & "[.]?", "", safe)
  if safe ~ "^[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg][:]?[8]?[04]?[48]?[30]?[/]":  
    var datestamp = urltimestamp_wayback(url)
    if datestamp !~ "[*|?]" and datestamp.len > 3 and datestamp.len < 15:
      return true
  return false

#
# Return true if URL is an alt-archive
#
proc isarchive_helper*(url, re: string): bool =
  var rre = "^" & re              
  if url ~ rre:
    return true
  return false

proc iswebcite*(url: string): bool = isarchive_helper(url, GX.service[1])
proc isarchiveis*(url: string): bool = isarchive_helper(url, GX.isre)
proc islocgov*(url: string): bool = isarchive_helper(url, GX.locgovre)
proc isporto*(url: string): bool = isarchive_helper(url, GX.service[4])
proc isstanford*(url: string): bool = isarchive_helper(url, GX.service[5])
proc isarchiveit*(url: string): bool = isarchive_helper(url, GX.service[6])
proc isbibalex*(url: string): bool = isarchive_helper(url, GX.bibalexre)
proc isnatarchivesuk*(url: string): bool = isarchive_helper(url, GX.natarchivesukre)
proc isvefsafn*(url: string): bool = isarchive_helper(url, GX.vefsafnre)
proc iseuropa*(url: string): bool = isarchive_helper(url, GX.europare)
proc ispermacc*(url: string): bool = isarchive_helper(url, GX.permaccre)
proc isproni*(url: string): bool = isarchive_helper(url, GX.pronire)
proc isparliament*(url: string): bool = isarchive_helper(url, GX.parliamentre)
proc isukweb*(url: string): bool = isarchive_helper(url, GX.ukwebre)
proc iscanada*(url: string): bool = isarchive_helper(url, GX.canadare)
proc iscatalon*(url: string): bool = isarchive_helper(url, GX.catalonre)
proc issingapore*(url: string): bool = isarchive_helper(url, GX.singaporere)
proc isslovene*(url: string): bool = isarchive_helper(url, GX.slovenere)
proc isfreezepage*(url: string): bool = isarchive_helper(url, GX.freezepagere)
proc iswebharvest*(url: string): bool = isarchive_helper(url, GX.webharvestre)
proc isnlaau*(url: string): bool = isarchive_helper(url, GX.nlaaure)
proc iswikiwix*(url: string): bool = isarchive_helper(url, GX.wikiwixre)
proc isyork*(url: string): bool = isarchive_helper(url, GX.yorkre)
proc ismemory*(url: string): bool = isarchive_helper(url, GX.memoryre)
proc islac*(url: string): bool = isarchive_helper(url, GX.lacre)

# newwebarchives - use GX.name or GX.service[#]

#
# Return true if any one of the archive's listed in "group" 
#
proc isarchive(url, group: string): bool =

  if group == "all":
    if isarchiveorg(url) or isarchive(url, "sub1"):
      return true

  if group == "sub1":  # everything but archive.org
    if iswebcite(url) or isfreezepage(url) or isnlaau(url) or 
       isarchive(url, "sub2"):
      return true

  if group == "sub2":  # everything but archive.org, webcite, freezepage and nlaau
    if isarchiveis(url) or islocgov(url) or isporto(url) or 
       isstanford(url) or isarchiveit(url) or isbibalex(url) or 
       isnatarchivesuk(url) or isvefsafn(url) or iseuropa(url) or
       ispermacc(url) or isproni(url) or isparliament(url) or
       isukweb(url) or iscanada(url) or iscatalon(url) or 
       issingapore(url) or isslovene(url) or iswebharvest(url) or
       iswikiwix(url) or isyork(url) or ismemory(url) or
       islac(url):
      return true

  if group == "sub3":  # everything using a 14-digit timestamp
    if isarchiveorg(url) or 
       isarchiveis(url) or islocgov(url) or isporto(url) or
       isstanford(url) or isarchiveit(url) or isbibalex(url) or
       isnatarchivesuk(url) or isvefsafn(url) or iseuropa(url) or
       ispermacc(url) or isproni(url) or isparliament(url) or
       isukweb(url) or iscanada(url) or iscatalon(url) or 
       issingapore(url) or isslovene(url) or iswebharvest(url) or
       iswikiwix(url) or isyork(url) or ismemory(url) or
       islac(url):
      return true 

  return false 

  # newwebarchives

#
# Given an archive URL, return the date stamp portion
#  https://archive.org/web/20061009134445/http://timelines.ws/countries/AFGHAN_B_2005.HTML ->
#   20061009134445
#
proc urltimestamp*(url: string): string =
  
  var
    c = 0

  if isarchiveorg(url) or isbibalex(url): # http://web.archive.bibalex.org:80/web/20011007083709/http..
    return urltimestamp_wayback(url)      # http://web.archive.org/web/20011007083709/http..

  if iswebcite(url) or isfreezepage(url) or isnlaau(url):   # no timestamp
    return ""

                                          # https://archive.is/20121209212901/http..
                                          # http://webarchive.nationalarchives.gov.uk/20091204115554/http
                                          # https://swap.stanford.edu/20091122200123/http
                                          # http://webarchive.proni.gov.uk/20111213123846/http
                                          # http://webarchive.parliament.uk/20110714070703/http
  if isarchiveis(url) or isstanford(url) or isproni(url) or
     isnatarchivesuk(url) or isparliament(url):                    
    c = awk.split(url, a, "/")
    if len(a) > 3:
      if a[3] ~ "^[0-9*?]+$":   
        return a[3] 

                                          # http://webarchive.nationalarchives.gov.uk/tna/20091204115554/http  (second version)
  if isnatarchivesuk(url):      
    c = awk.split(url, a, "/")           
    for i in 0..c - 1:
      if not empty(a[i]):
        if a[i] ~ "^[Tt][Nn][Aa]$" and i != high(a):   
          if a[i + 1] ~ "^[0-9*]+$": 
            return a[i + 1] 

                                          # http://webharvest.gov/peth04/20041022004143/http://www.ftc.gov/os/statutes/textile/alerts/dryclean
  if iswebharvest(url):
    c = awk.split(url, a, "/")
    if len(a) > 6:
      if a[4] ~ "^[0-9*?]+$":
        return a[4]

  if iswikiwix(url):                      # http://archive.wikiwix.com/cache/20180329074145/http://www.linterweb.fr
    c = awk.split(url, a, "/")            
    for i in 0..c - 1:
      if not empty(a[i]):
        if a[i] ~ "^[Cc][Aa][Cc][Hh][Ee]$" and i != high(a):
          if a[i + 1] ~ "^[0-9*?]+$":
            return a[i + 1]

  if islocgov(url) or isarchiveit(url):   # http://webarchive.loc.gov/all/20011209152223/http..
    c = awk.split(url, a, "/")            # http://wayback.archive-it.org/all/20130420084626/http..
    for i in 0..c - 1:
      if not empty(a[i]):
        if a[i] ~ "^[Aa][Ll][Ll]$" and i != high(a):
          if a[i + 1] ~ "^[0-9*?]+$":
            return a[i + 1]
        if a[i] ~ "^[0-9*?]+$":   
          return a[i] 

                                          # http://arquivo.pt/wayback/20091007194454/http..
                                          # http://arquivo.pt/wayback/wayback/20091007194454/http..
                                          # http://wayback.vefsafn.is/wayback/20071211000000/www.
                                          # http://www.padi.cat:8080/wayback/20140404212712/http
                                          # http://nukrobi2.nuk.uni-lj.si:8080/wayback/20160203130917/http
                                          # https://digital.library.yorku.ca/wayback/20160129214328/http
                                          # http://webarchive.bac-lac.gc.ca:8080/wayback/20080116045132/http
  if isporto(url) or isvefsafn(url) or iscatalon(url) or isslovene(url) or isyork(url) or islac(url):     
    c = awk.split(url, a, "/")            
    for i in 0..c - 1:                   
      if not empty(a[i]):
        if a[i] ~ "^[Ww][Aa][Yy][Bb][Aa][Cc][Kk]$" and i != high(a):
          if a[i + 1] ~ "^[Ww][Aa][Yy][Bb][Aa][Cc][Kk]$" and i + 1 != high(a):
            if a[i + 2] ~ "^[0-9*?]+$":
              return a[i + 2]
          else:
            if a[i + 1] ~ "^[0-9*?]+$":
              return a[i + 1]
        if a[i] ~ "^[0-9*?]+$":   
          return a[i] 

                                          # http://collections.internetmemory.org/nli/20160525150342/http
  if iseuropa(url) or ismemory(url):      # http://collection.europarchive.org/nli/20160525150342/http
    c = awk.split(url, a, "/")           
    for i in 0..c - 1:
      if not empty(a[i]):
        if a[i] ~ "^[Nn][Ll][Ii]$" and i != high(a):   
          if a[i + 1] ~ "^[0-9*]+$": 
            return a[i + 1] 
    
  if ispermacc(url):                      # http://perma-archives.cc/warc/20140729143852/http
    c = awk.split(url, a, "/")           
    for i in 0..c - 1:
      if not empty(a[i]):
        if a[i] ~ "^[Ww][Aa][Rr][Cc]$" and i != high(a):  
          if a[i + 1] ~ "^[0-9*]+$": 
            return a[i + 1] 
    
                                         # http://www.collectionscanada.gc.ca/webarchives/20060209004933/http
                                         # http://www.collectionscanada.gc.ca/archivesweb/20060209004933/http
  if iscanada(url):                      
    c = awk.split(url, a, "/")           
    for i in 0..c - 1:
      if not empty(a[i]):
        if a[i] ~ "^[Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss]$|^[Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss][Ww][Ee][Bb]$" and i != high(a):  
          if a[i + 1] ~ "^[0-9*]+$": 
            return a[i + 1] 
    
                                         # http://www.webarchive.org.uk/wayback/archive/20110324230020/http
  if isukweb(url):
    c = awk.split(url, a, "/")
    if len(a) > 5:
      if a[3] ~ "^[Ww][Aa][Yy][Bb][Aa][Cc][Kk]$":
        if a[4] ~ "^[Aa][Rr][Cc][Hh][Ii][Vv][Ee]$":
          if a[5] ~ "^[0-9*]+$":
            return a[5]  
   
                                         # http://eresources.nlb.gov.sg/webarchives/wayback/20100708034526/http
  if issingapore(url):
    c = awk.split(url, a, "/")
    if len(a) > 5:
      if a[3] ~ "^[Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss]$":
        if a[4] ~ "^[Ww][Aa][Yy][Bb][Aa][Cc][Kk]$":
          if a[5] ~ "^[0-9*]+$":
            return a[5]  
   
  return "" 

  # newwebarchives

#
# Given an archive.org URL, return the date stamp portion no matter what it contains even bad data
#
proc urltimestamp2*(url: string): string =

  var safe = url
  gsub("^[Hh][Tt][Tt][Pp][Ss]?[:]//" & GX.iahre & "[.]?", "", safe)
  if safe ~ "^[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg]":
    gsub("^[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg]/?[Ww]?[Ee]?[Bb]?/","",safe)
    if awk.split(safe,a,"/") > 0:
      return a[0]
  return ""


#
# Given a 8 to 14-char datestamp, return true if the dates and times are within normal ranges
#
proc validate_datestamp(stamp: string): bool =

  var 
    vyear, vmonth, vday, vhour, vmin, vsec = ""
    stamp = stamp

  if not isanumber(stamp):
    return false

  if len(stamp) == 8:
    stamp = stamp & "010101"

  if len(stamp) == 14:
  
    vyear = system.substr(stamp, 0, 3)
    vmonth = system.substr(stamp, 4, 5)
    vday = system.substr(stamp, 6, 7)
    vhour = system.substr(stamp, 8, 9)
    vmin = system.substr(stamp, 10, 11)
    vsec = system.substr(stamp, 12, 13)

    if vyear !~ "^(19[0-9]{2}|20[0-9]{2})$": return false
    if vmonth !~ "^(0[1-9]|1[012])$": return false
    if vday !~ "^(0[1-9]|1[0-9]|2[0-9]|3[01])$": return false
    if vhour !~ "^(0[0-9]|1[0-9]|2[0123])$": return false
    if vmin !~ "^(0[0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9])$": return false
    if vsec !~ "^(0[0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9])$": return false

    # If snapshot year is > current year
    if awk.split(todaysdate(), t, " ")  > 0: # "March 2016"
      if vyear > t[1]: 
        return false
    
  else: 
    return false

  return true

#
# Given a 3-word date (eg. "23 March 2016") verify it is three words and last is a 4-digit number
#
proc verifydate(s: string): bool =

  var
    c = 0

  c = awk.split(s, a, " ")
  if c == 3:
    if a[2] ~ "[0-9]{4}":
      return true

  return false

#
# Given a date string ("June 5, 2016", "5 April 1999", "2016-01-01")        
#  return "dmy", "mdy", "iso" or "ymd"
#  This is a simple proc and may give unexpected results with abnormal input
#  On error, return ""
#
proc dateformat*(s: string): string =

  var
    f, t = 0

  if awk.split(s, a, "-") == 3:
    if isanumber(a[0]):
      f = parseInt(strip(a[0]))
    if f > 1800 and f < 2200 and isanumber(a[1]) and isanumber(a[2]):    
      return "iso"
    else:
      return ""

  if awk.split(s, a, " ") == 3:    
    if isanumber(a[2]):
      t = parseInt(strip(a[2]))
      if t > 1800 and t < 2200:
        if isanumber(a[0]):
          return "dmy"
        else:         
          return "mdy"
      else:      
        if isanumber(a[0]):
          f = parseInt(strip(a[0]))
          if f > 1800 and f < 2200:
            return "ymd"

  return ""          

#
# Convert from mdy->dmy or dmy->mdy
#
# s = source string
# t = target (dmy or mdy)
#
proc redateformat*(s, t: string): string =

  var s = s

  if s == "" or t == "":
    return ""

  if dateformat(s) == "dmy" and t == "mdy":
    if awk.split(s, a, " ") == 3:
      return a[1] & " " & a[0] & ", " & a[2]

  if dateformat(s) == "mdy" and t == "dmy":
    s = replace(s, ",", "")
    if awk.split(s, a, " ") == 3:
      return a[1] & " " & a[0] & " " & a[2]
      
  return s

#
# Given a date, return "numeric", "alphanumeric", "none" 
#   if it's "2016-01-01" or "1 January 2016" 
#
proc isnumericdate(s: string): string =

  var 
    c = 0
    d = ""  

  c = awk.split(s, a, "-")

  if c == 3:
    if len(a[0]) == 4 and len(a[1]) == 2 and len(a[2]) == 2:
      return "numeric"

  d = dateformat(s)
  if d ~ "dmy|mdy":
    return "alphanumeric"
 
  return "none"

#
# Given a 14-digit timestamp, return a date in format YYYY-MM-DD
#
proc timestamp2numericdate(s: string): string =

  var 
    vyear, vmonth, vday, date = ""

  if validate_datestamp(s):
    vyear = system.substr(s, 0, 3)
    vmonth = system.substr(s, 4, 5)
    vday = system.substr(s, 6, 7)

    date = vyear & "-" & vmonth & "-" & vday
    return date

  return s

#
# Remove old comments, left by other bots
#
#
proc cleanoldcomments(tl: string): string = 

  var
    safe = tl

  awk.gsub("[<][!]" & GX.space & "[-][-]" & GX.space & "[Dd][Aa][Ss][Hh][Bb][Oo][Tt]" & GX.space & "[-][-]" & GX.space & "[>]", "", safe)
  awk.gsub("[<][!]" & GX.space & "[-][-]" & GX.space & "[Aa]dde?d? by [Dd][Aa][Ss][Hh][Bb][Oo][Tt]" & GX.space & "[-][-]" & GX.space & "[>]", "", safe)
  awk.gsub("[<][!]" & GX.space & "[-][-]" & GX.space & "[Bb]ot [Rr]etrieved [Aa]rchive" & GX.space & "[-][-]" & GX.space & "[>]", "", safe)
  awk.gsub("[<][!]" & GX.space & "[-][-]" & GX.space & "[Aa]?d?d?e?d?[ ]{0,}b?y?[ ]{0,}[Hh][3e]ll[Bb]ot" & GX.space & "[-][-]" & GX.space & "[>]", "", safe)

  return safe

#
# Given an alternative archive website url (eg. webcite.org etc) as it exists in WayLink[].altarchencoded 
#  return the field value designated by "field" argument
#
proc altarchfield(url, field: string): string =
  for link in WayLink:
    if countsubstring(urldecode(link.altarchencoded), urldecode(url)) > 0:
      return fieldvalLO(link, field)
    if countsubstring(urldecode(link.altarch), urldecode(url)) > 0:
      return fieldvalLO(link, field)
  return ""

#
# Given a url, return its archival service name in wikisource markup.
#
proc servicename*(url: string): string =

  var oout = "(Unknown)<!--bot generated title-->"
  var safe = url
  gsub("^[Hh][Tt][Tt][Pp][Ss]?[:]//","",safe)

  if match(safe,"archive[.]today") > 0:
    oout = "[[Archive.is]]"

  elif match(safe,"archive[.]is") > 0:
    oout = "[[Archive.is]]"

  elif match(safe,"archive[.]org") > 0:
    oout = "[[Internet Archive]]"

  elif match(safe,"archive[-]it") > 0:
    oout = "[[Archive-It]]"

  elif match(safe,"bibalex[.]org") > 0:
    oout = "[[Bibliotheca_Alexandrina#Internet_Archive_partnership|Bibliotheca Alexandrina]]"

  elif match(safe,"collectionscanada") > 0:
    oout = "Canadian Government Web Archive"

  elif match(safe,"haw[.]nsk") > 0:
    oout = "the Croatian Web Archive (HAW)"

  elif match(safe,"nlib[.]ee") > 0:
    oout = "the Estonian Web Archive"

  # http://wayback.vefsafn.is/wayback/20100301195609/http://www.washingtonpost.com/ac2/wp-dyn/A62618-2002Apr16
  elif match(safe,"vefsafn[.]is") > 0:
    oout = "the Icelandic Web Archive"

  elif match(safe,"loc[.]gov") > 0:
    oout = "the [[Library of Congress]]"

  elif match(safe,"webharvest[.]gov") > 0:
    oout = "the [[National Archives and Records Administration]]"

  elif match(safe,"arquivo[.]pt") > 0:
    oout = "the [[Portugese Web Archive]]"

  elif match(safe,"proni[.]gov") > 0:
    oout = "the [[Public Record Office of Northern Ireland]]"

  elif match(safe,"uni[-]lj[.]si") > 0:
    oout = "the Slovenian Web Archive"

  elif match(safe,"stanford[.]edu") > 0:
    oout = "the [[Stanford University Libraries|Stanford Web Archive]]"

  elif match(safe,"nationalarchives[.]gov[.]uk") > 0:
    oout = "the [[UK Government Web Archive]]"

  elif match(safe,"parliament[.]uk") > 0:
    oout = "the UK Parliament's Web Archive"

  # https://www.webarchive.org.uk/wayback/archive/20080915222226/http://www.metric.org.uk/Press/Articles.aspx?ID=7
  elif match(safe,"webarchive[.]org[.]uk") > 0:
    oout = "the UK Web Archive"

  elif match(safe,"nlb[.]gov[.]sg") > 0:
    oout = "Web Archive Singapore"

  elif match(safe,"webcitation[.]org") > 0:
    oout = "[[WebCite]]"

  elif match(safe,"yorku[.]ca") > 0:
    oout = "[[York University Libraries|York University Digital Library]]"

  elif match(safe,"internetmemory[.]org") > 0:
    oout = "[[Internet Memory Foundation]]"

  elif match(safe,"webarchive[.]bac[-]lac[.]gc[.]ca") > 0:
    oout = "[[Library and Archives Canada]]"

  if oout ~ "Unknown":
    sendlog(Project.servicename, CL.name, url)

  return oout

  # newwebarchives

#
# Build a cite web template given url (required), date (optional)
#
proc buildciteweb*(url: string, title: varargs[string]): string =

  var ntitle = ""

  if len(title) == 0:
    ntitle = "|title=Unknown"
  else:
    if title[0] == nil:
      ntitle = "|title=Unknown"
    else:
      ntitle = "|title=" & title[0]

  return "{{cite web |url=" & url & " " & ntitle & " |dead-url=yes |access-date=" & todaysdatefull() & "}}"


#
# Given a date in YYYY-MM-DD , return in format (mdy,dmy,iso) condition
# return "" on error
#
proc date2format(dateinput, format: string): string =

  var
    newdate = ""
    dateinput = dateinput

  if len(dateinput) < 8:
    return ""
  gsub("[-]","",dateinput)
  if len(dateinput) != 8:
    return ""

  var parseddate = parse(dateinput, "yyyyMMdd") # Check for invalid data 
  if $parseddate ~ "[?][?][?]" or len($parseddate) == 0:
    return ""

  if format == "iso":
    newdate = format(parse(dateinput, "yyyyMMdd"), "yyyy-MM-dd")
  elif format == "mdy":
    newdate = format(parse(dateinput, "yyyyMMdd"), "MMMM d, yyyy")
  elif format == "dmy":
    newdate = format(parse(dateinput, "yyyyMMdd"), "d MMMM yyyy")
  else:
    if GX.datetype == "dmy":
      newdate = format(parse(dateinput, "yyyyMMdd"), "d MMMM yyyy")
    else:
      newdate = format(parse(dateinput, "yyyyMMdd"), "MMMM d, yyyy")

  if not empty(newdate):
    return newdate
  else:
    return ""
  return ""

#
# Helper function for other functions
#
proc datehelper(dateinput, olddate: string): string =

  var 
    newdate = ""

  if dateinput !~ "^[0-9]{8}$":
    return olddate

  var parseddate = parse(dateinput, "yyyyMMdd") # Check for invalid data 
  if $parseddate ~ "[?][?][?]" or len($parseddate) == 0:
    return olddate

  if dateformat(olddate) == "iso":
    newdate = format(parse(dateinput, "yyyyMMdd"), "yyyy-MM-dd")
  elif dateformat(olddate) == "mdy":
    newdate = format(parse(dateinput, "yyyyMMdd"), "MMMM d, yyyy")
  elif dateformat(olddate) == "dmy":
    newdate = format(parse(dateinput, "yyyyMMdd"), "d MMMM yyyy")
  else:
    if GX.datetype == "dmy":
      newdate = format(parse(dateinput, "yyyyMMdd"), "d MMMM yyyy")
    else:
      newdate = format(parse(dateinput, "yyyyMMdd"), "MMMM d, yyyy")

  if not empty(newdate):
    return newdate
  else:
    return olddate

  return olddate

#
# Given a timestamp (dateinput) and date it will be replacing (olddate), return date in Datetype format (dmy or mdy) if set, or same format as olddate
#
proc timestamp2date(dateinput, olddate: string): string =

  var
    dateinput = dateinput

  if not validate_datestamp(dateinput):
    return olddate

  if len(dateinput) > 8:
    dateinput = strip(substr(dateinput, 0, 7))
  elif len(dateinput) < 8:
    return "error"

  return datehelper(dateinput, olddate)

#
# Given a webcite URL, return the ID portion
#  "nobase62" if no base62 ID available 
#  "error" on error
#
proc webciteid(url: string): string = 

  var
    code = ""
    c = awk.split(url, a, "/")

  if c > 3:
    
    if a[3] ~ "[?]":
      awk.split(a[3], b, "[?]")
      code = b[0]
    else:
      code = a[3]    

    # valid URL formats that are not base62

    #  http://www.webcitation.org/query?id=1138911916587475
    #  http://www.webcitation.org/query?url=http..&date=2012-06-01+21:40:03
    #  http://www.webcitation.org/1138911916587475
    #  http://www.webcitation.org/cache/73e53dd1f16cf8c5da298418d2a6e452870cf50e
    #  http://www.webcitation.org/getfile.php?fileid=1c46e791d68e89e12d0c2532cc3cf629b8bc8c8e

    if code ~ "(?i)(^query|^cache|^[0-9]{8,20}|^getfile)":
      return "nobase62"
    elif not empty(code):
      return code

  return "error"

#
# Given a Freezepage URL return snapshot date obtained by web scrape in format "iso", "dmy", etc..
#
proc freezedate(url, format: string): string =

  # as of 16-Oct-2016 1

  var
    head, bodyfilename, fp = ""

  (head, bodyfilename) = getheadbody(url, "one")  # scrape body
  fp = readfile(bodyfilename)
  if awk.match(fp, "as of [0-9]{1,2}[-][A-Za-z]{3,9}[-][0-9]{4}", dest) > 0:
    gsub("^as of ", "", dest)
    awk.split(dest, a, "[-]")
    var o = date2format(a[2] & "-" & month2digit(a[1]) & "-" & zeropad(a[0]), format)
    if not empty(o):
      return o

  return "error"

#
# Given a NLA Australia URL, return a date in format modeled on date in datemodel
#
proc nlaautodate(url, datemodel: string): string =

    var
      hold = ""
      datemodel = datemodel

    #   http://pandora.nla.gov.au/pan/14231/20120727-0512/www.howlspace.com.au/en2/inxs/inxs.htm
    if awk.match(url, "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Pp][Aa][Nn][Dd][Oo][Rr][Aa][.][Nn][Ll][Aa][.][Gg][Oo][Vv][.][Aa][Uu][/][Pp][Aa][Nn][/][0-9]{4,7}[/][0-9]{8}[-][0-9]{4}[/]", dest) > 0:
      if awk.split(dest, a, "/") > 5:
        if awk.split(a[5], b, "[-]") > 0:
          hold = b[0]

    #   http://pandora.nla.gov.au/nph-wb/20010328130000/http://www.howlspace.com.au/en2/arenatina/arenatina.htm
    elif awk.match(url, "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Pp][Aa][Nn][Dd][Oo][Rr][Aa][.][Nn][Ll][Aa][.][Gg][Oo][Vv][.][Aa][Uu][/][Nn][Pp][Hh][-][Ww][Bb][/][0-9]{8,14}[/]", dest) > 0:
      if awk.split(dest, a, "/") > 4:
        hold = a[4]

    #   http://pandora.nla.gov.au/nph-arch/2000/S2000-Dec-5/http://www.paralympic.org.au/athletes/athleteprofile60da.html
    elif awk.match(url, "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Pp][Aa][Nn][Dd][Oo][Rr][Aa][.][Nn][Ll][Aa][.][Gg][Oo][Vv][.][Aa][Uu][/][Nn][Pp][Hh][-][Aa][Rr][Cc][Hh][/][0-9]{4}[/][A-Z][0-9]{4}[-][A-Z][a-z]{2}[-][0-9]{1,2}[/]", dest) > 0:
      if awk.split(dest, a, "/") > 5:
        if awk.split(a[5], b, "[-]") > 0:
          gsub("^[A-Z]", "", b[0])
          hold = b[0] & month2digit(b[1]) & zeropad(b[2])

    #   http://webarchive.nla.gov.au/gov/20120326012340/http://news.defence.gov.au/2011/09/09/army-airborne-insertion-capability/
    elif awk.match(url, "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Nn][Ll][Aa][.][Gg][Oo][Vv][.][Aa][Uu][/][Gg][Oo][Vv][/][0-9]{8,14}[/]", dest) > 0:
      if awk.split(dest, a, "/") > 4:
        hold = a[4]

    #   http://content.webarchive.nla.gov.au/gov/wayback/20120326012340/http://news.defence.gov.au/2011/09/09/army-airborne-insertion-capability
    elif awk.match(url, "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Cc][Oo][Nn][Tt][Ee][Nn][Tt][.][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Nn][Ll][Aa][.][Gg][Oo][Vv][.][Aa][Uu][/][Gg][Oo][Vv][/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][0-9]{8,14}[/]", dest) > 0:
      if awk.split(dest, a, "/") > 5:
        hold = a[5]

    if not empty(hold):
      if len(hold) > 8:
        hold = strip(substr(hold, 0, 7))
      elif len(hold) < 8:
        return "error"
      if empty(datemodel):
        datemodel = "1970-01-01"

      var dh = datehelper(hold, datemodel)
      return dh

    return "error"

#
# Given a Webcite URL, return a date in "dmy|mdy|iso" format
#  http://www.webcitation.org/64wvKQAc8?url=http.. == 2012-01-25
#  return "error" if trouble
#  return "nobase62" if URL doesn't contain a base 62 (see notes below)
#
proc base62todate(url, format: string): string =

  var 
    code = webciteid(url)
  
  if code == "nobase62":
    return "nobase62"

  if code != "error":

    let cmd = GX.base62 & " " & shquote(code)    # base62.lua
    let (outp, errC) = execCmdEx(cmd)
    if errC == 0:
      if awk.split(outp, d, "[|]") >= 3:
        if format == "mdy":
          if not empty(d[0]):
            return d[0]
        elif format == "dmy":
          if not empty(d[1]):
            return d[1]
        elif format == "iso":
          if not empty(d[2]):
            return d[2]
        else:
          if not empty(d[0]):
            return d[0]

  return "error"


#
# Given an archive url and archivedate return its datestamp in Datetype format (dmy or mdy), 
#   or ymd if that is the current format in archivedate. 
#  Otherwise, return curdate or "error" 
#  eg. 20080101 -> January 1, 2008 (if global Datetype=mdy)
#
proc urldate(url, archivedate, ccurdate: string): string =

  var 
    dateinput, tstamp, isodate = ""
    curdate = ccurdate
    archivedate = archivedate

  if archivedate == nil:
    return "error"
  if curdate == nil or curdate == "": 
    curdate = "error"
  if url == nil or url == "": 
    return curdate
  if archivedate ~ "[{][{]":  # skip embedded templates
    sendlog(Project.syslog, CL.name, url & "----" & archivedate & "---- embedded template urldate()")
    return "error"

  # URLs with 14-digit timestamps
  if isarchive(url, "sub3"):

    tstamp = urltimestamp(url)

    if not validate_datestamp(tstamp):
      if dummydate(tstamp, "1899"):
        return "1899-01-01"
      return curdate

    if not empty(tstamp):
      dateinput = strip(substr(tstamp, 0, 3) & substr(tstamp, 4, 5) & substr(tstamp, 6, 7))
      var dh = datehelper(dateinput, archivedate)
      if dh == archivedate:
        return curdate # some kind of error
      else:
        return dh

  if isnlaau(url):

    isodate = nlaautodate(url, archivedate)
    if isodate == "error":
      return curdate
    else:
      return isodate

  if isfreezepage(url):

    if empty(archivedate):
      archivedate = "1971-01-01"
    isodate = freezedate(url, dateformat(archivedate))
    if isodate == "error":
      return curdate
    else:
      return isodate

  if iswebcite(url):

    if empty(archivedate):
      archivedate = "1971-01-01"
    isodate = base62todate(url, dateformat(archivedate))

    if isodate == "error":
      return curdate
    elif isodate == "nobase62":
      #  http://www.webcitation.org/query?url=http..&date=2012-06-01+21:40:03
      if url ~ "date[=]" and url ~ "url[=]":
        if match(url, "date[=][^&$]*[^&$]?", dest) > 0:
          gsub("^date[=]","",dest)
          if awk.split(dest, a, "[+]") == 2:
            dest = a[0]
          if dest ~ "[0-9]{4}[-]?[0-9]{2}[-]?[0-9]{2}":
            gsub("[-]","",dest)
            var dh = datehelper(dest, archivedate)
            if dh == archivedate:
              return curdate # some kind of error
            else:
              return dh
    else:
      return isodate
        

  return curdate

  # newwebarchives

#
# Remove substring defined by 'start' and 'end' in string 'source'
#  . Returns the new string
#  . If error return full original 'source'
#
proc removesection*(source: string, s, e: int, caller: string): string =

  var debug = false
  if caller ~ "none":
    debug = true

  if debug:
    "removesection (s): " & $s >* "/dev/stderr"
    "removesection (e): " & $e >* "/dev/stderr"

  if empty(source) or e == 0 or s >= high(source):
    if debug: 
      "removesection: numbers wrong: " & $source.len & " " & $e & " " & $s >* "/dev/stderr"
    return source                  
  var newsource = source
  var final = ""        
  for i in 0..high(source):         
    if i < s or i > e :
      add(final, newsource[i])   
  if not empty(final):
    if debug:
      if final.len > 1000: 
        "removesection (final): <too big to display>" >* "/dev/stderr"
      else:
        "removesection (final): " & final >* "/dev/stderr"
    return final                 
  else:
    if debug: "removesection (abort) early" >* "/dev/stderr"
    return source

  return ""

#
# Insert 'new' string in 'source' at character location 'start' (w/ special rules for spaces customized for Wikipedia templates and external links)
#
proc insertsection*(source: string, start: int, new, caller: string): string =

  var debug = false
  if caller ~ "none":
    debug = true

  if debug: 
    "insertsection (source length): " & $source.len  >* "/dev/stderr"
    if source.len < 1000: 
      "insertsection (source value): |" & source & "|"  >* "/dev/stderr"
    else:
      "insertsection (source value): too big for display (whole article?)" >* "/dev/stderr"
    "insertsection (new length): " & $new.len  >* "/dev/stderr"
    if new.len < 1000: 
      "insertsection (new value): |" & new & "|"  >* "/dev/stderr"
    else:
      "insertsection (new value): too big for display (whole article?)" >* "/dev/stderr"
    "insertsection (start): " & $start  >* "/dev/stderr"
   
  if empty(source):                                 
    if debug: "insertsection (source is zero)"  >* "/dev/stderr"
    return new

  if empty(new):                                     
    if debug: "insertsection (new is zero)"  >* "/dev/stderr"
    return source

  if start > high(source):                               # Append to end of source if start is > length of source.
    if source[high(source)] == ' ':
      if debug: "insertsection (trap 1)"  >* "/dev/stderr"
      return source & new
    else:
      if debug: "insertsection (trap 2)"  >* "/dev/stderr"
      if source != "***!!***":      # special case: when source starts on a newline don't prepend a space 
        return source & " " & new
      else:
        return source & new

  var build = source

  for i in 0..high(source):

    if i == start:
      if debug: "insertsection (trap 3)"  >* "/dev/stderr"
                                                            # Append space if "start" is | or }, and preceeding is not a space
      if system.substr(source,i,i) ~ "[|]|[}]":
        if i > 0:
          if source[i - 1] != ' ':
            if debug: "insertsection (case 1)" >* "/dev/stderr"
            insert(build, new & " ", i)
          else:
            if debug: "insertsection (case 4)" >* "/dev/stderr"
            insert(build, new, i)
        else:
          insert(build, new, i)
          if debug: "insertsection (case 3)"  >* "/dev/stderr"

      else:
        insert(build, new, i)
        if debug: 
          "insertsection (case 2)"  >* "/dev/stderr"
          "insertsection (start) = " & $start >* "/dev/stderr"
          if source.len > 1000:
            "insertsection (source5) = <too big to display>" >* "/dev/stderr"
          else:
            "insertsection (source5) = " & source >* "/dev/stderr"

  return build

#
# In 'source' string, replace 'old' text with 'new' text (via non-regex)
#
proc replacetext*(source, old, new, caller: string): string =

  var debug = false
  if caller ~ "none":
    debug = true

  if debug: 
    "Caller: " & caller >* "/dev/stderr"
    "Source:" >* "/dev/stderr"
    if source.len > 5000:
      "<source too big to display>" >* "/dev/stderr"
    else:
      source >* "/dev/stderr"
    "Old:" >* "/dev/stderr"
    old >* "/dev/stderr"
    "New:"  >* "/dev/stderr"
    new >* "/dev/stderr"

  if empty(source) or empty(old):
    if debug:
      var msg = "Replacetext(1): Aborted: found " & $len(source) & " " & $len(old)                            
      msg >* "/dev/stderr"
    return source

  var source = source
  var old = old
  var new = new

  source = replace(source, "\n", "***!!***")         # For multi-line templates.. collapse newlines
  old = replace(old, "\n", "***!!***")

  var c = countsubstring(source, old)

  if c != 1:    # found 0 (or >1) instances of 'old' in 'source'

    if c > 1:                                        # Multiple-replace for certain caller types
      if caller ~ "^processoutside|^webarchiveoutside|^bareinside|^webarchiveinside|^waybackinside|^citeinside|^replacefullref2|^fixbadstatusbare1[.]1":
        source = replace(source, old, new)
        gsub("[*][*][*][!][!][*][*][*]", "\n", source)
        gsub("[*][*][*][!][!][*][*][*]", "\n", old)
        if debug:
          ("Replacetext(2): Found " & $c & " copy(s) of string (" & old & ") in source") >* "/dev/stderr"
        return source
      else:
        gsub("[*][*][*][!][!][*][*][*]", "\n", source)
        gsub("[*][*][*][!][!][*][*][*]", "\n", old)
        sendlog(Project.syslog, CL.name & " ---- error in gsub (" & caller & ") ---- " & old, new)

    if debug:
      echo "|" & old & "| is " & $old.len & " chars long."
      var msg = "Replacetext(2): Aborted: found " & intToStr(c) & " copy(s) of string (" & old & ") in source"
      msg >* "/dev/stderr"
    gsub("[*][*][*][!][!][*][*][*]", "\n", source)   # For multi-line templates.. restore newlines 
    return source

  var safe = source
  var inx = index(safe, old)
  if debug: "Index = " & $inx  >* "/dev/stderr"
  if inx == 0 and len(old) == len(safe):
    safe = ""
  else:
    safe = removesection(safe, inx, len(old) + inx - 1, caller)
  if debug: 
    "Post-remove (start block): " >* "/dev/stderr" 
    if safe.len > 1000:
      "<too big to display>" >* "/dev/stderr"
    else:
      safe >* "/dev/stderr"
    "Post-remove (end block): " >* "/dev/stderr" 
  safe = insertsection(safe, inx, new, caller)
  if debug: 
    "Post-insert (start block): " >* "/dev/stderr" 
    if safe.len > 1000:
      "<too big to display>" >* "/dev/stderr"
    else:
      safe >* "/dev/stderr"    
    "Post-insert (end block): " >* "/dev/stderr" 

  gsub("[*][*][*][!][!][*][*][*]", "\n", safe)       # For multi-line templates.. restore newlines

  return safe

#
# Return true if string contains a citation type to ignore
#
proc citeignore*(s: string): bool = 
  if s ~ "(?i)(cite ietf[ ]?[|])":
    return true
  return false

#
# Return true if url is to ignore/skip 
#
proc urlignore*(url: string): bool =
  if url ~ "(?i)[h][t][t][p][s]?[:][/][/]www[.]archive[.]org[/][0-9]{1,3}[/]items[/]":
    return true
  return false

#
# Return true if ref (or string) contains {{cbignore}} template.
#  If bot=medic return false
#  Does not look outside <ref></ref> pair
#
proc cbignore*(s: string): bool =
  if toLowerAscii(s) !~ "cbignore":
    return false
  if match(s, GX.cbignore, t) > 0:
    if t ~ "medic":
      return false
  return true

#
# Return true if same "\n" separarted line in article matching "lk" contains {{cbignore}} template.
#  If bot=medic return false
#  Does not look beyond the line break after lk
#  Handles multi-line templates OK so long as {{cbignore}} is on the same line as the last part of the template.
#  If > 1 match on lk then return false as we can't know which lk is being referenced.
#
proc cbignorebareline*(article, lk: string): bool =

  var
    field, sep = newSeq[string](0)
    c = 0

  c = patsplit(article, field, escapeRe(lk), sep)
  if c == 1:
    if awk.split(sep[1], a, "\n") > 0:
      if tolowerAscii(a[0]) !~ "cbignore":
        return false
      if match(a[0], GX.cbignore, t) > 0:
        if t ~ "medic":
          return false
      else:
        return false
    else:
      return false
  else:
    return false
  return true
    
#
# Return true if same "\n" separarted line in article matching "lk" contains {{dead link}} template.
#  Does not look beyond the line break after lk
#  Handles multi-line templates OK so long as {{dead}} is on the same line as the last part of the template.
#  If > 1 match on lk then return false as we can't know which lk is being referenced.
#
proc deadlinkbareline*(article, lk: string): bool =

  var
    field, sep = newSeq[string](0)
    c = 0

  c = patsplit(article, field, escapeRe(lk), sep)
  if c == 1:
    if awk.split(sep[1], a, "\n") > 0:
      if a[0] ~ GX.dead:
        return true

  return false
    
#
# Count number of dead links of this form:
#
# {{dead link|date=March 2018 |bot=InternetArchiveBot |fix-attempted=yes }}
#
# Note that "InternetArchiveBot" and "March 2018" are variable
#
proc deadcount*(): int =

  var
    field, sep = newSeq[string](0)
    c,count = 0

  c = patsplit(GX.articlework, field, GX.dead, sep)
  for i in 0..c - 1:
    if contains(field[i], "fix-attempted=yes"):
      inc(count)

  return count

#
# Given an External link in format [http://yahoo.com Yahoo] .. return the bare URL eg. http://yahoo.com
#  
proc stripfullel*(fullel: string): string =

  var
    tl = ""

  tl = strip(substr(fullel, 1, high(fullel) - 1) )  # Remove "[]"
  gsub("[\\t|\\n]"," ",tl)
  tl = stripwikicomments(tl)
  if awk.split(tl, a, " ") > 0:                         # Remove extlnk description string
    tl = a[0]            
    return tl

  return tl



#
# Format a non-IA URL into a regular format
# 
proc formatedorigurl*(url: string): string =

  var
    url = url   
    scheme = ""

  if url ~ "^none":
    return "none"

  var safe = strip(url)

  if len(safe) < 3:
    return url

  if safe ~ "(?i)(https?%3a)":  
    safe = urldecode(safe)
  if safe ~ "(?i)(https?[:]%2f)":  
    safe = urldecode(safe)

  if safe ~ "^[Hh][Tt][Tt][Pp][Ss]?[:]//":
    return safe        

  elif safe ~ "^//":         
    return "http:" & safe      

  else:

    scheme = uriparseElement(safe, "scheme")
    if not empty(strip(scheme)):
      return safe
    if noprotocol(safe):
      return "http://" & safe  # Assume the best..

  return url

#
# Given two non-archive URLs, determine if they are the same negating for encoding, https, capitalization, "www.", and port 80 differences
#
proc urlequal*(urlsource, wurlsource: string): bool =

        var
          urlsource = urlsource
          wurlsource = wurlsource

        if empty(urlsource) or empty(wurlsource):
          return false

        if not isarchive(urlsource, "all"):
          urlsource = formatedorigurl(urlsource)
        if not isarchive(wurlsource, "all"):
          wurlsource = formatedorigurl(wurlsource)

        gsub("[%]20|[ ]","%2B",urlsource)
        gsub("[%]20|[ ]","%2B",wurlsource)

        gsub("([%][a-z A-Z 0-9][a-z A-Z 0-9])$", "", urlsource)
        gsub("([%][a-z A-Z 0-9][a-z A-Z 0-9])$", "", wurlsource)

        urlsource = urldecode(urlsource)
        wurlsource = urldecode(wurlsource)

       # get rid of fragments..
        if match(urlsource, "[#][^$]*[^$]?", dest1) > 0:
          gsubs(dest1, "", urlsource)
        if match(wurlsource, "[#][^$]*[^$]?", dest2) > 0:
          gsubs(dest2, "", wurlsource)

       # remove trailing garbage
        gsub("([.]|[,]|[-]|[:]|[;])$", "", urlsource)
        gsub("([.]|[,]|[-]|[:]|[;])$", "", wurlsource)

        gsub("/$", "", urlsource)             
        gsub("/$", "", wurlsource)         

        gsub("^[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ww][Ww][.]", "http://", urlsource) 
        gsub("^[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ww][Ww][.]", "http://", wurlsource) 

        urlsource = tolowerAscii(removeport80(urlsource))
        wurlsource = tolowerAscii(removeport80(wurlsource))

        gsub("^[Hh][Tt][Tt][Pp][Ss]?", "http", urlsource)
        gsub("^[Hh][Tt][Tt][Pp][Ss]?", "http", wurlsource)

        if urlsource ~ "^ftp" and wurlsource ~ "^http":
          gsub("^ftp", "http", urlsource)
        elif wurlsource ~ "^ftp" and urlsource ~ "^http":
          gsub("^ftp", "http", wurlsource)

       # Check if query ? portion is the same even if arguments are in different order
        if match(urlsource, "[?][^$]*[^$]?", dest1) > 0 and match(wurlsource, "[?][^$]*[^$]?", dest2) > 0:
          if dest1 != dest2:
            var d1s = dest1
            var d2s = dest2
            sort(d1s, system.cmp)
            sort(d2s, system.cmp)
            if d1s == d2s:
              gsubs(dest1, "", urlsource)
              gsubs(dest2, "", wurlsource)

        if empty(urlsource) or empty(wurlsource):
          return false

        if wurlsource == urlsource or
           urldecode(wurlsource) == urlsource or
           wurlsource == urldecode(urlsource) or
           urldecode(wurlsource) == urldecode(urlsource):
          return true

        return false


#
# Return 0 if ref is not WP:BUNDELED (ie. more than one cite inside a <ref></ref>)
#  Only works if ref contains "archive-url=" and/or "wayback|" and/or "webarchive|" otherwise return 4
#
proc bundled*(s: string): int =

  var f = awk.split(s, a, "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]{0,1}[Dd][Aa][Tt][Ee]" & GX.space & "[=]")
  if f > 2:
    return 2
  var c = awk.split(s, a, "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]{0,1}[Uu][Rr][Ll]" & GX.space & "[=]")
  if c > 2: 
    return 2
  var d = awk.split(s, a, "[Ww]ayback" & GX.space & "[|]")
  if d > 2: 
    return 3
  var e = awk.split(s, a, "[Ww]eb[Aa]rchive" & GX.space & "[|]")
  if e > 2: 
    return 1

  if (c < 2 and f < 2) and d < 2 and e < 2:
    return 4

  return 0

#               
# Given an archive.org URL or similar archive service that uses 8-14 digit timestamps, 
#  return the original url portion following the timestamp .. if the whole URL was urlencoded then decode it
#  http://archive.org/web/20061009134445/http://timelines.ws/countries/AFGHAN_B_2005.HTML ->
#   http://timelines.ws/countries/AFGHAN_B_2005.HTML
#
proc wayurlurl*(url: string): string =

  var date = urltimestamp(url)
  if not empty(date):
    var inx = index(url, date)
    if inx >= 0:
      var baseurl = removesection(url, 0, inx + len(date), "wayurlurl")
      if baseurl ~ "(?i)(https?%3a)":
        baseurl = urldecode(baseurl)
      if not empty(baseurl) and noprotocol(baseurl):
        return "http://" & baseurl
      elif not empty(baseurl):
        return baseurl
  return url

#
# Given a wayback, webcite, loc, porto etc., return the original url portion if available otherwise return ""
#
proc urlurl*(url: string): string =

  var
    re = ""
    newurl = url

  if isarchive(url, "sub3"):  # services with a timestamp
    return wayurlurl(url)
  elif iswebcite(url):        # services without a determinable timestamp
    re = "^" & GX.wcre
  elif isfreezepage(url):
    re = "^" & GX.freezepagere
  elif isnlaau(url):
    re = "^" & GX.nlaaure

  gsub(re, "", newurl)

  if match(newurl, "[Hh][Tt][Tt][Pp][Ss]?[^\\s]*[^\\s]$", dest) > 0:
    if dest ~ "^[Hh][Tt][Tt][Pp][Ss]?[%]3[Aa]":
      dest = urldecode(dest)
    if iswebcite(url):
      gsub("[&]date[=][^$]*[^$]?", "", dest)  # Remove trailing date from query?url=http.. forms
    return dest

  elif iswebcite(url) or isfreezepage(url):  # try method 2 for example the URL doesn't start with "http"
    if match(newurl, "[Uu][Rr][Ll][=][^\\s]*[^\\s]$", dest) > 0:
      gsub("[Uu][Rr][Ll][=]", "", dest)
      if dest ~ "^[Hh][Tt][Tt][Pp][Ss]?[%]3[Aa]":
        dest = urldecode(dest)
      gsub("[&]date[=][^$]*[^$]?", "", dest)  # Remove trailing date from query?url=http.. forms
      return dest

  elif isnlaau(url) and not empty(newurl):   # filter known non-website URLs
    if newurl ~ "^[Hh][Tt][Tt][Pp][Ss]?[%]3[Aa]":
      newurl = urldecode(newurl)
    if newurl !~ "[.][Pp][Dd][Ff]|[.][Dd][Oo][Cc]|[.][Tt][Xx][Tt]|[Aa]ria[_]?awards?":
      if noprotocol(newurl):
        return "http://" & newurl
      else:
        return newurl

  return url

  # newwebarchives


#
# Given an archive.org URL, if it has doubles+ strip them 
#  eg. http://web/archive.org/2009/http://web/archive.org/2009/http://web/archive.org/2009/http:yahoo.com ->
#      http:yahoo.com
#
proc stripwayurlurl*(url: string): string =

    var
      suburl, newurl = ""

    suburl = wayurlurl(url)
    gsubs("/https%3A","/https:", suburl); gsubs("/http%3A","/http:", suburl)
    while true:
      if wayurlurl(suburl) == suburl:  # guard against endless loop caused by missing suburl value
        break
      if isarchiveorg(suburl):
        gsubs(":80/:80/", ":80/", suburl)
        newurl = wayurlurl(suburl)       
        if not isarchiveorg(newurl):
          return suburl
        suburl = newurl
      else:
        break

    return url


#
# Given a full ref string, replace old string with new string. Also remove duplicate cbignore
#   'caller' is a debugging string.
#   'fl' is optional flag "limited" to update the fullref only and not complete text
#
proc replacefullref*(fullref, old, new, caller: string, fl: varargs[string]): string =

  var 
    origfullref = fullref
    new = new
    newfullref, flag = ""
    c = 0
    field, field2, sep = newSeq[string](0)

  if len(fl) > 0:
    if fl[0] == nil or fl[0] == "":
      flag = ""
    else:
      flag = fl[0]          

 # Remove extra {{cbignore}} .. only if one in ref, and one in new text.. remove the newly added one and keep the original
  c = patsplit(new, field, GX.cbignore, sep)
  if c == 1:
    c = patsplit(fullref, field2, GX.cbignore)
    if c == 1:
      field[0] = ""
      new = unpatsplit(field, sep)
      sendlog(Project.logstraydt, CL.name, " ---- unknown5 --- replacefullref")

  newfullref = replacetext(fullref, old, new, "replacefullref1-" & caller)

 # Remove {{cbignore}} if followed by this type of {{dead link|date=.. |bot=InternetArchiveBot |fix-attempted=yes }}
  c = patsplit(newfullref, field, GX.cbignore, sep)
  for i in 0..len(sep) - 1:
    if match(sep[i], ("^" & GX.dead), dest) > 0:
      if dest ~ "InternetArchiveBot" and dest ~ ("[Ff]ix[-][Aa]ttempted" & GX.space & "[=]" & GX.space & "[Yy][Ee]?[Ss]?"):
        if i > 0:
          field[i-1] = ""
  newfullref = unpatsplit(field, sep)

  if flag == "limited":
    return newfullref
  else:
    return replacetext(GX.articlework, origfullref, newfullref, "replacefullref2-" & caller)

#
# Return true if "tl" is of type "name" (wayback|webarchive|cite|barelink)
#
proc datatype*(tl, name: string): bool =

  var 
    safe = stripwikicomments(tl)
    service = newSeq[string](0)
    re = ""

  if name == "webarchive":
    if safe ~ ("[Ww]ebarchive" & GX.space & "[|]") and safe ~ ("[|]" & GX.space & "[Uu][Rr][Ll][1]{0,1}" & GX.space & "[=]") and safe ~ ("[|]" & GX.space & "[Dd][Aa][Tt][Ee]" & GX.space & "[=]"):
      return true

  if name == "cite":
    if safe ~ ("[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]{0,1}[Uu][Rr][Ll]" & GX.space & "[=]" & GX.space) and safe ~ ("[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]{0,1}[Dd][Aa][Tt][Ee]" & GX.space & "[=]"):
      return true

  if name == "barelink":

    insert(service, GX.iare & "[/][Ww]?[We]?[Bb]?[/]?[0-9]{1,14}[/]", 0)
    insert(service, GX.wcre, 1)
    insert(service, GX.isre, 2)
    insert(service, GX.locgovre, 3)
    insert(service, GX.portore, 4)
    insert(service, GX.stanfordre, 5)
    insert(service, GX.archiveitre, 6)
    insert(service, GX.bibalexre, 7)
    insert(service, GX.natarchivesukre, 8)
    insert(service, GX.vefsafnre, 9)
    insert(service, GX.europare, 10)
    insert(service, GX.permaccre, 11)
    insert(service, GX.pronire, 12)
    insert(service, GX.parliamentre, 13)
    insert(service, GX.ukwebre, 14)
    insert(service, GX.canadare, 15)
    insert(service, GX.catalonre, 16)
    insert(service, GX.singaporere, 17)
    insert(service, GX.slovenere, 18)
    insert(service, GX.freezepagere, 19)
    insert(service, GX.webharvestre, 20)
    insert(service, GX.nlaaure, 21)
    insert(service, GX.wikiwixre, 22)
    insert(service, GX.yorkre, 23)
    insert(service, GX.memoryre, 24)
    insert(service, GX.lacre, 25)

    # newwebarchives

    for i in 0..high(service):
      re = "^" & service[i]
      if safe ~ re:
        return true

  return false


#
# skindeep(url1, url2)
#             
#  Return true if the difference between url1 and 2 is "skin deep"
#  ie. the only diff is https and/or :80 and/or archive.org/web/ and/or web.archive.org .. return 1
#      
proc skindeep*(url1, url2: string): bool =

  var safe1 = url1
  var safe2 = url2

  if GX.ver == "WaybackMedic2":
    return false

  gsub("^[Hh][Tt][Tt][Pp][Ss]","http", safe1)
  gsub("^[Hh][Tt][Tt][Pp][Ss]","http", safe2)
  sub("[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg][/][Ww][Ee][Bb][/]","archive.org/", safe1) 
  sub("[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg][/][Ww][Ee][Bb][/]","archive.org/", safe2) 
  sub(GX.iare, "http://archive.org", safe1)
  sub(GX.iare, "http://archive.org", safe2)

  if countsubstring(removeport80(safe1), removeport80(safe2)) > 0:
    return true

  return false

#
# Print contents of WayLink for debugging
#  If flag="filename" print to filename
#
proc debugarray(tag: int, filename: string): void =

    "  WayLink[" & $tag & "].origiaurl = " & WayLink[tag].origiaurl >> filename
    "  WayLink[" & $tag & "].formated = " & WayLink[tag].formated >> filename
    "  WayLink[" & $tag & "].origurl = " & WayLink[tag].origurl >> filename
    "  WayLink[" & $tag & "].origencoded = " & WayLink[tag].origencoded >> filename
    "  WayLink[" & $tag & "].origdate = " & WayLink[tag].origdate >> filename
    "  WayLink[" & $tag & "].newurl = " & WayLink[tag].newurl >> filename
    "  WayLink[" & $tag & "].newiaurl = " & WayLink[tag].newiaurl >> filename
    "  WayLink[" & $tag & "].altarch = " & WayLink[tag].altarch >> filename
    "  WayLink[" & $tag & "].altarchencoded = " & WayLink[tag].altarchencoded >> filename
    "  WayLink[" & $tag & "].altarchdate = " & WayLink[tag].altarchdate >> filename
    "  WayLink[" & $tag & "].mtag = " & $WayLink[tag].mtag >> filename
    "  WayLink[" & $tag & "].status = " & WayLink[tag].status >> filename
    "  WayLink[" & $tag & "].response = " & $WayLink[tag].response >> filename
    "  WayLink[" & $tag & "].breakpoint = " & WayLink[tag].breakpoint >> filename
    if not empty(WayLink[tag].fragment):
      "  WayLink[" & $tag & "].fragment = " & WayLink[tag].fragment >> filename
    if not empty(WayLink[tag].dummy):
      "  WayLink[" & $tag & "].dummy = " & WayLink[tag].dummy >> filename
    "  WayLink[" & $tag & "].available = " & WayLink[tag].available >> filename
    "--" >> filename        

# proc mktempname*(prefix: string): string =                                           

#
# Given a name, check if it exists in "discovered" file
#
proc isindiscovered(s: string): bool =

  var
    fp, targ = ""
    fpc = 0
    foundit = false
    s = tolowerAscii(strip(s))

  if existsFile(Project.discovered):
    fp = readfile(Project.discovered)
    fpc = awk.split(fp, a, "\n")
    for i in 0..fpc-1:
      targ = tolowerAscii(strip(a[i]))
      if not empty(targ):
        if targ == s:
          foundit = true
          break
  return foundit

#
# Generate edit summary 
#  3 edit types: GX.esrescued, GX.esformat and GX.esremoved
#
proc editsummary(): string =

  var
    outrescued, outremoved, outformat, final = ""

  if GX.esrescued > 0:
    if GX.esrescued > 1:
      outrescued = "Rescued " & $GX.esrescued & " archive links"
    else:
      outrescued = "Rescued " & $GX.esrescued & " archive link"

  if GX.esremoved > 0 and GX.esrescued > 0:
    if GX.esremoved > 1:
      outremoved = "remove " & $GX.esremoved & " links"
    else:
      outremoved = "remove " & $GX.esremoved & " link"
  elif GX.esremoved > 0 and GX.esrescued == 0:
    if GX.esremoved > 1:
      outremoved = "Removed " & $GX.esremoved & " archive links"
    else:
      outremoved = "Removed " & $GX.esremoved & " archive link"

  if GX.esformat > 0 and ( GX.esrescued > 0 or GX.esremoved > 0):
    if GX.esformat > 1:
      outformat = "reformat " & $GX.esformat & " links"
    else:
      outformat = "reformat " & $GX.esformat & " link"
  elif GX.esformat > 0 and ( GX.esrescued == 0 and GX.esremoved == 0):
    if GX.esformat > 1:
      outformat = "Reformat " & $GX.esformat & " archive links"
    else:
      outformat = "Reformat " & $GX.esformat & " archive link"

  if not empty(outrescued) and empty(outremoved) and empty(outformat):  # 100
    final = outrescued
  if not empty(outrescued) and not empty(outremoved) and empty(outformat):   # 110
    final = outrescued & "; " & outremoved
  if not empty(outrescued) and empty(outremoved) and not empty(outformat):   # 101
    final = outrescued & "; " & outformat
  if not empty(outrescued) and not empty(outremoved) and not empty(outformat):    # 111
    final = outrescued & "; " & outremoved & "; " & outformat

  if empty(outrescued) and not empty(outremoved) and empty(outformat):  # 010
    final = outremoved
  if empty(outrescued) and not empty(outremoved) and not empty(outformat):   # 011
    final = outremoved & "; " & outformat
  if empty(outrescued) and empty(outremoved) and not empty(outformat):  # 001
    final = outformat
  if empty(outrescued) and empty(outremoved) and empty(outformat): # 000
    final = ""

  if not empty(final):
    final = final & ". [[User:GreenC/WaybackMedic_2.1|Wayback Medic 2.1]]"
  else:
    final = "[[User:GreenC/WaybackMedic_2.1|Wayback Medic 2.1]]"

  return final

#                  
# Remove deadurl, archiveurl & archivedate from template and add {{cbignore}} and {{dead link}}
#
#  flag is optional parameter. If used set to one of these two:
#    flag="nocbignore" means don't add {{cbignore}} but add {{dead link}}
#    flag="nodeadlink" means don't add {{dead link}} or {{cbignore}}
#  no flag argument = add both 
#                  
proc removearchive(tl, caller, dead, cbignore: string): string =

  var debug = false

  var 
    tl = tl
    origurl = ""

  tl = cleanoldcomments(tl)
  origurl = getarg("archive-url", "clean", tl)

  sed("removearchive (0) = " & caller, debug)
  sed("removearchive (1) = " & tl, debug)
  tl = replacetext(tl, getarg("dead-url", "complete", tl), "", caller)  # remove dead-url
  sed("removearchive (2) = " & tl, debug)
  tl = replacetext(tl, getarg("archive-url", "complete", tl), "", caller)   # remove archiveurl
  sed("removearchive (3) = " & tl, debug)
  tl = replacetext(tl, getarg("archive-date", "complete", tl), "", caller)  # remove archivedate
  sed("removearchive (4) = " & tl, debug)

  # delete "|title=Archived copy"
  if tl ~ ("[|]" & GX.space & "[Tt][Ii][Tt][Ll][Ee]" & GX.space & "[=]" & GX.space & "Archived copy"):
    tl = replacetext(tl, "|title=Archived copy", "", caller)   # remove archiveurl
    sed("removearchive (5) = " & tl, debug)

  if cbignore == "nocbignore" and dead != "nodeadlink":
    tl = tl & "{{dead link|date=" & todaysdate() & "|bot=medic}}"
  elif cbignore != "nocbignore" and dead == "nodeadlink":
    if not dummydate(origurl, "189908"):
      tl = tl & "{{cbignore|bot=medic}}"
  elif cbignore != "nocbignore" and dead != "nodeadlink":
    tl = tl & "{{dead link|date=" & todaysdate() & "|bot=medic}}{{cbignore|bot=medic}}"

  sed("removearchive (6) = " & tl, debug)
  sendlog(Project.cbignore, CL.name, "removearchive1")
  return tl


#
# formatediaurl(string, cat)
#  cat = cite|wayback|bareurl
#
# Re-format IA URL into a regular format
#
proc formatediaurl*(tl, cat: string): string =

  var 
    url, newurl, safe, origtl = ""
    tl = tl  

  if cat == "cite":
    var re1 = "[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-]{0,1}[Uu][Rr][Ll]" & GX.space & "[=]" & GX.space 
    if tl ~ (re1 & "[Ww][Ee][Bb]"):
      sub(re1 & "[Ww][Ee][Bb]","archive-url=https://web",tl)
    if tl ~ (re1 & "[Ww]{3}[.][Ww][Ee][Bb]"):
      sub(re1 & "[Ww]{3}[.][Ww][Ee][Bb]","archive-url=https://web",tl)
    if tl ~ (re1 & "[wW]ayback"):
      sub(re1 & "[Ww]ayback","archive-url=https://web",tl)
    if tl ~ (re1 & "[Ll]ive[Ww]eb"):
      sub(re1 & "[Ll]ive[Ww]eb","archive-url=https://web",tl)
    if tl ~ (re1 & "[Aa]rchive"):
      sub(re1 & "[Aa]rchive","archive-url=https://web.archive",tl)
    url = getarg("archive-url", "clean", tl)
    newurl = formatediaurl(url, "barelink")   # recurse
    if countsubstring(url, newurl) < 1:
      tl = replacetext(tl, url, newurl, "formatediaurl1")
      return strip(tl)

    return strip(tl)

  if cat == "wayback":
    var re2 = "[|]" & GX.space & "[Uu][Rr][Ll]" & GX.space & "[=]" & GX.space 
    if tl !~ (re2 & "[Hh][Tt][Tt][Pp]") and tl !~ (re2 & "[}|]") and tl ~ ("[|]" & GX.space & "[Uu][Rr][Ll]" & GX.space & "[=]"):
      sub(re2,"|url=http://",tl)
      return strip(tl)

  if cat == "barelink":
    var re3 = "^[Hh][Tt][Tt][Pp][Ss]?[:]//"
    if tl ~ (re3 & "[Aa]rchive"):
      gsub(re3 & "[Aa]rchive", "https://web.archive", tl)
    elif tl ~ (re3 & "[Ww][WwEe][WwBb][.][Aa]rchive"):
      gsub(re3 & "[Ww][WwEe][WwBb][.][Aa]rchive", "https://web.archive", tl)
    elif tl ~ (re3 & "[Ww][Ww][Ww][.][Ww][Ee][Bb][.][Aa]rchive"):
      gsub(re3 & "[Ww][Ww][Ww][.][Ww][Ee][Bb][.][Aa]rchive", "https://web.archive", tl)
    elif tl ~ (re3 & "[lL]iveweb[.][Aa]rchive"):
      gsub(re3 & "[Ll]iveweb[.][Aa]rchive", "https://web.archive", tl)
    elif tl ~ (re3 & "[Ww]ayback[.][Aa]rchive"):
      gsub(re3 & "[Ww]ayback[.][Aa]rchive", "https://web.archive", tl)

    if tl ~ (re3 & "web.archive.org/[0-9]{1,14}/"):      # Insert /web/ into path if not already
      var a, c = ""
      match(tl, "^https[:]//web.archive.org/[0-9]{1,14}/", a)
      if awk.split(a, b, "/") > 0:
        c = "https://web.archive.org/web/" & b[3] & "/"
        gsubs(a, c, tl)
    
    if tl ~ "[:]80/":
      url = wayurlurl(tl)
      if url ~ "^[Hh][Tt][Tt][Pp][Ss]":
        safe = url
        gsub("^[Hh][Tt][Tt][Pp][Ss]", "http", safe)
        origtl = tl
        tl = replace(tl, url, safe)
        sendlog(Project.logwronghttps, CL.name, origtl & " " & tl)
        if Runme.port80:
          awk.sub( "[:]80/", "/", tl, 1)
      else:
        if tl ~ "[:]80/" and Runme.port80:
          awk.sub( "[:]80/", "/", tl, 1)

    return strip(tl)

  return strip(tl)

#
# Log (append) a line to Project[wayrmfull] 
# 
proc sendlogwayrm(database, name, msg, tl: string) =

  name & "----" & msg >> database
  "\n" & name & ":" >> Project.wayrmfull             

  if datatype(tl, "cite"):
    "<ref>" & tl & "</ref>" >> Project.wayrmfull
  elif datatype(tl, "webarchive"):
    "<ref>" & tl & "</ref>" >> Project.wayrmfull
  elif datatype(tl, "wayback"):
    let iaurl = "https://web.archive.org/web/" & getarg("date", "clean", tl) & "/" & uriparseEncodeurl(urldecode(getarg("url", "clean", tl)))
    "<ref>" & tl & "</ref> (" & iaurl & ")" >> Project.wayrmfull
  elif datatype(tl, "barelink"):
    "<ref>[" & tl & " Link]</ref>" >> Project.wayrmfull

#
# Given a citation template, return the archivedate in timestamp format (YYYYMMDD) (not including archivedate=)
#  . if unable to parse a given date, return 19700101
#  . if archivedate is blank or missing, return ""
#
proc getargarchivedatestamp*(tl: string): string =

  var 
    safe = ""

  if isarg("archive-date", "exists", tl):
    safe = getarg("archive-date", "clean", tl)
    if len(safe) > 3:
      let cmd = "date --date=\"" & safe & "\" +'%Y%m%d'"            # date (GNU coreutils) 8.21
      let (outp, errC) = execCmdEx(cmd)
      if errC == 0:
        return strip(outp)
      else:
        return "19700101"
    else:
      return ""
  return ""


#
# Increase GX.changes and log location of change 
#
proc incchanges(num: int, loc: string): string {.discardable} =

  for i in 1..num:
    GX.changes = GX.changes + 1

  (loc & " (" & $num & ")") >> GX.datadir & "changes"

  return ""


#
# Encode special wikitext characters
#
proc encodemag*(s: string): string =

  var
    s = s
    c = 0
    field, sep = newSeq[string](0)

  gsubs("{{=}}", "AaWaybackMedicEncodemag", s) # remove magic {{=}} so patsplit can find the end of template
  gsubs("{{!}}", "BbWaybackMedicEncodemag", s) # remove magic {{!}} (renders as "|" in templates)
  gsubs("{{'}}", "CcWaybackMedicEncodemag", s) # remove magic {{'}}
  gsubs("{{snd}}", "Dd1WaybackMedicEncodemag", s) # remove magic {{snd}} (renders as long slash)
  gsubs("{{spnd}}", "Dd2WaybackMedicEncodemag", s) # remove magic {{spnd}} (renders as long slash)
  gsubs("{{sndash}}", "Dd3WaybackMedicEncodemag", s) # remove magic {{sndash}} (renders as long slash)
  gsubs("{{spndash}}", "Dd4WaybackMedicEncodemag", s) # remove magic {{spndash}} (renders as long slash)
  gsubs("{{Spaced en dash}}", "Dd5WaybackMedicEncodemag", s) # remove magic {{Spaced en dash}} (renders as long slash)
  gsubs("{{spaced en dash}}", "Dd6WaybackMedicEncodemag", s) # remove magic {{spaced en dash}} (renders as long slash)
  gsubs("{{·}}", "EeWaybackMedicEncodemag", s) # remove magic {{·}} (renders as dot)
  gsubs("{{•}}", "FfWaybackMedicEncodemag", s) # remove magic {{•}} (renders as *)
  gsubs("{{\\}}", "GgWaybackMedicEncodemag", s) # remove magic {{\}} (renders as \)
  gsubs("{{en dash}}", "HhWaybackMedicEncodemag", s) # remove magic {{en dash}} (renders as )
  gsubs("{{em dash}}", "IiWaybackMedicEncodemag", s) # remove magic {{em dash}} (renders as )

  # Convert magic characters to percent-encoded within URLs

  c = awk.patsplit(s, field, "[Hh][Tt][Tt][Pp][^\\s\\]|}{<]*[^\\s\\]|}{<]", sep)
  for i in 0..c-1:
    if contains(field[i], "AaWaybackMedicEncodemag"):
      var orig = field[i]
      gsubs("AaWaybackMedicEncodemag", "%3D", field[i])
      gsubs("AaWaybackMedicEncodemag", "{{=}}", orig)
      if GX.encodemag1 == 0:
        inc(GX.encodemag1)
        inc(GX.esformat)
        incchanges(1, "encodemag1")
        sendlog(Project.logpctmagic, CL.name, orig & " ---- " & field[i])

    if contains(field[i], "BbWaybackMedicEncodemag"):
      var orig = field[i]
      gsubs("BbWaybackMedicEncodemag", "%7C", field[i])
      gsubs("BbWaybackMedicEncodemag", "{{!}}", orig)
      if GX.encodemag2 == 0:
        inc(GX.encodemag1)
        inc(GX.esformat)
        incchanges(1, "encodemag2")
        sendlog(Project.logpctmagic, CL.name, orig & " ---- " & field[i])

  s = unpatsplit(field, sep)
  return s

#
# Decode special wikitext characters
#
proc decodemag*(s: string): string =

  var s = s
  gsubs("AaWaybackMedicEncodemag", "{{=}}", s)
  gsubs("BbWaybackMedicEncodemag", "{{!}}", s)
  gsubs("CcWaybackMedicEncodemag", "{{'}}", s)
  gsubs("Dd1WaybackMedicEncodemag", "{{snd}}", s)
  gsubs("Dd2WaybackMedicEncodemag", "{{spnd}}", s)
  gsubs("Dd3WaybackMedicEncodemag", "{{sndash}}", s)
  gsubs("Dd4WaybackMedicEncodemag", "{{spndash}}", s)
  gsubs("Dd5WaybackMedicEncodemag", "{{Spaced en dash}}", s)
  gsubs("Dd6WaybackMedicEncodemag", "{{spaced en dash}}", s)
  gsubs("EeWaybackMedicEncodemag", "{{·}}", s)
  gsubs("FfWaybackMedicEncodemag", "{{•}}", s)
  gsubs("GgWaybackMedicEncodemag", "{{\\}}", s)
  gsubs("HhWaybackMedicEncodemag", "{{en dash}}", s)
  gsubs("IiWaybackMedicEncodemag", "{{em dash}}", s)

  return s


#
# Check for this bug:
#  https://en.wikipedia.org/w/index.php?title=Abingdon_Preparatory_School&diff=prev&oldid=771864698
#
proc nospacebug(): bool =

  if not GX.nospace:
    return true

  var
    article = GX.article
    articlework = GX.articlework

  gsub(" ", "", article)
  gsub(" ", "", articlework)
  if article != articlework:
    return true
  return false


#
# Encode or log embedded templates eg. |date={{date|2017}}
#
#  If action is "encode" then change it to: |date=AaWaybackMedicEmTemdate|2017BbWaybackMedicEmTem
#  If action is "log" then log existence to syslog
#  If action is "encode log" then do both
#  If action is "decode" then undo encoding
#
#  return modified string 'fp'
#
proc emtem(fp, action: string): string {.discardable} =

  var fp = fp

  if empty(fp):
    sed("emtem: empty string error", Debug.network)
    return fp
  if action !~ "log|encode|decode":
    sed("emtem: error in action type", Debug.network)
    return fp

  if action == "decode":
    gsub("AaWaybackMedicEmTem", "[{][{]", fp)
    gsub("BbWaybackMedicEmTem", "[}][}]", fp)
    return fp
 
  var
    field, sep = newSeq[string](0)
    farr = initTable[int, string]()
    lp = len(fp)
    i,j,c,t = 0
    h,d = ""
    
  c = awk.patsplit(fp, field, GX.cite2, sep)
  if (c > 0):
    for k in 0..c-1:
      if field[k] ~ "[{][{]":                                     # Found 1+ {{ .. an embedded template
  
        # If an embedded template, and not a double embedded template 2x {{
        if countsubstring(fp, field[k]) == 1 and countsubstring(field[k], "{{") == 2:
          h = ""
          j = 0
          var uarr = initTable[int, string]()
          i = index(fp, field[k]) + len(field[k])
          while(true):
            h = h & awk.substr(fp, i, 1)
            if awk.substr(fp, i, 1) ~ "[}]" and awk.substr(fp, i+1, 1) ~ "[}]":
              h = h & "}"
              if countsubstring(h, "{{") < 2:
                inc(j)
                uarr[j] = h
              else:                                           # Found 2x {{ double-embedded, bail out
                h = ""
                sendlog(Project.syslog, CL.name, h & " ---- Found double embedded in emtem1.1")
                sed("emtem: " & h & " ---- Found double embedded in emtem1.1", Debug.network) 
                break
              if h ~ "[{][{]":
                h = ""
                inc(i)
              else:
                break
            inc(i)
            if i > lp:                                        # Abort endless loop
              h = ""
              sendlog(Project.syslog, CL.name, h & " ---- Unable to find end of template in emtem1.2")
              sed("emtem: " & h & " ---- Unable to find end of template in emtem1.2", Debug.network) 
              break
  
          d = ""
  
         # log and/or fix embedded templates
          if h ~ "[}][}]$":
        
           # first embedded template in the head
            if action ~ "encode":
              gsub("[{][{]", "AaWaybackMedicEmTem", field[k])
              gsub("[}][}]", "BbWaybackMedicEmTem", field[k])
            if action ~ "log":
              awk.match(field[k], "[|][\\s]*[^=]*[=][\\s]*[{][{][^}]*[}][}]", dest)
              if not empty(dest):
                sendlog(Project.syslog, CL.name, dest & " ---- emtem2.1")
  
           # for..in through the remaining 
            for k in uarr.keys:
              if not empty(uarr[k]):
                if action ~ "encode":
                  gsub("[{][{]", "AaWaybackMedicEmTem", uarr[k])
                  gsub("[}][}]", "BbWaybackMedicEmTem", uarr[k])
                if action ~ "log":
                  awk.match(uarr[k], "[|][\\s]*[^=]*[=][\\s]*[{][{][^}]*[}][}]", dest)
                  if not empty(dest):
                    sendlog(Project.syslog, CL.name, dest & " ---- emtem2.2")
                d = d & uarr[k]
  
            farr[t] = field[k] & d

            # restore {{cite web}} head and tail {{ }}
            if action ~ "encode":
              gsub("^AaWaybackMedicEmTem", "{{", farr[t])
              gsub("BbWaybackMedicEmTem$", "}}", farr[t])

            inc(t)
  
        elif countsubstring(field[k], "{{") > 2:                   # Found 2x {{ double-embedded in head, bail out
          sendlog(Project.syslog, CL.name, h & " ---- Found double embedded in emtem1.3")
          sed("emtem: " & h & " ---- Found double embedded in emtem1.3", Debug.network) 
 
   # update fp with changes 
    if action == "encode":
      if len(farr) > 0:
        for u in farr.keys:
          var uf = emtem(farr[u], "decode")
          if not empty(uf):
            gsubs(uf, farr[u], fp)

    return fp
