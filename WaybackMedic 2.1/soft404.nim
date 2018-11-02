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
# From archive.is webmaster:
#
# I also added a flag :showstatus to show extra information on the page
# For example http://archive.is/AVCOv:showstatus shows that http code
# was 403 and the heuristics content analyzer things that it is soft 404
# (it does not depend on the http code, solely on the content)
#
# Sometimes it guess soft404 when http-code is 200:
# http://archive.is/2Ehff:showstatus
#
# Sometimes the content analyzer fails: http://archive.is/PPB2z:showstatus
#

proc soft404ais*(shorturl: string): string =

  var
    xmlin,status = ""
    reason = ""
    soft = false
    errC = 0

  (xmlin, errC) = archiveispage(shorturl & ":showstatus")
  if empty(xmlin):
    return "Blank page 17.b"

  gsub("[ ]|\\n", "", xmlin)

  if match(xmlin, "middle\"[>]httpcode[=][0-9]+[<]", status) > 0:
    gsub("middle\"[>]httpcode[=]", "", status)
    gsub("[<]", "", status)

  # >soft404/*reason=
  if match(xmlin, "[>]soft404[/]") > 0:
    soft = true
    reason = "soft404ais"
  
  if status ~ "^[4-9]":
    soft = true
    if empty(reason):
      reason = "Status " & status
    else:
      reason = "Status " & status & " / " & reason 

  # sendlog(Project.syslog, CL.name, "status=" & status & " reason=" & " soft404=" & $soft)
  sed("soft404ais: status=" & status & " reason=" & " soft404=" & $soft, Debug.network)

  if soft:
    return reason
  else:
    return "OK"  

