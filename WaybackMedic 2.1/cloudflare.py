#!/usr/bin/python
#
# Bypass Cloudflare DDOS protection with cfscrape library. 
#  https://github.com/Anorov/cloudflare-scrape
# Note: SSL doesn't work, use HTTP 
# If it stops working check for newer version
#
import cfscrape, sys

scraper = cfscrape.create_scraper()           # returns a CloudflareScraper instance
# Or: scraper = cfscrape.CloudflareScraper()  # CloudflareScraper inherits from requests.Session

if (sys.argv[1] == "content"):
	print scraper.get(sys.argv[2]).content
if (sys.argv[1] == "header"):
	print scraper.get(sys.argv[2]).headers

