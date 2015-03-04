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


while getopts "irh"; do
  case $opt in
    i)
      install
      ;;
    r)
      run
      ;;
    h)
      showhelp
      ;;
  esac
done

# Let's make sure mail is there.
if ! which -s mail;
then
  echo "Mail command not found. Cannot continue." >&2
  exit 5
elif ! which -s curl; then
  echo "Curl command not found. Cannot continue." >&2
  exit 6
fi

OLD_MD5=`cat "$CURRENT_IPS_FILE"

NEW_DATA=`curl https://api.fastly.com/public-ip-list -H "Fastly-Key:$API_KEY"`