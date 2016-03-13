WaybackMedic bot
===================
by User:Green Cardamom (en.wikipedia.org)
March 2016
MIT License

Info
========
Source code for WaybackMedic bot.
GNU Awk 4.1

The core functionality is medic.awk. driver.awk "drives" (executes) medic, which in turn is executed by GNU Parellel
project is a tool for creating new batches of articles for processing
bug is a tool to view article diffs after processing to see what changes medic proposed
demon-* is the communication layer with AWB 
When running AWB, if the demon detects changes to an article since medic processed it, it will reprocess the article real-time to prevent unintended reverts

Installation
==================
The install instructions are in 0INSTALL

Credits
==================
Want to use MediaWiki API with Awk? Check out 'MediaWiki Awk API Library'
https://github.com/greencardamom/MediaWikiAwkAPI


