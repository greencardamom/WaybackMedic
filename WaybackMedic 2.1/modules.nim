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
# Convert short-form WebCite URLs to long-form using webcitlong.awk (must be run before fixstraydt() )
#
proc fixwebcitlong(longverify: bool): string {.discardable} =

  var
    body = ""
    verify = ""
    errC = 0
    webcitlongcount = 0
    articlename = GX.workfile

  if Runme.webcitlong != true:
    return

  if longverify == true:
    verify = " -v"

  if not GX.webciteok:  # API down
    return

  let command = GX.webcitlong & " -s " & shquote(articlename) & " -n " & shquote(CL.name) & " -l " & shquote(Project.meta) & verify

  (body, errC) = execCmdEx(command)

  webcitlongcount = parseInt(strip(body))

  if webcitlongcount > 0:

    gsubs("workarticle.txt", "article.webcitlong.txt", articlename)

    if existsFile(articlename):
      GX.articlework = readfile(articlename)
    else:
      return

    if len(GX.articlework) < 10:
      GX.articlework = GX.article
      sendlog(Project.logwebcitlong, CL.name & " ---- error " & body & " ", "fixwebcitlong1")
      return

    GX.articlework >* GX.workfile

    GX.esformat = GX.esformat + webcitlongcount
    incchanges(webcitlongcount, "fixwebcitlong")

    # logging done via webcitlong.awk
    # sendlog(Project.logwebcitlong, CL.name & " ---- " & $webcitlongcount & " ", "fixwebcitlong2")

#
# Convert short-form wikiwix.com URLs to long-form using wikiwix.awk (must be run before fixstraydt() )
#
proc fixwikiwixlong(): string {.discardable} =

  var
    body = ""
    errC = 0
    wikiwixlongcount = 0
    articlename = GX.workfile

  if Runme.wikiwixlong != true:
    return

  let command = GX.wikiwixlong & " -s " & shquote(articlename) & " -n " & shquote(CL.name) & " -l " & shquote(Project.meta)

  (body, errC) = execCmdEx(command)

  wikiwixlongcount = parseInt(strip(body))

  if wikiwixlongcount > 0:

    gsubs("workarticle.txt", "article.wikiwixlong.txt", articlename)

    if existsFile(articlename):
      GX.articlework = readfile(articlename)
    else:
      return

    if len(GX.articlework) < 10:
      GX.articlework = GX.article
      sendlog(Project.logwikiwixlong, CL.name & " ---- error " & body & " ", "fixwikiwixlong1")
      return

    GX.articlework >* GX.workfile

    GX.esformat = GX.esformat + wikiwixlongcount
    incchanges(wikiwixlongcount, "fixwikiwixlong")

    # logging done via wikiwixlong.awk
    # sendlog(Project.logwikiwixlong, CL.name & " ---- " & $wikiwixlongcount & " ", "fixwikiwixlong2")

#
# Convert short-form freezepage.com URLs to long-form using freezelong.awk (must be run before fixstraydt() )
#
proc fixfreezelong(): string {.discardable} =

  var
    body = ""
    errC = 0
    freezelongcount = 0
    articlename = GX.workfile

  if Runme.freezelong != true:
    return

  let command = GX.freezelong & " -s " & shquote(articlename) & " -n " & shquote(CL.name) & " -l " & shquote(Project.meta)

  (body, errC) = execCmdEx(command)

  freezelongcount = parseInt(strip(body))

  if freezelongcount > 0:

    gsubs("workarticle.txt", "article.freezelong.txt", articlename)

    if existsFile(articlename):
      GX.articlework = readfile(articlename)
    else:
      return

    if len(GX.articlework) < 10:
      GX.articlework = GX.article
      sendlog(Project.logfreezelong, CL.name & " ---- error " & body & " ", "fixfreezelong1")
      return

    GX.articlework >* GX.workfile

    GX.esformat = GX.esformat + freezelongcount
    incchanges(freezelongcount, "fixfreezelong")

    # logging done via freezelong.awk
    # sendlog(Project.logfreezelong, CL.name & " ---- " & $freezelongcount & " ", "fixfreezelong2")

