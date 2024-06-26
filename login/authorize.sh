#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-01-12
# License: MIT (https://github.com/abbaspour/okta-bash/blob/master/LICENSE)
# #########################################################################################

set -euo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare OKTA_DOMAIN=''

declare client_id=''
declare authorizationServerId=''

declare response_type='token id_token'
declare redirect_uri='https://jwt.io'
declare scope='openid profile email'
declare prompt=''
declare response_mode=''
declare idp=''

declare authorization_endpoint='/oauth2/default/v1/authorize'

declare opt_flow='implicit'
declare opt_state='state'
declare opt_nonce='nonce'
declare opt_login_hint=''
declare opt_clipboard=0
declare opt_pp=1
declare opt_open=''
declare opt_browser=''

command -v jq >/dev/null || { echo >&2 "error: jq not found";  exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-d domain] [-c client_id] [-a server_id] [-r idp] [-R response_type] [-f flow] [-u callback] [-s scope] [-p prompt] [-M mode] [-P|-m|-C|-N|-o|-h]
        -d domain      # Okta domain
        -c client_id   # Okta client ID
        -A id          # authorization server id (default is "default")
        -r id          # IdP ID to use as realm
        -R types       # comma separated response types (default is "${response_type}")
        -f flow        # OAuth2 flow type (implicit,code,pkce,hybrid)
        -u callback    # callback URL (default ${redirect_uri})
        -s scopes      # comma separated list of scopes (default is "${scope}")
        -p prompt      # prompt type: none, silent, login, consent
        -M model       # response_mode of: fragment, form_post, query, okta_post_message
        -S state       # state
        -n nonce       # nonce
        -H hint        # login hint
        -C             # copy to clipboard
        -N             # no pretty print
        -o             # Open URL
        -b browser     # Choose browser to open (firefox, chrome, safari)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -d amin.okta.com -n "my nonce" -c c123 -C -f pkce
END
    exit $1
}

urlencode() {
    jq -rn --arg x "${1}" '$x|@uri'
}

base64_urlencode() {
    echo -n "$1" | base64 -w0 | tr '+' '-' | tr '/' '_' | tr -d '='
}

random() {
    # shellcheck disable=SC2034
    for i in {0..32}; do echo -n $((RANDOM % 10)); done
}

gen_code_verifier() {
    base64_urlencode "$(random)"
}

gen_code_challenge() {
    readonly cc=$(echo -n "$1" | openssl dgst -binary -sha256)
    base64_urlencode "$cc"
}

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "d:c:A:r:R:f:u:s:p:M:S:n:H:b:CNohv?" opt; do
    case ${opt} in
    d) OKTA_DOMAIN=${OPTARG} ;;
    c) client_id=${OPTARG} ;;
    A) authorization_endpoint="/oauth2/${OPTARG}/v1/authorize" ;;
    r) idp="${OPTARG}" ;;
    R) response_type=$(echo "${OPTARG}" | tr ',' ' ') ;;
    f) opt_flow=${OPTARG} ;;
    u) redirect_uri=${OPTARG} ;;
    p) prompt=${OPTARG} ;;
    M) response_mode=${OPTARG} ;;
    s) scope=$(echo "${OPTARG}" | tr ',' ' ') ;;
    S) opt_state=${OPTARG} ;;
    n) opt_nonce=${OPTARG} ;;
    H) opt_login_hint=${OPTARG} ;;
    C) opt_clipboard=1 ;;
    N) opt_pp=0 ;;
    o) opt_open=1 ;;
    b) opt_browser="-a ${OPTARG} " ;;
    v) set -x ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${OKTA_DOMAIN}" ]] && {  echo >&2 "ERROR: OKTA_DOMAIN undefined";  usage 1;  }
[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined";  usage 1; }

declare response_param=''

case ${opt_flow} in
  implicit) response_param="response_type=$(urlencode "${response_type}")" ;;
  *code) response_param='response_type=code' ;;
  pkce | hybrid)
    code_verifier=$(gen_code_verifier)
    code_challenge=$(gen_code_challenge "${code_verifier}")
    echo "code_verifier=${code_verifier}"
    response_param="code_challenge_method=S256&code_challenge=${code_challenge}"
    if [[ ${opt_flow} == 'pkce' ]]; then response_param+='&response_type=code'; else response_param+='&response_type=code%20token%20id_token'; fi
    ;;
  *) echo >&2 "ERROR: unknown flow: ${opt_flow}"
    usage 1
    ;;
esac

[[ ${OKTA_DOMAIN} =~ ^http ]] || OKTA_DOMAIN=https://${OKTA_DOMAIN}


declare authorize_params

authorize_params="client_id=${client_id}&${response_param}&nonce=$(urlencode "${opt_nonce}")&redirect_uri=$(urlencode "${redirect_uri}")&scope=$(urlencode "${scope}")"

[[ -n "${idp}" ]] && authorize_params+="&idp=${idp}"
[[ -n "${prompt}" ]] && authorize_params+="&prompt=${prompt}"
[[ -n "${response_mode}" ]] && authorize_params+="&response_mode=${response_mode}"
[[ -n "${opt_state}" ]] && authorize_params+="&state=$(urlencode "${opt_state}")"
[[ -n "${opt_login_hint}" ]] && authorize_params+="&login_hint=$(urlencode "${opt_login_hint}")"

declare authorize_url="${OKTA_DOMAIN}${authorization_endpoint}?${authorize_params}"

if [[ ${opt_pp} -eq 0 ]]; then
  echo "${authorize_url}"
else
    echo "${authorize_url}" | sed -E 's/&/ &\
    /g; s/%20/ /g; s/%3A/:/g;s/%2F/\//g'
fi

[[ -n "${opt_clipboard}" ]] && echo "${authorize_url}" | pbcopy
[[ -n "${opt_open}" ]] && open "${opt_browser}" "${authorize_url}"
