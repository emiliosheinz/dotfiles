#!/usr/bin/env zsh
# ws workspace from WS_WORKSPACE, and ws verbs inside a
# session re-dispatch through hostrun with the argv untouched.
set -uo pipefail
here="${0:A:h}"
ws="${here}/../../scripts/.local/scripts/tmux-workspace-manager"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${tmp}/bin"
printf '#!/bin/zsh\nprint -r -- "$@" > "%s/hostrun.argv"\nexit 0\n' "${tmp}" > "${tmp}/bin/hostrun"; chmod +x "${tmp}/bin/hostrun"
fail=0
check() { if eval "$2"; then print "ok   $1"; else print "FAIL $1"; fail=1; fi }

out=$(env -u TMUX WS_WORKSPACE=wsA bash "${ws}" workspace); rc=$?
check "ws workspace prints WS_WORKSPACE without tmux" '(( rc == 0 )) && [[ "$out" == wsA ]]'
out=$(env -u TMUX -u WS_WORKSPACE bash "${ws}" workspace 2>&1); rc=$?
check "ws workspace outside tmux and without WS_WORKSPACE still fails" '(( rc != 0 ))'

rm -f "${tmp}/hostrun.argv"
SANDBOX_SESSION_ID=1-2 WS_WORKSPACE=wsA PATH="${tmp}/bin:${PATH}" bash "${ws}" wt add repo -b main; rc=$?
check "inside a session, ws wt add re-dispatches through hostrun verbatim" '(( rc == 0 )) && [[ "$(cat "${tmp}/hostrun.argv")" == "ws wt add repo -b main" ]]'
rm -f "${tmp}/hostrun.argv"
SANDBOX_SESSION_ID=1-2 WS_WORKSPACE=wsA PATH="${tmp}/bin:${PATH}" bash "${ws}" switch other; rc=$?
check "inside a session, ws switch is routed too" '(( rc == 0 )) && [[ "$(cat "${tmp}/hostrun.argv")" == "ws switch other" ]]'
rm -f "${tmp}/hostrun.argv"
out=$(SANDBOX_SESSION_ID=1-2 WS_WORKSPACE=wsA PATH="${tmp}/bin:${PATH}" bash "${ws}" workspace)
check "inside a session, ws workspace stays local" '[[ "$out" == wsA && ! -e "${tmp}/hostrun.argv" ]]'
out=$(env -u SANDBOX_SESSION_ID -u TMUX PATH="${tmp}/bin:${PATH}" bash "${ws}" wt add 2>&1); rc=$?
check "outside a session, ws wt add keeps its own validation (no hostrun)" '(( rc != 0 )) && [[ ! -e "${tmp}/hostrun.argv" ]]'
exit $fail
