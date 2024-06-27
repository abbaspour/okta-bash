#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-06-24
# License: MIT (https://github.com/abbaspour/okta-bash/blob/master/LICENSE)
##########################################################################################

set -ueo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found";  exit 3; }
command -v awk >/dev/null || { echo >&2 "error: awk not found";  exit 3; }
command -v sed >/dev/null || { echo >&2 "error: sed not found";  exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-d domain] [-D preview] [-A api_token] [-f file] [-t type] [-C|-I|-v|-h]
        -e file        # .env file location (default cwd)
        -A token       # SSWS token
        -d domain      # Okta domain
        -D domain      # Okta preview domain
        -f file        # output file name. default is 'okta_apps.json'
        -t type        # saml, oidc or all (default)
        -C             # fetch credentials
        -I             # include inactive apps
        -h|?           # usage
        -v             # verbose

eg,
     $0 -d test.oktapreview.com
END
  exit $1
}

declare yourOktaDomain=''
declare applicationIdAppend=''
declare output='okta_apps.json'
declare app_type='all'
declare q_status='.status == "ACTIVE"'

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"
[[ -f "${DIR}/../.env" ]] && . "${DIR}/../.env"

while getopts "e:A:d:D:f:t:IChv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  d) yourOktaDomain="${OPTARG}.okta.com";;
  D) yourOktaDomain="${OPTARG}.oktapreview.com";;
  A) api_token=${OPTARG} ;;
  f) output=${OPTARG} ;;
  t) app_type=${OPTARG} ;;
  I) q_status='.status == "ACTIVE" or .status == "INACTIVE"' ;;
  C) applicationIdAppend+="/credentials/secrets" ;;
  v) set -x ;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

declare q_type=''

case ${app_type} in
  oidc) q_type='.signOnMode == "OPENID_CONNECT"' ;;
  saml) q_type='.signOnMode == "SAML_2_0"' ;;
  all) q_type='.signOnMode == "SAML_2_0" or .signOnMode == "OPENID_CONNECT"' ;;
  *) echo >&2 "unknown app type ${app_type}"; exit 1;;
esac


[[ -z "${yourOktaDomain}" ]] && { echo >&2 "ERROR: yourOktaDomain undefined"; usage 1; }
[[ -z "${api_token}" ]] && { echo >&2 "ERROR: api_token undefined"; usage 1; }

# Temporary file to store responses
TEMP_FILE=`mktemp`

# Initial API endpoint
API_ENDPOINT="https://${yourOktaDomain}/api/v1/apps"

# Function to fetch and append applications to the temporary file
fetch_apps() {
  local url=$1

  # Fetch the current page of applications and headers
  local response=$(curl -s -D - -X GET "$url" \
    -H "Accept: application/json" \
    -H "Authorization: SSWS ${api_token}")

  # Extract and filter active applications
  echo "$response" | sed -n '/^\r$/,$p' | jq -c ".[] | select((${q_status}) and (${q_type}))" >> $TEMP_FILE

  # Extract the next link from the Link header
  next_link=$(echo "$response" | awk -F'[<>]' '/rel="next"/ {print $2}')

  echo "${next_link}"
}

# Initialize the temporary file
> $TEMP_FILE

# Fetch the first page of applications
declare next_url=$API_ENDPOINT

while [[ -n "${next_url}" ]]; do
  next_url=$(fetch_apps "$next_url")
done

# Combine all application objects into a single JSON array and save to the output file
jq -s '.' $TEMP_FILE > "${output}"

# Remove the temporary file
rm $TEMP_FILE

# Check if the file was created successfully
if [[ -f "${output}" ]]; then
  echo "List of Okta applications has been saved to ${output}"
else
  echo "Failed to save the applications list to ${output}"
  exit 1
fi

