#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-v|-h]
        -e file        # .env file location (default cwd)
        -d domain      # Okta domain
        -D domain      # Okta preview domain
        -i id          # IdP id
        -h|?           # usage
        -v             # verbose

eg,
     $0 -D test -i 123abc
END
    exit $1
}

declare yourOktaDomain=''
declare idpId=''

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"
[[ -f "${DIR}/../.env" ]] && . "${DIR}/../.env"

while getopts "e:i:d:D:hv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  d) yourOktaDomain="${OPTARG}.okta.com";;
  D) yourOktaDomain="${OPTARG}.oktapreview.com";;
  i) idpId="${OPTARG}";;
  v) set -x ;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${yourOktaDomain}" ]] && { echo >&2 "ERROR: yourOktaDomain undefined"; usage 1; }
[[ -z "${idpId}" ]] && { echo >&2 "ERROR: idpId undefined"; usage 1; }

curl -s --request GET \
    -o sp-${yourOktaDomain}-metadata.xml \
    --url "https://${yourOktaDomain}/api/v1/idps/${idpId}/metadata.xml"


