#
# Collection of various URI encode/decode techniques
#

#
# Given a URI, return percent-encoded in the hostname (limited), path and query portion only. 
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
  scheme = sys2var(command)
  if(scheme ~ /^http/)
    return scheme
}

#
#  optional wrapper for other functions
#    eg. urlendecode("Władysław T. Benda", "encode")
#
function urlendecode(str,type,     command)
{
    if(type ~ /encode/)
      return strip(urlencodenim(str))
    else if(type ~ /decode/)
      return strip(urldecodenim(str))
    else
      return str
}             

#
# urlendecode.nim
#
# #
# # urlendecode - fast URL encode/decode
# #
# # Feb 2016
# #
# import os,cgi
# proc usage() =
#   echo ""
#   echo " urlendecode -- encode or decode a URL"
#   echo ""
#   echo "     Usage:"
#   echo "            -e <string>      Encode a string"
#   echo "            -d <string>      Decode a string"
#   echo ""
#   echo "     Example:"
#   echo "            urlendecode -e \"Władysław T. Benda\""
#   echo ""
#   quit(1)
#
# if commandLineParams().len != 2:
#   usage()
#
# let
#   myswitch = commandLineParams()[0]
#   mystring = commandLineParams()[1]
#
# if myswitch == "-e":
#   echo encodeUrl(mystring)
# elif myswitch == "-d":
#   echo decodeUrl(mystring)
# else:
#   usage()
#
# ------------------
# To re-compile:
#
#  1. Download and install Nim programming language
#
#  2. Compile and test:
#
#     nim c -r urlendecode.nim -e "Władysław T. Benda"
#
#  3. Make distribution:
#
#     nim -d:release --opt:size c urlendecode.nim && strip -s urlendecode
#

#
# url-encode via nim 
#
function urlencodenim(str) {
   return strip(sys2var(Exe["urlendecode"] " -e \"" str "\""))
}

#
# url-decode via nim 
#
function urldecodenim(str) {
   return strip(sys2var(Exe["urlendecode"] " -d \"" str "\""))
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
# url-encode a string (flawed code breaks on certain characters but does so silently)
#  Credit: Rosetta Stone May 2015
#
function urlencodeawk(str,  c, len, res, i, ord) {

        for (i = 0; i <= 255; i++)
                ord[sprintf("%c", i)] = i
        len = length(str)
        res = ""
        for (i = 1; i <= len; i++) {
                c = substr(str, i, 1);
                if (c ~ /[0-9A-Za-z]/)
                        res = res c
                else
                        res = res "%" sprintf("%02X", ord[c])
        }
        return res
}

#
# URL-decode awk method. Unreliable with stuff like all-part-of-%E2%80%98jawn%E2%80%99
#  Adaption credit: http://www.shelldorado.com/scripts/cmds/urldecode
#
function urldecode(url,  hextab,decoded,len,i,c,c1,c2,code,encodedLF,str) {

        str = url
        encodedLF = 0 # set to 1 to decode linefeed character

        hextab ["0"] = 0;       hextab ["8"] = 8;
        hextab ["1"] = 1;       hextab ["9"] = 9;
        hextab ["2"] = 2;       hextab ["A"] = hextab ["a"] = 10
        hextab ["3"] = 3;       hextab ["B"] = hextab ["b"] = 11;
        hextab ["4"] = 4;       hextab ["C"] = hextab ["c"] = 12;
        hextab ["5"] = 5;       hextab ["D"] = hextab ["d"] = 13;
        hextab ["6"] = 6;       hextab ["E"] = hextab ["e"] = 14;
        hextab ["7"] = 7;       hextab ["F"] = hextab ["f"] = 15;

        decoded = ""
        i   = 1
        len = length (str)
        while ( i <= len ) {
            c = substr (str, i, 1)
            if ( c == "%" ) {
                if ( i+2 <= len ) {
                    c1 = substr (str, i+1, 1)
                    c2 = substr (str, i+2, 1)
                    if ( hextab [c1] == "" || hextab [c2] == "" ) {
                        print "WARNING (urldecode): invalid hex encoding: %" c1 c2 > "/dev/stderr"
                    } else {
                        code = 0 + hextab [c1] * 16 + hextab [c2] + 0
                        #print "\ncode=", code
                        c = sprintf ("%c", code)
                        i = i + 2
                    }
                } else {
                    print "WARNING (urldecode): invalid % encoding: " substr (str, i, len - i) > "/dev/stderr"
                }
            } else if ( c == "+" ) {    # special handling: "+" means " "
                c = "+"                 # GreenC mod - retain +
            }
            decoded = decoded c
            ++i
        }
        if ( encodedLF ) {
            return decoded      # no line newline on output
        } else {
            return decoded
        }
}


function testurlendecode() {

  print "Test string: Władysław T. Benda"
  print ""
  print "urlencodenim()    = " urlencodenim("Władysław T. Benda")
  print "urlencodepython() = " urlencodepython("Władysław T. Benda")
  print "urlencodepython() = " urlencodepython("Władysław T. Benda")
  print ""
  print "urldecodenim()    = " urldecodenim("Władysław T. Benda")
  print "urldecodepython() = " urldecodepython("Władysław T. Benda")
  print "urldecodepython() = " urldecodepython("Władysław T. Benda")

}

#                
# URL-encode limited set of characters needed for Wikipedia templates
#    https://en.wikipedia.org/wiki/Template:Cite_web#URL
#
function urlencodelimited(url,  safe) {

  safe = url
  gsub(/[ ]/, "%20", safe)
  gsub(/["]/, "%22", safe)
  gsub(/[']/, "%27", safe)
  gsub(/[<]/, "%3C", safe)
  gsub(/[>]/, "%3E", safe)
  gsub(/[[]/, "%5B", safe)
  gsub(/[]]/, "%5D", safe)
  gsub(/[{]/, "%7B", safe)
  gsub(/[}]/, "%7D", safe)
  gsub(/[|]/, "%7C", safe)
  return safe

}