#
# Soft404 detector. This can be included in any program not just Medic. See wayback_soft404() and archiveis_soft404() for how to setup
#  return "OK" is nothing detected. 
#  Otherwise return a string showing type of soft404. 
#  It might also return a blank string in "Pure image" case.
#  origurl should be " " in most cases.
#  source should be "api" in most cases.
#
proc soft404(url, title, bodyplain, bodyHTML, origurl, source: string): string =

  var
    body = ""
    lbh, lbp = 0
    maxBlank = 900  # max size of plaintext (bytes) to be considered a blank page

  # Pure image
  if url ~ "(?i)[.](jpg|gif|png|pdf|ppt|pps|doc|mp3|mp4|flv|wav|xls|swf|txt|ram|xlsx)$":
    return 

  lbh = len(bodyHTML)
  lbp = len(bodyplain)                       
  if lbp < lbh:        
    body = bodyplain
  else:
    body = bodyHTML

  # Blank page
  if lbp < lbh:               
    if lbp < maxBlank and lbp > 0:
      return "Blank page 17.a (" & $lbp & ")"

  # key words in page title .. will have some false positives

  if title ~ "(?i)([ .,-]|^)(301|302|400|401|403|404|405|406|408|409|410|415|416|417|429|500|502|503|504|508|520|521)([ ,.-]|$|error)":
    return "Check 1.a"
  if title ~ "(?i)(^|[ ])(wayback|internet archive|unavailable|redirect|robots|error|uknown|noth?i?n?g?[ ]?(found|available|here)|not[ ]be[ ]found)([ ]|$)":
    return "Check 2.a"
  if title ~ "(?i)([ ]|^)((can[']t|couldn[']t|didn[']t|unable to|cannot|not) (find|found))([ ]|$)":
    return "Check 3.a"
  if title ~ "(?i)(Доступ запрещен|Страница не найдена|Pagina inexistenta|无法找到该页|서비스 이용에 불편을 드려 대단히 죄송합니다)":
    return "Check 3.b"
  if title ~ "(?i)((log|sign)[- ]?in|^error[:]? forbidden|There was an error|access forbidden|^Error|Site off[- ]?line|site disabled|Whoops)":
    return "Check 3.c"
  if title ~ "(?i)(p[áa]gina no encontrada|No se encontr[óo] la p[áa]gina|[ ]erro[ ]|[ ]errato[ ])": 
    return "Check 4.a"
  if url ~ "(?i)(temporarily[-]?unavailable|login$)":
    return "Check 4.b"
  if title ~ "(?i)(Page non trouv[ée]e)": 
    return "Check 4.c"
  if title ~ "(?i)(No content found at the requested URL)": 
    return "Check 4.d"
  if contains(title, "GeoCities: Get a web site with easy-to-use site building tools"): 
    return "Check 5.00"
  if contains(body, "Leider ist die Website GeoCities, auf die Sie zugreifen wollten, nicht mehr verfügbar"): 
    return "Check 5.01"
  if contains(title, "ESPN Video"):
    return "Check 5.03"
  if contains(url, "espn.go.com/video"):
    return "Check 5.04"
  if contains(title, "Indiatimes: India News, Business, Movies, Cricket, Shopping, more"):
    return "Check 5.05"
  if contains(body, "the GeoCities web site you were trying to reach is no longer available"): 
    return "Check 5.06"
  if contains(body, "We can't find a Walmart.com page that matches your request"):
    return "Check 5.07"
  if url ~ "(?i)(a-league[.]com[.]au[/]Scoreboard[_]HAL)":
    return "Check 5.08"
  if contains(body, "アクセスしたページは、以下のいずれかの理由で閲覧できませ"):  # www.geocities.jp
    return "Check 5.09"
  if body ~ "(?i)(Hulu requires Flash Player)":
    return "Check 5.10"
  if body ~ "(?i)(Default Web Site Page If you feel)":
    return "Check 5.11"
  if url ~ "(?i)(jpost[.]com)" and strip(url) ~ "ShowFull$":
    return "Check 5.12"

  if body ~ "(?i)(Server Error in '[^']*' Application)":
    return "Check 5.1.0"

  if body ~ "(?i)(application error|stack trace)" and body ~ "(?i)(mysql)":
    return "Check 5.1.2"

  when compiles(GX.iare):
    if source == "api":  # Only filter Wayback/ArchiveIS redirects from API sourced urls
      if bodyHTML ~ "(?i)([>][ ]{0,}redirected from)" and bodyHTML ~ "(?i)([>][ ]{0,}via)" and bodyHTML ~ GX.iare:
        return "Check 6.0"

  if url ~ "blogspot[.]com" and len(bodyHTML) < 50000:
    return "Check 6.1"

 # Domain forsale sites
  if bodyHTML ~ "(trade[.]realtime[.]at|acquirethisname[.]com|domain[-]holding[.]co[.]uk|auction[.]nic[.]ru|dsultra[.]com|adimg[.]uimserv[.]net|www[.]sedo[.]com)":
    return "Check 6.20"
  if title ~ "domain sale offer":
    return "Check 6.21"
  if body ~ "(?i)((the|this) domain)" and body ~ "(?i)(may be for sale)":
    return "Check 6.22"
  if body ~ "(?i)(This domain name has just been registered)" and body ~ "(?i)(why is this page displayed)":
    return "Check 6.23"
  if body ~ "(?i)(below are sponsored listings for goods and services related to)":
    return "Check 6.24"
  if body ~ "(?i)(This domain name expired)":
    return "Check 6.25"
  if body ~ "(?i)(Sponsored Listings displayed above are served automatically by a third party)":
    return "Check 6.26"

  if body ~ "(?i)((page|article|url|resource|file|content|document|object|item|video) (isn[']t|is not|wasn[']t|was not|not) (unavailable|available|here|online|live|(be )?found|find|located|delivered)|unable to (find|locate) the (page|article|url|resource|file|document|content|object|item|video)|connection timed out)":
    if url !~ "amazon.com|amzn.com":
      return "Check 7"

  if bodyHTML ~ "(?i)(invalid story key|liInvalidStoryKey)" and origurl ~ "news[.]rgj[.]com":
    return "Check 7.1"

  if body ~ "(?i)((page|article|url|resource|file|content|document|object|item|video) (could not|can not|cannot|couldn[']?t|can[']?t) be displayed|not acceptable[!]|(couldn[']?t|can[']?t|cannot|could not) (find|locate) (the )?(page|article|url|resource|file|content|document|object|item|video|(what (you[']re|you are) looking for)))":
    return "Check 8.1"

  if body ~ "(?i)((page|article|url|resource|file|content|document|object|item|video) is (temporary|temporarily|currently|permanently) (unavailable|down|off[- ]line))":
    return "Check 8.2"

  if body ~ "(?i)((page|article|url|resource|file|wordpress[.]com|content|document|object|item|video)[,]? (does not|is not|isn[']t|is no longer|no longer) (available|here|online|live|exist[s]?)|(page|article|url|resource|file) (that)?[ ]?(you|you[']ve|you have)?[ ]?requested[ ](does not exist|(could not|can't|couldn[']t|cannot) be (unavailable|available|here|online|live|found|find|located|delivered)|(was|is) not (unavailable|available|here|online|live|(be )?found|find|located|delivered)|(is|was) no longer (unavailable|available|here|online|live|(be )?found|find|located|delivered)|((was|is) either unavailable or you need permission|may no longer exist) ) )":
    return "Check 9"

  if body ~ "(?i)((page|article|url|resource|file|content|document|object|item|video) (that)?[ ]?(you[']re|you are|you were) (looking for|trying to access) (can[']t|cannot|could not|can not|is not|isn[']t|is no longer|doesn't exist|requires a login|was not found|is unavailable|has either been)[ ]?(be found|located|available|here|online|live)?)":
    return "Check 9.1"

  if body ~ "(?i)((could not|can not|cannot|couldn[']?t|can[']?t) (find|locate) (that |the )?(page|article|url|resource|file|content|document|object|item|video) (you[']re|you are|you were) (look|request))":
    return "Check 9.2"

  if body ~ "(?i)((page|article|url|resource|file|content|document|object|item|video) (that)?[ ]?(you|you[']ve|you have)?[ ]?requested (was not|wasn[']t|could not be|couldn't be|is not|is no longer|isn[']t|is currently) (unavailable|available|here|online|live|(be )?found|located|delivered))":
    return "Check 9.3"

  if body ~ "(?i)((page|article|url|resource|file|content|document|object|item|video) you (were|are) looking f?o?r?[ ]?((has been|was|is) moved|doesn[']t exist|(was not|wasn't) (unavailable|available|here|online|live|(be )?found|find|located|delivered))|in this blog does not exist|(could not|couldn't|cannot) be (unavailable|available|here|online|live|(be )?found|find|located|delivered)|(page|article|url|resource|file) you (are|were) trying to access (is no longer available|(could not|couldn't|cannot) be (unavailable|available|here|online|live|(be )?found|find|located|delivered))|the (page|article|url|resource|file) you (were|are) looking for[.]|you are looking for something that is not (unavailable|available|here|online|live|(be )?found|find|located|delivered))":
    return "Check 10"

  if body ~ "(?i)((page|article|url|resource|file|content|document|object|item|video) (which )?(no longer|doesn't|does not) (available|here|online|live|(be )?found|find|located|exist))":
    return "Check 10.1"

  if bodyHTML ~ "(?i)(https? 40[4321]|missing page [(]404[)]|404[- ]?error|error[e]? 404|not found [-]?[ ]?404|404 [-]?[ ]?not found|welp[.]? 404|403 [-]?[ ]?access forbidden|Ошибка 404|Fehler 404|Greška 404|404 No encontrado|Грешка 404|HTTP와 404|HTTP їА·щ 404|404 page|404 HIBA)":
    return "Check 11"
 
  if body ~ "(?i)(not authorized to (access|view) this (page|article|url|resource|file|content|document|object|item|video)|you have tried to reach a (page|article|url|resource|file|content|document|object|item|video) that (doesn't|does not) exist|(page|article|url|resource|file|content|document|object|item|video) is not currently available|This Windows Live Space is no longer available|error occurred while processing your request|Compilation failed[:] nothing to repeat at offset|(page|article|url|resource|file|content|document|object|item|video) may have been moved or deleted|(page|article|url|resource|file|content|document|object|item|video) You Are Looking For Is (Not|no longer) (Available|here)|link you (just )?clicked does not seem to go where we thought it would|(page|article|url|resource|file|content|document|object|item|video) you were looking could not be (unavailable|available|here|online|live|(be )?found|find|located|delivered)|following document could not be (unavailable|available|here|online|live|(be )?found|find|located|delivered)|There is currently no text in this (page|article|url|resource|file|content|document|object|item|video)|web site you are accessing has experienced an unexpected error|(page|article|url|resource|file|content|document|object|item|video) is either no longer available or has been|(not able|unable) to (find|locate) (that|the) (page|article|url|resource|file|content|document|object|item|video)|temporary Parking (page|article|url|resource|file|content|document|object|item|video))":
    return "Check 11.1"

  if body ~ "(?i)((page|article|url|resource|file|content|document|object|item|video) you (have )?requeste?d? (does not|was not|could not be|can not be|cannot be|can[']t be) (unavailable|available|here|online|live|found|find|located|exist|delivered)|cannot locate the link to the (page|article|url|resource|file|content|document|object|item|video))":
    return "Check 11.2"
 
  if body ~ "(?i)(You need to have a recent version of flash installed|browser isn't equipped to work|browser you are using is not fully supported|there are no items? to display)":
    return "Check 11.3"
 
  if body ~ "(?i)(sorry[,]? but that (page|article|url|resource|file|content|document|object|item|video) (doesn’t|does not) exist|No Such URL at This Domain|URL[,]? you requesting is not reachable|(page|article|url|resource|file|content|document|object|item|video) you have requested, as typed, does not exist at this address|(page|article|url|resource|file|content|document|object|item|video) you have requested is restricted to registered users|We can’t seem to (find|locate) the (page|article|url|resource|file|content|document|object|item|video) you’re looking for|(page|article|url|resource|file|content|document|object|item|video) you are looking for has either moved during our website makeover or is no longer available|Sorry[,]? the (page|article|url|resource|file|content|document|object|item|video) you requested could not be (unavailable|available|here|online|live|(be )?found|find|located|delivered)|we (can't|cannot) (find|locate) what you were looking for|(page|article|url|resource|file|content|document|object|item|video) you are looking for has been removed, had its name changed, or is temporarily unavailable)":
    return "Check 11.4"
 
  if body ~ "(?i)((page|module) non trouv[ée][e]?|archivo no encontrado|pagina non trovata|página não encontrada|erreur 404|något saknas|(seite|datei) nicht gefunden|pagina niet gevonden|Blog nicht gefunden|Hittar inte sidan|Den valda sidan kunde inte hittas|página solicitada no existe|página solicitada ya no existe|La pagina che stai cercando non esiste|Die Seite wurde nicht gefunden|siden kan ikke vises|Siden ble ikke funnet|La page demandée n'a pu être trouvée|no hemos podido hallar la página)":
    return "Check 12"

  if body ~ "(?i)(Página no encontrada|La p[áa]gina que estabas buscando en este blog no existe|У вас нет доступа к этой странице|Strana koju tražite ne postoji|La página no existe|Sidan kunde inte hittas|Contenido no encontrado|mas esta página está apresentando um erro|page demandée n'existe|page n'existe pas|seite existiert leider nicht|sidan hittas tyvärr inte|Работа сайта приостановлена|Pagina nu a fost gasită|page n'a pas pu être trouvée|No Encontrado[,]? Error|El objeto no está disponible|Sidan kan inte hittas|La Page que vous demandez est introuvable|pagina richiesta non esiste|Pagina non disponibile|Página no encontrada|página seleccionada no existe)":
    return "Check 12.1"

  if body ~ "(?i)(페이지를 찾을 수 없습니다|ページが見つかりません)":
    return "Check 12.2"

