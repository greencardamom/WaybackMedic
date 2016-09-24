discard """ 

The MIT License (MIT)

Copyright (c) 2016 by User:Green Cardamom (at en.wikipedia.org)

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
var CL*: CLObj

let docOptDoc = """

WaybackMedic

Usage: medic
  medic -p <project> -n <name> -s <sourcefile> -d <debugopt>
  medic (-h | --help)
  medic (-v | --version)

Options:
  -p            WaybackMedic project ID. Required.
  -n            Wikipedia article name. Required.
  -s            Wikipedia source file. Required.
  -d            Debug
  -h --help     Show this screen.
  -v --version  Show version.
"""

let docOptArgs = docopt(docOptDoc, version = "WaybackMedic (nim) 0.03")

#echo docOptArgs

if docOptArgs["-p"]:
  CL.project = $docOptArgs["<project>"] 
if docOptArgs["-n"]:
  CL.name = $docOptArgs["<name>"]        
if docOptArgs["-s"]:
  CL.sourcefile = $docOptArgs["<sourcefile>"]
if docOptArgs["-d"]:
  CL.debug = $docOptArgs["<debugopt>"]



if len(CL.project) == 0 or len(CL.name) == 0 or len(CL.sourcefile) == 0:
  "medic -h for help" >* "/dev/stderr"
  quit(QuitSuccess)

if not existsFile(CL.sourcefile):
  "Unable to find sourcefile " & CL.sourcefile >* "/dev/stderr"
  quit(QuitSuccess)

if len(CL.debug) == 0:
  CL.debug = "n"


# _______________________________________________________________________________  Global var declaration

type
  GXObj* = object
    home: string           # home directory
    agent: string          # wget agent string
    wgetopts: string       # wget options
    datetype: string       # Date format type (dmy or myd) obtained from article templates {{use dmy}} and {{use mdy}}
    datetypeexists: bool   # If a date type template exists in the article or not
    id: int                # running count of number of links found .. used to index WayLink[id]
    article: string        # original copy of article (stays unchanged)
    articlework: string    # working copy of article
    datadir: string        # full path/name of data directory
    wid: string            # data directory id eg. wm-20160503034
    cx: int
    changes: int           # number of changes (edits) made to article
    redirloop: int         # flag used in api
    unavailableloop: int   # flag used in api
    numfound: int          # number of links found in article
    ver: string            # version

var GX*: GXObj

# Directories should have a trailing slash
GX.home = "/home/adminuser/wmnim/wm2/"

# Version. This is used in skindeep()
GX.ver = "WaybackMedic2"

# String included with http requests shows in remote logs. Name of program, contact info and name of article processed. 
if CL.name !~ "'|`|\"|’":  # Don't add name with these characters as it's too complicated to escape on shell
  GX.agent = "http://en.wikipedia.org/wiki/User:Green_Cardamom/WaybackMedic2 ('" & CL.name & "')"
else:
  GX.agent = "http://en.wikipedia.org/wiki/User:Green_Cardamom/WaybackMedic2"

# Default wget options (include lead/trail spaces)
GX.wgetopts = " --no-cookies --ignore-length --user-agent=\"" & GX.agent & "\" --no-check-certificate --tries=2 --timeout=110 --waitretry=10 --retry-connrefused "

GX.datetype = "mdy"
GX.datetypeexists = false
GX.id = -1
GX.changes = 0
GX.redirloop = 0
GX.unavailableloop = 0

GX.article = readfile(CL.sourcefile)
#GX.article = readfile("/home/adminuser/cbdb/data/cb20151231-20160304.80001-91992/wm-04011825312457/article.txt")
#GX.article = readfile("test.0")
GX.articlework = GX.article

GX.datadir = dirname(CL.sourcefile)
GX.cx = awk.split(GX.datadir, GXax, "/")
GX.wid = GXax[GX.cx - 2]
"" >* "/tmp/" & GX.wid                                 # Directory ID for tracking running/stuck process


# _______________________________________________________________________________  Enable/Disable features

type
  RunmeObj* = object
    fixthespuriousone: bool          
    fixtrailingchar: bool
    fixencodedurl: bool
    fixemptywayback: bool
    fixemptyarchive: bool
    fixdatemismatch: bool
    fixbadstatus: bool
    api: bool

var Runme*: RunmeObj

# Set to "false" to disable features

Runme.fixthespuriousone = true
Runme.fixtrailingchar = true
Runme.fixencodedurl = true
Runme.fixemptywayback = true
Runme.fixemptyarchive = true
Runme.fixdatemismatch = true
Runme.fixbadstatus = true
Runme.api = true

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
    newiadate*: string
    newaltarch*: string
    manual*: string
    timeout*: string
    apimismatch*: string
    jsonmismatch*: string
    syntaxerror*: string
    servicename*: string
    bogusapi*: string
    bummer*: string
    docfixes*: string
    cbignore*: string
    critical*: string
    discovered*: string
    wayrm*: string
    wayrmfull*: string
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
  WayLink.insert(LinksObj(origiaurl: "none", formated: "none", origurl: "none", origdate: "197001010001", mtag: -1, origencoded: "none", altarch: "none", altarchencoded: "none", altarchdate: "none", newurl: "none", newiaurl: "none", status: "0", available: "false"), i)
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
# For process_article(), save results to speed up processing.
#

type
  ProcObj* = object
    citeinsideb: seq[string]
    citeinsidec: int
    articlenoref: string
    articlenorefb: seq[string]
    articlenorefc: int
    citeoutsideb: seq[string]
    citeoutsidec: int
    bareoutsideb: seq[string] 
    bareoutsidec: int
var Proc*: ProcObj

Proc.citeinsidec = -1
Proc.articlenorefc = -1
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
    servicename =  Archive service name found is unknown. Update list in servicename() in medic.awk.
    log*      =    Log files for fixes made.
    newiadate =    Log of cases when the IA snapshot date changed.
    newaltarch =   Log of cases where alternative archive URL added.
    wayall    =    All IA links found.
    wayrm     =    IA links deleted from wikipedia.
    wayrmfull =    Formated file for processing by medic.awk to see why links were removed.

    # Function names (Revision) for this project:

"""
    docs >* Project.docfixes

    let c = awk.split(readfile(GX.home & "medic.nim"), a, "\n")
    for i in 0..c - 1:
      if a[i] ~ "[(]Rev[:][ ][A-Z]":
        " " & a[i]  >> Project.docfixes

