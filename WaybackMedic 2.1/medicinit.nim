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


# _____________________________________________________________  Command line parse

type
  CLObj* = object
    name: string         # name passed by -n
    project: string
    sourcefile: string
    debug: string
    interval: string
var CL*: CLObj

for poKind, poKey, poVal in getopt():
  case poKind
  of cmdArgument:
    discard
  of cmdLongOption, cmdShortOption:
    case poKey
    of "p":                    # -p=<val>    WaybackMedic project ID. Required.
      CL.project = poVal
    of "n":                    # -n=<val>    Wikipedia article name. Required.
      CL.name = poVal
    of "s":                    # -s=<val>    Wikipedia source file. Required.
      CL.sourcefile = poVal
    of "d":                    # -d=<val>    Debug
      CL.debug = poVal
    of "i":                    # -i=<val>    Interval (secs) for hearbeat of API, 0=always
      CL.interval = poVal
  of cmdEnd: 
    assert(false)

# There is a bug in parseopt() see https://forum.nim-lang.org/t/4080
# This works around it for now (July 2018)
if CL.name ~ "xx42":
  CL.name = gsubs("xx42","\"",CL.name)

if empty(CL.project) or empty(CL.name) or empty(CL.sourcefile):
  echo "\nWaybackMedic\n\nUsage:\n"
  echo "  medic -p <project> -n <name> -s <sourcefile> -d <debugopt> -i <interval>"
  echo ""
  quit(QuitSuccess)  

if empty(CL.debug):
  CL.debug = "n"

if empty(CL.interval):
  CL.interval = "0"

if not existsFile(CL.sourcefile):
  "Unable to find sourcefile " & CL.sourcefile >* "/dev/stderr"
  quit(QuitSuccess)


# _______________________________________________________________________________  Global var declaration

type
  GXObj* = object
    home: string           # home directory
    agent: string          # wget agent string
    agentlynx: string      # lynx agent string
    wgetopts: string       # wget options
    datetype: string       # Date format type (dmy or myd) obtained from article templates {{use dmy}} and {{use mdy}}
    datetypeexists: bool   # If a date type template exists in the article or not
    id: int                # running count of number of links found .. used to index WayLink[id]
    article: string        # original copy of article (stays unchanged)
    articlework: string    # working copy of article
    workfile: string       # path/name of work file eg. articlework.txt
    robotsinx: string      # file contents of robotsinx 
    robotsdir: string      # directory containing robots.txt downloads
    ramdir: string         # Ramdisk directory 
    datadir: string        # full path/name of data directory
    wid: string            # data directory id eg. wm-20160503034
    cx: int
    encodemag1: int        # tracker for encodemag()
    encodemag2: int        #
    webciteok: bool        # if WebCite API is working
    changes: int           # number of changes (edits) made to article (internal count)
    esrescued: int         # Edit summary: number of links rescued
    esremoved: int         # Edit summary: number of links removed
    esformat: int          # Edit summary: number of links format changes
    lynxloop: int          # flag used in getheadlynx
    redirloop: int         # flag used in api
    unavailableloop: int   # flag used in api
    nospace: bool          # flag used to disable nospacebug()
    numfound: int          # number of links found in article
    tempname: int          # used in mktempname()
    imp: string            # if project is for IMP
    service: seq[string]   # domain + paths up to point of source URL
    soft404: string        # string of readfile(Project.soft404)
    soft404c: int          # number of lines in soft404.bm file
    soft404a: seq[string]  # array of lines in soft404.bm
    soft404i: string       # string of readfile(Project.soft404i)
    soft404ic: int
    soft404ia: seq[string]
    iahre: string          # regular-expression matching IA links
    iare: string           # regular-expression matching IA links
    wcre: string           # regular-expression matching WebCite links
    isre: string           # regular-expression matching Archive.is links
    locgovre: string       # regular-expression matching LOC links
    portore: string        # regular-expression matching Portugal links
    stanfordre: string     # regular-expression matching Stanford links
    archiveitre: string    # regular-expression matching Archive-it.org
    bibalexre: string      # regular-expression matching BibAlex
    vefsafnre: string      # regular-expression matching Iceland
    natarchivesukre: string # regular-expression matching National Archives (UK)  # newwebarchive
    europare: string
    memoryre: string
    permaccre: string
    pronire: string
    parliamentre: string
    ukwebre: string
    canadare: string
    catalonre: string
    singaporere: string
    slovenere: string
    freezepagere: string
    wikiwixre: string
    webharvestre: string
    nlaaure: string
    yorkre: string
    lacre: string
    dead: string           # regular-expression matching {{dead link}}
    cbignore: string       # regular-expression matching {{cbignore}}
    deadcbignore: string   # regular-expression matching {{dead link}}{{cbignore}}
    shttp: string          # regular-expression matching ^https?
    anytp: string          # regular-expression matching ^https?|^ftp|.."
    space: string          # regular-expression matching <space> for use inside templates
    cite: string           # regular-expression matching cite templates 
    cite2: string          # regular-expression matching cite templates 
    filext: string         # regular-expression matching URLs with a file extension
    ver: string            # version
    base62: string         # path to base62.lua
    wcapi: string          # path to webciteapi.awk
    wam: string            # path to wam.awk
    straydt: string        # path to straydt.awk
    webcitlong: string     # path to webcitlong.awk
    freezelong: string     # path to freezelong.awk
    wikiwixlong: string    # path to wikiwixlong.awk
    archiveis: string      # path to archiveis.awk
    citeaddl: string       # path to citeaddl.awk
    unixfile: string       # path to unix command 'file'

var GX*: GXObj

# Directories should have a trailing slash
GX.home = "/home/adminuser/wmnim/wm2/"

# Version. This is used in skindeep()
GX.ver = "WaybackMedic2"

# Location of RAM disk (need at least 20MB free)
GX.ramdir = "/mnt/ramdisk/"

# String included with http requests shows in remote logs. Name of program, contact info and name of article processed. 
GX.agent = "http://en.wikipedia.org/wiki/User:GreenC/WaybackMedic_2.1 (" & shquote(CL.name) & ")"

GX.agentlynx = "--useragent=" & shquote(GX.agent)

# Default wget options (include lead/trail spaces)
GX.wgetopts = " --no-cookies --ignore-length --user-agent=" & shquote(GX.agent) & " --no-check-certificate --tries=2 --timeout=110 --waitretry=10 --retry-connrefused "

# Location of wam.awk if used 
GX.wam = GX.home & "modules/wam/wam.awk"
if not existsFile(GX.wam):
  "Unable to find " & GX.wam >* "/dev/stderr"
  quit(QuitSuccess)

