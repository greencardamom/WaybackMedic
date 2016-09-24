#
# Search wikipedia dump for a string
#
#  XML parse code credit: Rob Speer (https://github.com/rspeer/wiki2text)
#
import re, options, strutils, os, streams, parsexml, awk

# Define search pattern here:

let mySearchRe = re"archive[.]org/w?e?b?/?[0-9]{1,14}/|[{][{][ ]?[Ww]ayback"

# Define location of Wikipedia dump here
#   Download: https://en.wikipedia.org/wiki/Wikipedia:Database_download#English-language_Wikipedia

let wpDump = "/mnt/WindowsFdriveTdir/wikipedia-dump/enwiki-20160820-pages-articles.xml"



var
  countAllArticle = 0 # All article count
  countArticle = 0    # Article titles containing a match (any number of matches)
  countHits = 0       # Number of matches of search pattern (running total)
  maxCount = 0        # Stop searching after X countArticle for speed testing. Set to 0 to find all.

type
  TagType = enum
    TITLE, TEXT, REDIRECT, NS
  ArticleData = array[TagType, string]

#
# Search text
#
proc searchText(article: ArticleData): bool {.discardable.} =
  var
    artcount = 0
    pos = -1
    # matches = newSeq[string](1)

  inc countAllArticle

  while pos < article[TEXT].len:
    pos = find(article[TEXT], mySearchRe, pos + 1)
    # pos = find(article[TEXT], mySearchRe, matches, pos + 1)
    if pos == -1: break
    inc artcount

  if artcount > 0:
    inc countArticle      # number of article titles matching
    countHits += artcount # number of matches of search pattern
    #echo article[TITLE], "----", artcount
    echo article[TITLE]
    result = true

  if maxCount > 0:
    if countArticle >= maxCount:
      echo ""
      echo "Articles all: ", countAllArticle
      echo "Articles with a match: ", countArticle
      echo "Number of pattern matches: ", countHits
      quit()

var
  RELEVANT_XML_TAGS = ["title", "text", "ns"]
  textBuffer = ""
  s = newFileStream(wpDump, fmRead)
  gettingText = false
  gettingAttribute = false
  article: ArticleData
  xml: XmlParser

if s == nil: quit("cannot open the file " & wpDump)
for tag in TITLE..NS: article[tag] = ""
xml.open(s, wpDump, options={reportWhitespace})

while true:
    # Scan through the XML, handling each token as it arrives.
    xml.next()
    case xml.kind
    of xmlElementStart, xmlElementOpen:
      if RELEVANT_XML_TAGS.contains(xml.elementName):
        # If this is a "title", "text", or "ns" tag, prepare to get its
        # text content. Move our writing pointer to the beginning of
        # the text buffer, so we can overwrite what was there.
        textBuffer.setLen(0)
        gettingText = true
      elif xml.elementName == "page":
        # If this is a new instance of the <page> tag that contains all
        # these tags, then reset the value that won't necessarily be
        # overridden, which is the redirect value.
        article[REDIRECT].setLen(0)
      elif xml.elementName == "redirect":
        # If this is the start of a redirect tag, prepare to get its
        # attribute value.
        gettingAttribute = true
    of xmlAttribute:
      # If we're looking for an attribute value, and we found one, add it
      # to the buffer.
      if gettingAttribute:
        textBuffer.add(xml.attrValue)
    of xmlCharData, xmlWhitespace:
      # If we're looking for text, and we found it, add it to the buffer.
      if gettingText:
        textBuffer.add(xml.charData)
    of xmlElementEnd:
      # When we reach the end of an element we care about, take the text
      # we've found and store it in the 'article' data structure. We can
      # accomplish this quickly by simply swapping their references.
      case xml.elementName
      of "title":
        swap article[TITLE], textBuffer
      of "text":
        swap article[TEXT], textBuffer
      of "redirect":
        swap article[REDIRECT], textBuffer
      of "ns":
        swap article[NS], textBuffer
      of "page":
        # When we reach the end of the <page> tag, send the article
        # data to searchText().
        searchText(article)
      else:
        discard

      # Now that we've reached the end of an element, stop extracting
      # text. (We'll never need to extract text from elements that can
      # have other XML elements nested inside them.)
      gettingText = false
      gettingAttribute = false

    of xmlEof:
      break

    else:
      discard
xml.close

"Search Wikipedia completed" >* "/dev/stderr"
"----" >* "/dev/stderr"
("Articles all: " & $countAllArticle) >* "/dev/stderr"
("Articles with a match: " & $countArticle) >* "/dev/stderr"
("Number of pattern matches: " & $countHits) >* "/dev/stderr"