#
# Merge {{cite archives}} to {{webarchive}}
#
proc fixciteaddl(): string {.discardable} =

  var
    body = ""
    errC = 0
    citeaddlcount = 0
    articlename = GX.workfile

  if Runme.citeaddl != true:
    return

  let command = GX.citeaddl & " -s " & shquote(articlename) & " -n " & shquote(CL.name) & " -l " & shquote(Project.meta)

  (body, errC) = execCmdEx(command)

  citeaddlcount = parseInt(strip(body))

  if citeaddlcount > 0:

    gsubs("workarticle.txt", "article.citeaddl.txt", articlename)

    if existsFile(articlename):
      GX.articlework = readfile(articlename)
    else:
      return

    if len(GX.articlework) < 10:
      GX.articlework = GX.article
      sendlog(Project.logciteaddl, CL.name & " ---- error " & body & " ", "fixciteaddl1")
      return

    GX.articlework >* GX.workfile

    GX.esformat = GX.esformat + citeaddlcount
    incchanges(citeaddlcount, "fixciteaddl")


    # logging done via citeaddl.awk
    # sendlog(Project.logciteaddl, CL.name & " ---- " & $citeaddlcount & " ", "fixciteaddl2")

#
# Convert short-form Archive.is URLs to long-form using archiveis.awk (must be run before fixstraydt() )
#
proc fixarchiveis(): string {.discardable} =

  var
    body = ""
    errC = 0
    archiveiscount = 0
    articlename = GX.workfile

  if Runme.archiveis != true:
    return

  let command = GX.archiveis & " -s " & shquote(articlename) & " -n " & shquote(CL.name) & " -l " & shquote(Project.meta)

  (body, errC) = execCmdEx(command)

  archiveiscount = parseInt(strip(body))

  if archiveiscount > 0:

    gsubs("workarticle.txt", "article.archiveis.txt", articlename)

    if existsFile(articlename):
      GX.articlework = readfile(articlename)
    else:
      return

    if len(GX.articlework) < 10:
      GX.articlework = GX.article
      sendlog(Project.logarchiveislong, CL.name & " ---- error " & body & " ", "fixarchiveis1")
      return

    GX.articlework >* GX.workfile

    GX.esformat = GX.esformat + archiveiscount
    incchanges(archiveiscount, "fixarchiveis")

    # normal logging done via archiveis.awk
    # sendlog(Project.logarchiveislong, CL.name & " ---- " & $archiveiscount & " ", "fixarchiveis2")


#
# Fix stray dead link templates using straydt.awk (must be run after fixwebcitlong(), fixarchiveis() and fixciteaddl() )
#
proc fixstraydt(): string {.discardable} =

  var
    body = ""
    errC = 0
    straydtcount = 0
    articlename = GX.workfile

  if Runme.straydt != true:
    return

  let command = GX.straydt & " -s " & shquote(articlename) & " -n " & shquote(CL.name) & " -l " & shquote(Project.meta)

  (body, errC) = execCmdEx(command)

  straydtcount = parseInt(strip(body))

  if straydtcount > 0:

    gsubs("workarticle.txt", "article.straydt.txt", articlename)

    if existsFile(articlename):
      GX.articlework = readfile(articlename)
    else:
      return

    if len(GX.articlework) < 10:
      GX.articlework = GX.article
      sendlog(Project.logstraydt, CL.name & " ---- error " & body & " ", "fixstraydt1")
      return

    GX.articlework >* GX.workfile

    GX.esformat = GX.esformat + straydtcount
    incchanges(straydtcount, "fixstraydt")

    # logging done via straydt.awk
    # sendlog(Project.logstraydt, CL.name & " ---- " & $straydtcount & " ", "fixstraydt2")


#
# Fix {{webarchive}} merge using external script wam.awk
#
proc fixwam(): string {.discardable} =

  var
    body = ""
    errC = 0
    wamcount = 0
    articlename = GX.workfile

  if Runme.wam != true:
    return

  let command = GX.wam & " -s " & shquote(articlename) & " -n " & shquote(CL.name) & " -l " & shquote(Project.meta)

  (body, errC) = execCmdEx(command)

  wamcount = parseInt(strip(body))

  if wamcount > 0:

    gsubs("workarticle.txt", "article.wam.txt", articlename)

    if existsFile(articlename):
      GX.articlework = readfile(articlename)
    else:
      return

    if len(GX.articlework) < 10:
      GX.articlework = GX.article
      sendlog(Project.logwam, CL.name & " ---- error " & body & " ", "fixwam1")
      return

    GX.articlework >* GX.workfile

    GX.esformat = GX.esformat + wamcount
    incchanges(wamcount, "fixwam")

    # logging done via wam.awk
    # sendlog(Project.logwam, CL.name & " ---- " & $wamcount & " ", "fixwam2")