# Location of straydt.awk if used 
GX.straydt = GX.home & "modules/straydt/straydt.awk"
if not existsFile(GX.straydt):
  "Unable to find " & GX.straydt >* "/dev/stderr"
  quit(QuitSuccess)

# Location of webcitlong.awk if used 
GX.webcitlong = GX.home & "modules/webcitlong/webcitlong.awk"
if not existsFile(GX.webcitlong):
  "Unable to find " & GX.webcitlong >* "/dev/stderr"
  quit(QuitSuccess)

# Location of wikiwixlong.awk if used 
GX.wikiwixlong = GX.home & "modules/wikiwixlong/wikiwixlong.awk"
if not existsFile(GX.wikiwixlong):
  "Unable to find " & GX.wikiwixlong >* "/dev/stderr"
  quit(QuitSuccess)

# Location of freezelong.awk if used 
GX.freezelong = GX.home & "modules/freezelong/freezelong.awk"
if not existsFile(GX.freezelong):
  "Unable to find " & GX.freezelong >* "/dev/stderr"
  quit(QuitSuccess)

# Location of archiveis.awk if used 
GX.archiveis = GX.home & "modules/archiveis/archiveis.awk"
if not existsFile(GX.archiveis):
  "Unable to find " & GX.archiveis >* "/dev/stderr"
  quit(QuitSuccess)

# Location of citeaddl.awk if used 
GX.citeaddl = GX.home & "modules/citeaddl/citeaddl.awk"
if not existsFile(GX.citeaddl):
  "Unable to find " & GX.citeaddl >* "/dev/stderr"
  quit(QuitSuccess)

# Location of base62.lua
GX.base62 = GX.home & "base62.lua"
if not existsFile(GX.base62):
  "Unable to find " & GX.base62 >* "/dev/stderr"
  quit(QuitSuccess)

# Location of webciteapi.awk
GX.wcapi = GX.home & "webciteapi.awk"
if not existsFile(GX.wcapi):
  "Unable to find " & GX.wcapi >* "/dev/stderr"
  quit(QuitSuccess)

GX.datetype = "mdy"
GX.datetypeexists = false
GX.id = -1
GX.changes = 0
GX.lynxloop = 0
GX.redirloop = 0
GX.unavailableloop = 0
GX.encodemag1 = 0
GX.encodemag2 = 0
GX.webciteok = true
GX.nospace = true

GX.article = readfile(CL.sourcefile)
GX.articlework = GX.article           

# create a physical copy of article.txt --> workarticle.txt (GX.workfile)
var safe = CL.sourcefile
GX.workfile = awk.gsub("article.txt$","workarticle.txt",safe)
GX.article >* GX.workfile

GX.datadir = dirname(CL.sourcefile)
GX.cx = awk.split(GX.datadir, GXax, "/")
GX.wid = GXax[GX.cx - 2]
"" >* "/tmp/" & GX.wid                                 # Directory ID for tracking running/stuck process

# <space> inside templates
GX.space = "[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}[ ]{0,}[\\n\\t]{0,}"

GX.service = newSeq[string](0)

GX.tempname = 0

if CL.project ~ "^imp":
  awk.split(CL.project, impa, "[.]")
  if impa[0] ~ "md$":
    GX.imp = "ModDel"
  elif impa[0] ~ "a$":
    GX.imp = "Add"
  else:
    GX.imp = ""
else:
  GX.imp = ""

GX.unixfile = "/usr/bin/file"
if not existsFile(GX.unixfile):
  "Unable to find " & GX.unixfile >* "/dev/stderr"
  quit(QuitSuccess)

#
# Webarchive service regex 
#
# archive.org
# web, wayback, liveweb, www, www.web
# classic-web, web-beta, replay, replay.web, web.wayback
#
GX.iahre = "(wik|[Cc][Ll][Aa][Ss][Ss][Ii][Cc][-][Ww][Ee][Bb]|[Ww][Ww][Ww][.][Ww][Ee][Bb]|[Ww][Ww][Ww]|[Ww][Ee][Bb][-][Bb][Ee][Tt][Aa]|[Rr][Ee][Pp][Ll][Aa][Yy][-][Ww][Ee][Bb]|[Rr][Ee][Pp][Ll][Aa][Yy]|[Ww][Ee][Bb][.][Ww][Aa][Yy][Bb][Aa][Cc][Kk]|[Ww][Ee][Bb]|[Ww][Aa][Yy][Bb][Aa][Cc][Kk])"
GX.iare = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/]" & GX.iahre & "[.]?[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg][:]?[4]?[48]?[30]?"
insert(GX.service, GX.iare & "[/]?[Ww]?[Ee]?[Bb]?[/][0-9*]{1,14}[/]", 0)

# webcitation.org
GX.wcre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[Ww]?[Ww]?[.]?[Ww][Ee][Bb][Cc][Ii][Tt][Aa][Tt][Ii][Oo][Nn][.][Oo][Rr][Gg][:]?[4]?[48]?[30]?"
insert(GX.service, GX.wcre & "[/]", 1)

# archive.is, .fo, .li, .today
GX.isre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[Ww]?[Ww]?[.]?[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.]([Tt][Oo][Dd][Aa][Yy]|[Ii][Ss]|[Ll][Ii]|[Ff][Oo])[:]?[4]?[48]?[30]?[/]"
insert(GX.service, GX.isre, 2)

# LOC - http://webarchive.loc.gov/all/20111109051100/http
#       http://webarchive.loc.gov/lcwa0010/20111109051100/http
GX.locgovre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Ll][Oo][Cc][.][Gg][Oo][Vv][:]?[4]?[48]?[30]?"
insert(GX.service, GX.locgovre & "[/]?([WwAa]?[EeLl]?[BbLl]?|[Ll][Cc][Ww][Aa][0-9]{1,6})[/][0-9*]{8,14}[/]", 3)

# Portugal - http://arquivo.pt/wayback/20091010102944/http..
GX.portore = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[WwEe]?[WwBb]?[.]?[Aa][Rr][Qq][Uu][Ii][Vv][Oo][.][Pp][Tt][:]?[4]?[48]?[30]?"
insert(GX.service, GX.portore  & "[/]?[Ww]?[Aa]?[Yy]?[Bb]?[Aa]?[Cc]?[Kk]?[/]?[Ww]?[Aa]?[Yy]?[Bb]?[WwAa]?[EeCcLl]?[BbKkLl]?[/][0-9*]{8,14}[/]", 4)

# Stanford - https://swap.stanford.edu/20091122200123/http
GX.stanfordre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ss][Ww][Aa][Pp][.][Ss][Tt][Aa][Nn][Ff][Oo][Rr][Dd][.][Ee][Dd][Uu][:]?[4]?[48]?[30]?"
insert(GX.service, GX.stanfordre  & "[/]?[Ww]?[Ee]?[Bb]?[/][0-9*]{8,14}[/]", 5)

