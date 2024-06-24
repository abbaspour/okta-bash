#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-05-09
# License: MIT (https://github.com/abbaspour/okta-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-d domain] [-c client_id] [-u username] [-p password] [-x client_secret] [-a server_id] [-s scope] [-h|-v]
        -e file        # .env file location (default cwd)
        -d domain      # Okta domain
        -c client_id   # Okta client ID
        -x secret      # Okta client secret
        -a id          # authorization server id
        -u username    # Username or email
        -p password    # Password
        -s scopes      # comma separated list of scopes (default is "${AUTH0_SCOPE}")
        -h|?           # usage
        -v             # verbose

eg,
     $0 -d amin.oktapreview.com -c ccc -u me@there.com -p somepass
END
  exit $1
}

declare OKTA_DOMAIN=''

declare client_id=''
declare authorizationServerId=''

declare response_type='id_token'
declare scope='openid profile email'
declare grant_type='password'

declare token_endpoint='/oauth2/v1/token'
declare http_basic=1

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "d:c:x:a:r:u:s:p:bhv?" opt; do
    case ${opt} in
    d) OKTA_DOMAIN=${OPTARG} ;;
    c) client_id=${OPTARG} ;;
    x) client_secret=${OPTARG} ;;
    a) authorization_endpoint="/oauth2/${OPTARG}/v1/authorize" ;;
    u) username=${OPTARG} ;;
    p) password=${OPTARG} ;;
    b) http_basic=1 ;;
    s) scope=$(echo "${OPTARG}" | tr ',' ' ') ;;
    v) set -x ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${OKTA_DOMAIN}" ]] && {  echo >&2 "ERROR: OKTA_DOMAIN undefined";  usage 1;  }
[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined";  usage 1; }

[[ -z "${username}" ]] && { echo >&2 "ERROR: username undefined"; usage 1; }
[[ -z "${password}" ]] && { echo >&2 "ERROR: password undefined"; usage 1; }

declare secret=''
declare authorization_header=''

if [[ ${http_basic} -eq 1 ]]; then
  authorization_header=$(printf "%s:%s" "${client_id}" "${client_secret}" | openssl base64 -e -A)
else
  [[ -n "${client_secret}" ]] && secret="&client_secret=${client_secret}"
  [[ -n "${code_verifier}" ]] && secret+="&code_verifier=${code_verifier}"
fi

if [[ -n "${kid}" && -n "${private_pem}" && -f "${private_pem}" ]]; then
  readonly assertion=$(../clients/client-assertion.sh -d "${OKTA_DOMAIN}" -i "${client_id}" -k "${kid}" -f "${private_pem}")
  readonly client_assertion=$(
    cat <<EOL
  , "client_assertion" : "${assertion}",
  "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
EOL
  )
else
  readonly client_assertion=''
fi

declare -r BODY="grant_type=${grant_type}&username=${username}&password=${password}&scope=${scope}"

[[ ${OKTA_DOMAIN} =~ ^http ]] || OKTA_DOMAIN=https://${OKTA_DOMAIN}

if [[ ${http_basic} -eq 1 ]]; then
  curl --request POST \
    -H "Authorization: Basic ${authorization_header}" \
    --url "${OKTA_DOMAIN}${token_endpoint}" \
    --data "${BODY}"
else
  curl --request POST \
    --url "${OKTA_DOMAIN}${token_endpoint}" \
    --data "${BODY}"
fi

