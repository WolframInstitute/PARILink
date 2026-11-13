#!/bin/sh
# Print the machine name that the Wolfram job container must have.
#
# A license line (mathpass) is issued for one machine name. WOLFRAM_MATHPASS_B64 holds the
# line, base64-encoded: machine name, MathID, activation key and password, with tabs between
# them. The name is its first part. Without a license line the name is parilink-ci.
#
# The CI and Release workflows give this name to the job container as its host name; see
# CONTRIBUTING.md, "Continuous integration". Only the name is printed, never the rest of the line.
set -eu

# Read the line as bytes, so that no tool reports text that is not valid in the locale.
LC_ALL=C
export LC_ALL

default_name=parilink-ci
encoded=${WOLFRAM_MATHPASS_B64:-}

if [ -z "$encoded" ]; then
    printf '%s\n' "$default_name"
    exit 0
fi

fail() {
    echo "license-machine-name: WOLFRAM_MATHPASS_B64 must be the base64 text of a license line that starts with a machine name." >&2
    exit 1
}

decoded=$(printf '%s' "$encoded" | base64 -d 2>/dev/null) || fail
# The first line that is not blank and not a comment holds the license.
name=$(printf '%s\n' "$decoded" | awk -F '\t' '!/^[ \t\r]*%/ && !/^[ \t\r]*$/ { print $1; exit }' 2>/dev/null) || fail

# The name goes into the options of the container, so accept only a plain host name.
case "$name" in
    '' | -* | .* | *[!A-Za-z0-9.-]*) fail ;;
esac
[ "${#name}" -le 63 ] || fail

printf '%s\n' "$name"
