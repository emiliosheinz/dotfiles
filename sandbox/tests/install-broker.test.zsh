#!/usr/bin/env zsh
# install-broker.zsh unit test: renders against a temp HOME with a
# launchctl stub; running twice leaves the same end state and never
# overwrites an existing auto-approve list.
set -uo pipefail
here="${0:A:h}"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${tmp}/bin" "${tmp}/home"
cat > "${tmp}/bin/launchctl" <<'STUB'
#!/bin/zsh
print -r -- "$*" >> "${LAUNCHCTL_CALLS}"
STUB
chmod +x "${tmp}/bin/launchctl"
export LAUNCHCTL_CALLS="${tmp}/calls"
fail=0
check() { if eval "$2"; then print "ok   $1"; else print "FAIL $1"; fail=1; fi }
run() { (export HOME="${tmp}/home" PATH="${tmp}/bin:${PATH}"; zsh "${here}/../install-broker.zsh" >/dev/null) }

plist="${tmp}/home/Library/LaunchAgents/local.hostrun.plist"
approve="${tmp}/home/.local/state/agent-sandbox/host/auto-approve"
run; rc=$?
check "first run: exit 0, plist rendered and lint-clean" '(( rc == 0 )) && plutil -lint -s "${plist}"'
check "placeholder replaced with the real HOME in WatchPaths" '! grep -q SANDBOX_HOME_DIR "${plist}" && grep -q "<string>${tmp}/home/.local/state/agent-sandbox/inbox</string>" "${plist}"'
check "auto-approve seeded from the default list" 'cmp -s "${approve}" "${here}/../auto-approve.default"'
check "job booted out then bootstrapped" '[[ "$(sed -n 1p "${LAUNCHCTL_CALLS}")" == "bootout gui/$(id -u)/local.hostrun" && "$(sed -n 2p "${LAUNCHCTL_CALLS}")" == "bootstrap gui/$(id -u) ${plist}" ]]'

print '^custom$' > "${approve}"
sum1=$(md5 -q "${plist}")
run; rc=$?
check "second run: exit 0, plist byte-identical" '(( rc == 0 )) && [[ "$(md5 -q "${plist}")" == "${sum1}" ]]'
check "second run keeps the edited auto-approve list" '[[ "$(cat "${approve}")" == "^custom$" ]]'
check "second run reloads the job the same way" '(( $(wc -l < "${LAUNCHCTL_CALLS}") == 6 ))'
exit $fail
