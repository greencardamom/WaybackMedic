WaybackMedic bot
===================
Bot info page at Wikipedia: https://en.wikipedia.org/wiki/User:Green_Cardamom/WaybackMedic_2 

by User:Green Cardamom (en.wikipedia.org)
March 2016
MIT License

Caution
=======
Version 2.0 is outdated and has many small bugs that are fixed in 2.1 - it's not recommended for production use. Version 2.1 will be uploaded sometime in the future. If you need it sooner please contact me on Wikipedia.

Source
========
Nim 0.13.1
GNU Awk 4.1

The core functionality is medic.nim which copiles to a binary executable "medic"

driver.awk "drives" (executes) medic, which in turn is executed by GNU Parallel in batches

project.awk is a tool for creating and managing batches of articles for processing by medic

bug.awk is a tool to view article diffs after processing to see what changes medic proposed

demon-* is the communication layer with AWB - deprecated with WaybackMedic2 in favor of Pywikibot

Install and operate
==================
Install instructions 0INSTALL

Operating instructions 0RUN

Credits
==================
Want to use MediaWiki API with Awk? Check out 'MediaWiki Awk API Library'
https://github.com/greencardamom/MediaWikiAwkAPI


