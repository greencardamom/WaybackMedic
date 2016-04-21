WaybackMedic bot
===================
Bot info page at Wikipedia: https://en.wikipedia.org/wiki/User:Green_Cardamom/WaybackMedic

by User:Green Cardamom (en.wikipedia.org)
March 2016
MIT License

Source
========
Nim 0.13.1
GNU Awk 4.1

The core functionality is medic.nim. 

driver.awk "drives" (executes) medic, which in turn is executed by GNU Parallel in batches

project is a tool for creating and managing batches of articles for processing by medic

bug is a tool to view article diffs after processing to see what changes medic proposed

demon-* is the communication layer with AWB 

When running AWB, if the demon detects changes to an article since medic processed it, it will re-process the article real-time to prevent unintended reverts

Install and operate
==================
Install instructions 0INSTALL

Operating instructions 0RUN

Credits
==================
Want to use MediaWiki API with Awk? Check out 'MediaWiki Awk API Library'
https://github.com/greencardamom/MediaWikiAwkAPI


