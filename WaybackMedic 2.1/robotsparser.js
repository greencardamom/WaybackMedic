/*

  node robotsparser.js <robots.txt filename> <URL to parse>

  returns "false" if URL is blocked by robots.txt

  Uses node library: https://www.npmjs.com/package/robots-txt-parser

*/

const fs = require('fs');
var robotsParser = require('robots-txt-parser');
var robots = robotsParser(
  {
    userAgent: 'ia_archiver', // The default user agent to use when looking for allow/disallow rules, if this agent isn't listed in the active robots.txt, we use *.
    allowOnNeutral: true // The value to use when the robots.txt rule's for allow and disallow are balanced on whether a link can be crawled.
  });

robots.setUserAgent('ia_archiver');

// If robots.txt file exists
if (fs.existsSync(process.argv[2])) {
  // read it in to a string
  var content = fs.readFileSync(process.argv[2], 'utf8');
  // load string into parser as the active robots.txt
  robots.parseRobots('A1', content);
  // print to console if the URL (argv[3]) is allowed (true) or blocked (false)
  // console.log(robots.canCrawlSync(process.argv[3]));
  process.stdout.write(robots.canCrawlSync(process.argv[3]).toString());
  process.exit();
}

process.stdout.write("true");
process.exit();
