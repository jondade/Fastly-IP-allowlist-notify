#! /bin/bash
#
# Whitelist-cron.sh
# A script which can run as a cron job and notifies if the list
# of Fastly IPs has changed compared to the previous known list.
#
# This requires your system to have:
#    curl - a command line web client
#    md5(sum) - a command for calculating and checking sums of files
#    mail(x) - a command line mail/smtp client
#
#
# Stores the list of 'current' IPs in CURRENT_IPS_FILE and uses diff
# to see if this has changed.
#
# Make sure to insert an API key in the variable prior to use. Note
# that this is in clear text so this file should be accessible to
# as few people as possible to maintain security
#
# If you have any bugs or issues with this script you can find assitance
# in the fastly community forum at https://community.fastly.com/
#
# If you would like to submit a pull request or patch, please do so at my
# github repository: http://github.com/jondade/IP-whitelist-cron
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
# editors own risk. No support is offered.
#


# This will install the script to the /sbin directory for running.
function install {
  echo "Please enter your Fastly API key"
  read KEY
  echo "Please enter your list of email recipients. Please separate them with a ';' and use no spaces"
  read ADDRESSES
  # Let's make sure required commands can be found is there.
  if ! find_command mail; then
    echo "Mail command not found. Cannot continue." >&2
    exit 5
  elif ! find_command curl; then
    echo "Curl command not found. Cannot continue." >&2
    exit 6
  elif ! find_command md5sum -a ! which -s md5; then
    echo "No MD5 tool found. Please install one and retry." >&2
    exit 7
  elif [ -z $KEY -o -z $ADDRESSES ]; then
    echo "Key or email recipients was not valid. Please try again."
    exit 8
  elif ! find_command sed; then
    echo "Could not find sed command. Cannot continue. Please install sed or manually install this script." >&2
    exit 9
  fi

  # Duplicate this script into /sbin/fastly-ips.sh and set permissions
  cat "$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")" > /sbin/fastly-ips.sh
  chown 0:0 chmod 700 /sbin/fastly-ips.sh

  # Set up some vars from random to make sure the Fastly API is not smashed all at once.
  # by default this runs once a week.
  minute=$(getnum 60)
  hour=$(getnum 24)
  day=$(getnum 7)

  # Need to check the key for validity (?) and
  # ensure the addresses are valid.

  sed -i -e "s/API_KEY=\"\"/API_KEY=\"$KEY\"/" /sbin/fastly-ips.sh
  echo "$minute $hour * * $day /sbin/fastly-ips.sh -r" >> /etc/crontab

  fetchIPData | md5sum > $CURRENT_IPS_FILE
}

function fetchIPData () {
  curl https://api.fastly.com/public-ip-list -H "Fastly-Key:$API_KEY"
}

function getnum () {
  out=$RANDOM
  let "out %= $1"
  echo $out
}

function run {

  # We don't need to keep the actual data. Lets save disk space and just keep MD5s.
  OLD_MD5=`cat "$CURRENT_IPS_FILE"`
  NEW_DATA=$(fetchIPData)

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
  N.B. This is a simple bash script, please read it for bug/pull request details.
OEM

}

function find_command () {
  command -v $1 >/dev/null
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

# Insert non-obligatory quote