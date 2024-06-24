#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-04-04
# License: MIT (https://github.com/abbaspour/okta-bash/blob/master/LICENSE)
##########################################################################################

set -ueo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-d domain] [-D preview] [-i idp_id] [-a api_token] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # SSWS token
        -d domain      # Okta domain
        -D domain      # Okta preview domain
        -i id          # IdP id
        -h|?           # usage
        -v             # verbose

eg,
     $0 -d test.oktapreview.com
END
  exit $1
}

declare yourOktaDomain=''
declare idpId=''

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"
[[ -f "${DIR}/../.env" ]] && . "${DIR}/../.env"

while getopts "e:a:d:D:i:hv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  d) yourOktaDomain="${OPTARG}.okta.com";;
  D) yourOktaDomain="${OPTARG}.oktapreview.com";;
  i) idpId="${OPTARG}";;
  a) api_token=${OPTARG} ;;
  v) set -x ;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${yourOktaDomain}" ]] && { echo >&2 "ERROR: yourOktaDomain undefined"; usage 1; }
[[ -z "${api_token}" ]] && { echo >&2 "ERROR: api_token undefined"; usage 1; }
[[ -z "${idpId}" ]] && { echo >&2 "ERROR: idpId undefined"; usage 1; }

curl -s -X GET -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: SSWS ${api_token}" "https://${yourOktaDomain}/api/v1/idps/${idpId}/credentials/keys" | jq .