

#
# Return the network location
#  "https://www.cwi.nl:80/guido&path.ht, -> www.cwi.nl:80
#
function uriparseNetloc(str,   safe) {

  safe = str
  gsub(/'/, "'\\''", safe)
  gsub(/’/, "'\\’'", save)
  out = Exe["python3"] " -c \"from urllib.parse import urlparse, quote; import sys; o = urlparse(sys.argv[1]); print(o.netloc)\" '" str "'"

}

#
# URL-endecode - encode or decode
#
#  eg. urlendecode("Władysław T. Benda", "encode")
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
# url-encode via nim (fast)
#
function urlencodenim(str) {
   return strip(sys2var(Exe["urlendecode"] " -e \"" str "\""))
}

#
# url-decode via nim (fast)
#
function urldecodenim(str) {
   return strip(sys2var(Exe["urlendecode"] " -d \"" str "\""))
}

#
# url-encode via Python (slow)
#  Credit: https://askubuntu.com/questions/53770/how-can-i-encode-and-decode-percent-encoded-strings-on-the-command-line
#     See for other options
#
function urlencodepython(str,   command) {          

   # python -c "import urllib, sys; print urllib.quote(sys.argv[1])" "Emil Młynarski"
   command = Exe["python"] " -c \"import urllib, sys; print urllib.quote(sys.argv[1])\" \"" str "\""
   return strip(sys2var(command))
}

#
# url-decode via Python (slow)
#  Credit: https://askubuntu.com/questions/53770/how-can-i-encode-and-decode-percent-encoded-strings-on-the-command-line
#     See for other options
#
function urldecodepython(str,   command) {

   # python -c "import urllib, sys; print urllib.quote(sys.argv[1])" "Emil%20M%C5%82ynarski"
   command = Exe["python"] " -c \"import urllib, sys; print urllib.unquote(sys.argv[1])\" \"" str "\""
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
