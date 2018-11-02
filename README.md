WaybackMedic bot
===================
Bot info page at Wikipedia: https://en.wikipedia.org/wiki/User:GreenC/WaybackMedic_2.1 

by User:GreenC (en.wikipedia.org)
2016-2018
MIT License

Source
========
Nim 0.18.0
GNU Awk 4.1

The core functionality is medic.nim which compiles to a binary executable "medic"

driverm.awk "drives" (executes) medic, which in turn is executed by GNU Parallel in batches

projectm.awk is a tool for creating and managing batches of articles for processing by medic

bugm.awk is a tool to view article diffs after processing to see what changes medic proposed

Install and operate
==================
Install instructions 0INSTALL

Operating instructions 0RUN

Credits
==================
Want to use MediaWiki API with Awk? Check out 'BotWikiAwk'
https://github.com/greencardamom/BotWikiAwk