# Archive-it.org - http://wayback.archive-it.org/all/20130420084626/http
GX.archiveitre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/]" & GX.iahre  & "[.]?[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-][Ii][Tt][.][Oo][Rr][Gg][:]?[4]?[48]?[30]?"
insert(GX.service, GX.archiveitre  & "[/]?[WwAa]?[EeLl]?[BbLl]?[/][0-9*]{8,14}[/]", 6)

# BibAlex - http://web.archive.bibalex.org:80/web/20011007083709/http
#           http://web.petabox.bibalex.org/web/20060521125008/http://developmentgap.org/rmalenvi.html
GX.bibalexre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[Ee]?[Bb]?[.]?([Pp][Ee][Tt][Aa][Bb][Oo][Xx]|[Aa][Rr][Cc][Hh][Ii][Vv][Ee])[.][Bb][Ii][Bb][Aa][Ll][Ee][Xx][.][Oo][Rr][Gg][:]?[4]?[48]?[30]?"
insert(GX.service, GX.bibalexre  & "[/]?[WwAa]?[EeLl]?[BbLl]?[/][0-9*]{8,14}[/]", 7)

# National Archives UK - http://webarchive.nationalarchives.gov.uk/20091204115554/http
GX.natarchivesukre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/]([Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee]|[Yy][Oo][Uu][Rr][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss])[.][Nn][Aa][Tt][Ii][Oo][Nn][Aa][Ll][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss][.][Gg][Oo][Vv].[Uu][Kk][:]?[4]?[48]?[30]?"
insert(GX.service, GX.natarchivesukre  & "([/]tna)?[/][0-9*]{8,14}[/]", 8)

# National Archives Iceland - http://wayback.vefsafn.is/wayback/20060413000000/http
GX.vefsafnre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][.][Vv][Ee][Ff][Ss][Aa][Ff][Nn][.][Ii][Ss][:]?[4]?[48]?[30]?"
insert(GX.service, GX.vefsafnre & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][0-9*]{8,14}[/]", 9)

# Europa Archives (Ireland) - http://collection.europarchive.org/nli/20160525150342/http
GX.europare = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Cc][Oo][Ll][Ll][Ee][Cc][Tt][Ii][Oo][Nn][Ss]?[.][Ee][Uu][Rr][Oo][Pp][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.europare  & "[/][Nn][Ll][Ii][/][0-9*]{8,14}[/]", 10)

# Perma.CC Archives - http://perma-archives.org/warc/20140729143852/http
GX.permaccre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Pp][Ee][Rr][Mm][Aa]([-][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss])?[.]([Oo][Rr][Gg]|[Cc][Cc])[:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.permaccre  & "[/][Ww][Aa][Rr][Cc][/][0-9*]{8,14}[/]", 11)

# Proni Web Archives - http://webarchive.proni.gov.uk/20111213123846/http
GX.pronire = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Pp][Rr][Oo][Nn][Ii][.][Gg][Oo][Vv][.][Uu][Kk][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.pronire  & "[/][0-9*]{8,14}[/]", 12)

# UK Parliament - http://webarchive.parliament.uk/20110714070703/http
GX.parliamentre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Pp][Aa][Rr][Ll][Ii][Aa][Mm][Ee][Nn][Tt][.][Uu][Kk][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.parliamentre  & "[/][0-9*]{8,14}[/]", 13)

# UK Web Archive (British Library) - http://www.webarchive.org.uk/wayback/archive/20110324230020/http
GX.ukwebre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ww][Ww][.][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg][.][Uu][Kk][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.ukwebre  & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][Aa][Rr][Cc][Hh][Ii][Vv][Ee][/][0-9*]{8,14}[/]", 14)

# Canada - http://www.collectionscanada.gc.ca/webarchives/20060209004933/http
GX.canadare = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ww][Ww][.][Cc][Oo][Ll][Ll][Ee][Cc][Tt][Ii][Oo][Nn][Ss][Cc][Aa][Nn][Aa][Dd][Aa][.][Gg][Cc][.][Cc][Aa][:]?[8]?[04]?[48]?[30]?[/]([Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss][Ww][Ee][Bb]|[Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss])[/]"
insert(GX.service, GX.canadare & "[0-9*]{8,14}[/]", 15)

# Catalonian Archive - http://www.padi.cat:8080/wayback/20140404212712/http
GX.catalonre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ww][Ww][.][Pp][Aa][Dd][Ii][.][Cc][Aa][Tt][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.catalonre  & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][0-9*]{8,14}[/]", 16)

# Singapore Archives - http://eresources.nlb.gov.sg/webarchives/wayback/20100708034526/http
GX.singaporere = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ee][Rr][Ee][Ss][Oo][Uu][Rr][Cc][Ee][Ss][.][Nn][Ll][Bb][.][Gg][Oo][Vv][.][Ss][Gg][:]?[8]?[04]?[48]?[30]?[/][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss][/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/]"
insert(GX.service, GX.singaporere  & "[0-9*]{8,14}[/]", 17)

# Slovenian Archives - http://nukrobi2.nuk.uni-lj.si:8080/wayback/20160203130917/http
GX.slovenere = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Nn][Uu][Kk][Rr][Oo][Bb][Ii][0-9]?[.][Nn][Uu][Kk][.][Uu][Nn][Ii][-][Ll][Jj][.][Ss][Ii][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.slovenere  & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][0-9*]{8,14}[/]", 18)

# Freezepage - http://www.freezepage.com/1249681324ZHFROBOEGE
GX.freezepagere = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[Ww]?[Ww]?[.]?[Ff][Rr][Ee][Ee][Zz][Ee][Pp][Aa][Gg][Ee][.][Cc][Oo][Mm][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.freezepagere, 19)

# National Archives US - http://webharvest.gov/peth04/20041022004143/http
GX.webharvestre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Hh][Aa][Rr][Vv][Ee][Ss][Tt][.][Gg][Oo][Vv][:]?[4]?[48]?[30]?"
insert(GX.service, GX.webharvestre & "[/][^/]*[/][0-9*]{8,14}[/]", 20)

