#!/usr/bin/env zsh
# Runs every unit test in this directory; --smoke adds the smoke matrix.
# Must run from an unsandboxed shell.
set -uo pipefail
here="${0:A:h}"
fail=0
run() { print -- "== $1"; "${@:2}" || fail=1 }
for t in "${here}"/*.test.zsh; do run "${t:t}" zsh "${t}"; done
for t in "${here}"/*.test.mjs; do run "${t:t}" node "${t}"; done
[[ "${1:-}" == --smoke ]] && run smoke.zsh zsh "${here}/../smoke.zsh"
exit $fail
