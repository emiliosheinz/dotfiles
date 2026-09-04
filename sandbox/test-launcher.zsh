#!/usr/bin/env zsh
# sandbox-run unit tests: CWD refusal (SBOX-01), tool preconditions (SBOX-54),
# repo validation (SBOX-04), agent resolution (SBOX-53), policy rendering
# (SBOX-50), session/environment contract (SBOX-17), process model (SBOX-09).
# Runs on the host; every launch renders a real policy.
set -uo pipefail
here="${0:A:h}"
launcher="${here}/../scripts/.local/scripts/sandbox-run"
tmp=$(mktemp -d)
stubs="${tmp}/stubs"; work="${tmp}/work"
mkdir -p "${stubs}" "${work}"
export SANDBOX_STATE_ROOT="${tmp}/state"
trap 'rm -rf "${tmp}"' EXIT
fail=0
check() { if eval "$2"; then print "ok   $1"; else print "FAIL $1"; fail=1; fi }
real_jq=$(command -v jq); real_safehouse=$(command -v safehouse)

# --- SBOX-01: unsafe launch directories -------------------------------------
for dir in / "${HOME}" "${HOME}/dev/.worktrees"; do
    out=$(cd "${dir}" && "${launcher}" claude 2>&1); rc=$?
    check "refuses CWD ${dir}" '(( rc != 0 )) && [[ "$out" == *"${dir}"* ]]'
done

# --- SBOX-54: host tool preconditions ---------------------------------------
out=$(cd "${work}" && PATH="${stubs}:/bin" "${launcher}" claude 2>&1); rc=$?
check "missing jq is named" '(( rc != 0 )) && [[ "$out" == *jq* ]]'
ln -s "${real_jq}" "${stubs}/jq"
out=$(cd "${work}" && PATH="${stubs}:/usr/bin:/bin" "${launcher}" claude 2>&1); rc=$?
check "missing safehouse is named" '(( rc != 0 )) && [[ "$out" == *safehouse* ]]'
printf '#!/bin/sh\necho "Agent Safehouse 0.9.0"\n' > "${stubs}/safehouse"; chmod +x "${stubs}/safehouse"
out=$(cd "${work}" && PATH="${stubs}:/usr/bin:/bin" "${launcher}" claude 2>&1); rc=$?
check "old safehouse names both versions" '(( rc != 0 )) && [[ "$out" == *0.9.0* && "$out" == *0.11.1* ]]'
rm "${stubs}/safehouse" "${stubs}/jq"

# --- SBOX-04: worktree CWD whose source repo is missing ---------------------
bogus_ws="${HOME}/dev/.worktrees/sbx-test-$$"
mkdir -p "${bogus_ws}/bogus-repo"
out=$(cd "${bogus_ws}/bogus-repo" && "${launcher}" claude 2>&1); rc=$?
rm -rf "${bogus_ws}"
check "bogus worktree repo is named" '(( rc != 0 )) && [[ "$out" == *bogus-repo* ]]'

# --- SBOX-50: rendered policy = generator header, then the scope file -------
policy=$(cd "${work}" && SANDBOX_RUN_PRINT_POLICY=1 "${launcher}" claude 2>&1); rc=$?
gen_line=$(print -r -- "${policy}" | grep -n ';; Source: 00-base.sb' | head -1 | cut -d: -f1)
scope_line=$(print -r -- "${policy}" | grep -n ';; ws-scope.sb' | head -1 | cut -d: -f1)
check "print-policy exits 0 with generator header" '(( rc == 0 )) && [[ -n "$gen_line" ]]'
check "scope rules follow the generator rules" '[[ -n "$scope_line" ]] && (( scope_line > gen_line ))'
check "print-policy selects the claude profile" '[[ "$policy" == *"Source: 60-agents/claude-code.sb"* ]]'
check "print-policy leaves no session behind" '[[ -z "$(ls "${SANDBOX_STATE_ROOT}/sessions" 2>/dev/null)" ]]'
policy=$(cd "${work}" && SANDBOX_RUN_PRINT_POLICY=1 "${launcher}" opencode 2>&1)
check "opencode selects the opencode profile" '[[ "$policy" == *"Source: 60-agents/opencode.sb"* ]]'

# --- SBOX-53 / SBOX-17: agent from PATH, environment contract ---------------
cat > "${stubs}/claude" <<'STUB'
#!/bin/zsh
env > "${PWD}/env.txt"
exit 0
STUB
chmod +x "${stubs}/claude"
(cd "${work}" && PATH="${stubs}:${PATH}" NPM_CONFIG_PREFIX=/nope "${launcher}" claude) ; rc=$?
envf="${work}/env.txt"
sid=$(grep '^SANDBOX_SESSION_ID=' "${envf}" 2>/dev/null | cut -d= -f2-)
check "agent resolved from PATH stub and ran" '(( rc == 0 )) && [[ -s "$envf" ]]'
check "SANDBOX_SESSION_ID exported" '[[ "$sid" == <->-<-> ]]'
check "SANDBOX_SESSION_LOG points into the session dir" 'grep -qx "SANDBOX_SESSION_LOG=${SANDBOX_STATE_ROOT}/sessions/${sid}/log.jsonl" "$envf"'
check "WS_WORKSPACE exported (empty outside ~/dev)" 'grep -qx "WS_WORKSPACE=" "$envf"'
check "PATH starts with the tooldir" 'grep -q "^PATH=${work:A}/.tools/bin:" "$envf"'
check "NPM_CONFIG_PREFIX unset" '! grep -q "^NPM_CONFIG_PREFIX=" "$envf"'
check "session log created" '[[ -f "${SANDBOX_STATE_ROOT}/sessions/${sid}/log.jsonl" ]]'
meta="${SANDBOX_STATE_ROOT}/host/meta/${sid}.json"
check "host meta written with workdir" '[[ "$(jq -r .workdir "$meta")" == "${work:A}" ]]'
check "SANDBOX_RUN_AGENT_BIN override honoured" '(cd "${work}" && SANDBOX_RUN_AGENT_BIN="${stubs}/claude" "${launcher}" claude) && [[ -s "$envf" ]]'

