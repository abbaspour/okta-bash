#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-07-04
# License: MIT (https://github.com/abbaspour/okta-bash/blob/master/LICENSE)
##########################################################################################

set -ueo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function urlencode() {
    jq -rn --arg x "${1}" '$x|@uri'
}

function usage() {
  cat <<END >&2
USAGE: $0 [-d domain] [-c client_id] [-x client_secret] [-s scope] [-v|-h]
        -d domain      # Okta domain
        -c client_id   # client ID
        -x secret      # client secret
        -A id          # authorization server id (default is "default")
        -b             # HTTP Basic authentication (default is POST payload)
        -k kid         # client public key jwt id
        -f private.pem # client private key pem file
        -s scope       # scopes
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin.okta.com -c aIioQEeY7nJdX78vcQWDBcAqTABgKnZl -x XXXXXX
END
  exit $1
}

declare OKTA_DOMAIN=''
declare client_id=''
declare client_secret=''
declare http_basic=0
declare kid=''
declare private_pem=''
declare authorization_server='default'
declare scope=''

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "d:c:A:x:k:f:s:bhv?" opt; do
  case ${opt} in
  d) OKTA_DOMAIN=${OPTARG} ;;
  c) client_id=${OPTARG} ;;
  x) client_secret=${OPTARG} ;;
  A) authorization_server="${OPTARG}";;
  k) kid=${OPTARG} ;;
  f) private_pem=${OPTARG} ;;
  s) scope=$(echo "${OPTARG}" | tr ',' ' ') ;;
  b) http_basic=1 ;;
  v) set -x ;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${OKTA_DOMAIN}" ]] && { echo >&2 "ERROR: OKTA_DOMAIN undefined"; usage 1; }
[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined"; usage 1; }
[[ -z "${scope}" ]] && { echo >&2 "ERROR: scope undefined"; usage 1; }

declare secret=''
declare authorization_header=''

if [[ ${http_basic} -eq 1 ]]; then
  authorization_header=$(printf "%s:%s" "${client_id}" "${client_secret}" | openssl base64 -e -A)
else
  [[ -n "${client_secret}" ]] && secret="&client_secret=${client_secret}"
fi

if [[ -n "${kid}" && -n "${private_pem}" && -f "${private_pem}" ]]; then
  readonly assertion=$(./client-assertion.sh -d "${OKTA_DOMAIN}" -A "${authorization_server}" -i "${client_id}" -k "${kid}" -f "${private_pem}")
  readonly client_assertion="&client_assertion=${assertion}&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
else
  readonly client_assertion=''
fi

declare BODY="client_id=${client_id}&grant_type=client_credentials${secret}${client_assertion}&scope=${scope}"

[[ ${OKTA_DOMAIN} =~ ^http ]] || OKTA_DOMAIN=https://${OKTA_DOMAIN}

readonly token_endpoint="/oauth2/${authorization_server}/v1/token"

if [[ ${http_basic} -eq 1 ]]; then
  curl --request POST \
    -H "Authorization: Basic ${authorization_header}" \
    --url "${OKTA_DOMAIN}${token_endpoint}" \
    --data "${BODY}"
else
  curl --request POST \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --url "${OKTA_DOMAIN}${token_endpoint}" \
    --data "${BODY}"
fi

echo