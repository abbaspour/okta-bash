#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-01-12
# License: MIT (https://github.com/abbaspour/okta-bash/blob/master/LICENSE)
# https://developer.okta.com/docs/guides/configure-native-sso/main/
##########################################################################################

set -ueo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function urlencode() {
    jq -rn --arg x "${1}" '$x|@uri'
}

function usage() {
  cat <<END >&2
USAGE: $0 [-d domain] [-c client_id] [-x client_secret] [-p code_verifier] [-u callback] [-a authorization_code] [-v|-h]
        -d domain      # Okta domain
        -c client_id   # client ID
        -x secret      # client secret
        -p verifier    # PKCE code_verifier (no secret required)
        -A id          # authorization server id (default is "default")
        -a code        # Authorization Code to exchange or id_token (if native SSO)
        -D code        # Device Code to exchange (switches to device_code flow)
        -S secret      # Device secret (switches to native SSO flow)
        -u callback    # callback URL (default is https://jwt.io)
        -b             # HTTP Basic authentication (default is POST payload)
        -U endpoint    # token endpoint URI (default is '/v1/token')
        -k kid         # client public key jwt id
        -f private.pem # client private key pem file
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin.okta.com -c aIioQEeY7nJdX78vcQWDBcAqTABgKnZl -x XXXXXX -a 803131zx232
END
  exit $1
}

declare OKTA_DOMAIN=''
declare client_id=''
declare client_secret=''
declare redirect_uri='https://jwt.io'
declare authorization_code=''
declare code_verifier=''
declare scope=''
declare device_secret=''
declare grant_type='authorization_code'
declare code_type='code'
declare http_basic=0
declare kid=''
declare private_pem=''
declare token_endpoint='/oauth2/default/v1/token'

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "d:c:u:A:a:x:p:D:U:k:f:S:s:bhv?" opt; do
  case ${opt} in
  d) OKTA_DOMAIN=${OPTARG} ;;
  c) client_id=${OPTARG} ;;
  x) client_secret=${OPTARG} ;;
  u) redirect_uri=${OPTARG} ;;
  A) token_endpoint="/oauth2/${OPTARG}/v1/token" ;;
  a) authorization_code=${OPTARG} ;;
  p) code_verifier=${OPTARG} ;;
  U) token_endpoint=${OPTARG} ;;
  k) kid=${OPTARG} ;;
  f) private_pem=${OPTARG} ;;
  D) code_type='device_code'; grant_type='urn:ietf:params:oauth:grant-type:device_code'; authorization_code=${OPTARG} ;;
  S) grant_type='urn:ietf:params:oauth:grant-type:token-exchange'; device_secret=${OPTARG} ;;
  s) scope=$(echo "${OPTARG}" | tr ',' ' ') ;;
  b) http_basic=1 ;;
  v) set -x ;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${OKTA_DOMAIN}" ]] && { echo >&2 "ERROR: OKTA_DOMAIN undefined"; usage 1; }
[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined"; usage 1; }
[[ -z "${redirect_uri}" ]] && { echo >&2 "ERROR: redirect_uri undefined"; usage 1; }
[[ -z "${authorization_code}" ]] && { echo >&2 "ERROR: authorization_code undefined"; usage 1; }

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

declare BODY="client_id=${client_id}&grant_type=${grant_type}&redirect_uri=${redirect_uri}${secret}${client_assertion}&scope=$(urlencode "${scope}")"

if [[ -z "${device_secret}" ]]; then
  BODY+="&${code_type}=${authorization_code}"
else
  BODY+="&actor_token=${device_secret}&actor_token_type=urn:x-oath:params:oauth:token-type:device-secret&subject_token=${authorization_code}&subject_token_type=urn:ietf:params:oauth:token-type:id_token&audience=$(urlencode "api://default")"
fi

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

echo