# opencode absent from PATH: fall back to <brew prefix>/bin/opencode (SBOX-53)
mkdir -p "${tmp}/bin"
printf '#!/bin/zsh\nprint -r -- "$0" > "${PWD}/env.txt"\n' > "${tmp}/bin/opencode"; chmod +x "${tmp}/bin/opencode"
printf '#!/bin/sh\nexit 0\n' > "${stubs}/brew"; chmod +x "${stubs}/brew"
ln -sf "${real_jq}" "${stubs}/jq"; ln -sf "${real_safehouse}" "${stubs}/safehouse"
rm -f "${envf}"
(cd "${work}" && PATH="${stubs}:/usr/bin:/bin" "${launcher}" opencode 2>/dev/null); rc=$?
check "opencode falls back to the brew prefix" '(( rc == 0 )) && [[ "$(cat "$envf")" == "${tmp}/bin/opencode" ]]'
rm -f "${stubs}/brew" "${stubs}/jq" "${stubs}/safehouse"
# --- SBOX-09: exit status, signals, supervisor lifetime ---------------------
cat > "${stubs}/claude" <<'STUB'
#!/bin/zsh
exit 7
STUB
(cd "${work}" && PATH="${stubs}:${PATH}" "${launcher}" claude 2>/dev/null); rc=$?
check "agent exit status propagated" '(( rc == 7 ))'
queues=("${SANDBOX_STATE_ROOT}"/sessions/*/requests(N)); logs=("${SANDBOX_STATE_ROOT}"/sessions/*/log.jsonl(N))
check "session queue removed after exit, log kept" '(( ${#queues} == 0 && ${#logs} > 0 ))'

cat > "${stubs}/claude" <<'STUB'
#!/bin/zsh
trap 'echo SIGTERM > "${PWD}/signal.txt"; exit 143' TERM
echo $$ > "${PWD}/agent.pid"
while :; do sleep 1; done
STUB
wait_for() { local i; for i in {1..50}; do eval "$1" && return 0; sleep 0.1; done; return 1 }
rm -f "${work}/agent.pid" "${work}/signal.txt"
(cd "${work}" && PATH="${stubs}:${PATH}" "${launcher}" claude 2>/dev/null) &
lpid=$!
wait_for '[[ -s "${work}/agent.pid" ]]'
kill -TERM "${lpid}"
wait "${lpid}"; rc=$?
check "SIGTERM forwarded to the agent" '[[ "$(cat "${work}/signal.txt" 2>/dev/null)" == SIGTERM ]]'
check "launcher exits with the agent's status after SIGTERM" '(( rc == 143 ))'

rm -f "${work}/agent.pid"
(cd "${work}" && PATH="${stubs}:${PATH}" "${launcher}" claude 2>/dev/null) &
lpid=$!
wait_for '[[ -s "${work}/agent.pid" ]]'
sid=$(ls -t "${SANDBOX_STATE_ROOT}/host/meta" | head -1 | sed 's/\.json$//')
sup=$(jq -r .supervisor_pid "${SANDBOX_STATE_ROOT}/host/meta/${sid}.json")
kill -KILL "$(cat "${work}/agent.pid")"
start=$SECONDS
wait "${lpid}"; rc=$?
check "SIGKILLed agent: launcher exits within 5 s with 137" '(( SECONDS - start <= 5 && rc == 137 ))'
check "SIGKILLed agent: supervisor gone" '! kill -0 "${sup}" 2>/dev/null'

rm -f "${work}/agent.pid"
(cd "${work}" && PATH="${stubs}:${PATH}" "${launcher}" claude 2>/dev/null) &
lpid=$!
wait_for '[[ -s "${work}/agent.pid" ]]'
sid=$(ls -t "${SANDBOX_STATE_ROOT}/host/meta" | head -1 | sed 's/\.json$//')
sup=$(jq -r .supervisor_pid "${SANDBOX_STATE_ROOT}/host/meta/${sid}.json")
kill -KILL "${lpid}"; wait "${lpid}" 2>/dev/null
check "SIGKILLed launcher: supervisor exits within 5 s" 'wait_for "! kill -0 ${sup} 2>/dev/null"'
kill -KILL "$(cat "${work}/agent.pid")" 2>/dev/null
exit $fail
