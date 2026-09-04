#!/usr/bin/env zsh
# SBOX-16: the host-owned claude launcher runs the highest installed version.
set -uo pipefail
here="${0:A:h}"
launcher="${here}/../scripts/.local/bin/claude"
tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail=0
check() { if eval "$2"; then print "ok   $1"; else print "FAIL $1"; fail=1; fi }

versions="${tmp}/versions"; mkdir -p "${versions}"
for v in 2.0.0 10.0.0; do
    printf '#!/bin/sh\necho "stub-%s $*"\n' "$v" > "${versions}/${v}"; chmod +x "${versions}/${v}"
done
out=$(CLAUDE_VERSIONS_DIR="${versions}" zsh "${launcher}" --version)
check "picks highest by version sort with args" '[[ "$out" == "stub-10.0.0 --version" ]]'
rm "${versions}/10.0.0"
out=$(CLAUDE_VERSIONS_DIR="${versions}" zsh "${launcher}")
check "falls back to the previous version once removed" '[[ "$out" == "stub-2.0.0 " ]]'
rm "${versions}/2.0.0"
CLAUDE_VERSIONS_DIR="${versions}" zsh "${launcher}" 2>/dev/null; rc=$?
check "no versions installed exits non-zero" '(( rc != 0 ))'
exit $fail
