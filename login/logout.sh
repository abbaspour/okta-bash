#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-01-31
# License: MIT (https://github.com/abbaspour/okta-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail
declare OKTA_DOMAIN=''
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-d domain] [-c client_id] [-i id_token] [-b browser] [-f|-C|-o|-h]
        -d domain      # Okta domain
        -i id_token    # id_token hint
        -r uri         # post logout redirect_uri
        -s state       # (optional) state
        -C             # copy to clipboard
        -o             # Open URL
        -b browser     # Choose browser to open (firefox, chrome, safari)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -d amin -i xxx.xxx.xxx -C
END
    exit $1
}

urlencode() {
    jq -rn --arg x "${1}" '$x|@uri'
}

declare OKTA_DOMAIN=''

declare id_token_hint=''
declare state=''
declare post_logout_redirect_uri=''
declare opt_browser=''

while getopts "d:b:i:s:r:Cohv?" opt; do
    case ${opt} in
    d) OKTA_DOMAIN=${OPTARG} ;;
    i) id_token_hint=${OPTARG} ;;
    s) state=${OPTARG} ;;
    r) post_logout_redirect_uri=${OPTARG} ;;
    C) opt_clipboard=1 ;;
    o) opt_open=1 ;;
    b) opt_browser="-a ${OPTARG} " ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${id_token_hint}" ]] && {  echo >&2 "ERROR: id_token_hint undefined";  usage 1;  }

[[ -z ${OKTA_DOMAIN} ]] && {
  OKTA_DOMAIN=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${id_token_hint}")
}

[[ ${OKTA_DOMAIN} =~ ^http ]] || OKTA_DOMAIN=https://${OKTA_DOMAIN}

declare logout_url

logout_url="${OKTA_DOMAIN}/oauth2/v1/logout?"

logout_url+="id_token_hint=${id_token_hint}&"

[[ -n "${state}" ]] && logout_url+="state=${state}&"
[[ -n "${post_logout_redirect_uri}" ]] && logout_url+="post_logout_redirect_uri=$(urlencode "${post_logout_redirect_uri}")&"

echo "${logout_url}"

[[ -n "${opt_clipboard}" ]] && echo "${logout_url}" | pbcopy
[[ -n "${opt_open}" ]] && open "${opt_browser}" "${logout_url}"