# NLA Australia (Pandora, Trove etc)
#  http://pandora.nla.gov.au/pan/14231/20120727-0512/www.howlspace.com.au/en2/inxs/inxs.htm
#  http://pandora.nla.gov.au/pan/128344/20110810-1451/www.theaureview.com/guide/festivals/bam-festival-2010-ivorys-rock-qld.html
#  http://pandora.nla.gov.au/nph-wb/20010328130000/http://www.howlspace.com.au/en2/arenatina/arenatina.htm
#  http://pandora.nla.gov.au/nph-arch/2000/S2000-Dec-5/http://www.paralympic.org.au/athletes/athleteprofile60da.html
#  http://webarchive.nla.gov.au/gov/20120326012340/http://news.defence.gov.au/2011/09/09/army-airborne-insertion-capability/
#  http://content.webarchive.nla.gov.au/gov/wayback/20120326012340/http://news.defence.gov.au/2011/09/09/army-airborne-insertion-capability
GX.nlaaure = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/](pandora|webarchive|content[.]webarchive)[.]nla.gov.au[:]?[8]?[04]?[48]?[30]?[/](pan|nph[-]wb|nph[-]arch|gov|gov[/]wayback)[/]([0-9]{4,7}[/][0-9]{8}[-][0-9]{4}|[0-9]{14}|[0-9]{4}[/][A-Z][0-9]{4}[-][A-Z][a-z]{2}[-][0-9]{1,2})[/]"
insert(GX.service, GX.nlaaure, 21)

# WikiWix - http://archive.wikiwix.com/cache/20180329074145/http://www.linterweb.fr
GX.wikiwixre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Ww][Ii][Kk][Ii][Ww][Ii][Xx][.][Cc][Oo][Mm][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.wikiwixre, 22)

# York University Archives
# https://digital.library.yorku.ca/wayback/20160129214328/http
GX.yorkre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Dd][Ii][Gg][Ii][Tt][Aa][Ll][.][Ll][Ii][Bb][Rr][Aa][Rr][Yy][.][Yy][Oo][Rr][Kk][.][Cc][Aa][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.yorkre & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][0-9*]{8,14}[/]", 23)

# Internet Memory Foundation (Netherlands) - http://collections.internetmemory.org/nli/20160525150342/http
GX.memoryre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Cc][Oo][Ll][Ll][Ee][Cc][Tt][Ii][Oo][Nn][Ss][.][Ii][Nn][Tt][Ee][Rr][Nn][Ee][Tt][Mm][Ee][Mm][Oo][Rr][Yy][.][Oo][Rr][Gg][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.memoryre  & "[/][Nn][Ll][Ii][/][0-9*]{8,14}[/]", 24)

# Library and Archives Canada - http://webarchive.bac-lac.gc.ca:8080/wayback/20080116045132/http
GX.lacre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Bb][Aa][Cc][-][Ll][Aa][Cc][.][Gg][Cc][.][Cc][Aa][:]?[8]?[04]?[48]?[30]?"
insert(GX.service, GX.lacre  & "[/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][/][0-9*]{8,14}[/]", 25)

# newwebarchive (above)
# newwebarchive (straydt.awk - copy of above)
# newwebarchive (atools.awk - entire file requires update)

# {{dead link .. }}
GX.dead = "[{][ ]{0,1}[{]" & GX.space & "[Dd][Ee][Aa][Dd][ -]?[Ll][Ii][Nn][Kk][^}]*[}][ ]{0,1}[}]"

# {{cbignore .. }}
GX.cbignore = "[{]" & GX.space & "[{]" & GX.space & "[Cc][Bb][Ii][Gg][Nn][Oo][Rr][Ee][^}]*[}]" & GX.space & "[}]"

# {{dead link}}|{{dead link}}{{cbignore}}|{{cbignore}}{{dead link}}
GX.deadcbignore = "(" & GX.dead & ")|(" & GX.dead & GX.cbignore & ")|(" & GX.cbignore & GX.dead & ")"

# http
GX.shttp = "^[Hh][Tt][Tt][Pp][Ss]?"

# citation templates - OLD - retired August 18 2018
#GX.cite = "[{][ ]{0,}[Cc]ite[^}]+}|[{][ ]{0,}[Cc]ita[^}]+}|[{][ ]{0,}[Vv]cite[^}]+}|[{][ ]{0,}[Vv]ancite[^}]+}|[{][ ]{0,}[Hh]arvrefcol[^}]+}|[{][ ]{0,}[Cc]itation[^}]+}"
#GX.cite2 = "[{][{][ ]{0,}[Cc]ite[^}]+}}|[{][{][ ]{0,}[Cc]ita[^}]+}}|[{][{][ ]{0,}[Vv]cite[^}]+}}|[{][{][ ]{0,}[Vv]ancite[^}]+}}|[{][{][ ]{0,}[Hh]arvrefcol[^}]+}}|[{][{][ ]{0,}[Cc]itation[^}]+}}"

