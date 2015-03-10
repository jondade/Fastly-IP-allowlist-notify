#! /bin/bash
#
# Whitelist-cron.sh
# A script which can run as a cron job and notifies if the list
# of Fastly IPs has changed compared to the previous known list.
#
# Stores the list of 'current' IPs in CURRENT_IPS_FILE and uses diff
# to see if this has changed.
#
# Make sure to insert an API key in the variable prior to use. Note
# that this is in clear text so this file should be accessible to
# as few people as possible to maintain security
#
# License: MIT
# Use of this script is entirely at the user's own risk. No warranty
# is offered or implied.

# Configuration variables.
# Update these as necessary.
API_URL="https://api.fastly.com/list-all-ips"
CURRENT_IPS_FILE="/var/spool/Fastly-IPs"
API_KEY=""
EMAIL_RECIPIENTS=""

#
# Changelog
# 0.0.1
#   J Dade
#   Created first version to start testing.
#   Todo:
#     1: Curl request and diff for changes.
#     2: Mail for noitification of a change.
#     3: Create install function which can add the cron job and 
#         modify the script's options
#     4: Make notification modular / plugable for alternate methods
#
# No user serviceable parts after this point. Any changes are at the
# editors own risk. No support is offerec
#

function install {  
  # Let's make sure required commands can be found is there.
  if ! which -s mail;
  then
    echo "Mail command not found. Cannot continue." >&2
    exit 5
  elif ! which -s curl; then
    echo "Curl command not found. Cannot continue." >&2
    exit 6
  elif ! which -s md5sum -a ! which -s md5;
    echo "No MD5 tool found. Please install one and retry." >&2
    exit 7
  fi

  # Duplicate this script into /sbin/fastly-ips.sh and set permissions
  cat "$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")" > /sbin/fastly-ips.sh
  chown 0:0 chmod 700 /sbin/fastly-ips.sh

  # Set up some vars from random to make sure the Fastly API is not smashed all at once.
  # by default this runs once a week.
  minute=$(getnum 60)
  hour=$(getnum 24)
  day=$(getnum 7)

  echo "$minute $hour * * $day /sbin/fastly-ips.sh -r" >> /etc/crontab
}

function getnum () {
  out=$RANDOM
  let "out %= $1"
  echo $out
}

function run {


  # We don't need to keep the actual data. Lets save disk space and just keep MD5s.
  OLD_MD5=`cat "$CURRENT_IPS_FILE"`
  NEW_DATA=`curl https://api.fastly.com/public-ip-list -H "Fastly-Key:$API_KEY"`

  NEW_MD5=$(echo $NEW_DATA | md5sum)

  if [ "$OLD_MD5" == "$NEW_MD5" ]; then
    echo "No ip changes."
    exit 0;
  else
    UPDATED_MESSAGE=$(cat <<-EOM
      The fastly whitelist checksum did not match in the latest check. An update to the whitelisting
      rules may be required.

      The lastest json data is:

      $NEW_DATA
EOM
)
    echo "$UPDATED_MESSAGE" | mail -E -s 'Fastly whitelist updated' "$EMAIL_RECIPIENTS"
    exit $?
  fi
}

function showhelp {
  cat <<OEM
Usage: $(basename "$(test -L "$0" && readlink "$0" || echo "$0")") <args>
  Possible arguments are:
    i     install this script.
    r     run the script to verify the MD5 / email recipients of an update.
    h     show this message
OEM

}

#
# Real script starts here
#
if [ "$#" -lt 1 ]; then
  echo "Not enough arguments."
  showhelp
  exit 1
fi

while getopts "irh" opt; do
  case "$opt" in
    i)
      install
      ;;
    r)
      run
      ;;
    h)
      showhelp
      exit 0
      ;;
  esac
done

# If we get here something went wrong....

