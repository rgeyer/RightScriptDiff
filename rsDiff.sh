#!/bin/bash

[ -f rsDiffAuth.sh ] && source rsDiffAuth.sh

# Setup some utilities for changing text color and weight.
bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
reset=$(tput sgr0)

info=${bold}${blue}
success=${bold}${green}
failure=${bold}${red}

# Check if the user supplied anything as input params.
if [ $# -gt 0 ]; then
  for arg in $@
  do
    # Check for two forms of email input -e<email_address> and --email=<email_address>
    [ -n "`echo $arg | grep '\-e'`" ] && login=`echo $arg | sed 's/-e\(.*\)/\1/'`
    [ -n "`echo $arg | grep '\--email='`" ] && login=`echo $arg | sed 's/--email=\(.*\)/\1/'`

    # Check for two forms of password input -p<password> and --password=<password>
    [ -n "`echo $arg | grep '\-p'`" ] && password=`echo $arg | sed 's/-p\(.*\)/\1/'`
    [ -n "`echo $arg | grep '\--password='`" ] && password=`echo $arg | sed 's/--password=\(.*\)/\1/'`

    # Check for two forms of account input -a<account_id> and --account_id=<account_id>
    [ -n "`echo $arg | grep '\-a'`" ] && account=`echo $arg | sed 's/-a\(.*\)/\1/'`
    [ -n "`echo $arg | grep '\--account_id='`" ] && account=`echo $arg | sed 's/--account_id=\(.*\)/\1/'`

    # Check for two forms of script list input -s<path_to_scripts> and --path_to_scripts=<path_to_scripts>
    [ -n "`echo $arg | grep '\-s'`" ] && path_to_scripts=`echo $arg | sed 's/-s\(.*\)/\1/'`
    [ -n "`echo $arg | grep '\--path_to_scripts='`" ] && path_to_scripts=`echo $arg | sed 's/--path_to_scripts=\(.*\)/\1/'`
  done
fi

if [ -z "$login" ]; then
  echo "${info}Please enter your my.rightscale.com account email address...${reset}"
  read login
fi
if [ -z "$password" ]; then
  echo "${info}Please enter your my.rightscale.com account password...${reset}"
  read password
fi
if [ -z "$account" ]; then
  echo "${info}Please enter your my.rightscale.com account number...${reset}"
  read account
fi
if [ -z "$path_to_scripts" ]; then
  echo "${info}Please enter the path to scripts stored locally...${reset}"
  read path_to_scripts
fi

tempDir="/tmp/rsDiff_`date +%Y%m%d%H%M`"

[ ! -d "$tempDir" ] && mkdir -p "$tempDir"

authCookieName="$tempDir/rsAuthCookie"
scriptsResponse="$tempDir/right_scripts.xml"

curl -c $authCookieName -u "$login":"$password" https://my.rightscale.com/api/acct/$account/login?api_version=1.0

echo "${info}Grabbing all RightScripts for user: $login on account: $account.  Be patient, this could take a while...${reset}"
# We're grabbing all of the scripts for the account.  If we've got a particulary busy account, this could be a bad choice.
curl -k -H 'X-API-VERSION:1.0' -b $authCookieName https://my.rightscale.com/api/acct/$account/right_scripts.xml > $scriptsResponse

OIFS=$IFS
IFS=$(echo -en "\n\b")
for script in $path_to_scripts
do
  scriptId=`basename "$script" | grep -o '^[0-9]*'`
  xpath $scriptsResponse "//right-script[href='https://my.rightscale.com/api/acct/$account/right_scripts/$scriptId']/script" | sed 's/<script>//' | sed 's/<\/script>//' | perl -mHTML::Entities -n -e 'print HTML::Entities::decode_entities($_)' > "$tempDir/$scriptId.sh"
  diffResult=`diff -b -y --suppress-common-lines "$script" "$tempDir/$scriptId.sh"`
  if [ -z "$diffResult" ]; then
    echo "${success}Local copy of `basename $script` does not differ from RightScale copy.${reset}"
  else
    echo "${failure}Local copy of `basename $script` differs from RightScale copy.. Diff below..${reset}"
    echo "$diffResult"
  fi
done
IFS=$OIFS

rm -rf "$tempDir"