# Cite templates. To generate list of affected templates see https://phabricator.wikimedia.org/T178106 and https://en.wikipedia.org/wiki/User:GreenC/software/templatesearch
# Copy list to file "cites-list" and run these two awk commands to generate regex statements (needs minor manual adjustments at end)
# Also update atools.awk
# awk -ilibrary 'BEGIN{printf "(?i)([{][ ]*("; for(i=1;i<=splitn("cites-list",a,i);i++){gsub(/^\"{{|}}\",?$/,"",a[i]);printf subs("-","[-]",a[i]) "|" }; printf "[^}]+})" }'
GX.cite = "(?i)([{][ ]*(A Short Biographical Dictionary of English Literature|AZBilliards|BDMag|Bokref|Catholic[-]hierarchy|Cita audio|Cita conferencia|Cita conferenza|Cita DANFS|Cita enciclopedia|Cita Enciclopedia Católica|Cita entrevista|Cita episodio|Cita grupo de noticias|Cita historieta|Cita immagine|Cita juicio|Cita libro|Cita lista de correo|Cita mapa|Cita news|Cita notas audiovisual|Cita noticia|Cita pubblicazione|Cita publicación|Citar web|Cita tesis|Cita testo|Citation|Citation step free tube map|Citation Style documentation|Cita TV|Cita vídeo|Cita visual|Cita web|Cite act|Cite Australasia|Cite AV media|Cite AV media notes|Cite book|Cite comic|Cite comics image|Cite comics image lrg|Cite conference|Cite constitution|Cite DVD notes|Cite encyclopedia|Cite episode|Citeer boek|Citeer encyclopedie|Citeer journal|Citeer nieuws|Citeer tijdschrift|Citeer web|Cite Hansard|Cite IETF|Cite interview|Cite IrishBio|Cite journal|Cite letter|Cite magazine|Cite mailing list|Cite map|Cite Memoria Chilena|Cite music release notes|Cite news|Cite newsgroup|Cite PH act|Cite podcast|Cite postcode project|Cite press release|Cite QPN|Cite quick|Cite report|Cite SBDEL|Cite serial|Cite sign|Cite speech|Cite sports[-]reference|Cite techreport|Cite thesis|Cite Transperth timetable|Cite Trove newspaper|Cite tweet|Cite video|Cite vob|Cite web|Cite wikisource|College athlete recruit end|Cytuj stronę|DNZB|Documentación cita|Etude|Gazette WA|Goalzz|Harvard reference|Harvrefcol|Internetquelle|IPMag|IPSite|ITIS|IUCN|Kilde artikkel|Kilde avhandling|Kilde avis|Kilde AV[-]medium|Kilde bok|Kilde konferanse|Kilde oppslagsverk|Kilde pressemelding|Kilde www|KLISF|Lien conférence|Lien vidéo|Lien web|Macdonald Dictionary|MTRsource|Obra citada|Online source|PBMag|Press|Pressmeddelanderef|SA Rugby Article|Silvics|Singapore legislation|Source archived|Tidningsref|Tidskriftsref|Vancite book|Vancite journal|Vancite news|Vancite web|Vcite book|Vcite journal|Vcite news|Vcite web|Verkkoviite|Webbref|WebbrefSV|Web kaynağı|Web reference|WsPSM|Статья)[^}]+})"
# awk -ilibrary 'BEGIN{printf "(?i)([{][{][ ]*("; for(i=1;i<=splitn("cites-list",a,i);i++){gsub(/^\"{{|}}\",?$/,"",a[i]);printf subs("-","[-]",a[i]) "|" }; printf "[^}]+}})" }'
GX.cite2 = "(?i)([{][{][ ]*(A Short Biographical Dictionary of English Literature|AZBilliards|BDMag|Bokref|Catholic[-]hierarchy|Cita audio|Cita conferencia|Cita conferenza|Cita DANFS|Cita enciclopedia|Cita Enciclopedia Católica|Cita entrevista|Cita episodio|Cita grupo de noticias|Cita historieta|Cita immagine|Cita juicio|Cita libro|Cita lista de correo|Cita mapa|Cita news|Cita notas audiovisual|Cita noticia|Cita pubblicazione|Cita publicación|Citar web|Cita tesis|Cita testo|Citation|Citation step free tube map|Citation Style documentation|Cita TV|Cita vídeo|Cita visual|Cita web|Cite act|Cite Australasia|Cite AV media|Cite AV media notes|Cite book|Cite comic|Cite comics image|Cite comics image lrg|Cite conference|Cite constitution|Cite DVD notes|Cite encyclopedia|Cite episode|Citeer boek|Citeer encyclopedie|Citeer journal|Citeer nieuws|Citeer tijdschrift|Citeer web|Cite Hansard|Cite IETF|Cite interview|Cite IrishBio|Cite journal|Cite letter|Cite magazine|Cite mailing list|Cite map|Cite Memoria Chilena|Cite music release notes|Cite news|Cite newsgroup|Cite PH act|Cite podcast|Cite postcode project|Cite press release|Cite QPN|Cite quick|Cite report|Cite SBDEL|Cite serial|Cite sign|Cite speech|Cite sports[-]reference|Cite techreport|Cite thesis|Cite Transperth timetable|Cite Trove newspaper|Cite tweet|Cite video|Cite vob|Cite web|Cite wikisource|College athlete recruit end|Cytuj stronę|DNZB|Documentación cita|Etude|Gazette WA|Goalzz|Harvard reference|Harvrefcol|Internetquelle|IPMag|IPSite|ITIS|IUCN|Kilde artikkel|Kilde avhandling|Kilde avis|Kilde AV[-]medium|Kilde bok|Kilde konferanse|Kilde oppslagsverk|Kilde pressemelding|Kilde www|KLISF|Lien conférence|Lien vidéo|Lien web|Macdonald Dictionary|MTRsource|Obra citada|Online source|PBMag|Press|Pressmeddelanderef|SA Rugby Article|Silvics|Singapore legislation|Source archived|Tidningsref|Tidskriftsref|Vancite book|Vancite journal|Vancite news|Vancite web|Vcite book|Vcite journal|Vcite news|Vcite web|Verkkoviite|Webbref|WebbrefSV|Web kaynağı|Web reference|WsPSM|Статья)[^}]+}})"

# file extensions
GX.filext = "(?i)[.](jpg|gif|png|pdf|ppt|pps|doc|mp3|mp4|flv|wav|xls|swf|txt|ram|xlsx)$"

# _______________________________________________________________________________  Enable/Disable features

type
  RunmeObj* = object
    fixthespuriousone: bool          
    fixtrailingchar: bool
    fixencodedurl: bool
    fixemptywayback: bool
    fixemptyarchive: bool
    fixdatemismatch: bool
    fixdoubleurl: bool
    fixbadstatus: bool
    fixitems: bool
    replacedeadlink: bool
    api: bool
    robots: bool
    port80: bool
    wam: bool
    straydt: bool
    webcitlong: bool
    webcitlongverify: bool
    freezelong: bool
    wikiwixlong: bool
    archiveis: bool
    citeaddl: bool
    newaltarchinx: bool
    replacewikiwix: bool
    memento: bool
    fixru: bool

var Runme*: RunmeObj

# Set to "false" to disable features

if CL.project !~ "france":  # standard settings
  Runme.fixthespuriousone = true 
  Runme.fixtrailingchar = true 
  Runme.fixencodedurl = true 
  Runme.fixemptywayback = true 
  Runme.fixemptyarchive = true 
  Runme.fixdatemismatch = true 
  Runme.fixdoubleurl = true 
  Runme.fixbadstatus = true 
  Runme.fixitems = true
  Runme.api = true
  Runme.replacedeadlink = true
  Runme.robots = false       # If true, keep links blocked by robots. If false, delete links blocked by robots. Either way logs to "robotstxt" 
  Runme.port80 = false       # If true, strip ":80" from URLs. Stripping is noisy since every URL added by IABot has it. 
  Runme.wam = true           # Run the wam.awk script
  Runme.straydt = true       # Run the straydt.awk script
  Runme.webcitlong = true    # Run the webcitlong.awk script
  Runme.webcitlongverify = true # Verify existing long format URLs (has big API overhead)
  Runme.freezelong = true    # Run the freezelong.awk script
  Runme.wikiwixlong = true   # Run the wikiwixlong.awk script
  Runme.archiveis = true     # Run the archiveis.awk script
  Runme.citeaddl = false     # Run the citeaddl.awk script
  Runme.newaltarchinx = false # Keep local cache of newaltarch webpages. Should be false unless doing debugging work.
  Runme.replacewikiwix = false # Replace existing wikiwix.com archives with anything else if available otherwise keep in place
  Runme.memento = true       # Check mementoweb.org when looking for alt-archives 
  Runme.fixru = false        # Fix some russian links 1-time

