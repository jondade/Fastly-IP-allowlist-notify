#! /bin/bash
#
# Allowlist-cron.sh
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
# If you have any bugs or issues with this script you can find assitance
# in the Fastly community forum at https://community.fastly.com/
#
# If you would like to submit a pull request or patch, please do so at my
# github repository: https://github.com/jondade/Fastly-IP-allowlist-notify
#
# License: MIT
# Use of this script is entirely at the user's own risk. No warranty
# is offered or implied.

# Configuration variables.
# Update these as necessary.
EMAIL_RECIPIENTS=""

#
# No user serviceable parts after this point. Any changes are at the
# editors own risk. No support is offered.
#


# This will install the script to the /sbin directory for running.
function install {
  echo "Please enter your list of email recipients. One per line. Blank line to finish."
  ADDRESSES=$(read_addresses)
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
  elif [ -z "$ADDRESSES" ]; then
    echo "Email recipients is not valid. Please try again."
    exit 8
  elif ! find_command sed; then
    echo "Could not find sed command. Cannot continue. Please install sed or manually install this script." >&2
    exit 9
  fi

  # Duplicate this script into SCRIPTNAME and set permissions
  cp "$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"  ${SCRIPTNAME}
  chmod 755 ${SCRIPTNAME}

  # Set up some vars from random to make sure the Fastly API is not smashed all at once.
  # by default this runs once a week.
  minute=$(getnum 60)
  hour=$(getnum 24)
  day=$(getnum 7)

  # Need to ensure the addresses are valid.

  sed -i -e "s/EMAIL_RECIPIENTS=\"\"/EMAIL_RECIPIENTS=\"${ADDRESSES}\"/" ${SCRIPTNAME}
  echo "$minute $hour * * $day ${SCRIPTNAME} -r" >> /etc/crontab

  if [[ ! -e ${DATA_PATH} ]]; then
    mkdir -p ${DATA_PATH}
  fi

  DATA=$(fetchIPData)
  echo "${DATA}" | md5sum > ${CURRENT_IP_MD5}
  echo "${DATA}" > ${CURRENT_IP_DATA}

  echo "Initial data for IP allowlisting:"
  echo "${DATA}"
  echo
  echo "Mailing recipients first data to test."

  MESSAGE=$(cat <<-EOM
      The Fastly allowlist IP json data are:

      $DATA

      Please ensure the firewalls allow these IPs.
EOM
)

  echo "${MESSAGE}" | mail -E -s 'Fastly allowlist intial set' "${ADDRESSES}"

}

function fetchIPData () {
  curl -s 'https://api.fastly.com/public-ip-list'
}

function getnum () {
  out=${RANDOM}
  let "out %= $1"
  echo $out
}

function trim_sum_data () {
  echo $1 | sed -e 's/^\([A-Za-z0-9]\+\)\s.*/\1/'
}

function run {
  # We don't need to keep the actual data. Lets save disk space and just keep MD5s.
  OLD_MD5=$( trim_sum_data $(cat ${CURRENT_IP_MD5}) )
  NEW_DATA=$(fetchIPData)

  NEW_MD5=$( trim_sum_data $(echo ${NEW_DATA} | md5sum ) )

  if [ "${OLD_MD5}" == "${NEW_MD5}" ]; then
    echo "No ip changes."
    exit 0;
  else
    if [[ ${DEBUG} == "true" ]]; then
      echo ${NEW_MD5} > ${CURRENT_IP_MD5}
      echo ${NEW_DATA} > ${CURRENT_IP_DATA}
    fi
    UPDATED_MESSAGE=$(cat <<-EOM
      The Fastly allowlist checksum did not match in the latest check. An update to the allowlisting
      rules may be required.

      The lastest json data is:

      ${NEW_DATA}
EOM
)
    echo "${UPDATED_MESSAGE}" | mail -E -s 'Fastly allowlist updated' "${EMAIL_RECIPIENTS}"
    exit $?
  fi
}

function showhelp {
  cat <<OEM
Usage: $(basename $0) <args>
  Possible arguments are:
    i     install this script.
    r     run the script to verify the MD5 / email recipients of an update.
    h     show this message.
    v     show debug output.
  N.B. This is a simple bash script, please read it for bug/pull request details.
OEM

}

function find_command () {
  command -v $1 >/dev/null
}

function read_addresses () {
  loop="true"
  read email
  list="${email}"
  while ( "${loop}" == "true" ); do
    read email
    if [[ "${email}" == "" ]]; then
      loop="false";
    else
      list="${list} ${email}"
    fi
  done
  echo "${list}"
}

#
# Real script starts here
#

# Static variables for reuse later.
API_URL="https://api.fastly.com/public-ip-list"
SCRIPTNAME="/usr/local/sbin/fastly-ips.sh"
DATA_PATH="/var/spool/fastly"
CURRENT_IP_MD5="${DATA_PATH}/fastly-IP.md5"
CURRENT_IP_DATA="${DATA_PATH}/fastly-IP.json"
DEBUG="false"

if [[ $# -lt 1 ]]; then
  echo "Not enough arguments."
  showhelp
  exit 1
fi

while getopts "irvh" opt; do
  case "${opt}" in
    h)
      showhelp
      exit 0
      ;;
    v)
      DEBUG="true"
      set -e
      set -x
      ;;
    r)
      run
      ;;
    i)
      install
      ;;
  esac
done

# If we get here something went wrong....

# Insert non-obligatory quote