#
# Setup -- read project.cfg paths, and define logfile names
#  . pid was given on command-line
#
proc setup(pid: string): bool {.discardable.} =

  if existsFile(GX.home & "project.cfg"):
    var c = awk.split(readfile(GX.home & "project.cfg"), a, "\n")
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
    "Unable to find " & GX.home & "project.cfg" >* "/dev/stderr"
    quit(QuitFailure)

  if isNil(Project.data) or isNil(Project.meta):
    "Unable to find project info in " & GX.home & "project.cfg" >* "/dev/stderr"
    quit(QuitFailure)

  Project.id = pid
  Project.auth   = Project.meta & "auth"
  Project.index  = Project.meta & "index"
  Project.indextemp  = Project.meta & "index.temp"
  Project.wayall = Project.meta & "wayall"               # List of all IA links
  Project.newiadate = Project.meta & "newiadate"         # Log of cases when the IA snapshot date changed
  Project.newaltarch = Project.meta & "newaltarch"       # Log of cases when alternative archive's are added
  Project.manual = Project.meta & "manual"               # Manual processing needed
  Project.timeout = Project.meta & "timeout"             # Remote server timed out
  Project.apimismatch = Project.meta & "apimismatch"     # API returned fewer records than sent. name|sent|received
  Project.jsonmismatch = Project.meta & "jsonmismatch"   # API returned different size csv files. name|csv1|csv2
  Project.syntaxerror = Project.meta & "syntaxerror"     # Syntax error running a shell command
  Project.servicename = Project.meta & "servicename"     # Archive service name found is unknown. Update servicename() in medic.awk
  Project.bogusapi = Project.meta & "bogusapi"           # IA API returned a bogus recommendation. Page actually works.
  Project.bummer = Project.meta & "bummer"               # Found a bummer page.
  Project.docfixes = Project.meta & "Documentation"      # Documentation / fix revisions for this project
  Project.cbignore = Project.meta & "cbignore"           # {{cbignore|bot=medic}} was added to these articles
  Project.critical = Project.meta & "critical"           # Critical system errors
  Project.discovered = Project.meta & "discovered"       # Articles that have changes made (for import to AWB)
  Project.wayrm  = Project.meta & "wayrm"                # IA links deleted from articles
  Project.wayrmfull  = Project.meta & "wayrmfull"        # Formated to be run through medic.awk for testing
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

  documentation()