else:

  Runme.fixthespuriousone = false
  Runme.fixtrailingchar = true 
  Runme.fixencodedurl = true 
  Runme.fixemptywayback = false 
  Runme.fixemptyarchive = true 
  Runme.fixdatemismatch = true 
  Runme.fixdoubleurl = true 
  Runme.fixbadstatus = true 
  Runme.fixitems = true
  Runme.api = true
  Runme.replacedeadlink = true
  Runme.robots = false       # If true, keep links blocked by robots. If false, delete links blocked by robots. Either way logs to "robotstxt" 
  Runme.port80 = false       # If true, strip ":80" from URLs. Stripping is noisy since every URL added by IABot has it. 
  Runme.wam = false           # Run the wam.awk script
  Runme.straydt = true       # Run the straydt.awk script
  Runme.webcitlong = true    # Run the webcitlong.awk script
  Runme.webcitlongverify = true # Verify existing long format URLs (has big API overhead)
  Runme.freezelong = false    # Run the freezelong.awk script
  Runme.wikiwixlong = true   # Run the wikiwixlong.awk script
  Runme.archiveis = true    # Run the archiveis.awk script
  Runme.citeaddl = false     # Run the citeaddl.awk script
  Runme.newaltarchinx = false # Keep local cache of newaltarch webpages. Should be false unless doing debugging work.

# _____________________________________ DebugObj

type
  DebugObj* = object
    network*: bool
    api*: bool
    s*: bool
    e*: bool
    process*: bool
    wgetlog*: bool
var Debug*: DebugObj

Debug.network = false
Debug.api = false
Debug.s = false
Debug.e = false
Debug.process = false
Debug.wgetlog = false

if CL.debug == "y":
  Debug.network = true
  Debug.api = true
  Debug.wgetlog = true

# _____________________________________ ProjObj

type
  ProjectObj* = object
    id*: string
    data*: string
    meta*: string
    auth*: string
    index*: string
    indextemp*: string
    wayall*: string
    allwebcite*: string
    allarchiveis*: string
    alllocgov*: string
    allporto*: string
    allstanford*: string
    allarchiveit*: string
    allbibalex*: string
    allvefsafn*: string
    allnatarchivesuk*: string # newwebarchives .. also add in deletenamewrapper and deletenamewrapimp
    alleuropa: string
    allmemory: string
    allpermacc: string
    allproni: string
    allparliament: string
    allukweb: string
    allcanada: string
    allcatalon: string
    allsingapore: string
    allslovene: string
    allfreezepage: string
    allwikiwix: string
    allwebharvest: string
    allnlaau: string
    allyork: string
    alllac: string
    allitems*: string
    newiadate*: string
    newaltarch*: string
    newialink*: string
    newaltarchinx*: string
    manual*: string
    timeout*: string
    apimismatch*: string
    jsonmismatch*: string
    syntaxerror*: string
    phantom*: string
    syslog*: string   
    servicename*: string
    soft404*: string
    soft404i*: string
    bogusapi*: string
    bummer*: string
    robotstxt*: string
    robotsinx*: string
    robotsdir*: string
    docfixes*: string
    cbignore*: string
    critical*: string
    discovered*: string
    wayrm*: string
    wayrmfull*: string
    waydeep*: string
    log404*: string
    logspurone*: string
    logmissprot*: string
    logmissweb*: string
    logemptyarch*: string
    logtrail*: string
    logemptyway*: string
    logencode*: string
    logdeadurl*: string
    logskindeep*: string
    logdoubleurl*: string
    logdatemismatch*: string
    logwronghttps*: string
    logwam*: string
    logstraydt*: string
    logwebcitlong*: string
    logfreezelong*: string
    logwikiwixlong*: string
    logbadstatusother*: string
    logarchiveislong*: string
    logciteaddl*: string
    logbrbug*: string
    lognowikiway*: string
    logiats*: string
    logembway*: string
    logembwebarchive*: string
    logfixswitch*: string
    logfixitems*: string
    logdoublewebarchive*: string
    logpctmagic*: string
    log3slash*: string

var Project*: ProjectObj

# _____________________________________ LinksObj

type
  LinksObj* = object
    origiaurl*: string
    formated*: string
    origurl*: string
    origdate*: string
    mtag*: int
    origencoded*: string
    altarch*: string
    altarchencoded*: string
    altarchdate*: string
    newurl*: string
    newiaurl*: string
    status*: string
    available*: string
    response*: int
    breakpoint*: string
    fragment*: string
    dummy*: string

var WayLink* = newSeq[LinksObj]()
#
# Given object X, return the value of 'field' in string format
#  . bool and int types are converted to string
#
#     for link in WayLink:
#       echo link.fieldvalLO("origurl")
#
proc fieldvalLO(link: LinksObj, field: string): string =
  result = ""
  for name, value in link.fieldPairs:
    when value is bool:
      if name == field:
        return $value
    when value is string:
      if name == field:
        return value
    when value is int:
      if name == field:
        return $value

proc newWayLink*(i: int): bool {.discardable.} =
  WayLink.insert(LinksObj(origiaurl: "none", formated: "none", origurl: "none", origdate: "197001010001", mtag: -1, origencoded: "none", altarch: "none", altarchencoded: "none", altarchdate: "none", newurl: "none", newiaurl: "none", status: "0", available: "false", response: -1, breakpoint: "none", fragment: "", dummy: ""), i)
  WayLink[i].mtag = i


# _____________________________________ MemObj
#
# Memento 
#

type
  MemObj* = object
    closest*: string
    prev*: string
    next*: string
    first*: string
var MemLink*: MemObj

#
# See doc for fieldvalLO 
#
proc fieldvalMO(link: MemObj, field: string): string =
  result = ""
  for name, value in link.fieldPairs:
    when value is bool:
      if name == field:
        return $value
    when value is string:
      if name == field:
        return value
    when value is int:
      if name == field: 
        return $value

# _____________________________________ ProcObj
#
# For process_article(), save/cache results to speed up processing.
#

type
  ProcObj* = object
    citeinsideb: seq[string]
    citeinsidec: int
    articlenoref: string
    articlenorefb: seq[string]
    articlenorefc: int
    weboutsideb: seq[string]
    weboutsidec: int
    citeoutsideb: seq[string]
    citeoutsidec: int
    bareoutsideb: seq[string] 
    bareoutsidec: int
var Proc*: ProcObj

Proc.citeinsidec = -1
Proc.articlenorefc = -1
Proc.weboutsidec = -1
Proc.citeoutsidec = -1
Proc.bareoutsidec = -1

# _______________________________________________________________________  Setup

