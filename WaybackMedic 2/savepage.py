#!/usr/bin/python

import pywikibot, sys

# Usage: savepage [article name] [edit comment] [local file]

f = open(sys.argv[3], 'r')
newtext = f.read()

articlename = sys.argv[1].decode('utf-8')
editcomment = sys.argv[2].decode('utf-8')

site = pywikibot.Site('en', 'wikipedia')  # The site we want to run our bot on
page = pywikibot.Page(site, articlename)
page.text = newtext.decode('utf-8')
page.save(editcomment)  # Saves the page

f.close()
