#
# Define hard-coded paths used by all programs
# Read project.cfg
#

BEGIN {

  # Directories should have a trailing slash
  Home = "/home/adminuser/wayback-medic/"

  # Ramdisk can be any directory. If you don't have one, set it to "/tmp/"
  Ramdisk = "/mnt/ramdisk/"

  # String included with http requests shows in remote logs. Include name of program and your contact info.
  Agent = "WaybackMedic: en.wikipedia.org/wiki/User:Green_Cardamom/WaybackMedic"

  Exe["rm"] = "/bin/rm"
  Exe["mv"] = "/bin/mv"
  Exe["cp"] = "/bin/cp"
  Exe["ls"] = "/bin/ls"
  Exe["chmod"] = "/bin/chmod"
  Exe["test"] = "/usr/bin/test"
  Exe["grep"] = "/bin/grep"
  Exe["wc"] = "/usr/bin/wc"
  Exe["diff"] = "/usr/bin/diff"
  Exe["sort"] = "/usr/bin/sort"
  Exe["head"] = "/usr/bin/head"
  Exe["tail"] = "/usr/bin/tail"
  Exe["date"] = "/bin/date"
  Exe["sleep"] = "/bin/sleep"
  Exe["awk"] = "/usr/local/bin/awk"
  Exe["wget"] = "/usr/bin/wget"
  Exe["mkdir"] = "/bin/mkdir"
  Exe["uuidgen"] = "/usr/bin/uuidgen"

  Exe["jq"] = "/usr/bin/jq"  # Version 1.5 

  Exe["medic"] = Home "medic.awk"
  Exe["bug"] = Home "bug.awk"

  # If you have installed wdiff (for color inline diffs)
  Exe["coldiff"] = Home "coldiff"
 
  delete Config
  readprojectcfg()
 
}

#
# Read project.cfg into Config[]
#
function readprojectcfg(  a,b,c,i,p) {

  checkexists(Home "project.cfg", "init.awk", "exit")

  c = split(readfile(Home "project.cfg"), a, "\n")
  while(i++ < c){
    if(a[i] == "" || substr(a[i],1,1) ~ /#/) # Ignore comment lines starting with #
      continue
    if(a[i] ~ /^default.id/) {
      split(a[i],b,"=")
      Config["default"]["id"] = strip(b[2])
    }
    if(a[i] ~ /[.]data/) {
      split(a[i], b, "=")
      p = gensub(/[.]data$/,"","g",strip(b[1]))
      Config[p]["data"] = strip(b[2])
    }
    if(a[i] ~ /[.]meta/) {
      split(a[i], b, "=")
      p = gensub(/[.]meta$/,"","g",strip(b[1]))
      Config[p]["meta"] = strip(b[2])
    }
  }

}