#
# Document the fixes and revisions made for this project 
#
proc documentation() =

  if not existsFile(Project.docfixes):
    let docs = """

Documentation for Wayback Medic project """ & Project.id & """
 
    # File descriptions:

    index     =    Database index file.
    auth      =    List of articles processed.
    discovered =   List of articles edited by WaybackMedic.
    timeout   =    Server timeout log. The IA API or Wayback Machine.
    bogusapi  =    IA API returned a bogus recommendation (eg. 404/403), page really works.
    manual    =    Articles that need manual processing. Search medic.awk for "Project.manual" for reasons.
    cbignore  =    {{cbignore|bot=medic}} was added to these articles.
    critical  =    Critical system errors.
    jsonmismatch = First and second API request are different lengths. Files are csv.orig and csv2.orig in data directory.
    apimismatch =  API returned +/- number json records originally requested. C.f. data/postfile and data/csv.
    syntaxerror =  Syntax error running a shell command
    phantom     =  Has > 0 GX.changes but no changes in GX.articlework
    syslog    =    Various syslog messages.
    soft404   =    List of soft404 URLs found manually in Alt Archives
    soft404i  =    List of soft404 URLs found manually in Internet Archive 
    servicename =  Archive service name found is unknown. Update list in servicename() in medic.awk.
    log*      =    Log files for fixes made.
    newiadate =    Log of cases when the IA snapshot date changed.
    newaltarch =   Log of cases where alternative archive URL added.
    newaltarchinx  Index to cached copy of webpage that was found.
    newialink  =   Log of cases where new IA link added.
    wayall    =    All IA links found.
    allwebcite=    All WebCite links found.
    allarchiveis=  All Archive.is links found.
    alllocgov =    All loc.gov links found.
    allporto  =    All Portugal links found.
    allstanford=   All Stanford links found.
    allarchiveit=  All Archive-it.org links found.
    allbibalex =   All bibalex.org links found.
    allvefsafn =   All Icelandic Archives links found.
    allnatarchivesuk =   All National Archives (UK) links found. # newwebarchives
    alleuropa = 
    allmemory = 
    allpermacc = 
    allproni = 
    allparliament = 
    allukweb = 
    allcanada = 
    allcatalon = 
    allsingapore = 
    allslovene = 
    allfreezepage = 
    allwikiwix = 
    allwebharvest = 
    allnlaau = 
    allyork = 
    alllac = 
    allitems  =    All archive.org /items/ links.
    wayrm     =    IA links deleted from wikipedia.
    wayrmfull =    Formated file for processing by medic.awk to see why links were removed.
    waydeep  =     Debugging info to monitor behavior of queryapi

    # Function names (Revision) for this project:

"""
    docs >* Project.docfixes

    if existsFile(GX.home & "medic.nim"):
      let c = awk.split(readfile(GX.home & "medic.nim"), a, "\n")
      for i in 0..c - 1:
        if a[i] ~ "[(]Rev[:][ ][A-Z]":
          " " & a[i]  >> Project.docfixes

#
# Clear log files before re-running medic (only in debug mode)
#
proc clearlogs(): bool {.discardable} =

  if CL.debug !~ "y|Y":
    return

  var 
    body = ""
    errC = 0
    command = ""

  let cwd = getCurrentDir()
  setCurrentDir(Project.meta)
  if getCurrentDir() == cwd:
    ("Unable to change directory to " & Project.meta) >* "/dev/stderr"
    return

  CL.name >* (Project.meta & "auth.clearlogs")
  
  if not empty(GX.imp):
    command = "./deletenamewrapimp clearlogs"
  else:
    command = "./deletenamewrapper clearlogs"

  (body, errC) = execCmdEx(command)
  if not empty(strip(body)): 
    body >* "/dev/stderr"

  setCurrentDir(cwd)

