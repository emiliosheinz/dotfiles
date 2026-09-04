#!/usr/bin/env zsh
# install-broker.zsh: render and load the hostrun launchd job (idempotent).
# Renders sandbox/local.hostrun.plist.template with the real HOME into
# ~/Library/LaunchAgents/local.hostrun.plist, seeds the auto-approve list
# when absent, and (re)bootstraps the job. `--uninstall` removes it.
set -euo pipefail
here="${0:A:h}"
root="${HOME}/.local/state/agent-sandbox"
plist="${HOME}/Library/LaunchAgents/local.hostrun.plist"
label="local.hostrun"
domain="gui/$(id -u)"

if [[ "${1:-}" == --uninstall ]]; then
    launchctl bootout "${domain}/${label}" 2>/dev/null || true
    rm -f "${plist}"
    print "hostrun broker removed"
    exit 0
fi

command -v jq >/dev/null || { print -u2 "install-broker: jq is required"; exit 1 }
mkdir -p "${root}/inbox" "${root}/host" "${HOME}/Library/LaunchAgents"
[[ -e "${root}/host/auto-approve" ]] || cp "${here}/auto-approve.default" "${root}/host/auto-approve"
sed "s|SANDBOX_HOME_DIR|${HOME}|g" "${here}/local.hostrun.plist.template" > "${plist}.tmp"
plutil -lint -s "${plist}.tmp"
mv -f "${plist}.tmp" "${plist}"
launchctl bootout "${domain}/${label}" 2>/dev/null || true
launchctl bootstrap "${domain}" "${plist}"
launchctl print "${domain}/${label}" >/dev/null
print "hostrun broker installed: ${plist}"