#  if body ~ "(?i)(wayback machine doesn[']t have that page archived|bummer page not found)":
#    return "Check 13"

  if body ~ "(?i)(no results (that)?[ ]?matched (your)?[ ]?search|doesn[']t match any taxon or name records in the AFD)":
    return "Check 13.1"

  if body ~ "(?i)(requested (resource|url|article|page|file|content|document|object|item|video) (was not|wasn't|has) (unavailable|available|here|online|live|(be )?found|find|located|expired|delivered)|(page|article|url|resource|file|content|document|object|item|video) (could not|couldn't|can't|cannot) be (unavailable|available|here|online|live|(be )?found|find|located|delivered)|article not existed)":
    return "Check 14"

  if body ~ "(?i)(could not be (unavailable|available|here|online|live|found|find|located) on this server. The system administrator has been notified|not found[,]? error)":
    return "Check 14.1"

  if bodyHTML ~ "(?i)([>]Bad Request [(]Invalid Hostname[)][<])":
    return "Check 14.2"

  if body ~ "(?i)((the|this) (page|url|file|resource|content|document|object|item|video) (you|you've|you have) requested)" and body ~ "(?i)(was not (unavailable|available|here|online|live|(be )?found|find|located|delivered)|is not available)":
    return "Check 15.1"

  if body ~ "(?i)(your search session h?a?s?[ ]? expired)" and body ~ "(?i)(return to the search page and try again)":
    return "Check 15.2"

  if bodyHTML ~ "(?i)([<][ ]*service unavailable|(page|article|url|resource|content|document|object|item|video) (is|was) temporarily unavailable|you (are|were) looking for a (page|article|url|resource|file|content|document|object|item|video) that (does not|doesn[']?t) exist|(page|article|url|resource|file|content|document|object|item|video) (does not|doesn[']?t) exist)":
    return "Check 16"

  if body ~ "(?i)(please retry after some time|account suspended|Sorry, No posts to display|We apologize for the inconvenience but the page you are trying to view is not available)":
    return "Check 16.2"

#    if a ~ "(?i)(wayback machine doesn't have that page)":
#      return "Check 17.b"


  return "OK"