#
# Setup -- read project.cfg (or projimp.cfg) paths, and define logfile names
#  . pid was given on command-line
#
proc setup(pid: string): bool {.discardable.} =

  var
    cfgname = "project.cfg"

  if pid ~ "^imp":
    cfgname = "projimp.cfg"

  if existsFile(GX.home & cfgname):
    let c = awk.split(readfile(GX.home & cfgname), a, "\n")
    for i in 0..c - 1:
      if a[i] == "" or substr(a[i],0,1) == "#":    # ignore lines starting with #
        continue
      if a[i] ~ ("^" & pid & "[.]data"):
        if awk.split(a[i],b,"=") > 0:
          Project.data = strip(b[1])
        else:
          Project.data = a[i]
      if a[i] ~ ("^" & pid & "[.]meta"):
        if awk.split(a[i],b,"=") > 0:
          Project.meta = strip(b[1])
        else:
          Project.meta = a[i]
  else:
    "Unable to find " & GX.home & cfgname >* "/dev/stderr"
    quit(QuitFailure)

  if isNil(Project.data) or isNil(Project.meta):
    "Unable to find project info in " & GX.home & cfgname >* "/dev/stderr"
    quit(QuitFailure)

  Project.id = pid
  Project.auth   = Project.meta & "auth"
  Project.index  = Project.meta & "index"
  Project.indextemp  = Project.meta & "index.temp"

  # newwebarchives
  Project.wayall = Project.meta & "wayall"               # List of all IA links
  Project.allwebcite = Project.meta & "allwebcite"       # List of all WebCite links
  Project.allarchiveis = Project.meta & "allarchiveis"   # List of all Archive.is links
  Project.alllocgov = Project.meta & "alllocgov"         # List of all loc.govlinks
  Project.allporto = Project.meta & "allporto"           # List of all Portugal links
  Project.allstanford = Project.meta & "allstanford"     # List of all Stanford links
  Project.allarchiveit = Project.meta & "allarchiveit"   # List of all Archive-it.org links
  Project.allbibalex = Project.meta & "allbibalex"       # List of all Bibalex.org links
  Project.allvefsafn = Project.meta & "allvefsafn"       # List of all Icelandic links
  Project.allnatarchivesuk = Project.meta & "allnatarchivesuk" # List of all National Archives links  
  Project.alleuropa = Project.meta & "alleuropa"
  Project.allmemory = Project.meta & "allmemory"
  Project.allpermacc = Project.meta & "allpermacc"
  Project.allproni = Project.meta & "allproni"
  Project.allparliament = Project.meta & "allparliament"
  Project.allukweb = Project.meta & "allukweb"
  Project.allcanada = Project.meta & "allcanada"
  Project.allcatalon = Project.meta & "allcatalon"
  Project.allsingapore = Project.meta & "allsingapore"
  Project.allslovene = Project.meta & "allslovene"
  Project.allfreezepage = Project.meta & "allfreezepage"
  Project.allwikiwix = Project.meta & "allwikiwix"
  Project.allwebharvest = Project.meta & "allwebharvest"
  Project.allnlaau = Project.meta & "allnlaau"
  Project.allyork = Project.meta & "allyork"
  Project.alllac = Project.meta & "alllac"

  Project.allitems = Project.meta & "allitems"           # List of all archive.org /items/ links
  Project.newiadate = Project.meta & "newiadate"         # Log of cases when the IA snapshot date changed
  Project.newaltarch = Project.meta & "newaltarch"       # Log of cases when alternative archive's are added
  Project.newaltarchinx = Project.meta & "newaltarchinx" # Index to cached copy of found webpage
  Project.newialink = Project.meta & "newialink"         # Log of cases when new IA links are added
  Project.manual = Project.meta & "manual"               # Manual processing needed
  Project.timeout = Project.meta & "timeout"             # Remote server timed out
  Project.apimismatch = Project.meta & "apimismatch"     # API returned fewer records than sent. name|sent|received
  Project.jsonmismatch = Project.meta & "jsonmismatch"   # API returned different size csv files. name|csv1|csv2
  Project.syntaxerror = Project.meta & "syntaxerror"     # Syntax error running a shell command
  Project.phantom = Project.meta & "phantom"             # Has > 0 GX.changes but no changes in GX.articlework
  Project.syslog = Project.meta & "syslog"               # Syslog messages
  Project.soft404 = GX.home & "static/" & "soft404.bm"   # Soft404 URLs found manually in Alt Archives
  Project.soft404i = GX.home & "static/" & "soft404i.bm" # Soft404 URLs found manually in Internet Archive
  Project.servicename = Project.meta & "servicename"     # Archive service name found is unknown. Update servicename() in medic.awk
  Project.bogusapi = Project.meta & "bogusapi"           # IA API returned a bogus recommendation. Page actually works.
  Project.bummer = Project.meta & "bummer"               # Found a bummer page.
  Project.robotstxt = Project.meta & "robotstext"        # Found a robots.txt block page
  Project.robotsinx = Project.meta & "robotsinx"         # Index of results of robots.txt for root domain at archive.org
  Project.robotsdir = Project.meta & "robotsdir/"        # Directory containing robots.txt file downloads
  # Project.robotsdir = GX.ramdir & Project.id & "/robotsdir"
  Project.docfixes = Project.meta & "Documentation"      # Documentation / fix revisions for this project
  Project.cbignore = Project.meta & "cbignore"           # {{cbignore|bot=medic}} was added to these articles
  Project.critical = Project.meta & "critical"           # Critical system errors
  Project.discovered = Project.meta & "discovered"       # Articles that have changes made (for import to AWB)
  Project.wayrm  = Project.meta & "wayrm"                # IA links deleted from articles
  Project.wayrmfull  = Project.meta & "wayrmfull"        # Formated to be run through medic.awk for testing
  Project.waydeep = Project.meta & "waydeep"             # Log special cases to monitor behavior of algo
  Project.log404 = Project.meta & "log404"
  Project.logspurone = Project.meta & "logspurone"
  Project.logmissprot = Project.meta & "logmissprot"
  Project.logmissweb = Project.meta & "logmissweb"
  Project.logemptyarch = Project.meta & "logemptyarch"
  Project.logtrail = Project.meta & "logtrail"
  Project.logemptyway = Project.meta & "logemptyway"
  Project.logencode = Project.meta & "logencode"
  Project.logdeadurl = Project.meta & "logdeadurl"
  Project.logskindeep = Project.meta & "logskindeep"
  Project.logdoubleurl = Project.meta & "logdoubleurl"
  Project.logdatemismatch = Project.meta & "logdatemismatch"
  Project.logwronghttps = Project.meta & "logwronghttps"
  Project.logwam = Project.meta & "logwam"
  Project.logstraydt = Project.meta & "logstraydt"
  Project.logwebcitlong = Project.meta & "logwebcitlong"
  Project.logfreezelong = Project.meta & "logfreezelong"
  Project.logwikiwixlong = Project.meta & "logwikiwixlong"
  Project.logbadstatusother = Project.meta & "logbadstatusother"
  Project.logarchiveislong = Project.meta & "logarchiveislong"
  Project.logciteaddl = Project.meta & "logciteaddl"
  Project.lognowikiway = Project.meta & "lognowikiway"
  Project.logiats = Project.meta & "logiats"
  Project.logembway = Project.meta & "logembway"
  Project.logembwebarchive = Project.meta & "logembwebarchive"
  Project.logfixswitch = Project.meta & "logfixswitch"
  Project.logfixitems = Project.meta & "logfixitems"
  Project.logdoublewebarchive = Project.meta & "logdoublewebarchive"
  Project.logpctmagic = Project.meta & "logpctmagic"
  Project.log3slash = Project.meta & "log3slash"

  documentation()

  # Slimer (ie. Firefox) headless browser requires a Firefox version < 60.0
  putEnv("SLIMERJSLAUNCHER","/home/adminuser/firefox58/firefox")

 # Load ~/meta/xxx/robotsinx
 # if existsFile(Project.robotsinx):
 #   GX.robotsinx = readfile(Project.robotsinx)
 # else:
 #   GX.robotsinx = ""

 # Create robotsdir 
  if not existsFile(Project.robotsdir):
    createDir(Project.robotsdir)
#  if not existsFile(Project.meta & "robotsdir") and existsFile(Project.robotsdir):
#    createSymlink(Project.robotsdir, Project.meta & "robotsdir")
#    Project.robotsdir = Project.meta & "robotsdir/"    

 # Load ~/static/soft404.bm files and split into global array GX.soft404a
  if existsFile(Project.soft404):
    GX.soft404 = readfile(Project.soft404)
    GX.soft404c = awk.split(GX.soft404, GX.soft404a, "\n")
    GX.soft404 = ""
    if GX.soft404c > 0: 
      for i in 0..GX.soft404c - 1:
        if GX.soft404a[i] ~ "(?i)(^http)":
          GX.soft404a[i] = strip(GX.soft404a[i])
          gsub("(?i)(https[:])", "http:", GX.soft404a[i])
        else:
          GX.soft404a[i] = ""
  else:
    if Debug.network:
      echo Project.soft404 & " can't be found!"
    GX.soft404 = ""
  if existsFile(Project.soft404i):
    GX.soft404i = readfile(Project.soft404i)
    GX.soft404ic = awk.split(GX.soft404i, GX.soft404ia, "\n")
    GX.soft404i = ""
    if GX.soft404ic > 0: 
      for i in 0..GX.soft404ic - 1:
        if GX.soft404ia[i] ~ "(?i)(^http)":
          GX.soft404ia[i] = strip(GX.soft404ia[i])
          gsub("(?i)(https[:])", "http:", GX.soft404ia[i])
        else:
          GX.soft404ia[i] = ""
  else:
    GX.soft404i = ""

  clearlogs()


