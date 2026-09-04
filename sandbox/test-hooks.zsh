#!/usr/bin/env zsh
# SBOX-41 (hook record from Claude Code hook JSON), SBOX-42 (sandbox-note),
# SBOX-44/45 (append discipline: no session, cap reached, malformed input).
set -uo pipefail
here="${0:A:h}"
hook="${here}/../scripts/.local/scripts/sandbox-denial-hook"
note="${here}/../scripts/.local/scripts/sandbox-note"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
log="${tmp}/log.jsonl"; : > "${log}"
export SANDBOX_SESSION_LOG="${log}" SANDBOX_SESSION_ID="123-45" WS_WORKSPACE="wsA"
fail=0
check() { if eval "$2"; then print "ok   $1"; else print "FAIL $1"; fail=1; fi }
last() { tail -n 1 "${log}" }

post_tool_use='{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/id_ed25519"},"tool_response":{"stdout":"","stderr":"cat: /private/var/fixture/.ssh/id_ed25519: Operation not permitted","interrupted":false}}'
print -r -- "${post_tool_use}" | zsh "${hook}"; rc=$?
check "PostToolUse denial: exit 0" '(( rc == 0 ))'
check "PostToolUse denial: hook record with cmd" '[[ "$(last | jq -r .src)" == hook && "$(last | jq -r .cmd)" == "cat ~/.ssh/id_ed25519" ]]'
check "PostToolUse denial: snippet holds the matching output" '[[ "$(last | jq -r .snippet)" == *"Operation not permitted"* ]]'
check "PostToolUse denial: session and ws tagged" '[[ "$(last | jq -r .session)" == 123-45 && "$(last | jq -r .ws)" == wsA ]]'

failure='{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"tmux ls"},"error":"error connecting to /private/tmp/tmux-501/default (Operation not permitted)"}'
print -r -- "${failure}" | zsh "${hook}"
check "PostToolUseFailure error: hook record" '[[ "$(last | jq -r .cmd)" == "tmux ls" && "$(last | jq -r .snippet)" == *"Operation not permitted"* ]]'

long=$(printf 'EPERM %0.s' {1..200})
print -r -- "{\"tool_input\":{\"command\":\"x\"},\"tool_response\":{\"stderr\":\"${long}\"}}" | zsh "${hook}"
check "snippet capped at 400 characters" '(( $(last | jq -r ".snippet | length") == 400 ))'

n=$(wc -l < "${log}")
print -r -- '{"tool_input":{"command":"ls"},"tool_response":{"stdout":"file\n","stderr":""}}' | zsh "${hook}"; rc=$?
check "clean output: exit 0, nothing written" '(( rc == 0 && $(wc -l < "${log}") == n ))'
print -r -- 'not json at all' | zsh "${hook}"; rc=$?
check "malformed JSON: exit 0, nothing written" '(( rc == 0 && $(wc -l < "${log}") == n ))'
print -r -- "${post_tool_use}" | SANDBOX_SESSION_LOG= zsh "${hook}"; rc=$?
check "unset SANDBOX_SESSION_LOG: exit 0, nothing written" '(( rc == 0 && $(wc -l < "${log}") == n ))'

big="${tmp}/big.jsonl"; mkfile -n 20m "${big}"
print -r -- "${post_tool_use}" | SANDBOX_SESSION_LOG="${big}" zsh "${hook}"; rc=$?
check "log at 20 MB: exit 0, append skipped" '(( rc == 0 && $(stat -f %z "${big}") == 20 * 1024 * 1024 ))'

zsh "${note}" "docker ps" "check whether the dev stack is up"; rc=$?
check "sandbox-note two args: exit 0, note record" '(( rc == 0 )) && [[ "$(last | jq -r .src)" == note && "$(last | jq -r .want)" == "docker ps" && "$(last | jq -r .why)" == "check whether the dev stack is up" ]]'
zsh "${note}" "open a URL"; rc=$?
check "sandbox-note one arg: why empty" '(( rc == 0 )) && [[ "$(last | jq -r .why)" == "" && "$(last | jq -r .want)" == "open a URL" ]]'
SANDBOX_SESSION_LOG="${big}" zsh "${note}" "x" "y"; rc=$?
check "sandbox-note at 20 MB: exit 0, append skipped" '(( rc == 0 && $(stat -f %z "${big}") == 20 * 1024 * 1024 ))'
exit $fail
