#!/usr/bin/env bash

readonly b=$(basename "${1}")

openssl rsa -in "${1}" -out "converted-${b}" -traditional