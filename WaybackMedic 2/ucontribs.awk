#!/usr/local/bin/gawk -E

# ucontribs.awk
#  -- download user contribs for daterange 
#
# ./ucontribs.awk -n <name> -s <start> -e <end>  
#
#    name   = Wikipedia userid without the "User:" portion
#    start  = start date in form 20150601 (ie. June 1 2015)
#    end    = end date
#
#  If start and end date are the same it will be for that 24hr period.
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

@include "getopt.awk"
@include "init.awk"
@include "library.awk"

BEGIN {

        Maxlag = 10

        while ((C = getopt(ARGC, ARGV, "n:s:e:")) != -1) {
          opts++
          if(C == "n")                         # -n <name>    Name of entity 
            entity = verifyval(Optarg)
          if(C == "s")                         # -s <date>    Start date to get results eg. 20160214
            sdate = verifyval(Optarg)
          if(C == "e")                         # -e <date>    End date to get results eg. 20160215 (if same as start does 24hr range)
            edate = verifyval(Optarg)
        }

        if(entity == "" || sdate == "" || edate == "") {
          print 0
          exit
        }

        entity = gensub(" ","_","g",entity)
        sdate = sdate "000000"
        edate = edate "235959"

        if ( ! ucontribs(entity,sdate,edate) )
          print 0
     
        print "Total sources rescued: " totalc > "/dev/stderr"

}

function ucontribs(entity,sdate,edate,      url, results) {

        gsub(" ","_",entity)

        # MediaWiki namespace codes
        #  https://www.mediawiki.org/wiki/Extension_default_namespaces
        # Sample API call
        #  url = "http://en.wikipedia.org/w/api.php?action=query&list=usercontribs&ucuser=Cyberbot_II&uclimit=500&ucstart=20160214000000&ucend=20160214235959&ucdir=newer&ucnamespace=0&ucprop=title|comment&format=xml&maxlag=5"

        url = "http://en.wikipedia.org/w/api.php?action=query&list=usercontribs&ucuser=" entity "&uclimit=500&ucstart=" sdate "&ucend=" edate "&ucdir=newer&ucnamespace=0&ucprop=title|parsedcomment&format=xml&maxlag=" Maxlag

        results = getapiresults(url, entity) 

        results = uniq(results)
        if ( length(results) > 0) 
          print results
        return length(results)

}

function getapiresults(url, entity,          xmlin, xmlout, continuecode) {

        xmlin = http2var(url)
        xmlout = parsexml(xmlin)
        continuecode = getcontinue(xmlin, method)

        while ( continuecode ) {
            url = "http://en.wikipedia.org/w/api.php?action=query&list=usercontribs&ucuser=" entity "&uclimit=500&continue=-||&uccontinue=" continuecode "&ucstart=" sdate "&ucend=" edate "&ucdir=newer&ucnamespace=0&ucprop=title|parsedcomment&format=xml&maxlag=" Maxlag
            xmlin = http2var(url)
            xmlout = xmlout "\n" parsexml(xmlin)
            continuecode = getcontinue(xmlin)
        }

        return xmlout
}

function parsexml(xmlin,   f,g,e,c,a,i,b,d,out,comment,title,dest1,dest2){

  f = split(xmlin,e,/<usercontribs>|<\/usercontribs>/)
  c = split(e[2],a,"/>")

  while(++i < c) {
    if(a[i] ~ /[<]item userid[=]/) {
      match(a[i], /title="[^\"]*"/,k) 
      split(gensub("title=","","g",k[0]), g, "\"")
      title = convertxml(g[2])
      match(a[i], /parsedcomment="[^\"]*"/,k)
      comment = gensub("parsedcomment=","","g",k[0])
      if(comment ~ /Rescuing [0-9]{1,} sources/) {
        out = out title "\n"
        match(comment, /Rescuing [0-9]{1,} sources/, dest1)
        match(dest1[0], /[ ][0-9]{1,}[ ]/, dest2)
        totalc = totalc + strip(dest2[0])
      }
      #out = out title "\n"
    }
  }
  return out

}

function getcontinue(xmlin,      re,a,b,c) {

        # eg. <continue uccontinue="20160214061737|704890823" continue="-||"/>
        match(xmlin, /uccontinue="[^\"]*"/, a)
        split(a[0], b, "\"")
        if ( length(b[2]) > 0)
            return b[2]
        return 0
}


#
# Uniq a list of \n separated names
#
function uniq(names,    b,c,i,x) {

        c = split(names, b, "\n")
        names = "" # free memory
        while (i++ < c) {
            if(b[i] ~ "for API usage") {
                print "ucontribs.awk: Max lag exceeded. Try again when servers less busy or increase Maxlag variable. See https://www.mediawiki.org/wiki/Manual:Maxlag_parameter." > "/dev/stderr"
                print 0
                exit
            }
            if(b[i] == "")
                continue
            if(x[b[i]] == "")
                x[b[i]] = b[i]
        }
        delete b # free memory
        return join2(x,"\n")
}

