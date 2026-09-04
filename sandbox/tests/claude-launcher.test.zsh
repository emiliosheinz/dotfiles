#!/usr/bin/env zsh
# The host-owned claude launcher runs the highest installed version.
set -uo pipefail
here="${0:A:h}"
launcher="${here}/../../scripts/.local/bin/claude"
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

# Through the real chain: shell function -> sandbox-run ->
# ~/.local/bin/claude -> highest version. Needs the host launcher installed.
real_versions="${HOME}/.local/share/claude/versions"
if [[ -d "${real_versions}" && "$(readlink "${HOME}/.local/bin/claude")" == *dotfiles/scripts/.local/bin/claude ]]; then
    stub="${real_versions}/99.0.0"
    trap 'rm -f "${stub}"; rm -rf "${tmp}"' EXIT
    printf '#!/bin/sh\necho stub-version\n' > "${stub}"; chmod +x "${stub}"
    out=$(cd "${HOME}/dotfiles" && zsh -c 'source ~/.aliases.zsh; claude --version' 2>/dev/null </dev/null)
    check "shell function runs the 99.0.0 stub through the sandbox" '[[ "$out" == stub-version ]]'
    rm -f "${stub}"
    out=$(cd "${HOME}/dotfiles" && zsh -c 'source ~/.aliases.zsh; claude --version' 2>/dev/null </dev/null)
    check "after removal the previously installed version runs" '[[ "$out" == *"(Claude Code)"* ]]'
else
    print "SKIP host launcher not installed (~/.local/bin/claude is not the dotfiles script)"
fi
exit $fail
